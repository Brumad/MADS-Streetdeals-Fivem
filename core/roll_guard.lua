-- Controle de oportunidade (R04.4, R08.2, R08.3, R01.4): cada abordagem elegivel recebe UM token de
-- sorteio; abrir/fechar a NUI nao gera novos sorteios. Chaves sao identificadores PERSISTENTES do
-- jogador (nao o source), entao reconexao nao zera cooldown. Estruturas sao varridas (sem vazamento).
local M = {}
M.__index = M

-- opts: { clock = function() -> segundos, playerCooldownSec, pedCooldownSec, approachTtlSec, maxEntries }
function M.new(opts)
    return setmetatable({
        clock = assert(opts.clock),
        playerCooldown = opts.playerCooldownSec,
        pedCooldown = opts.pedCooldownSec,
        ttl = opts.approachTtlSec,
        maxEntries = opts.maxEntries,
        players = {}, peds = {}, approaches = {}, nextId = 0, count = 0,
    }, M)
end

function M:sweep()
    local now = self.clock()
    for k, t in pairs(self.players) do
        if t <= now then self.players[k] = nil; self.count = self.count - 1 end
    end
    for k, t in pairs(self.peds) do
        if t <= now then self.peds[k] = nil; self.count = self.count - 1 end
    end
    for id, a in pairs(self.approaches) do
        if a.expires <= now then self.approaches[id] = nil; self.count = self.count - 1 end
    end
end

-- Inicia abordagem. Retorna approachId ou (nil, motivo).
function M:begin_approach(identifier, pedKey)
    if type(identifier) ~= 'string' or identifier == '' then return nil, 'bad_identifier' end
    if type(pedKey) ~= 'string' or pedKey == '' then return nil, 'bad_ped' end
    local now = self.clock()
    if self.count >= self.maxEntries then self:sweep() end
    if self.count + 3 > self.maxEntries then return nil, 'guard_full' end -- falha segura

    local pUntil = self.players[identifier]
    if pUntil and pUntil > now then return nil, 'player_cooldown' end
    local dUntil = self.peds[pedKey]
    if dUntil and dUntil > now then return nil, 'ped_cooldown' end

    if not pUntil then self.count = self.count + 1 end
    if not dUntil then self.count = self.count + 1 end
    self.players[identifier] = now + self.playerCooldown
    self.peds[pedKey] = now + self.pedCooldown

    self.nextId = self.nextId + 1
    local id = self.nextId
    self.approaches[id] = { identifier = identifier, pedKey = pedKey, rolled = false, expires = now + self.ttl }
    self.count = self.count + 1
    return id
end

-- Consome o unico sorteio da abordagem. true na primeira vez; depois (nil, motivo).
function M:consume_roll(approachId, identifier)
    local a = self.approaches[approachId]
    if not a then return nil, 'unknown_or_expired' end
    if a.identifier ~= identifier then return nil, 'not_owner' end
    if a.expires <= self.clock() then
        self.approaches[approachId] = nil; self.count = self.count - 1
        return nil, 'unknown_or_expired'
    end
    if a.rolled then return nil, 'already_rolled' end
    a.rolled = true
    return true
end

function M:finish(approachId)
    if self.approaches[approachId] then
        self.approaches[approachId] = nil
        self.count = self.count - 1
    end
end

return M
