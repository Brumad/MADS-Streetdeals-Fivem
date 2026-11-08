package.path = './?.lua;' .. package.path
local T = require 'tests.framework'
local json = require 'core.json'
local dialogue = require 'core.dialogue'
local sessionmod = require 'core.session'
local rngmod = require 'core.rng'
local cfg = require 'config.config'

-- ===== json =====
T.test('json: roundtrip, unicode, escapes, numeros', function()
    local v = { a = 1, b = { 1, 2, 3 }, c = 'ação "x"\n\\', d = true, e = 1.5, f = {} }
    local d = json.decode(json.encode(v))
    T.eq(d.a, 1); T.eq(d.b[3], 3); T.eq(d.c, 'ação "x"\n\\'); T.eq(d.d, true); T.eq(d.e, 1.5)
    T.eq(json.decode('"\\u00e7\\ud83d\\ude00"'), 'ç😀')
    T.eq(json.decode('null'), json.null); T.eq(json.decode(' [1 , 2] ')[2], 2); T.eq(json.decode('-3e2'), -300)
end)
T.test('json: rejeita malformado, truncado, lixo, profundidade e tamanho', function()
    for _, s in ipairs({ '{', '[1,', '{"a":}', '{"a" 1}', '[1 2]', '"abc', '{"a":1}x', 'tru', '', '{"a":"\\q"}', '"\\ud800"', '\x01' }) do
        local v, e = json.decode(s); T.eq(v, nil, s); T.truthy(e)
    end
    T.eq(json.decode(string.rep('[', 100) .. string.rep(']', 100)), nil)
    T.eq(select(2, json.decode(string.rep('a', 300000))), 'too_long')
    T.eq(json.decode(nil), nil)
end)
T.test('json: encode rejeita NaN/inf', function()
    T.raises(function() json.encode(0 / 0) end); T.raises(function() json.encode(math.huge) end)
end)

