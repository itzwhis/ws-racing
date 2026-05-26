-- ============================================================
-- WS Racing — Client Main + Commands

 -- ============================================================
-- Reselling is NOT allowed.
-- ============================================================
local RSGCore = exports['rsg-core']:GetCoreObject()

RegisterCommand('racemenu', function()
    TriggerServerEvent('race:requestMenu')
end, false)

RegisterNetEvent('race:requestMenuFromCmd', function()
    TriggerServerEvent('race:requestMenu')
end)

-- Race creation commands (/addcp, /addstart, /undo) are registered in client/menu.lua

RegisterCommand('savrace', function()
    if not CreatingRace or CreatingRace.name == '' then
        lib.notify({ title='Racing', description='No race in progress', type='error' })
        return
    end
    if #CreatingRace.checkpoints < 1 then
        lib.notify({ title='Racing', description='Add at least 1 checkpoint', type='error' })
        return
    end
    if #CreatingRace.startPositions < 1 then
        lib.notify({ title='Racing', description='Add at least 1 start position', type='error' })
        return
    end
    TriggerServerEvent('race:saveRace', CreatingRace)
    CreatingRace = { name='', raceType='circuit', maxParticipants=10, minLevel=0, collision=true, blacklist={}, mountClass='open', checkpoints={}, startPositions={} }
end, false)

RegisterCommand('cancelcreate', function()
    CreatingRace = { name='', raceType='circuit', maxParticipants=10, minLevel=0, collision=true, blacklist={}, mountClass='open', checkpoints={}, startPositions={} }
    lib.notify({ title='Racing', description='Race creation cancelled', type='warning' })
end, false)

print('^2[ws-racing]^7 Client started — /racemenu to open')
print('^1WS Scripts^7 — ^3WS Racing^7 ready')
