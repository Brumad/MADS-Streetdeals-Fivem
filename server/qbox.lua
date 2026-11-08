-- UNICA camada que fala com qbx_core / ox_inventory / dispatch (R07). Assinaturas verificadas no codigo-fonte
-- (qbx_core 1.24.1, ox_inventory main): ver REFERENCIAS_TECNICAS.md. Integracao real: pendente de homologacao.
local Q = {}

local function core() return exports.qbx_core end

function Q.get_player(src)
    local ok, pl = pcall(function() return core():GetPlayer(src) end)
    if ok and pl and pl.PlayerData and pl.PlayerData.citizenid then return pl end
    return nil
end

-- Identificador PERSISTENTE (citizenid), nunca o source.
function Q.player(src)
    local pl = Q.get_player(src)
    if not pl then return nil end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    local md = pl.PlayerData.metadata or {}
    return {
        src = src, identifier = pl.PlayerData.citizenid,
        coords = { x = c.x, y = c.y, z = c.z }, bucket = GetPlayerRoutingBucket(src),
        alive = GetEntityHealth(ped) > 0 and not md.isdead and not md.inlaststand,
        inVehicle = GetVehiclePedIsIn(ped, false) ~= 0,
    }
end

-- Estado do ped (entidade de rede) segundo o SERVIDOR.
function Q.ped(netId)
    if type(netId) ~= 'number' or netId <= 0 then return nil end
    local ok, e = pcall(NetworkGetEntityFromNetworkId, netId)
    if not ok or not e or e == 0 or not DoesEntityExist(e) or GetEntityType(e) ~= 1 then return { exists = false } end
    local c = GetEntityCoords(e)
    local okp, pop = pcall(GetEntityPopulationType, e)
    return {
        exists = true, isPlayer = IsPedAPlayer(e), health = GetEntityHealth(e),
        coords = { x = c.x, y = c.y, z = c.z }, bucket = GetEntityRoutingBucket(e),
        model = GetEntityModel(e), population = okp and pop or nil,
    }
end

-- Policiais EM SERVICO (qbx_core GetDutyCountType retorna count, players).
function Q.police_count(cfg)
    local ok, count = pcall(function() return core():GetDutyCountType(cfg.police.jobType) end)
    if ok and type(count) == 'number' then return count end
    return nil
end

function Q.stock(cfg, src)
    local out = {}
    for _, g in ipairs(cfg.goods) do
        local n = 0
        if g.mode == 'units' then
            n = math.floor((exports.ox_inventory:GetItemCount(src, g.unitItem) or 0) / cfg.economy.unitsPerPackage)
        else
            n = exports.ox_inventory:GetItemCount(src, g.item) or 0
        end
        out[g.key] = n
    end
    return out
end

-- Portas do ledger. Garantem que o `src` ainda e o mesmo jogador (citizenid) antes de agir.
function Q.ports(cfg)
    local function same(tx)
        local pl = Q.get_player(tx.src)
        return pl and pl.PlayerData.citizenid == tx.identifier and pl or nil
    end
    return {
        remove_item = function(tx)
            if not same(tx) then return false end
            local ok = exports.ox_inventory:RemoveItem(tx.src, tx.item, tx.itemCount)
            return ok == true
        end,
        pay = function(tx)
            local pl = same(tx)
            if not pl then return false end
            local kind = cfg.payment.kind
            if kind == 'item' then
                return exports.ox_inventory:AddItem(tx.src, cfg.payment.moneyItem, tx.total) and true or false
            end
            return pl.Functions.AddMoney(kind, tx.total, cfg.payment.reason) == true
        end,
        return_item = function(tx)
            if not same(tx) then return false end
            return exports.ox_inventory:AddItem(tx.src, tx.item, tx.itemCount) and true or false
        end,
    }
end

function Q.notify(src, text, kind)
    pcall(function() core():Notify(src, text, kind or 'inform') end)
end

return Q
