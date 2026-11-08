-- R02: perfil individual do comprador. Atributos sorteados por faixa do arquetipo => a mesma skin
-- pode gerar NPCs diferentes; todos os atributos alimentam as decisoes (negotiation/probability).
local util = require 'core.util'

local M = {}

function M.pick_archetype(cfg, rng, modelName, zoneKey)
    local hint = modelName and cfg.modelArchetypeHints[modelName]
    if hint and cfg.archetypes[hint] and rng.float() < (cfg.hintStrength or 0.8) then
        return hint
    end
    local weights = cfg.archetypeSpawnWeights[zoneKey] or cfg.archetypeSpawnWeights.default
    return util.weighted_pick(rng, weights)
end

-- opts: { modelName?, modelHash?, zone? }
function M.generate(cfg, rng, opts)
    opts = opts or {}
    local zone = opts.zone or 'default'
    local archetype = M.pick_archetype(cfg, rng, opts.modelName, zone)
    local a = cfg.archetypes[archetype]
    return {
        archetype = archetype,
        modelName = opts.modelName,
        modelHash = opts.modelHash,
        zone = zone,
        aggression = util.range(rng, a.aggression),
        patience = util.range(rng, a.patience),
        interest = util.range(rng, a.interest),
        priceTolerance = util.range(rng, a.priceTolerance),
        reportProneness = util.range(rng, a.reportProneness),
        budget = math.floor(util.range(rng, a.budget)),
        mood = util.range(rng, a.mood),
        fightMult = a.fightMult,
        insistence = 0,
        turns = 0,
    }
end

return M
