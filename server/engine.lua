-- Orquestrador AUTORITATIVO do servidor. Sem natives: tudo que toca o jogo/Qbox entra por `env`
-- (ver server/main.lua e tests/test_engine.lua). Cliente envia so intencoes (passo de scroll, qtd, texto).
local economy = require 'core.economy'
local profiles = require 'core.profiles'
local probability = require 'core.probability'
local negotiation = require 'core.negotiation'
local rollguard = require 'core.roll_guard'
local sessionmod = require 'core.session'
local ledgermod = require 'core.ledger'
local dialogue = require 'core.dialogue'

local M = {}
M.__index = M

M.ERR_TEXT = {
    not_ready = 'Sistema indisponivel no momento.', no_player = 'Jogador nao carregado.',
    bad_payload = 'Requisicao invalida.', dead_or_vehicle = 'Voce nao pode negociar agora.',
    already_in_session = 'Voce ja esta em uma negociacao.', ped_invalid = 'Esta pessoa nao esta disponivel.',
    ped_dead = 'Esta pessoa nao esta em condicoes de conversar.', bucket = 'Esta pessoa nao esta disponivel.',
    too_far = 'Chegue mais perto.', ped_unverified = 'Esta pessoa nao pode ser abordada.',
    ped_not_ambient = 'Esta pessoa nao pode ser abordada.', ped_blocked = 'Esta pessoa nao pode ser abordada.',
    no_stock = 'Voce nao tem mercadoria suficiente.', police_unavailable = 'Sistema indisponivel no momento.',
    cooldown = 'Aguarde um pouco antes de abordar de novo.', ped_busy = 'Alguem ja esta falando com essa pessoa.',
    no_session = 'Negociacao encerrada.', not_owner = 'Negociacao invalida.', expired = 'A negociacao expirou.',
    bad_seq = 'Requisicao invalida.', replay_or_out_of_order = 'Requisicao duplicada.',
    too_many_turns = 'Conversa longa demais. A pessoa perdeu o interesse.', rate_limited = 'Calma! Muitas acoes seguidas.',
    busy = 'Aguarde a resposta.', moved_away = 'Voce se afastou.', ped_gone = 'A pessoa foi embora.',
    bad_step = 'Preco invalido.', step_out_of_range = 'Preco invalido.', bad_quantity = 'Quantidade invalida.',
    bad_goods = 'Mercadoria invalida.', no_deal = 'Nao ha acordo para confirmar.', deal_expired = 'O acordo expirou.',
    terminal = 'A conversa terminou.', payment_failed = 'O pagamento falhou; a mercadoria foi devolvida.',
    processing_error = 'Erro ao processar a venda. Procure a administracao.', bad_text = 'Mensagem invalida.',
    unknown_action = 'Acao desconhecida.', wrong_mode = 'Acao indisponivel nesta negociacao.',
}

local ARCH_LABEL = { comum = 'Pedestre', empresario = 'Empresario', atleta = 'Atleta', morador_de_rua = 'Morador de rua' }

-- env: ver contrato no topo de tests/test_engine.lua
function M.new(env)
    local cfg = env.cfg
    local self = setmetatable({ env = env, cfg = cfg, ready = false, lastDispatch = {}, dealSeq = 0 }, M)
    self.guard = rollguard.new({ clock = env.now, playerCooldownSec = cfg.guard.playerCooldownSec,
        pedCooldownSec = cfg.guard.pedCooldownSec, approachTtlSec = cfg.guard.approachTtlSec, maxEntries = cfg.guard.maxEntries })
    self.sessions = sessionmod.new({ clock = env.now, ttlSec = cfg.session.ttlSec, dealTtlSec = cfg.session.dealTtlSec,
        maxTurns = cfg.session.maxTurns, minActionIntervalMs = cfg.session.minActionIntervalMs,
        burst = cfg.session.maxPerPlayerBurst, burstWindowSec = 5, idgen = function() return env.rng.int(1, 0xFFFFFF) end })
    self.ledger = ledgermod.new({ store = env.store, ports = env.ports, clock = env.wall or env.now,
        maxUnitPrice = cfg.economy.maxUnitPrice, maxPackages = cfg.economy.maxPackages })
    return self
end

local function fail(err, extra)
    local r = { ok = false, err = err, message = M.ERR_TEXT[err] or M.ERR_TEXT.bad_payload }
    if extra then for k, v in pairs(extra) do r[k] = v end end
    return r
end

