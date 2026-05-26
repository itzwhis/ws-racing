-- ============================================================
-- WS Racing — Client NUI Menu (adapted to RedM mounts)
 
 -- ============================================================
-- Reselling is NOT allowed.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

CreatingRace = {
    name='', raceType='circuit', maxParticipants=10,
    minLevel=0, collision=true, blacklist={},
    mountClass='open',
    checkpoints={}, startPositions={}
}

local MenuState = {
    open  = false,
    role  = 'player',
    lobby = { active=false, raceId=nil, raceData=nil, participants={}, betAmount=0 }
}

local function PushCreateState()
    SendNUIMessage({
        action = 'createState',
        create = {
            name            = CreatingRace.name,
            raceType        = CreatingRace.raceType,
            maxParticipants = CreatingRace.maxParticipants,
            minLevel        = CreatingRace.minLevel,
            collision       = CreatingRace.collision,
            vehicleClass    = CreatingRace.mountClass, -- name kept for NUI compat
            mountClass      = CreatingRace.mountClass,
            checkpoints     = CreatingRace.checkpoints or {},
            startPositions  = CreatingRace.startPositions or {},
        }
    })
end

local function ResetCreateState()
    CreatingRace = {
        name='', raceType='circuit', maxParticipants=10,
        minLevel=0, collision=true, blacklist={},
        mountClass='open', checkpoints={}, startPositions={}
    }
    PushCreateState()
end

local function CloseRaceUI()
    if MenuState.open then
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'close' })
        MenuState.open = false
    end
end

local function OpenRaceUI(role, payload)
    MenuState.open  = true
    MenuState.role  = role or 'player'
    MenuState.lobby = payload or MenuState.lobby
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', role = MenuState.role, data = MenuState.lobby, playerName = GetPlayerName(PlayerId()) })
    PushCreateState()
end

local function UpdateLobby(payload)
    MenuState.lobby = payload or MenuState.lobby
    SendNUIMessage({ action = 'updateLobby', data = MenuState.lobby, role = MenuState.role })
end

local function IsCreating()
    return CreatingRace and CreatingRace.name ~= ''
end

-- ============================================================
-- Detect current mount class (horse / wagon / onfoot)
-- ============================================================
function GetMyMountClass()
    local ped = PlayerPedId()
    if IsPedOnMount and IsPedOnMount(ped) then return 'horse' end
    if IsPedInAnyVehicle(ped, false) then return 'wagon' end
    return 'onfoot'
end

-- Ground-snap helper for spawned checkpoint/start coords
local function SnapToGround(x, y, z)
    local ok, gz = GetGroundZFor_3dCoord(x + 0.0, y + 0.0, (z or 0.0) + 50.0, false)
    if ok and gz and gz ~= 0.0 then return gz end
    return z or 0.0
end

