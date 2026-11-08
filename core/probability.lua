-- R04: motor ponderado de resultados na abordagem. Plus rara = exatamente 1/denominator por
-- abordagem elegivel, UM sorteio inteiro independente de atributos (R04.4); demais resultados
-- sao ponderados por perfil/zona/orcamento (R02.2, R02.5) com pesos configuraveis (R04.7).
local util = require 'core.util'

local M = {}
M.OUTCOMES = { 'negotiate_simple', 'refuse_simple', 'refuse_report', 'plus_combo', 'fight' }

function M.roll_rare(cfg, rng)
    return rng.int(1, cfg.rare.denominator) == 1
end

-- packagePrice (opcional): referencia vigente; combo exige orcamento p/ >= 2 pacotes.
function M.weights(cfg, npc, zoneKey, packagePrice)
    local z = cfg.zones[zoneKey] or cfg.zones.default
    local base = cfg.approachWeights
    local w = {}
    w.negotiate_simple = base.negotiate_simple * z.negotiate * (0.6 + npc.interest * 0.8)
    w.refuse_simple = base.refuse_simple * (1.3 - npc.interest * 0.6)
    w.refuse_report = base.refuse_report * z.report * (0.5 + npc.reportProneness)
    w.fight = base.fight * z.fight * npc.fightMult * (0.4 + npc.aggression * 1.2)
        * (1 + (50 - npc.mood) / 100)
    w.plus_combo = base.plus_combo * z.combo * (0.5 + npc.interest)
    if packagePrice and npc.budget < 2 * packagePrice then w.plus_combo = 0 end
    return w
end

-- Um sorteio por abordagem. Quem garante "uma unica oportunidade" e core.roll_guard.
function M.roll_approach(cfg, npc, zoneKey, packagePrice, rng)
    if M.roll_rare(cfg, rng) then
        return { outcome = 'plus_rare', rare = true }
    end
    local outcome = util.weighted_pick(rng, M.weights(cfg, npc, zoneKey, packagePrice))
    return { outcome = outcome, rare = false }
end

return M
