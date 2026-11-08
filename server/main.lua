-- Cola FiveM/Qbox do servidor. Toda a logica esta em server/engine.lua (testada localmente com dublês).
local cfg = require 'config.config'
local util = require 'core.util'
local okl, localCfg = pcall(require, 'config.local')
if okl and type(localCfg) == 'table' then util.deep_merge(cfg, localCfg) end

local rngmod = require 'core.rng'
local aimod = require 'core.ai'
local Engine = require 'server.engine'
local qbox = require 'server.qbox'
local dispatch = require 'server.dispatch'
local Store = require 'server.journal_store'

local RES = GetCurrentResourceName()
local levels = { debug = 0, info = 1, warn = 2, error = 3 }
local minLevel = GetConvar('mads_sd_loglevel', 'info')
local function log(level, msg, data)
    if (levels[level] or 1) < (levels[minLevel] or 1) then return end
    local extra = ''
    if data then
        local parts = {}
        for k, v in pairs(data) do parts[#parts + 1] = ('%s=%s'):format(k, tostring(v)) end
        table.sort(parts); extra = ' ' .. table.concat(parts, ' ')
    end
    print(('[%s] [%s] %s%s'):format(RES, level, msg, extra)) -- NUNCA logar chaves nem texto de conversa
end

-- ---- dependencias reais ----
for _, dep in ipairs({ 'qbx_core', 'ox_inventory', 'ox_lib', 'oxmysql', 'ox_target' }) do
    if GetResourceState(dep) ~= 'started' then log('error', 'dependencia nao iniciada', { dep = dep }) end
end

-- ---- nomes de modelo (hash -> nome) para dicas de arquetipo ----
local modelNames = {}
local function reg(name) modelNames[joaat(name) & 0xFFFFFFFF] = name end
for name in pairs(cfg.modelArchetypeHints) do reg(name) end
for _, name in ipairs(cfg.pedNames) do reg(name) end

local function now() return GetGameTimer() / 1000.0 end
local engine

local function build_ai()
    if not cfg.ai.enabled then return nil end
    local key = GetConvar('mads_sd_ai_key', '') -- `set` (nunca `setr`): nao replica ao cliente
    if key == '' then log('info', 'IA externa desativada: sem chave (usando fallback local)'); return nil end
    return aimod.new_client({
        cfg = cfg.ai, key = key, now = now,
        after = function(ms, fn) SetTimeout(ms, fn) end,
        http = function(url, method, body, headers, cb)
            PerformHttpRequest(url, function(status, text) cb(status, text) end, method, body, headers)
        end,
    })
end

local function start()
    local store = Store.new()
    local okd, derr = store:init()
    if not okd then log('error', 'journal indisponivel; vendas BLOQUEADAS', { err = derr }); return end
    local env = {
        cfg = cfg, rng = rngmod.system(), now = now, wall = os.time, store = store, log = log,
        player = qbox.player, ped = qbox.ped,
        police_count = function() return qbox.police_count(cfg) end,
        stock = function(src) return qbox.stock(cfg, src) end,
        ports = qbox.ports(cfg),
        model_name = function(h) return modelNames[(h or 0) & 0xFFFFFFFF] end,
        zone = function(c)
            local best, bd
            for _, a in ipairs(cfg.areas) do
                local d = #(vector3(c.x, c.y, c.z) - vector3(a.x, a.y, a.z))
                if d <= a.r and (not bd or d < bd) then best, bd = a.zone, d end
            end
            return best or 'default'
        end,
        dispatch = function(alert) return dispatch.send(cfg, alert, log) end,
        push = function(src, ev, payload) TriggerClientEvent(ev, src, payload) end,
        after = function(ms, fn) SetTimeout(ms, fn) end,
        ai = build_ai(),
    }
    engine = Engine.new(env)
    local sum, err = engine:start()
    if not sum then log('error', 'engine nao iniciou (falha segura)', { err = tostring(err) }); return end
    log('info', 'iniciado', { ai = env.ai and 'externa' or 'fallback-local', recuperacao_revisao = sum.review, devolvidos = sum.refunded })
end

CreateThread(function() Wait(1000); start() end)

-- ---- callbacks (cada um responde SEMPRE; erro -> tabela de falha) ----
local lastApproach = {}
lib.callback.register('mads_sd:approach', function(source, payload)
    if not engine then return { ok = false, err = 'not_ready', message = Engine.ERR_TEXT.not_ready } end
    local t = GetGameTimer()
    if lastApproach[source] and t - lastApproach[source] < 500 then
        return { ok = false, err = 'rate_limited', message = Engine.ERR_TEXT.rate_limited }
    end
    lastApproach[source] = t
    local ok, res = pcall(engine.approach, engine, source, payload)
    if not ok then log('error', 'approach falhou', { err = tostring(res) }); return { ok = false, err = 'bad_payload' } end
    return res
end)

lib.callback.register('mads_sd:action', function(source, payload)
    if not engine then return { ok = false, err = 'not_ready', message = Engine.ERR_TEXT.not_ready } end
    local p = promise.new()
    local done = false
    local function resolve(r) if not done then done = true; p:resolve(r) end end
    SetTimeout(15000, function() resolve({ ok = false, err = 'busy', message = 'Tempo esgotado.' }) end)
    engine:action(source, payload, resolve)
    return Citizen.Await(p)
end)

lib.callback.register('mads_sd:clientConfig', function()
    return { interaction = cfg.interaction, anim = cfg.anim, session = { fightSeconds = cfg.session.fightSeconds },
        maxMove = cfg.validation.maxMoveFromStart }
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastApproach[src] = nil
    if engine then engine:close_player(src, 'player_dropped') end
end)

CreateThread(function()
    while true do
        Wait(10000)
        if engine then engine:tick() end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == RES then TriggerClientEvent('mads_sd:closed', -1, { reason = 'resource_stop' }) end
end)

-- ---- administracao (restrito por ACE: add_ace group.admin command.mads_sd_review allow) ----
RegisterCommand('mads_sd_review', function(source)
    if not engine then return print('engine indisponivel') end
    local list = engine.ledger:list_review()
    local out = ('%d transacao(oes) em revisao'):format(#list)
    for _, r in ipairs(list) do
        out = out .. ('\n  %s | %s | cid=%s item=%s x%s total=%s'):format(r.key, tostring(r.note), tostring(r.data and r.data.identifier),
            tostring(r.data and r.data.item), tostring(r.data and r.data.itemCount), tostring(r.data and r.data.total))
    end
    print(out)
    if source > 0 then qbox.notify(source, out:sub(1, 200), 'inform') end
end, true)

RegisterCommand('mads_sd_resolve', function(source, args)
    if not engine then return end
    local ok, err = engine.ledger:resolve(args[1] or '', args[2] or '')
    print(ok and 'resolvido' or ('falha: ' .. tostring(err)))
end, true)