-- ============================================================
-- COMMANDS — Add checkpoint / start / undo
-- ============================================================
RegisterCommand('addcp', function()
    if not IsCreating() then
        lib.notify({ title='Racing', description='Start route setup in the UI first', type='error', duration=4000 })
        return
    end
    local pos = GetEntityCoords(PlayerPedId())
    local gz  = SnapToGround(pos.x, pos.y, pos.z)
    table.insert(CreatingRace.checkpoints, { x=pos.x, y=pos.y, z=gz })
    PushCreateState()
    lib.notify({ title='Racing', description='📍 Checkpoint #' .. #CreatingRace.checkpoints .. ' Added', type='success', duration=2500 })
end, false)

RegisterCommand('addstart', function()
    if not IsCreating() then
        lib.notify({ title='Racing', description='Start route setup in the UI first', type='error', duration=4000 })
        return
    end
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local gz  = SnapToGround(pos.x, pos.y, pos.z)
    table.insert(CreatingRace.startPositions, { x=pos.x, y=pos.y, z=gz, heading=heading })
    PushCreateState()
    lib.notify({ title='Racing', description='🚦 Start Position #' .. #CreatingRace.startPositions .. ' Added', type='success', duration=2500 })
end, false)

RegisterCommand('undo', function()
    if not IsCreating() then return end
    if #CreatingRace.checkpoints > 0 then
        table.remove(CreatingRace.checkpoints)
        PushCreateState()
        lib.notify({ title='Racing', description='↩️ Last Checkpoint Removed', type='warning', duration=2000 })
    else
        lib.notify({ title='Racing', description='No checkpoints to remove', type='error', duration=3000 })
    end
end, false)

-- ============================================================
-- NET EVENTS
-- ============================================================
RegisterNetEvent('race:openAdminMenu', function()
    OpenRaceUI('admin', MenuState.lobby)
end)

RegisterNetEvent('race:openPlayerMenu', function(raceInfo)
    OpenRaceUI('player', raceInfo or MenuState.lobby)
end)

RegisterNetEvent('race:adminReceiveRaces', function(races)
    SendNUIMessage({ action = 'receiveAdminRaces', races = races or {} })
end)

RegisterNetEvent('race:lobbySelected', function(data)
    UpdateLobby(data or MenuState.lobby)
    if data and data.raceData then
        local mc = data.raceData.mount_class
        if mc and mc ~= '' and mc ~= 'open' then
            lib.notify({
                title       = 'Racing',
                description = '🔒 Race Restriction: ' .. (Config.MountClasses[mc] or mc) .. ' Only',
                type        = 'inform', duration = 7000,
            })
        end
    end
end)

RegisterNetEvent('race:playerReceiveRaces', function(races)
    SendNUIMessage({ action = 'receiveLeaderboardRaces', races = races or {} })
end)

RegisterNetEvent('race:receiveLeaderboard', function(results)
    SendNUIMessage({ action = 'receiveLeaderboard', results = results or {} })
end)

RegisterNetEvent('race:receiveMyStats', function(stats)
    SendNUIMessage({ action = 'receiveStats', stats = stats or {} })
end)

RegisterNetEvent('race:updateParticipants', function(list)
    MenuState.lobby.participants = list or {}
    SendNUIMessage({ action = 'updateParticipants', participants = list or {} })
end)

RegisterNetEvent('race:receiveGlobalLeaderboard', function(rows)
    SendNUIMessage({ action = 'receiveGlobalLeaderboard', rows = rows })
end)

RegisterNetEvent('race:lobbyOpened', function()
    SendNUIMessage({ action = 'lobbyOpened' })
end)

RegisterNetEvent('race:receiveRecentRaces', function(data)
    SendNUIMessage({ action = 'receiveRecentRaces', races = data or {} })
end)

RegisterNetEvent('race:startCountdown', function() CloseRaceUI() end)
RegisterNetEvent('race:showResults',   function()
    CloseRaceUI()
    -- Refresh stats in background so Player Stats page is up-to-date on next open
    Wait(2000) -- small delay to let the server finish saving the result
    TriggerServerEvent('race:getMyStats')
end)
RegisterNetEvent('race:cancelled',     function() CloseRaceUI() end)

-- ============================================================
-- NUI CALLBACKS
-- ============================================================
RegisterNUICallback('closeUI', function(_, cb) CloseRaceUI(); cb('ok') end)

RegisterNUICallback('requestAdminRaces', function(_, cb)
    TriggerServerEvent('race:adminGetRaces'); cb('ok')
end)

RegisterNUICallback('selectRace', function(data, cb)
    TriggerServerEvent('race:adminSelectRace', tonumber(data.raceId)); cb('ok')
end)

RegisterNUICallback('startRace', function(data, cb)
    TriggerServerEvent('race:adminStartRace', tonumber(data.raceId), tonumber(data.betAmount) or 0); cb('ok')
end)

RegisterNUICallback('requestGlobalLeaderboard', function(_, cb)
    TriggerServerEvent('race:getGlobalLeaderboard'); cb('ok')
end)

RegisterNUICallback('requestRecentRaces', function(_, cb)
    TriggerServerEvent('race:requestRecentRaces'); cb('ok')
end)

RegisterNUICallback('openLobby', function(data, cb)
    TriggerServerEvent('race:adminOpenLobby', {
        raceId          = tonumber(data.raceId),
        maxParticipants = tonumber(data.maxParticipants) or 10,
        betAmount       = tonumber(data.betAmount) or 0,
        laps            = tonumber(data.laps) or 1,
        raceType        = tostring(data.raceType or 'circuit'),
        collision       = data.collision == true,
    })
    cb('ok')
end)

RegisterNUICallback('deleteRace', function(data, cb)
    TriggerServerEvent('race:deleteRace', tonumber(data.raceId)); cb('ok')
end)

RegisterNUICallback('cancelRace', function(_, cb)
    TriggerServerEvent('race:adminCancel'); cb('ok')
end)

-- ============================================================
-- PLAYER JOIN — mount-class check
-- ============================================================
RegisterNUICallback('playerJoin', function(_, cb)
    local mountClass = GetMyMountClass()
    local restriction = MenuState.lobby.raceData and MenuState.lobby.raceData.mount_class
    if restriction and restriction ~= '' and restriction ~= 'open' then
        if mountClass ~= restriction then
            lib.notify({
                title = 'Racing',
                description = '⛔ You must be ' .. (Config.MountClasses[restriction] or restriction) .. ' to join. You are: ' .. mountClass,
                type = 'error', duration = 6000,
            })
            cb('error'); return
        end
    end
    TriggerServerEvent('race:playerJoin', mountClass)
    cb('ok')
end)

RegisterNUICallback('playerLeave', function(_, cb)
    TriggerServerEvent('race:playerLeave'); cb('ok')
end)

RegisterNUICallback('requestLeaderboardRaces', function(_, cb)
    TriggerServerEvent('race:playerGetRaces'); cb('ok')
end)

RegisterNUICallback('requestMyStats', function(_, cb)
    TriggerServerEvent('race:getMyStats'); cb('ok')
end)

RegisterNUICallback('getLeaderboard', function(data, cb)
    TriggerServerEvent('race:getLeaderboard', tonumber(data.raceId)); cb('ok')
end)

RegisterNUICallback('startCreateRoute', function(data, cb)
    local raceName = tostring(data.name or '')
    if raceName == '' then
        lib.notify({ title='Racing', description='Enter race name first', type='error', duration=4000 })
        cb('error'); return
    end
    -- NUI still sends vehicleClass key from the legacy form — map to mountClass
    local mountClass = tostring(data.mountClass or data.vehicleClass or 'open')
    if not Config.MountClasses[mountClass] then mountClass = 'open' end

    CreatingRace = {
        name            = raceName,
        raceType        = data.raceType or 'circuit',
        maxParticipants = tonumber(data.maxParticipants) or 10,
        minLevel        = tonumber(data.minLevel) or 0,
        collision       = data.collision == true,
        mountClass      = mountClass,
        blacklist       = {},
        checkpoints     = {},
        startPositions  = {}
    }
    PushCreateState()
    lib.notify({ title='Racing', description='🏗️ Route Setup: ' .. CreatingRace.name .. ' — /addcp, /addstart, /undo', type='success', duration=8000 })
    cb('ok')
end)

RegisterNUICallback('addCheckpoint', function(_, cb)
    if not IsCreating() then
        lib.notify({ title='Racing', description='Start route setup first', type='error', duration=4000 })
        cb('error'); return
    end
    local pos = GetEntityCoords(PlayerPedId())
    local gz  = SnapToGround(pos.x, pos.y, pos.z)
    table.insert(CreatingRace.checkpoints, { x=pos.x, y=pos.y, z=gz })
    PushCreateState()
    lib.notify({ title='Racing', description='📍 Checkpoint #' .. #CreatingRace.checkpoints .. ' Added', type='success', duration=2500 })
    cb('ok')
end)

RegisterNUICallback('addStart', function(_, cb)
    if not IsCreating() then
        lib.notify({ title='Racing', description='Start route setup first', type='error', duration=4000 })
        cb('error'); return
    end
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local gz  = SnapToGround(pos.x, pos.y, pos.z)
    table.insert(CreatingRace.startPositions, { x=pos.x, y=pos.y, z=gz, heading=heading })
    PushCreateState()
    lib.notify({ title='Racing', description='🚦 Start Position #' .. #CreatingRace.startPositions .. ' Added', type='success', duration=2500 })
    cb('ok')
end)

RegisterNUICallback('saveCreatedRace', function(_, cb)
    if not IsCreating() then
        lib.notify({ title='Racing', description='No race in progress', type='error', duration=4000 })
        cb('error'); return
    end
    if #CreatingRace.checkpoints < 1 then
        lib.notify({ title='Racing', description='Add at least 1 checkpoint', type='error', duration=4000 })
        cb('error'); return
    end
    if #CreatingRace.startPositions < 1 then
        lib.notify({ title='Racing', description='Add at least 1 start position', type='error', duration=4000 })
        cb('error'); return
    end
    TriggerServerEvent('race:saveRace', CreatingRace)
    ResetCreateState()
    cb('ok')
end)

RegisterNUICallback('cancelCreate', function(_, cb)
    ResetCreateState()
    lib.notify({ title='Racing', description='Race creation cancelled', type='warning', duration=4000 })
    cb('ok')
end)