-- ===== dialogo =====
T.test('intencoes: ameaca, provocacao, desconto, educado, despedida, premium, neutro; acentos', function()
    local p = dialogue.parse_intent
    T.eq(p('vou te bater'), 'threat'); T.eq(p('Você é um IDIOTA'), 'provoke'); T.eq(p('faz um desconto aí'), 'discount')
    T.eq(p('Bom dia, tudo bem?'), 'polite'); T.eq(p('tchau'), 'bye'); T.eq(p('é produto de qualidade'), 'premium')
    T.eq(p('qual o seu nome'), 'chat'); T.eq(p(nil), 'chat'); T.eq(p('OBRIGADO'), 'polite')
end)
T.test('humor em rotulos e linhas locais contextuais por arquetipo/humor/preco', function()
    T.eq(dialogue.mood_label(10), 'furioso'); T.eq(dialogue.mood_label(50), 'neutro'); T.eq(dialogue.mood_label(95), 'animado')
    local rng = rngmod.seeded(1)
    local l = dialogue.line(rng, 'counter', 'comum', 'neutro', { price = 1750 })
    T.truthy(l:find('$1750', 1, true), l)
    T.truthy(dialogue.line(rng, 'cannot_afford', 'comum', 'neutro', { max = 2 }):find('2', 1, true))
    local seen = {}
    for i = 1, 60 do seen[dialogue.line(rng, 'greet', 'empresario', 'neutro')] = true end
    local n = 0; for _ in pairs(seen) do n = n + 1 end
    T.truthy(n >= 2, 'variacao')
    T.truthy(dialogue.line(rng, 'chat', 'comum', 'furioso'), 'humor furioso tem fala propria')
    T.truthy(dialogue.line(rng, 'inexistente', 'comum', 'neutro'), 'fallback seguro')
    for _, k in ipairs({ 'greet', 'combo', 'rare', 'accept', 'counter', 'hesitate', 'cannot_afford', 'refuse', 'refuse_report', 'fight', 'chat', 'polite', 'provoke', 'threat', 'discount', 'premium', 'bye', 'no_stock', 'walk_away' }) do
        T.truthy(#dialogue.line(rng, k, 'atleta', 'neutro', { price = 1, max = 1 }) > 0, k)
    end
end)
T.test('whitelist de intencoes', function()
    T.truthy(dialogue.valid_intent('polite')); T.falsy(dialogue.valid_intent('accept')); T.falsy(dialogue.valid_intent(nil))
end)

-- ===== sessoes =====
local function mks(over)
    local t = { now = 1000 }
    local o = { clock = function() return t.now end, ttlSec = 100, dealTtlSec = 30, maxTurns = 5, minActionIntervalMs = 250, burst = 3, burstWindowSec = 5 }
    for k, v in pairs(over or {}) do o[k] = v end
    return sessionmod.new(o), t
end
T.test('sessao: 1 por jogador, 1 por ped, fecha e libera ambos', function()
    local m = mks()
    local s = m:open({ src = 1, identifier = 'a', pedKey = 'p1', npc = {} })
    T.err('player_in_session', m:open({ src = 1, identifier = 'a', pedKey = 'p2' }))
    T.err('ped_busy', m:open({ src = 2, identifier = 'b', pedKey = 'p1' }))
    m:close(s.id, 'x')
    T.truthy(m:open({ src = 2, identifier = 'b', pedKey = 'p1' }))
    T.eq(m:count(), 1)
end)
T.test('sessao: authorize valida dono, ordem (seq), expiracao, turnos e ritmo', function()
    local m, t = mks()
    local s = m:open({ src = 1, identifier = 'a', pedKey = 'p1' })
    T.truthy(m:authorize(1, 'a', s.id, 1)); t.now = t.now + 1
    T.err('replay_or_out_of_order', m:authorize(1, 'a', s.id, 1))
    T.err('replay_or_out_of_order', m:authorize(1, 'a', s.id, 0))
    T.err('not_owner', m:authorize(2, 'a', s.id, 5)); T.err('not_owner', m:authorize(1, 'b', s.id, 5))
    T.err('bad_seq', m:authorize(1, 'a', s.id, 2.5)); T.err('bad_seq', m:authorize(1, 'a', s.id, '3'))
    T.truthy(m:authorize(1, 'a', s.id, 7)); T.err('rate_limited', m:authorize(1, 'a', s.id, 8)) -- <250ms
    t.now = t.now + 1; T.truthy(m:authorize(1, 'a', s.id, 8))
    t.now = t.now + 1
    T.err('rate_limited', m:authorize(1, 'a', s.id, 9)) -- rajada: 3 acoes em 5s
end)
T.test('sessao: expira, limite de turnos e sweep', function()
    local m, t = mks({ burst = 100 })
    local s = m:open({ src = 1, identifier = 'a', pedKey = 'p1' })
    for i = 1, 5 do t.now = t.now + 1; T.truthy(m:authorize(1, 'a', s.id, i)) end
    t.now = t.now + 1; T.err('too_many_turns', m:authorize(1, 'a', s.id, 6))
    local s2 = m:open({ src = 2, identifier = 'b', pedKey = 'p2' })
    t.now = t.now + 200
    T.err('expired', m:authorize(2, 'b', s2.id, 1))
    T.eq(#m:sweep(), 1); T.eq(m:count(), 0)
end)
T.test('sessao: churn longo nao vaza memoria', function()
    local m, t = mks({ ttlSec = 5 })
    for i = 1, 5000 do
        t.now = t.now + 1
        local s = m:open({ src = i % 7, identifier = 'a' .. i, pedKey = 'p' .. i })
        if s and i % 3 == 0 then m:close(s.id, 'x') end
        if i % 50 == 0 then m:sweep() end
    end
    m:sweep(); t.now = t.now + 10; m:sweep()
    T.eq(m:count(), 0)
    local n = 0; for _ in pairs(m.bySrc) do n = n + 1 end
    for _ in pairs(m.byPed) do n = n + 1 end
    T.eq(n, 0, 'indices limpos')
end)
