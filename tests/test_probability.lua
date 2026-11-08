package.path = './?.lua;' .. package.path
local T = require 'tests.framework'
local cfg = require 'config.config'
local rngmod = require 'core.rng'
local prob = require 'core.probability'
local profiles = require 'core.profiles'

local function npc_of(arch, over)
    local a = cfg.archetypes[arch]
    local n = { archetype = arch, aggression = (a.aggression[1] + a.aggression[2]) / 2,
        patience = 0.5, interest = 0.5, priceTolerance = 1.0, reportProneness = 0.35,
        budget = 10000, mood = 50, fightMult = a.fightMult, insistence = 0, turns = 0 }
    for k, v in pairs(over or {}) do n[k] = v end
    return n
end

-- C02: fronteira deterministica do raro
T.test('raro: fronteira exata (1 -> raro; 2 e 1000 -> nao raro)', function()
    T.truthy(prob.roll_rare(cfg, rngmod.scripted({ 1 })))
    T.falsy(prob.roll_rare(cfg, rngmod.scripted({ 2 })))
    T.falsy(prob.roll_rare(cfg, rngmod.scripted({ 1000 })))
    local r = prob.roll_approach(cfg, npc_of('comum'), 'default', 2000, rngmod.scripted({ 1 }))
    T.eq(r.outcome, 'plus_rare'); T.truthy(r.rare)
end)

T.test('raro: UM unico sorteio inteiro por abordagem (sem rerolls internos)', function()
    local rng = rngmod.scripted({ 1 })
    prob.roll_approach(cfg, npc_of('comum'), 'default', 2000, rng)
    local ints, floats = rng.calls()
    T.eq(ints, 1); T.eq(floats, 0, 'raro nao consome sorteio ponderado')
    local rng2 = rngmod.scripted({ 500 }, { 0.1 })
    prob.roll_approach(cfg, npc_of('comum'), 'default', 2000, rng2)
    local i2, f2 = rng2.calls()
    T.eq(i2, 1); T.eq(f2, 1)
end)

T.test('raro e independente de perfil, zona, humor e orcamento', function()
    for _, arch in ipairs({ 'comum', 'empresario', 'atleta', 'morador_de_rua' }) do
        for _, zone in ipairs({ 'default', 'busy', 'isolated', 'police_risk', 'near_station' }) do
            local r = prob.roll_approach(cfg, npc_of(arch, { mood = 0, budget = 0 }), zone, 2000, rngmod.scripted({ 1 }))
            T.eq(r.outcome, 'plus_rare', arch .. '/' .. zone)
        end
    end
end)

T.test('raro: frequencia estatistica ~ 1/1000 em 1.000.000 de abordagens (seed fixa)', function()
    local rng = rngmod.seeded(20240607)
    local hits, N = 0, 1000000
    for _ = 1, N do if prob.roll_rare(cfg, rng) then hits = hits + 1 end end
    local sigma = math.sqrt(N * 0.001 * 0.999)
    T.truthy(math.abs(hits - 1000) <= 4 * sigma, ('hits=%d fora de 1000+-%.0f'):format(hits, 4 * sigma))
end)

T.test('raro: denominador configuravel altera a taxa (prova que nao e hardcoded)', function()
    local c = { rare = { denominator = 10 } }
    local rng = rngmod.seeded(5)
    local hits, N = 0, 200000
    for _ = 1, N do if prob.roll_rare(c, rng) then hits = hits + 1 end end
    T.near(hits / N, 0.1, 0.005)
end)

T.test('combo e mais frequente que o raro; todos os 6 resultados ocorrem', function()
    local rng = rngmod.seeded(99)
    local counts = {}
    local N = 300000
    for _ = 1, N do
        local n = profiles.generate(cfg, rng, { modelName = 'a_m_y_business_01', zone = 'default' })
        local r = prob.roll_approach(cfg, n, 'default', 2000, rng)
        counts[r.outcome] = (counts[r.outcome] or 0) + 1
    end
    for _, o in ipairs({ 'plus_rare', 'plus_combo', 'negotiate_simple', 'refuse_simple', 'refuse_report', 'fight' }) do
        T.truthy((counts[o] or 0) > 0, 'resultado ausente: ' .. o)
    end
    T.truthy(counts.plus_combo > 20 * counts.plus_rare, 'combo >> raro')
    T.truthy(counts.negotiate_simple > counts.refuse_report, 'negociacao simples domina')
end)

T.test('perfil: atleta e morador de rua brigam mais que comum/empresario (R02.3)', function()
    local function fight_share(arch)
        local rng = rngmod.seeded(11)
        local f, N = 0, 60000
        for _ = 1, N do
            local n = profiles.generate(cfg, rng, { zone = 'default' })
            -- forca o arquetipo pra isolar o efeito
            local a = cfg.archetypes[arch]
            n.archetype = arch; n.fightMult = a.fightMult
            n.aggression = (a.aggression[1] + a.aggression[2]) / 2; n.mood = 50
            local r = prob.roll_approach(cfg, n, 'default', 2000, rng)
            if r.outcome == 'fight' then f = f + 1 end
        end
        return f / N
    end
    local comum, emp, ath, rua = fight_share('comum'), fight_share('empresario'), fight_share('atleta'), fight_share('morador_de_rua')
    T.truthy(ath > comum * 1.5, 'atleta > comum')
    T.truthy(rua > comum * 1.3, 'rua > comum')
    T.truthy(emp < comum, 'empresario < comum')
end)

T.test('zona muda o resultado: delegacia aumenta denuncia, isolado aumenta briga (R02.5)', function()
    local n = npc_of('comum')
    local d, st, iso, busy = prob.weights(cfg, n, 'default', 2000), prob.weights(cfg, n, 'near_station', 2000),
        prob.weights(cfg, n, 'isolated', 2000), prob.weights(cfg, n, 'busy', 2000)
    T.truthy(st.refuse_report > d.refuse_report * 1.9)
    T.truthy(iso.fight > d.fight)
    T.truthy(busy.refuse_report > d.refuse_report)
    T.truthy(st.plus_combo < d.plus_combo)
end)

T.test('orcamento real bloqueia combo (R02.2)', function()
    local poor = prob.weights(cfg, npc_of('comum', { budget = 3000 }), 'default', 2000)
    local rich = prob.weights(cfg, npc_of('comum', { budget = 9000 }), 'default', 2000)
    T.eq(poor.plus_combo, 0); T.truthy(rich.plus_combo > 0)
end)

T.test('humor baixo e interesse alto mudam pesos', function()
    local base = prob.weights(cfg, npc_of('comum'), 'default', 2000)
    local angry = prob.weights(cfg, npc_of('comum', { mood = 10 }), 'default', 2000)
    local keen = prob.weights(cfg, npc_of('comum', { interest = 0.9 }), 'default', 2000)
    T.truthy(angry.fight > base.fight)
    T.truthy(keen.negotiate_simple > base.negotiate_simple)
    T.truthy(keen.refuse_simple < base.refuse_simple)
end)

T.test('pesos todos zero nao quebram (retorna nil)', function()
    local util = require 'core.util'
    T.eq(util.weighted_pick(rngmod.scripted(nil, { 0.5 }), { a = 0, b = 0 }), nil)
end)
