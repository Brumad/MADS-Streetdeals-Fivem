-- Sessoes de negociacao (R01.4, R01.5, R08.1-R08.3): uma sessao por jogador, um jogador por NPC,
-- expiracao, numeracao de acoes (rejeita replay/fora de ordem) e limite de ritmo. Estado puro.
local M = {}
M.__index = M

-- opts: { clock, ttlSec, dealTtlSec, maxTurns, minActionIntervalMs, burst, burstWindowSec, idgen }
function M.new(opts)
    return setmetatable({
        clock = assert(opts.clock), ttl = opts.ttlSec, dealTtl = opts.dealTtlSec, maxTurns = opts.maxTurns,
        minIntervalMs = opts.minActionIntervalMs or 0, burst = opts.burst or 6, burstWindow = opts.burstWindowSec or 5,
        idgen = opts.idgen, byId = {}, bySrc = {}, byPed = {}, n = 0,
    }, M)
end

local function gen_id(self)
    self.n = self.n + 1
    local salt = self.idgen and self.idgen() or 0
    return ('s%d-%x'):format(self.n, salt)
end

-- s = { src, identifier, pedKey, npc, zone, ... campos livres } -> sessao | (nil, motivo)
function M:open(s)
    if self.bySrc[s.src] then return nil, 'player_in_session' end
    if s.pedKey and self.byPed[s.pedKey] then return nil, 'ped_busy' end
    local now = self.clock()
    local id = gen_id(self)
    local sess = {
        id = id, src = s.src, identifier = s.identifier, pedKey = s.pedKey, npc = s.npc, zone = s.zone,
        state = 'open', lastSeq = 0, turns = 0, createdAt = now, expiresAt = now + self.ttl,
        lastActionMs = nil, recent = {}, data = s.data or {},
    }
    self.byId[id] = sess
    self.bySrc[s.src] = id
    if s.pedKey then self.byPed[s.pedKey] = id end
    return sess
end

function M:close(id, reason)
    local s = self.byId[id]
    if not s then return nil end
    self.byId[id] = nil
    if self.bySrc[s.src] == id then self.bySrc[s.src] = nil end
    if s.pedKey and self.byPed[s.pedKey] == id then self.byPed[s.pedKey] = nil end
    s.state = 'closed'; s.closeReason = reason
    return s
end

function M:by_src(src) local id = self.bySrc[src]; return id and self.byId[id] or nil end

-- Valida uma acao do cliente: dono, estado, expiracao, ordem (seq estritamente crescente), ritmo.
-- Retorna sessao ou (nil, motivo). Nunca muda estado de negocio.
function M:authorize(src, identifier, id, seq)
    local s = self.byId[id]
    if not s then return nil, 'no_session' end
    if s.src ~= src or s.identifier ~= identifier then return nil, 'not_owner' end
    local now = self.clock()
    if s.expiresAt <= now then self:close(id, 'expired'); return nil, 'expired' end
    if math.type(seq) ~= 'integer' then return nil, 'bad_seq' end
    if seq <= s.lastSeq then return nil, 'replay_or_out_of_order' end
    if s.turns >= self.maxTurns then return nil, 'too_many_turns' end
    -- ritmo: intervalo minimo e rajada
    local ms = now * 1000
    if s.lastActionMs and self.minIntervalMs > 0 and ms - s.lastActionMs < self.minIntervalMs then
        return nil, 'rate_limited'
    end
    local r = s.recent
    local cut = now - self.burstWindow
    local k = 1
    while k <= #r and r[k] <= cut do k = k + 1 end
    if k > 1 then local nr = {}; for i = k, #r do nr[#nr + 1] = r[i] end; s.recent = nr; r = nr end
    if #r >= self.burst then return nil, 'rate_limited' end
    r[#r + 1] = now
    s.lastSeq = seq
    s.lastActionMs = ms
    s.turns = s.turns + 1
    return s
end

function M:sweep()
    local now, closed = self.clock(), {}
    for id, s in pairs(self.byId) do
        if s.expiresAt <= now then closed[#closed + 1] = self:close(id, 'expired') end
    end
    return closed
end

function M:count()
    local n = 0
    for _ in pairs(self.byId) do n = n + 1 end
    return n
end

return M
