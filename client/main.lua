-- Cliente: descoberta de pedestres (ox_target + tecla), abordagem, NUI, animacoes e briga.
-- O cliente NUNCA decide preco/pagamento/resultado: so apresenta o que o servidor autoriza.
local cfg = require 'config.config'
local state = { session = nil, ped = nil, seq = 0, ui = false, watcher = false, config = nil }

local function conf() return state.config or cfg end

local function notify(msg, kind)
    lib.notify({ description = msg, type = kind or 'inform', position = 'top' })
end

-- ---------- utilitarios de ped ----------
local function ped_ok(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    if IsPedAPlayer(entity) or IsPedDeadOrDying(entity, true) or IsPedInAnyVehicle(entity, false) then return false end
    local t = GetPedType(entity)
    for _, allowed in ipairs(conf().interaction.allowedPedTypes or { 4, 5 }) do if t == allowed then return true end end
    return false
end

local function can_approach(entity)
    if state.session or state.ui then return false end
    local me = PlayerPedId()
    if IsPedDeadOrDying(me, true) or IsPedInAnyVehicle(me, false) or IsPedRagdoll(me) then return false end
    return ped_ok(entity)
end

local function take_control(entity, ms)
    if NetworkHasControlOfEntity(entity) then return true end
    if not NetworkGetEntityIsNetworked(entity) then return true end -- ped local: controle e nosso
    local t = GetGameTimer() + (ms or 800)
    NetworkRequestControlOfEntity(entity)
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < t do Wait(25) end
    return NetworkHasControlOfEntity(entity)
end

local function play(entity, pair, ms, flags)
    if not pair or not DoesEntityExist(entity) then return end
    local ok, dict = pcall(lib.requestAnimDict, pair[1], 1500)
    if not ok or not dict then return end -- dicionario inexistente: segue sem animacao (nao trava)
    TaskPlayAnim(entity, pair[1], pair[2], 8.0, -8.0, ms or 1500, flags or 49, 0, false, false, false)
    RemoveAnimDict(pair[1])
end

local function face(entity, target)
    TaskTurnPedToFaceEntity(entity, target, 1500)
end

local function hold_ped(entity)
    if not DoesEntityExist(entity) then return end
    take_control(entity)
    SetBlockingOfNonTemporaryEvents(entity, true)
    TaskStandStill(entity, 120000)
    face(entity, PlayerPedId())
end

local function release_ped(entity, walk)
    if not entity or not DoesEntityExist(entity) then return end
    if take_control(entity, 300) then
        SetBlockingOfNonTemporaryEvents(entity, false)
        ClearPedTasks(entity)
        if walk and not IsPedDeadOrDying(entity, true) then TaskWanderStandard(entity, 10.0, 10) end
        SetPedAsNoLongerNeeded(entity)
    end
end

-- ---------- NUI ----------
local function close_ui()
    if state.ui then
        state.ui = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'close' })
    end
end

local function end_session(walk)
    local ped = state.ped
    state.session, state.ped, state.seq = nil, nil, 0
    close_ui()
    release_ped(ped, walk ~= false)
end

local function start_fight(ped, f)
    if not ped or not DoesEntityExist(ped) then return end
    CreateThread(function()
        local me = PlayerPedId()
        if take_control(ped, 1000) then
            SetBlockingOfNonTemporaryEvents(ped, false)
            ClearPedTasks(ped)
            SetPedCombatAttributes(ped, 46, true)
            SetPedFleeAttributes(ped, 0, false)
            SetPedCombatMovement(ped, 2)
            if f and f.chase then
                TaskGoToEntity(ped, me, -1, 1.2, 3.0, 1073741824, 0)
                Wait(1800)
            end
            if DoesEntityExist(ped) then TaskCombatPed(ped, me, 0, 16) end
        end
        local untilT = GetGameTimer() + ((f and f.seconds) or 25) * 1000
        while GetGameTimer() < untilT and DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) and not IsPedDeadOrDying(me, true) do
            Wait(500)
        end
        release_ped(ped, true) -- limpeza SEMPRE: NPC volta ao comportamento normal
    end)
end

local function handle_result(res)
    if not res then return end
    if res.outcome == 'fight' and res.fight then
        local ped = state.ped
        state.ped = nil -- a briga assume o ped; a limpeza fica na thread da briga
        start_fight(ped, res.fight)
    elseif res.outcome == 'sold' then
        local ped = state.ped
        if ped and DoesEntityExist(ped) then
            play(PlayerPedId(), conf().anim.trade, 1800); play(ped, conf().anim.tradeNpc, 1800)
        end
        notify(('Venda concluida: $%s'):format(res.total or '?'), 'success')
    elseif res.outcome == 'refuse' or res.outcome == 'refuse_report' then
        if state.ped then play(state.ped, conf().anim.refuse, 1800) end
        if res.outcome == 'refuse_report' then notify('Alguem pode ter chamado a policia!', 'error') end
    end
end

local function open_ui(view)
    state.ui = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'open', data = view })
end