function M:start()
    local okc, why = economy.validate_config(self.cfg)
    if not okc then self.env.log('error', 'config invalida', { why = why }); return nil, why end
    local sum, err = self.ledger:start()
    if not sum then self.env.log('error', 'ledger bloqueado (falha segura)', { err = err }); return nil, err end
    self.ready = true
    if sum.review > 0 then self.env.log('warn', 'transacoes em revisao manual', sum) end
    return sum
end

local function dist(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function patience_label(p) if p < 0.25 then return 'baixa' elseif p < 0.6 then return 'media' end return 'alta' end

-- ===== visao enviada ao cliente (sem orcamento/atributos exatos) =====
function M:_view(sess, extra)
    local cfg = self.cfg
    local lo, hi = economy.scroll_bounds(cfg)
    local d = sess.data
    local goods = {}
    for _, g in ipairs(cfg.goods) do
        goods[#goods + 1] = { key = g.key, label = g.label, stock = d.stock and d.stock[g.key] or 0, priceMult = g.priceMult }
    end
    local deal = d.deal and { id = d.deal.id, goods = d.deal.goods, unitPrice = d.deal.unitPrice, qty = d.deal.qty,
        total = d.deal.total, expiresIn = math.max(0, math.floor(d.deal.expiresAt - self.env.now())) } or nil
    local counter = d.counter and { unitPrice = d.counter.unitPrice, step = d.counter.step, qty = d.counter.qty } or nil
    local v = { ok = true, sessionId = sess.id, state = sess.state, mode = d.mode, outcome = d.outcome,
        npc = { archetype = ARCH_LABEL[sess.npc.archetype] or 'Pedestre', mood = dialogue.mood_label(sess.npc.mood) },
        scroll = { lo = lo, hi = hi, stepPct = cfg.economy.scroll.stepPct }, refPrice = d.refPrice,
        roundTo = cfg.economy.offerRoundTo,
        maxQty = d.maxQty, goods = goods, deal = deal, counter = counter, messages = d.history,
        ttl = math.max(0, math.floor(sess.expiresAt - self.env.now())), aiActive = d.aiUsed or false }
    if extra then for k, val in pairs(extra) do v[k] = val end end
    return v
end

local function push_msg(sess, who, text, source)
    local h = sess.data.history
    h[#h + 1] = { who = who, text = text, source = source }
    while #h > 14 do table.remove(h, 1) end
end

-- ===== abordagem =====
function M:approach(src, payload)
    local env, cfg = self.env, self.cfg
    if not self.ready then return fail('not_ready') end
    if type(payload) ~= 'table' then return fail('bad_payload') end
    local p = env.player(src)
    if not p then return fail('no_player') end
    if not p.alive or p.inVehicle then return fail('dead_or_vehicle') end
    if self.sessions:by_src(src) then return fail('already_in_session') end

    -- ---- identificar o ped (R01.3/R01.4/R08.1) ----
    local v = cfg.validation
    local netId = math.tointeger(payload.netId)
    local model, pedKey, pedCoords, verified
    if netId then
        local ped = env.ped(netId)
        if not ped or not ped.exists or ped.isPlayer then return fail('ped_invalid') end
        if ped.health <= 0 then return fail('ped_dead') end
        if ped.bucket ~= p.bucket then return fail('bucket') end
        if dist(p.coords, ped.coords) > v.maxApproachDistance then return fail('too_far') end
        if v.populationTypes and ped.population ~= nil then
            local ok = false
            for _, t in ipairs(v.populationTypes) do if t == ped.population then ok = true end end
            if not ok then return fail('ped_not_ambient') end
        end
        model, pedCoords, verified = ped.model, ped.coords, true
        pedKey = ('net:%d:%s'):format(netId, tostring(model))
    else
        if not v.allowUnverifiedLocalPeds then return fail('ped_unverified') end
        local pc = payload.pedCoords
        if type(pc) ~= 'table' or type(pc.x) ~= 'number' or type(pc.y) ~= 'number' then return fail('bad_payload') end
        if pc.x ~= pc.x or pc.y ~= pc.y then return fail('bad_payload') end
        if dist(p.coords, { x = pc.x, y = pc.y, z = pc.z or p.coords.z }) > v.maxApproachDistance + 2.0 then return fail('too_far') end
        model = math.tointeger(payload.modelHash) or 0
        pedCoords = { x = pc.x, y = pc.y, z = pc.z or p.coords.z }
        pedKey = ('loc:%s:%d:%d'):format(tostring(model), math.floor(pc.x / 3), math.floor(pc.y / 3))
        verified = false
    end
    local modelName = env.model_name and env.model_name(model) or nil
    for _, b in ipairs(v.blockedModels) do if b == modelName then return fail('ped_blocked') end end

    -- ---- elegibilidade economica: precisa ter mercadoria; policiais em servico ----
    local stock = env.stock(src)
    local any = false
    for _, g in ipairs(cfg.goods) do if (stock[g.key] or 0) >= 1 then any = true end end
    if not any then return fail('no_stock') end
    local police = env.police_count()
    if not police then return fail('police_unavailable') end
    local refPrice, perr = economy.package_price(cfg, police)
    if not refPrice then return fail('police_unavailable') end

    -- ---- uma oportunidade por abordagem elegivel (R04.4) ----
    local approachId, gerr = self.guard:begin_approach(p.identifier, pedKey)
    if not approachId then
        if gerr == 'ped_cooldown' then return fail('ped_busy') end
        return fail('cooldown')
    end
    local sess, serr = self.sessions:open({ src = src, identifier = p.identifier, pedKey = pedKey,
        npc = nil, zone = 'default', data = {} })
    if not sess then self.guard:finish(approachId); return fail(serr == 'ped_busy' and 'ped_busy' or 'already_in_session') end
    if not self.guard:consume_roll(approachId, p.identifier) then
        self.sessions:close(sess.id, 'roll_error'); return fail('cooldown')
    end

    local zone = env.zone and env.zone(p.coords) or 'default'
    local npc = profiles.generate(cfg, env.rng, { modelName = modelName, modelHash = model, zone = zone })
    local roll = probability.roll_approach(cfg, npc, zone, refPrice, env.rng)
    local d = sess.data
    sess.npc, sess.zone = npc, zone
    d.history, d.refPrice, d.stock, d.police = {}, refPrice, stock, police
    d.startCoords, d.pedNetId, d.verified, d.pedCoords = p.coords, netId, verified, pedCoords
    d.approachId, d.rare = approachId, roll.rare
    d.mode = 'simple'
    local lbl = dialogue.mood_label(npc.mood)

    env.log('info', 'abordagem', { outcome = roll.outcome, rare = roll.rare, zone = zone, archetype = npc.archetype,
        police = police, verified = verified, citizen = p.identifier })

    local outcome = roll.outcome
    if outcome == 'refuse_simple' or outcome == 'refuse_report' or outcome == 'fight' then
        return self:_terminal(sess, p, outcome == 'refuse_simple' and 'refuse' or outcome, true)
    end

    if outcome == 'plus_rare' then
        local prize = economy.rare_prize(cfg, police, env.rng)
        d.mode = 'rare'; d.maxQty = 1
        local goods
        for _, g in ipairs(cfg.goods) do if (stock[g.key] or 0) >= 1 and not goods then goods = g.key end end
        self.dealSeq = self.dealSeq + 1
        d.deal = { id = tostring(self.dealSeq), goods = goods, unitPrice = prize, qty = 1, total = prize,
            expiresAt = env.now() + cfg.session.dealTtlSec * 2, rare = true }
        sess.state = 'deal_ready'
        push_msg(sess, 'npc', dialogue.line(env.rng, 'rare', npc.archetype, lbl, { price = prize }), 'local')
    elseif outcome == 'plus_combo' then
        d.mode = 'combo'
        local want = env.rng.int(2, cfg.economy.maxPackages)
        d.maxQty = math.max(2, math.min(want, math.floor(npc.budget / refPrice)))
        d.maxQty = math.min(d.maxQty, cfg.economy.maxPackages)
        push_msg(sess, 'npc', dialogue.line(env.rng, 'combo', npc.archetype, lbl, { max = d.maxQty }), 'local')
    else
        d.maxQty = 1
        push_msg(sess, 'npc', dialogue.line(env.rng, 'greet', npc.archetype, lbl), 'local')
    end
    sess.state = sess.state == 'deal_ready' and 'deal_ready' or 'negotiating'
    return self:_view(sess)
end

-- Resultado terminal (recusa/denuncia/briga/abandono). A sessao permanece curta para travar o ped ate o cliente limpar.
function M:_terminal(sess, p, outcome, fresh)
    local env, cfg = self.env, self.cfg
    local npc, d = sess.npc, sess.data
    d.outcome = outcome; sess.state = 'terminal'
    sess.expiresAt = env.now() + (outcome == 'fight' and cfg.session.fightSeconds + 10 or 15)
    local lbl = dialogue.mood_label(npc.mood)
    local extra = {}
    if outcome == 'refuse_report' then
        extra.reported = self:_dispatch(sess, p)
    elseif outcome == 'fight' then
        extra.fight = { seconds = cfg.session.fightSeconds, chase = env.rng.float() < cfg.session.chaseChance }
    end
    local kind = outcome == 'refuse' and 'refuse' or outcome
    push_msg(sess, 'npc', dialogue.line(env.rng, kind, npc.archetype, lbl), 'local')
    return self:_view(sess, extra)
end

function M:_dispatch(sess, p)
    local env, cfg = self.env, self.cfg
    local dcfg = cfg.dispatch
    local last = self.lastDispatch[p.identifier]
    if last and env.now() - last < dcfg.cooldownSec then return false end
    self.lastDispatch[p.identifier] = env.now()
    local ok, res = pcall(env.dispatch, { coords = p.coords, code = dcfg.code, message = dcfg.message,
        src = p.src, zone = sess.zone })
    if not ok or res == false then env.log('warn', 'dispatch falhou', { err = tostring(res) }); return false end
    return true
end

-- ===== acoes =====
local function clean_text(t, max)
    if type(t) ~= 'string' then return nil end
    t = t:gsub('[%c]', ' '):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if #t < 1 or #t > max then return nil end
    if not utf8.len(t) then return nil end
    return t
end

local function goods_by_key(cfg, key)
    for _, g in ipairs(cfg.goods) do if g.key == key then return g end end
end

-- Frase da resposta: IA (se disponivel) com validacao; senao fallback local. cb(text, source) 1 vez.
function M:_phrase(sess, decision, fbKind, vars, amounts, playerText, cb)
    local env, cfg = self.env, self.cfg
    local npc = sess.npc
    local lbl = dialogue.mood_label(npc.mood)
    local function fallback() cb(dialogue.line(env.rng, fbKind, npc.archetype, lbl, vars), 'local') end
    local ai = env.ai
    local useAi = ai and (playerText ~= nil or cfg.ai.phraseOffers)
    if not useAi then return fallback() end
    local hist = {}
    for i = math.max(1, #sess.data.history - 5), #sess.data.history do hist[#hist + 1] = sess.data.history[i] end
    ai:ask({ player = sess.identifier, archetype = npc.archetype, moodLabel = lbl, patienceLabel = patience_label(npc.patience),
        decision = decision, amounts = amounts, qty = vars and vars.qty, history = hist, playerText = playerText },
        function(res, err)
            if res then
                sess.data.aiUsed = true
                cb(res.reply, 'ai', res.intent)
            else
                env.log('debug', 'ia indisponivel -> fallback local', { err = err })
                fallback()
            end
        end)
end

local function amounts_of(d, unit, total, counter)
    local a = { d.refPrice }
    if unit then a[#a + 1] = unit end
    if total then a[#a + 1] = total end
    if counter then a[#a + 1] = counter end
    return a
end

function M:action(src, payload, cb)
    local env, cfg = self.env, self.cfg
    local called = false
    local function reply(r) if called then return end called = true; cb(r) end
    local ok, e = pcall(self._action, self, src, payload, reply)
    if not ok then
        env.log('error', 'erro em action', { err = tostring(e) })
        reply(fail('bad_payload'))
    end
end

function M:_action(src, payload, reply)
    local env, cfg = self.env, self.cfg
    if not self.ready then return reply(fail('not_ready')) end
    if type(payload) ~= 'table' or type(payload.kind) ~= 'string' then return reply(fail('bad_payload')) end
    local p = env.player(src)
    if not p then return reply(fail('no_player')) end

    local prior = self.sessions:by_src(src)
    local sess, err = self.sessions:authorize(src, p.identifier, payload.sessionId, payload.seq)
    if not sess then
        if err == 'rate_limited' or err == 'replay_or_out_of_order' or err == 'bad_seq' then return reply(fail(err)) end
        return reply(fail(err, { closed = true }))
    end
    local d = sess.data

    -- cancelar e sempre permitido
    if payload.kind == 'cancel' then
        self.sessions:close(sess.id, 'cancelled')
        return reply({ ok = true, closed = true, outcome = d.outcome or 'cancelled', fight = nil })
    end

    if d.busy then return reply(fail('busy')) end
    if not p.alive then self.sessions:close(sess.id, 'player_dead'); return reply(fail('dead_or_vehicle', { closed = true })) end
    if dist(p.coords, d.startCoords) > cfg.validation.maxMoveFromStart then
        self.sessions:close(sess.id, 'moved_away'); return reply(fail('moved_away', { closed = true }))
    end
    if d.pedNetId then
        local ped = env.ped(d.pedNetId)
        if not ped or not ped.exists or ped.health <= 0 then
            self.sessions:close(sess.id, 'ped_gone'); return reply(fail('ped_gone', { closed = true }))
        end
    end
    if sess.state == 'terminal' then return reply(fail('terminal')) end

    local kind = payload.kind
    if kind == 'say' then return self:_say(sess, p, payload, reply) end
    if kind == 'offer' then return self:_offer(sess, p, payload, reply) end
    if kind == 'accept_counter' then return self:_accept_counter(sess, reply) end
    if kind == 'confirm' then return self:_confirm(sess, p, reply) end
    return reply(fail('unknown_action'))
end

function M:_say(sess, p, payload, reply)
    local env, cfg = self.env, self.cfg
    local d = sess.data
    local text = clean_text(payload.text, cfg.session.maxTextChars)
    if not text then return reply(fail('bad_text')) end
    push_msg(sess, 'player', text, 'player')
    local intent = dialogue.parse_intent(text)
    d.busy = true
    local lbl0 = dialogue.mood_label(sess.npc.mood)
    self:_phrase(sess, 'conversa', 'chat', {}, amounts_of(d, d.deal and d.deal.unitPrice, d.deal and d.deal.total, nil), text,
        function(line, source, aiIntent)
            d.busy = false
            if not self.sessions.byId[sess.id] then return reply(fail('no_session', { closed = true })) end
            if intent == 'chat' and aiIntent then intent = aiIntent end -- IA so sugere; whitelist ja validada
            sess.npc = negotiation.apply_intent(cfg, sess.npc, intent)
            local text2 = line
            local kindFb = (intent ~= 'chat') and intent or nil
            if source == 'local' and kindFb then
                text2 = dialogue.line(env.rng, kindFb, sess.npc.archetype, dialogue.mood_label(sess.npc.mood))
            end
            push_msg(sess, 'npc', text2, source)
            -- provocacao/ameaca pode escalar para briga (R02.4/R04.6); a IA nunca decide isso
            if (intent == 'provoke' or intent == 'threat') and env.rng.float() < negotiation.fight_probability(cfg, sess.npc, sess.zone) then
                return reply(self:_terminal(sess, p, 'fight'))
            end
            if intent == 'bye' then
                local v = self:_view(sess, { closed = true, outcome = 'walked' })
                self.sessions:close(sess.id, 'bye')
                return reply(v)
            end
            reply(self:_view(sess))
        end)
end

function M:_offer(sess, p, payload, reply)
    local env, cfg = self.env, self.cfg
    local d = sess.data
    if d.mode ~= 'simple' and d.mode ~= 'combo' then return reply(fail('wrong_mode')) end
    local goods = goods_by_key(cfg, payload.goods or cfg.goods[1].key)
    if not goods then return reply(fail('bad_goods')) end
    local qty = math.tointeger(payload.qty)
    if not qty or qty < 1 or qty > d.maxQty then return reply(fail('bad_quantity')) end
    local ref = math.floor(d.refPrice * (goods.priceMult or 1.0) + 0.5)
    local unit, uerr = economy.offer_unit_price(cfg, ref, payload.step)
    if not unit then return reply(fail(uerr)) end
    local total, terr = economy.combo_total(cfg, unit, qty)
    if not total then return reply(fail(terr)) end
    local stock = env.stock(p.src)
    d.stock = stock
    if (stock[goods.key] or 0) < qty then return reply(fail('no_stock')) end

    local decision, npc2, info = negotiation.evaluate(cfg, sess.npc,
        { step = math.tointeger(payload.step), unitPrice = unit, qty = qty }, sess.zone, env.rng)
    sess.npc = npc2
    d.counter = nil
    local vars, counterUnit = { price = unit, qty = qty, max = info.maxAffordableQty }, nil
    local fb = decision
    if decision == 'accept' then
        self.dealSeq = self.dealSeq + 1
        d.deal = { id = tostring(self.dealSeq), goods = goods.key, unitPrice = unit, qty = qty, total = total,
            expiresAt = env.now() + cfg.session.dealTtlSec }
        sess.state = 'deal_ready'
    elseif decision == 'counter' then
        counterUnit = economy.offer_unit_price(cfg, ref, info.counterStep)
        d.counter = { step = info.counterStep, unitPrice = counterUnit, qty = qty, goods = goods.key, ref = ref }
        vars.price = counterUnit
    elseif decision == 'hesitate' or decision == 'cannot_afford' then
        if decision == 'cannot_afford' and (not info.maxAffordableQty or info.maxAffordableQty < 1) then vars.max = 0 end
    elseif decision == 'refuse_report' or decision == 'fight' or decision == 'refuse' then
        return reply(self:_terminal(sess, p, decision == 'refuse' and 'refuse' or decision))
    end

    d.busy = true
    self:_phrase(sess, decision, fb, vars, amounts_of(d, unit, total, counterUnit), nil, function(line, source)
        d.busy = false
        if not self.sessions.byId[sess.id] then return reply(fail('no_session', { closed = true })) end
        push_msg(sess, 'npc', line, source)
        reply(self:_view(sess))
    end)
end

function M:_accept_counter(sess, reply)
    local env, cfg = self.env, self.cfg
    local d = sess.data
    local c = d.counter
    if not c then return reply(fail('no_deal')) end
    local total = economy.combo_total(cfg, c.unitPrice, c.qty)
    if not total then return reply(fail('bad_quantity')) end
    self.dealSeq = self.dealSeq + 1
    d.deal = { id = tostring(self.dealSeq), goods = c.goods, unitPrice = c.unitPrice, qty = c.qty, total = total,
        expiresAt = env.now() + cfg.session.dealTtlSec }
    d.counter = nil
    sess.state = 'deal_ready'
    push_msg(sess, 'npc', dialogue.line(env.rng, 'accept', sess.npc.archetype, dialogue.mood_label(sess.npc.mood),
        { price = c.unitPrice }), 'local')
    reply(self:_view(sess))
end

function M:_confirm(sess, p, reply)
    local env, cfg = self.env, self.cfg
    local d = sess.data
    local deal = d.deal
    if sess.state ~= 'deal_ready' or not deal then return reply(fail('no_deal')) end
    if deal.expiresAt <= env.now() then d.deal = nil; sess.state = 'negotiating'; return reply(fail('deal_expired')) end
    local goods = goods_by_key(cfg, deal.goods)
    if not goods then return reply(fail('bad_goods')) end
    local stock = env.stock(p.src)
    if (stock[goods.key] or 0) < deal.qty then return reply(fail('no_stock')) end

    -- o acordo e consumido AQUI (antes de executar): reenvio nao reabre a venda
    d.deal = nil
    local itemName, itemCount = goods.item, deal.qty
    if goods.mode == 'units' then itemName, itemCount = goods.unitItem, deal.qty * cfg.economy.unitsPerPackage end
    local tx = { key = sess.id .. ':' .. deal.id, identifier = p.identifier, src = p.src, item = itemName,
        itemCount = itemCount, qty = deal.qty, unitPrice = deal.unitPrice, total = deal.total,
        payKind = cfg.payment.kind, kind = deal.rare and 'rare' or d.mode }
    sess.state = 'settling'
    local res, lerr = self.ledger:execute_sale(tx)
    local out
    if not res then
        env.log('error', 'ledger recusou venda', { err = lerr, key = tx.key })
        out = fail('processing_error', { closed = true, outcome = 'error' })
    elseif res.status == 'completed' then
        env.log('info', 'venda concluida', { key = tx.key, total = deal.total, qty = deal.qty, kind = tx.kind })
        out = { ok = true, closed = true, outcome = 'sold', total = deal.total, qty = deal.qty, unitPrice = deal.unitPrice,
            rare = deal.rare or false, message = 'Venda concluida.' }
    elseif res.status == 'aborted' then
        out = fail('no_stock', { closed = true, outcome = 'aborted' })
    elseif res.status == 'compensated' then
        out = fail('payment_failed', { closed = true, outcome = 'compensated' })
    else
        env.log('error', 'venda em revisao manual', { key = tx.key, status = res.status })
        out = fail('processing_error', { closed = true, outcome = 'review' })
    end
    self.sessions:close(sess.id, 'settled')
    reply(out)
end

function M:close_player(src, reason)
    local s = self.sessions:by_src(src)
    if s then
        self.sessions:close(s.id, reason or 'player_dropped')
        if self.env.ai then self.env.ai:forget(s.identifier) end
    end
end

function M:tick()
    for _, s in ipairs(self.sessions:sweep()) do
        self.env.push(s.src, 'mads_sd:closed', { reason = 'expired' })
    end
    self.guard:sweep()
end

return M
