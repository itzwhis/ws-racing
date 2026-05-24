-- ============================================================
-- WS Racing — Server commands
-- ============================================================
local RSGCore = exports['rsg-core']:GetCoreObject()

RegisterCommand('racemenu', function(src)
    TriggerClientEvent('race:requestMenuFromCmd', src)
end, false)

RegisterCommand('leaderboard', function(src)
    TriggerClientEvent('race:openLeaderboardPicker', src)
end, false)

RegisterCommand('mystats', function(src)
    local player = RSGCore.Functions.GetPlayer(src)
    if not player then return end
    local stats = Database.GetPlayerHistory(player.PlayerData.citizenid)
    TriggerClientEvent('race:receiveMyStats', src, stats)
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
    TriggerClientEvent('ox_lib:notify', -1, {
        title='Racing', description='Race state force-reset by admin', type='warning', duration=4000,
    })
    print('[ws-racing] Race state force-reset by admin ' .. src)
end, false)

print('^2[ws-racing]^7 Commands registered')
