-- ============================================================
-- WS Racing — Client Main + Commands
-- ============================================================
local RSGCore = exports['rsg-core']:GetCoreObject()

RegisterCommand('racemenu', function()
    TriggerServerEvent('race:requestMenu')
end, false)

RegisterNetEvent('race:requestMenuFromCmd', function()
    TriggerServerEvent('race:requestMenu')
end)

-- ============================================================
-- Race creation slash-commands (alternative to F5/F6/F7)
-- ============================================================
RegisterCommand('addcheckpoint', function()
    if not CreatingRace or CreatingRace.name == '' then
        lib.notify({ title='Racing', description='Open /racemenu → Create New Race first', type='error' })
        return
    end
    local pos = GetEntityCoords(PlayerPedId())
    table.insert(CreatingRace.checkpoints, { x=pos.x, y=pos.y, z=pos.z })
    lib.notify({
        title       = 'Checkpoint #' .. #CreatingRace.checkpoints .. ' Added',
        description = math.floor(pos.x)..', '..math.floor(pos.y)..', '..math.floor(pos.z),
        type        = 'success',
    })
end, false)

RegisterCommand('addstart', function()
    if not CreatingRace or CreatingRace.name == '' then
        lib.notify({ title='Racing', description='Open /racemenu → Create New Race first', type='error' })
        return
    end
    local ped     = PlayerPedId()
    local pos     = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    table.insert(CreatingRace.startPositions, { x=pos.x, y=pos.y, z=pos.z, heading=heading })
    lib.notify({ title='Start Position #'..#CreatingRace.startPositions..' Added', type='success' })
end, false)

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
