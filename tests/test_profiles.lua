package.path = './?.lua;' .. package.path
local T = require 'tests.framework'
local cfg = require 'config.config'
local rngmod = require 'core.rng'
local profiles = require 'core.profiles'

T.test('perfil respeita faixas do arquetipo', function()
    local rng = rngmod.seeded(1)
    for _ = 1, 2000 do
        local n = profiles.generate(cfg, rng, { zone = 'default' })
        local a = cfg.archetypes[n.archetype]
        T.truthy(n.aggression >= a.aggression[1] and n.aggression <= a.aggression[2])
        T.truthy(n.patience >= a.patience[1] and n.patience <= a.patience[2])
        T.truthy(n.priceTolerance >= a.priceTolerance[1] and n.priceTolerance <= a.priceTolerance[2])
        T.truthy(n.budget >= a.budget[1] and n.budget <= a.budget[2])
        T.eq(n.insistence, 0)
    end
end)

T.test('mesma skin gera NPCs diferentes (R02.2)', function()
    local rng = rngmod.seeded(42)
    local seen, archs = {}, {}
    for _ = 1, 200 do
        local n = profiles.generate(cfg, rng, { modelName = 'a_m_y_business_01', zone = 'default' })
        seen[("%.4f"):format(n.priceTolerance)] = true
        archs[n.archetype] = true
    end
    local distinct = 0
    for _ in pairs(seen) do distinct = distinct + 1 end
    T.truthy(distinct > 100, 'atributos variam entre NPCs da mesma skin')
    T.truthy(archs.empresario, 'dica do modelo domina')
    local others = 0
    for k in pairs(archs) do if k ~= 'empresario' then others = others + 1 end end
    T.truthy(others >= 1, 'mas a skin nao determina o arquetipo sozinha')
end)

T.test('dicas de modelo e pesos de zona definem arquetipo', function()
    local rng = rngmod.seeded(2)
    local rua = 0
    for _ = 1, 1000 do
        if profiles.pick_archetype(cfg, rng, 'a_m_m_tramp_01', 'default') == 'morador_de_rua' then rua = rua + 1 end
    end
    T.truthy(rua > 750)
    local iso, def = 0, 0
    for _ = 1, 5000 do
        if profiles.pick_archetype(cfg, rng, nil, 'isolated') == 'morador_de_rua' then iso = iso + 1 end
        if profiles.pick_archetype(cfg, rng, nil, 'default') == 'morador_de_rua' then def = def + 1 end
    end
    T.truthy(iso > def * 2, 'zona isolada tem mais moradores de rua')
end)

T.test('os quatro arquetipos iniciais existem com modificadores de confronto', function()
    for _, a in ipairs({ 'comum', 'empresario', 'atleta', 'morador_de_rua' }) do T.truthy(cfg.archetypes[a], a) end
    T.truthy(cfg.archetypes.atleta.fightMult > cfg.archetypes.comum.fightMult)
    T.truthy(cfg.archetypes.morador_de_rua.fightMult > cfg.archetypes.comum.fightMult)
end)

T.test('geracao e deterministica com a mesma seed', function()
    local a = profiles.generate(cfg, rngmod.seeded(8), { zone = 'busy' })
    local b = profiles.generate(cfg, rngmod.seeded(8), { zone = 'busy' })
    T.eq(a.archetype, b.archetype); T.eq(a.budget, b.budget); T.eq(a.mood, b.mood)
end)
