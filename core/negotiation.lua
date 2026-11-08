-- Decisao de cada proposta. Probabilidades derivam de atributos reais do NPC (R02.2),
-- da razao oferta/referencia (R03.5) e da zona (R02.5). Nunca ha aceite por percentual fixo.
local util = require 'core.util'
local economy = require 'core.economy'

local M = {}
local clamp = util.clamp

local function zone_of(cfg, zoneKey) return cfg.zones[zoneKey] or cfg.zones.default end

-- Maior razao (oferta/referencia) que o NPC toleraria agora; humor alto relaxa, baixo aperta.
function M.effective_tolerance(npc)
    return npc.priceTolerance * (1 + 0.15 * (npc.mood - 50) / 50)
end

function M.accept_probability(cfg, npc, ratio)
    local n = cfg.negotiation
    local z = n.acceptSlope * (M.effective_tolerance(npc) - ratio)
        + n.interestWeight * (npc.interest - 0.5)
        + n.moodWeight * ((npc.mood - 50) / 50)
        - 0.15 * npc.insistence
    return 1 / (1 + math.exp(-z))
end

-- Sobrepreco aumenta o risco de denuncia; desconto reduz (piso evita risco zero).
function M.report_probability(cfg, npc, ratio, zoneKey)
    local n = cfg.negotiation
    local f = math.max(n.reportBase + n.reportSlope * (ratio - 1), n.reportFloor)
    return clamp(npc.reportProneness * zone_of(cfg, zoneKey).report * f, 0, 1)
end

function M.fight_probability(cfg, npc, zoneKey)
    local n = cfg.negotiation
    local p = n.fightBase * npc.aggression * npc.fightMult * zone_of(cfg, zoneKey).fight
        * (1 - 0.5 * npc.patience) * (1 + (50 - npc.mood) / 100)
    return clamp(p, 0, 1)
end

local function next_state(npc, patienceDelta, moodDelta)
    local c = util.shallow_copy(npc)
    c.patience = clamp(npc.patience - patienceDelta, 0, 1)
    c.mood = clamp(npc.mood + moodDelta, 0, 100)
    c.insistence = npc.insistence + 1
    c.turns = npc.turns + 1
    return c
end

-- Resolve uma recusa: denuncia > briga > recusa simples (R04.1/R04.2/R04.6). Duas chamadas rng.float().
local function refuse(cfg, npc, ratio, zoneKey, rng, state, info)
    info.pReport = M.report_probability(cfg, npc, ratio, zoneKey)
    if rng.float() < info.pReport then return 'refuse_report', state, info end
    info.pFight = M.fight_probability(cfg, npc, zoneKey)
    if rng.float() < info.pFight then return 'fight', state, info end
    return 'refuse', state, info
end

-- offer = { step = passo do scroll, unitPrice = preco unitario ja calculado pelo servidor, qty }
-- Retorna: decisao, novoEstadoDoNpc, info.
-- decisao: accept | counter | hesitate | cannot_afford | refuse | refuse_report | fight
function M.evaluate(cfg, npc, offer, zoneKey, rng)
    local n = cfg.negotiation
    local ratio = economy.ratio_from_step(cfg, offer.step)
    assert(ratio, 'evaluate: passo invalido (valide antes com economy)')
    local info = { ratio = ratio }

    -- Orcamento real do NPC limita a transacao (R02.2).
    local total = economy.combo_total(cfg, offer.unitPrice, offer.qty)
    assert(total, 'evaluate: quantidade/preco invalidos')
    info.total = total
    if total > npc.budget then
        info.maxAffordableQty = math.floor(npc.budget / offer.unitPrice)
        return 'cannot_afford', next_state(npc, 0.05, -2), info
    end

    local tol = M.effective_tolerance(npc)
    info.tolerance = tol
    info.pAccept = M.accept_probability(cfg, npc, ratio)
    if rng.float() < info.pAccept then
        return 'accept', next_state(npc, 0, n.moodDeltaAccept), info
    end

    local over = ratio > tol
    local cost = n.patienceCostBase + n.patienceCostPerInsist * npc.insistence
        + (over and n.patienceCostOverpriced or 0)
    local moodDelta = over and n.moodDeltaBadOffer or n.moodDeltaCounter
    local state = next_state(npc, cost, moodDelta)

    if state.patience <= 0 then
        state.mood = clamp(state.mood + n.moodDeltaRefuse, 0, 100)
        return refuse(cfg, npc, ratio, zoneKey, rng, state, info)
    end

    if over then
        local stepSize = cfg.economy.scroll.stepPct / 100
        local counter = math.min(ratio - stepSize, tol * (0.92 + 0.08 * npc.mood / 100))
        local lo = economy.scroll_bounds(cfg)
        local cstep = math.floor((counter - 1) / stepSize + 1e-9)
        if cstep < lo then
            -- nem no piso do scroll o NPC pagaria: encerra a conversa
            state.mood = clamp(state.mood + n.moodDeltaRefuse, 0, 100)
            return refuse(cfg, npc, ratio, zoneKey, rng, state, info)
        end
        info.counterStep = cstep
        return 'counter', state, info
    end
    return 'hesitate', state, info
end

return M
