-- ============================================================
-- WS Racing — Server Main
-- ============================================================
 -- ============================================================
-- Reselling is NOT allowed.
-- ============================================================
local RSGCore = exports['rsg-core']:GetCoreObject()

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() then
        Database.Initialize()
    end
end)

RaceState = {
    active       = false,
    raceId       = nil,
    raceData     = nil,
    checkpoints  = {},
    startPos     = {},
    participants = {},
    betAmount    = 0,
    adminSource  = nil,
    startTime    = nil,
    totalCPs     = 0,
}

function HardResetRaceState()
    RaceState = {
        active=false, raceId=nil, raceData=nil, checkpoints={}, startPos={},
        participants={}, betAmount=0, adminSource=nil, startTime=nil, totalCPs=0,
    }
end

function ResetRaceState(keepSelectedRace)
    local keepRaceId      = keepSelectedRace and RaceState.raceId or nil
    local keepRaceData    = keepSelectedRace and RaceState.raceData or nil
    local keepCheckpoints = keepSelectedRace and RaceState.checkpoints or {}
    local keepStartPos    = keepSelectedRace and RaceState.startPos or {}
    local keepAdmin       = keepSelectedRace and RaceState.adminSource or nil
    RaceState = {
        active=false, raceId=keepRaceId, raceData=keepRaceData,
        checkpoints=keepCheckpoints, startPos=keepStartPos,
        participants={}, betAmount=0, adminSource=keepAdmin,
        startTime=nil, totalCPs=0,
    }
end

-- Admin check: by license OR rsg-core permission group
function IsAdmin(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if Config.AllowedLicenses[id] then return true end
    end
    if Config.UseRSGAdminGroup then
        local ok = IsPlayerAceAllowed(src, 'command') -- ace-based fallback
        if ok then return true end
        -- Try rsg-core HasPermission if exposed
        local pdata = RSGCore.Functions.GetPlayer(src)
        if pdata then
            local perm = pdata.PlayerData.permission or (RSGCore.Functions.GetPermission and RSGCore.Functions.GetPermission(src))
            if perm == 'admin' or perm == 'god' then return true end
        end
    end
    return false
end

function Notify(src, msg, ntype)
    local t = ntype
    if t == 'inform' or t == 'info' then t = 'primary' end
    TriggerClientEvent('ox_lib:notify', src, { title = 'Racing', description = msg, type = t or 'inform', duration = Config.NotifyDuration })
end

function NotifyAll(msg, ntype)
    local t = ntype
    if t == 'inform' or t == 'info' then t = 'primary' end
    TriggerClientEvent('ox_lib:notify', -1, { title = 'Racing', description = msg, type = t or 'inform', duration = Config.NotifyDuration })
end

function NotifyRace(msg, ntype)
    local sent = {}
    for _, p in ipairs(RaceState.participants) do
        if p.source and not sent[p.source] then
            Notify(p.source, msg, ntype); sent[p.source] = true
        end
    end
    if RaceState.adminSource and not sent[RaceState.adminSource] then
        Notify(RaceState.adminSource, msg, ntype)
    end
end

function GetParticipantIdx(src)
    for i, p in ipairs(RaceState.participants) do
        if p.source == src then return i end
    end
    return nil
end

RegisterNetEvent('race:requestMenu', function()
    local src = source
    local p   = RSGCore.Functions.GetPlayer(src)
    if not p then return end
    if IsAdmin(src) then
        TriggerClientEvent('race:openAdminMenu', src)
    else
        TriggerClientEvent('race:openPlayerMenu', src, {
            active       = RaceState.active,
            raceData     = RaceState.raceData,
            participants = RaceState.participants,
            betAmount    = RaceState.betAmount,
        })
    end
end)

exports('IsAdmin',      IsAdmin)
exports('GetRaceState', function() return RaceState end)
print('^2[ws-racing]^7 Server started')
print('^1WS Scripts^7 — ^3WS Racing^7 loaded')
