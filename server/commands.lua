-- ============================================================
-- WS Racing — Server commands
-- ============================================================
 -- ============================================================
-- Reselling is NOT allowed.
-- ============================================================
local RSGCore = exports['rsg-core']:GetCoreObject()

-- /racemenu — open menu directly (no round-trip) so it always works
RegisterCommand('racemenu', function(src)
    if src == 0 then
        print('[ws-racing] /racemenu must be used in-game, not from console')
        return
    end
    local p = RSGCore.Functions.GetPlayer(src)
    if not p then
        print(('[ws-racing] /racemenu: player %s not loaded yet'):format(src))
        return
    end
    if IsAdmin(src) then
        print(('[ws-racing] /racemenu: opening ADMIN menu for src %s'):format(src))
        TriggerClientEvent('race:openAdminMenu', src)
    else
        print(('[ws-racing] /racemenu: opening PLAYER menu for src %s'):format(src))
        TriggerClientEvent('race:openPlayerMenu', src, {
            active       = RaceState and RaceState.active or false,
            raceData     = RaceState and RaceState.raceData or nil,
            participants = RaceState and RaceState.participants or {},
            betAmount    = RaceState and RaceState.betAmount or 0,
        })
    end
end, false)

RegisterCommand('leaderboard', function(src)
    TriggerClientEvent('race:openLeaderboardPicker', src)
end, false)

RegisterCommand('resetrace', function(src)
    if not IsAdmin(src) then
        TriggerClientEvent('ox_lib:notify', src, {
            title='Racing', description='No permission', type='error', duration=3000,
        })
        return
    end
    RaceState.active = false
    TriggerClientEvent('race:cancelled', -1)
    ResetRaceState(false)
    Notify(src, 'Race state force-reset by admin', 'warning')
    print('[ws-racing] Race state force-reset by admin ' .. src)
end, false)

print('^2[ws-racing]^7 Commands registered')
