package.path = './?.lua;' .. package.path
local T = require 'tests.framework'
local cfg = require 'config.config'
local rngmod = require 'core.rng'
local neg = require 'core.negotiation'
local economy = require 'core.economy'

local function npc(over)
    local n = { archetype = 'comum', aggression = 0.3, patience = 0.6, interest = 0.5,
        priceTolerance = 1.0, reportProneness = 0.4, budget = 20000, mood = 50, fightMult = 1.0,
        insistence = 0, turns = 0 }
    for k, v in pairs(over or {}) do n[k] = v end
    return n
end

T.test('R03.5: desconto aumenta aceitacao, sobrepreco reduz (ceteris paribus, monotono)', function()
    local n = npc()
    local prev = 2
    for step = -10, 10 do
        local p = neg.accept_probability(cfg, n, economy.ratio_from_step(cfg, step))
        T.truthy(p <= prev + 1e-12, 'aceitacao nao pode subir com o preco: step ' .. step)
        prev = p
    end
    local lo = neg.accept_probability(cfg, n, 0.7)
    local hi = neg.accept_probability(cfg, n, 1.4)
    T.truthy(lo > 0.8 and hi < 0.1, ('lo=%.3f hi=%.3f'):format(lo, hi))
    T.truthy(lo < 1 and hi > 0, 'sem garantias fixas (nunca 0% nem 100%)')
end)

T.test('R03.5: desconto reduz denuncia, sobrepreco aumenta (monotono nao decrescente)', function()
    local n = npc()
    local prev = -1
    for step = -10, 10 do
        local p = neg.report_probability(cfg, n, economy.ratio_from_step(cfg, step), 'default')
        T.truthy(p >= prev - 1e-12, 'denuncia nao pode cair com o preco: step ' .. step)
        prev = p
    end
    T.truthy(neg.report_probability(cfg, n, 0.6, 'default') < neg.report_probability(cfg, n, 1.4, 'default'))
    T.truthy(neg.report_probability(cfg, n, 0.5, 'default') > 0, 'piso: risco nunca e zero')
end)

T.test('atributos mudam a decisao: tolerancia, humor, interesse', function()
    local base = neg.accept_probability(cfg, npc(), 1.1)
    T.truthy(neg.accept_probability(cfg, npc({ priceTolerance = 1.3 }), 1.1) > base)
    T.truthy(neg.accept_probability(cfg, npc({ mood = 90 }), 1.1) > base)
    T.truthy(neg.accept_probability(cfg, npc({ mood = 10 }), 1.1) < base)
    T.truthy(neg.accept_probability(cfg, npc({ interest = 0.95 }), 1.1) > base)
    T.truthy(neg.accept_probability(cfg, npc({ insistence = 4 }), 1.1) < base, 'insistencia reduz')
end)

T.test('perfil de denuncia e zona alteram risco', function()
    T.truthy(neg.report_probability(cfg, npc({ reportProneness = 0.8 }), 1.2, 'default')
        > neg.report_probability(cfg, npc({ reportProneness = 0.1 }), 1.2, 'default'))
    T.truthy(neg.report_probability(cfg, npc(), 1.2, 'near_station') > neg.report_probability(cfg, npc(), 1.2, 'isolated'))
end)

T.test('briga: depende de arquetipo, agressividade e humor (R04.6)', function()
    local base = neg.fight_probability(cfg, npc(), 'default')
    T.truthy(neg.fight_probability(cfg, npc({ fightMult = 2.0 }), 'default') > base)
    T.truthy(neg.fight_probability(cfg, npc({ aggression = 0.9 }), 'default') > base)
    T.truthy(neg.fight_probability(cfg, npc({ mood = 5 }), 'default') > base)
end)

T.test('evaluate: aceita quando sorteio < pAccept; recusa/contra quando >', function()
    local d, s = neg.evaluate(cfg, npc(), { step = -4, unitPrice = 1600, qty = 1 }, 'default', rngmod.scripted(nil, { 0.0 }))
    T.eq(d, 'accept'); T.truthy(s.mood > 50)
    local d2, s2, i2 = neg.evaluate(cfg, npc(), { step = 8, unitPrice = 2800, qty = 1 }, 'default', rngmod.scripted(nil, { 0.99 }))
    T.eq(d2, 'counter'); T.truthy(i2.counterStep and i2.counterStep < 8, 'contraproposta abaixo da oferta')
    T.truthy(s2.patience < 0.6 and s2.mood < 50 and s2.insistence == 1)
    local d3 = neg.evaluate(cfg, npc(), { step = -2, unitPrice = 1800, qty = 1 }, 'default', rngmod.scripted(nil, { 0.999 }))
    T.eq(d3, 'hesitate', 'oferta ok mas NPC nao convencido')
end)