-- Todo callback NUI responde (cb) mesmo com erro: a interface nunca fica presa (R06.3).
RegisterNUICallback('act', function(data, cb)
    if not state.session then return cb({ ok = false, err = 'no_session', message = 'Negociacao encerrada.', closed = true }) end
    state.seq = state.seq + 1
    local ok, res = pcall(lib.callback.await, 'mads_sd:action', false, {
        sessionId = state.session, seq = state.seq, kind = data and data.kind,
        step = data and data.step, qty = data and data.qty, goods = data and data.goods, text = data and data.text })
    if not ok or type(res) ~= 'table' then
        return cb({ ok = false, err = 'comm', message = 'Falha de comunicacao com o servidor.' })
    end
    handle_result(res)
    if res.closed or res.state == 'terminal' then
        -- terminal: a NUI mostra o desfecho e pede 'close'; ped permanece preso so ate la
        if res.closed then end_session(res.outcome ~= 'fight') end
    end
    cb(res)
end)

RegisterNUICallback('close', function(_, cb)
    local id = state.session
    if id then
        state.seq = state.seq + 1
        pcall(lib.callback.await, 'mads_sd:action', false, { sessionId = id, seq = state.seq, kind = 'cancel' })
    end
    end_session(true)
    cb({ ok = true })
end)

RegisterNetEvent('mads_sd:closed', function()
    if state.session or state.ui then end_session(true); notify('A negociacao foi encerrada.', 'inform') end
end)

-- vigia SO durante a sessao (sem varredura global permanente)
local function watch()
    if state.watcher then return end
    state.watcher = true
    CreateThread(function()
        while state.session do
            Wait(500)
            local me = PlayerPedId()
            local ped = state.ped
            local lost = IsPedDeadOrDying(me, true)
                or (ped and (not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true)))
                or (ped and #(GetEntityCoords(me) - GetEntityCoords(ped)) > (conf().maxMove or 12.0) + 4.0)
            if lost then
                local id = state.session
                if id then
                    state.seq = state.seq + 1
                    pcall(lib.callback.await, 'mads_sd:action', false, { sessionId = id, seq = state.seq, kind = 'cancel' })
                end
                end_session(true)
                break
            end
        end
        state.watcher = false
    end)
end

-- ---------- abordagem ----------
local function approach(entity)
    if not can_approach(entity) then return end
    local me = PlayerPedId()
    hold_ped(entity)
    play(me, conf().anim.hello, 1200)
    local c = GetEntityCoords(entity)
    local res = lib.callback.await('mads_sd:approach', false, {
        netId = NetworkGetEntityIsNetworked(entity) and NetworkGetNetworkIdFromEntity(entity) or nil,
        modelHash = GetEntityModel(entity), pedCoords = { x = c.x, y = c.y, z = c.z } })
    if type(res) ~= 'table' or not res.ok then
        release_ped(entity, true)
        notify((res and res.message) or 'Nao foi possivel abordar.', 'error')
        return
    end
    state.session, state.ped, state.seq = res.sessionId, entity, 0
    watch()
    if res.outcome == 'fight' then handle_result(res) end
    open_ui(res)
    if res.outcome == 'refuse' or res.outcome == 'refuse_report' then handle_result(res) end
end

local function nearest_ped()
    local me = PlayerPedId()
    local mc = GetEntityCoords(me)
    local best, bd = nil, (conf().interaction.keyDistance or 2.5)
    for _, p in ipairs(GetGamePool('CPed')) do -- so ao apertar a tecla (nunca em loop)
        if p ~= me and can_approach(p) then
            local d = #(GetEntityCoords(p) - mc)
            if d < bd then best, bd = p, d end
        end
    end
    return best
end

local function setup_interaction()
    local mode = conf().interaction.mode
    if mode == 'target' or mode == 'both' then
        exports.ox_target:addGlobalPed({ {
            name = 'mads_sd_approach', icon = 'fa-solid fa-comments', label = 'Abordar',
            distance = conf().interaction.targetDistance or 2.5,
            canInteract = function(entity) return can_approach(entity) end,
            onSelect = function(data) approach(data.entity) end,
        } })
    end
    if mode == 'key' or mode == 'both' then
        RegisterCommand('mads_sd_approach', function()
            local p = nearest_ped()
            if p then approach(p) end
        end, false)
        RegisterKeyMapping('mads_sd_approach', 'StreetDeals: abordar pedestre', 'keyboard', conf().interaction.key or 'G')
    end
end

CreateThread(function()
    Wait(1500)
    local ok, remote = pcall(lib.callback.await, 'mads_sd:clientConfig', false)
    if ok and type(remote) == 'table' then
        state.config = { interaction = remote.interaction, anim = remote.anim, maxMove = remote.maxMove }
    end
    setup_interaction()
end)

AddEventHandler('onClientResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    pcall(function() exports.ox_target:removeGlobalPed('mads_sd_approach') end)
    if state.ped then release_ped(state.ped, true) end
    SetNuiFocus(false, false)
end)