T.test('evaluate: contraproposta nunca excede a tolerancia e e valida no scroll', function()
    local n = npc({ priceTolerance = 0.9 })
    local d, _, info = neg.evaluate(cfg, n, { step = 8, unitPrice = 3000, qty = 1 }, 'default', rngmod.scripted(nil, { 0.99 }))
    T.eq(d, 'counter')
    local ratio = economy.ratio_from_step(cfg, info.counterStep)
    T.truthy(ratio, 'passo de contraproposta dentro dos limites')
    T.truthy(ratio <= neg.effective_tolerance(n) + 1e-9)
end)

T.test('evaluate: orcamento insuficiente -> cannot_afford com quantidade maxima', function()
    local n = npc({ budget = 4500 })
    local d, _, info = neg.evaluate(cfg, n, { step = 0, unitPrice = 2000, qty = 3 }, 'default', rngmod.scripted(nil, {}))
    T.eq(d, 'cannot_afford'); T.eq(info.maxAffordableQty, 2); T.eq(info.total, 6000)
end)

T.test('evaluate: paciencia esgotada encerra (denuncia, briga ou recusa simples)', function()
    local n = npc({ patience = 0.05, reportProneness = 1.0, priceTolerance = 0.5 })
    -- u=0.99 (nao aceita); report roll 0.0 < pReport -> refuse_report
    local d = neg.evaluate(cfg, n, { step = 10, unitPrice = 3000, qty = 1 }, 'default', rngmod.scripted(nil, { 0.99, 0.0 }))
    T.eq(d, 'refuse_report')
    -- report 0.99 nao dispara; fight 0.0 < pFight -> fight (agressivo)
    local m = npc({ patience = 0.05, reportProneness = 0.1, aggression = 1.0, fightMult = 2.0, mood = 5, priceTolerance = 0.5 })
    T.eq((neg.evaluate(cfg, m, { step = 10, unitPrice = 3000, qty = 1 }, 'default', rngmod.scripted(nil, { 0.99, 0.99, 0.0 }))), 'fight')
    -- nenhum dispara -> recusa simples
    local k = npc({ patience = 0.05, aggression = 0.0, priceTolerance = 0.5 })
    T.eq((neg.evaluate(cfg, k, { step = 10, unitPrice = 3000, qty = 1 }, 'default', rngmod.scripted(nil, { 0.99, 0.99, 0.99 }))), 'refuse')
end)

T.test('evaluate: insistencia repetida acaba esgotando a paciencia (loop finito)', function()
    local n = npc({ patience = 0.5, priceTolerance = 0.6 })
    local rng = rngmod.seeded(3)
    local ended, rounds = false, 0
    while not ended and rounds < 50 do
        rounds = rounds + 1
        local d, s = neg.evaluate(cfg, n, { step = 10, unitPrice = 3000, qty = 1 }, 'default', rng)
        n = s
        if d == 'refuse' or d == 'refuse_report' or d == 'fight' or d == 'accept' then ended = true end
    end
    T.truthy(ended and rounds < 50, 'negociacao termina em tempo finito')
end)

T.test('evaluate: entrada invalida do cliente nao passa (assert -> falha segura)', function()
    T.raises(function() neg.evaluate(cfg, npc(), { step = 99, unitPrice = 1, qty = 1 }, 'default', rngmod.seeded(1)) end)
    T.raises(function() neg.evaluate(cfg, npc(), { step = 0, unitPrice = 2000, qty = 9 }, 'default', rngmod.seeded(1)) end)
end)

T.test('evaluate nao muta o NPC de entrada (estado imutavel)', function()
    local n = npc()
    neg.evaluate(cfg, n, { step = 5, unitPrice = 2500, qty = 1 }, 'default', rngmod.scripted(nil, { 0.99 }))
    T.eq(n.patience, 0.6); T.eq(n.mood, 50); T.eq(n.insistence, 0)
end)
