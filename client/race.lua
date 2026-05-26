-- ============================================================
-- WS Racing — Client Race Logic (RedM port)
-- Uses proximity-based checkpoints + RedM blips + simple markers

 -- ============================================================
-- Reselling is NOT allowed.
-- ============================================================
local RSGCore = exports['rsg-core']:GetCoreObject()

local inRace        = false
local raceData      = nil
local myCheckpoint  = 1
local currentLap    = 1
local totalLaps     = 1
local raceStartTime = nil
local participants  = {}
local cpBlips       = {}
local noCollision   = false
local lobbyStartPos    = nil
local lobbyCheckpoints = nil
local lobbyBlips       = {}
local raceType         = 'circuit'
local bestLapTime      = nil
local lapStartTime     = nil

-- RedM blip hashes (resolved at runtime to avoid signed/unsigned mismatch)
local BLIP_CP     = GetHashKey('blip_ambient_ped_medium_higher')
local BLIP_FINISH = GetHashKey('blip_ambient_ped_medium_higher')
local BLIP_START  = GetHashKey('blip_ambient_ped_medium_higher')

-- Yellow blip color index (RedM palette ~ 5 = yellow/gold)
local BLIP_COLOR_YELLOW = 5

-- Flag prop spawned at start + finish lines
local FLAG_PROP = `mp006_s_racexmasflag01x`

-- Checkpoint pass sound (RedM frontend sound set)
local CP_SOUND_NAME = 'CHECKPOINT_PERFECT'
local CP_SOUND_SET  = 'HUD_MINI_GAMES_SOUNDSET'

-- Tracked flag props for cleanup
local raceProps      = {}
local lobbyRaceProps = {}

-- RedM marker hashes
local MARKER_RING    = 0x94FDAE17 -- horizontal flat ring (lies flat on ground)
local MARKER_SPHERE  = 0x50638AB9 -- debug sphere (small, soft)

-- Ground-snap helper: drops a coord to the actual ground Z under it.
local function GroundZ(x, y, z)
    local ok, gz = GetGroundZFor_3dCoord(x + 0.0, y + 0.0, (z or 0.0) + 50.0, false)
    if ok and gz and gz ~= 0.0 then return gz end
    return z or 0.0
end

-- ============================================================
-- HELPERS
-- ============================================================
local function GetMountOrVehicle(ped)
    if IsPedOnMount and IsPedOnMount(ped) then
        local mount = GetMount(ped)
        if mount and mount ~= 0 then return mount end
    end
    if IsPedInAnyVehicle(ped, false) then
        return GetVehiclePedIsIn(ped, false)
    end
    return 0
end

local function DrawRedmMarker(mtype, x, y, z, sx, sy, sz, r, g, b, a)
    -- RedM DRAW_MARKER signature
    Citizen.InvokeNative(
        0x2A32FAA57B937173, mtype + 0,
        x + 0.0, y + 0.0, z + 0.0,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        sx + 0.0, sy + 0.0, sz + 0.0,
        math.floor(r), math.floor(g), math.floor(b), math.floor(a),
        false, false, 2, 0, 0, 0, false
    )
end

-- RedM blip helpers
local function AddRedmBlip(hash, x, y, z, label)
    local sprite = hash or GetHashKey('blip_ambient_ped_medium_higher')
    local blip = Citizen.InvokeNative(0x554D9D53F696D002, sprite, x + 0.0, y + 0.0, z + 0.0) -- BlipAddForCoords
    if blip and blip ~= 0 then
        -- Force show on minimap + main map
        Citizen.InvokeNative(0x736AAC5D9D55777D, blip, true) -- SET_BLIP_SHOW_ON_MINIMAP / DISPLAY
        -- Yellow tint so it stands out on minimap
        Citizen.InvokeNative(0x662D364ABF16DE2F, blip, BLIP_COLOR_YELLOW) -- SET_BLIP_COLOR
        Citizen.InvokeNative(0x9CB1A1623062F402, blip, BLIP_COLOR_YELLOW) -- alt color setter (fallback)
        -- Scale up a touch for visibility
        pcall(function() Citizen.InvokeNative(0xD38744167B2FA257, blip, 1.2) end) -- SET_BLIP_SCALE
        if label then
            -- SET_BLIP_NAME_FROM_PLAYER_STRING via SetTextComponent for RedM
            pcall(function()
                Citizen.InvokeNative(0x9CB1A1623062F402, blip, label)
            end)
        end
    end
    return blip
end

-- Spawn a flag prop at a coord (ground-snapped). Returns the prop entity.
local function SpawnFlagProp(x, y, z, heading)
    local model = FLAG_PROP
    if not IsModelInCdimage(model) then return 0 end
    RequestModel(model)
    local t = 0
    while not HasModelLoaded(model) and t < 50 do
        Wait(50); t = t + 1
    end
    if not HasModelLoaded(model) then return 0 end
    local gz = GroundZ(x, y, z)
    local prop = CreateObject(model, x + 0.0, y + 0.0, gz + 0.0, false, false, false, false, false)
    if prop and prop ~= 0 then
        SetEntityHeading(prop, heading or 0.0)
        if PlaceObjectOnGroundProperly then pcall(PlaceObjectOnGroundProperly, prop) end
        FreezeEntityPosition(prop, true)
        SetEntityInvincible(prop, true)
    end
    SetModelAsNoLongerNeeded(model)
    return prop or 0
end

local function ClearProps(list)
    if not list then return end
    for i, p in ipairs(list) do
        if p and p ~= 0 and DoesEntityExist(p) then
            DeleteObject(p); DeleteEntity(p)
        end
        list[i] = nil
    end
end

-- Spawn 2 flags at the start line + 2 at the finish line
-- Flags are placed perpendicular to the track direction (one left, one right)
-- with 3 meters between them, and rotated 90° so the flag fabric faces across the track.
local function SpawnRaceFlags(startPositions, checkpoints, list)
    ClearProps(list)
    local HALF_GAP = 3.5 -- 3.5m each side = 7m total between the two flags
    -- RedM heading convention: 0 = north (+Y). Forward = (-sin(h), cos(h)),
    -- Right vector (perpendicular to track) = (cos(h), sin(h)).
    -- Start line: use first start pos and offset perpendicular to heading
    if startPositions and startPositions[1] then
        local sp = startPositions[1]
        local hx, hy = tonumber(sp.x), tonumber(sp.y)
        local hz = tonumber(sp.z)
        local h  = tonumber(sp.heading or 0.0)
        local rad = math.rad(h)
        -- left/right of the rider (perpendicular to facing direction)
        local ox = math.cos(rad) * HALF_GAP
        local oy = math.sin(rad) * HALF_GAP
        local f1 = SpawnFlagProp(hx + ox, hy + oy, hz, h)
        local f2 = SpawnFlagProp(hx - ox, hy - oy, hz, h)
        if f1 ~= 0 then list[#list+1] = f1 end
        if f2 ~= 0 then list[#list+1] = f2 end
    end
    -- Finish line: last checkpoint, offset perpendicular to direction from previous CP
    if checkpoints and #checkpoints > 0 then
        local last = checkpoints[#checkpoints]
        local fx, fy = tonumber(last.x), tonumber(last.y)
        local fz = tonumber(last.z)
        local dirH = 0.0
        if #checkpoints >= 2 then
            local prev = checkpoints[#checkpoints - 1]
            dirH = math.deg(math.atan(fx - tonumber(prev.x), fy - tonumber(prev.y)))
        end
        local rad = math.rad(dirH)
        local ox = math.cos(rad) * HALF_GAP
        local oy = math.sin(rad) * HALF_GAP
        local f3 = SpawnFlagProp(fx + ox, fy + oy, fz, dirH)
        local f4 = SpawnFlagProp(fx - ox, fy - oy, fz, dirH)
        if f3 ~= 0 then list[#list+1] = f3 end
        if f4 ~= 0 then list[#list+1] = f4 end
    end
end

-- Play checkpoint pass sound
local function PlayCheckpointSound()
    pcall(function()
        Citizen.InvokeNative(0x67C540AA08E4A6F5, CP_SOUND_NAME, CP_SOUND_SET, true, 0)
    end)
end

-- ============================================================
-- NO-COLLISION SYSTEM (mounts + wagons)
-- ============================================================
CreateThread(function()
    while true do
        if noCollision and inRace then
            Wait(0)
            local myPed = PlayerPedId()
            local myEnt = GetMountOrVehicle(myPed)
            if myEnt ~= 0 then
                for _, pid in ipairs(GetActivePlayers()) do
                    if pid ~= PlayerId() then
                        local otherPed = GetPlayerPed(pid)
                        if otherPed and otherPed ~= 0 and DoesEntityExist(otherPed) then
                            local otherEnt = GetMountOrVehicle(otherPed)
                            if otherEnt ~= 0 and otherEnt ~= myEnt and DoesEntityExist(otherEnt) then
                                SetEntityNoCollisionEntity(myEnt, otherEnt, true)
                                SetEntityNoCollisionEntity(otherEnt, myEnt, true)
                            end
                            -- also peds vs peds
                            SetEntityNoCollisionEntity(myPed, otherPed, true)
                            SetEntityNoCollisionEntity(otherPed, myPed, true)
                        end
                    end
                end
            end
        else
            Wait(300)
        end
    end
end)

-- ============================================================
-- IN-GAME NUI HUD
-- ============================================================
local function UpdateRaceHUD()
    if not inRace or not raceData then
        SendNUIMessage({ action = 'raceHUD', show = false })
        return
    end

    local cpTotal  = #(raceData.checkpoints or {})
    local cpPassed = math.min(myCheckpoint - 1, cpTotal)
    local gameT    = GetGameTimer()
    local elapsed  = gameT - (raceStartTime or gameT)
    local mins     = math.floor(elapsed / 60000)
    local secs     = math.floor((elapsed % 60000) / 1000)
    local ms       = elapsed % 1000

    -- Speed (mount/wagon/onfoot)
    local ped   = PlayerPedId()
    local ent   = GetMountOrVehicle(ped)
    local speed
    if ent ~= 0 then
        speed = GetEntitySpeed(ent)
    else
        speed = GetEntitySpeed(ped)
    end
    if Config.UseMPH then speed = math.floor(speed * 2.236936) else speed = math.floor(speed * 3.6) end

    -- Calculate position
    local pos        = 1
    local myServerId = GetPlayerServerId(PlayerId())
    for _, p in ipairs(participants) do
        if p.source ~= myServerId and (p.cpDone or 0) > cpPassed then
            pos = pos + 1
        end
    end

    -- Top-10 ranking
    local racersSorted = {}
    for _, p in ipairs(participants) do racersSorted[#racersSorted + 1] = p end
    local meIn = false
    for _, p in ipairs(racersSorted) do if p.source == myServerId then meIn = true; break end end
    if not meIn then
        racersSorted[#racersSorted + 1] = { source = myServerId, name = 'You', cpDone = (myCheckpoint or 1) - 1, finishTime = nil }
    end
    table.sort(racersSorted, function(a, b)
        if (a.cpDone or 0) ~= (b.cpDone or 0) then return (a.cpDone or 0) > (b.cpDone or 0) end
        return (a.name or '') < (b.name or '')
    end)
    local racersNUI = {}
    for i = 1, math.min(#racersSorted, 10) do
        local p = racersSorted[i]
        local isMe = (p.source == myServerId)
        local gap = ''
        if p.finishTime then
            gap = string.format('%d:%02d', math.floor(p.finishTime/60), p.finishTime%60)
        end
        racersNUI[#racersNUI + 1] = { position = i, name = p.name or 'Unknown', isMe = isMe, gap = gap }
    end

    SendNUIMessage({
        action      = 'raceHUD',
        show        = true,
        position    = 'P' .. pos,
        lap         = currentLap .. '/' .. totalLaps,
        speed       = speed,
        checkpts    = cpPassed .. '/' .. cpTotal,
        timer       = string.format('%02d:%02d', mins, secs),
        timerBig    = string.format('%02d:%02d.%03d', mins, secs, ms),
        racers      = racersNUI,
        raceType    = raceType,
        speedUnit   = Config.UseMPH and 'MPH' or 'KM/H',
        bestLap     = bestLapTime and string.format('%02d:%02d.%03d', math.floor(bestLapTime/60000), math.floor((bestLapTime%60000)/1000), bestLapTime%1000) or nil,
    })
end

-- ============================================================
-- CHECKPOINT MARKERS — simple vertical cylinder + ground ring
-- ============================================================
local function DrawCheckpointGate(cpIndex)
    if not raceData or not raceData.checkpoints then return end
    local cp = raceData.checkpoints[cpIndex]
    if not cp then return end
    local cx, cy = tonumber(cp.x), tonumber(cp.y)
    local gz = GroundZ(cx, cy, tonumber(cp.z))
    local isFinish = (cpIndex == #raceData.checkpoints)

    if isFinish then
        -- Finish: red double ring on ground
        DrawRedmMarker(MARKER_RING, cx, cy, gz + 0.05, 6.0, 6.0, 0.2, 255, 50, 50, 200)
        DrawRedmMarker(MARKER_RING, cx, cy, gz + 0.05, 4.0, 4.0, 0.2, 255, 255, 255, 160)
    else
        local c = Config.CheckpointColor
        DrawRedmMarker(MARKER_RING, cx, cy, gz + 0.05, 5.5, 5.5, 0.2, c[1], c[2], c[3], c[4])
        DrawRedmMarker(MARKER_RING, cx, cy, gz + 0.05, 3.5, 3.5, 0.2, c[1], c[2], c[3], math.floor((c[4] or 180) * 0.5))
    end
end

local function DrawLobbyFlag(positions)
    if not positions or #positions == 0 then return end
    local myServerId = GetPlayerServerId(PlayerId())
    local myIdx = 1
    for i, p in ipairs(participants) do
        if p.source == myServerId then myIdx = i; break end
    end
    local slotIdx = ((myIdx - 1) % #positions) + 1
    local sp = positions[slotIdx] or positions[1]
    local sx, sy = tonumber(sp.x), tonumber(sp.y)
    local gz = GroundZ(sx, sy, tonumber(sp.z))
    local c = Config.StartColor
    DrawRedmMarker(MARKER_RING, sx, sy, gz + 0.05, 4.5, 4.5, 0.2, c[1], c[2], c[3], c[4])
    DrawRedmMarker(MARKER_RING, sx, sy, gz + 0.05, 2.8, 2.8, 0.2, c[1], c[2], c[3], math.floor((c[4] or 200) * 0.5))
end

-- ============================================================
-- BLIPS
-- ============================================================
-- ============================================================
-- GPS multi-route line on minimap (yellow)
-- ============================================================
local gpsRouteActive = false
local gpsRouteCheckpoints = nil
local gpsRouteFromIndex = 1

function ClearGpsRoute()
    gpsRouteActive = false
    gpsRouteCheckpoints = nil
    gpsRouteFromIndex = 1
    pcall(ClearGpsMultiRoute)
end

local function RenderGpsRouteNow()
    if not gpsRouteCheckpoints then return end
    pcall(ClearGpsMultiRoute)
    pcall(StartGpsMultiRoute, joaat('COLOR_YELLOW'), true, true)
    for i = (gpsRouteFromIndex or 1), #gpsRouteCheckpoints do
        local cp = gpsRouteCheckpoints[i]
        if cp then
            pcall(AddPointToGpsMultiRoute, tonumber(cp.x), tonumber(cp.y), tonumber(cp.z))
        end
    end
    pcall(SetGpsMultiRouteRender, true)
end

-- Create the route once; only re-render when the checkpoint list or the
-- starting index actually changes. This avoids flicker from constant rebuilds.
function StartGpsRouteFromCheckpoints(checkpoints, fromIndex)
    if not checkpoints or #checkpoints == 0 then ClearGpsRoute(); return end
    fromIndex = fromIndex or 1
    if gpsRouteActive and gpsRouteCheckpoints == checkpoints and gpsRouteFromIndex == fromIndex then
        return -- already rendered with same data; do not rebuild
    end
    gpsRouteCheckpoints = checkpoints
    gpsRouteFromIndex = fromIndex
    gpsRouteActive = true
    RenderGpsRouteNow()
end

-- Persistent renderer: re-asserts SetGpsMultiRouteRender(true) without
-- rebuilding the route. Some natives quietly disable the render flag when
-- the player leaves a checkpoint area; re-asserting keeps the yellow line
-- visible without causing flicker (we never call StartGpsMultiRoute here).
CreateThread(function()
    while true do
        if gpsRouteActive then
            pcall(SetGpsMultiRouteRender, true)
        end
        Wait(2000)
    end
end)



function ClearBlips()
    for _, b in ipairs(cpBlips) do
        if b and DoesBlipExist(b) then RemoveBlip(b) end
    end
    cpBlips = {}
    ClearGpsRoute()
end

function ClearLobbyBlips()
    for _, b in ipairs(lobbyBlips) do
        if b and DoesBlipExist(b) then RemoveBlip(b) end
    end
    lobbyBlips = {}
    ClearGpsRoute()
end

function BuildLobbyBlips(checkpoints, startPositions)
    ClearLobbyBlips()
    if startPositions then
        for i, sp in ipairs(startPositions) do
            local b = AddRedmBlip(BLIP_START, tonumber(sp.x), tonumber(sp.y), tonumber(sp.z), 'Start ' .. i)
            table.insert(lobbyBlips, b)
        end
    end
    if checkpoints then
        local total = #checkpoints
        for i, cp in ipairs(checkpoints) do
            local isFinish = (i == total)
            local b = AddRedmBlip(isFinish and BLIP_FINISH or BLIP_CP,
                tonumber(cp.x), tonumber(cp.y), tonumber(cp.z),
                isFinish and 'Finish' or ('CP ' .. i))
            table.insert(lobbyBlips, b)
        end
    end
    if checkpoints then
        StartGpsRouteFromCheckpoints(checkpoints, 1)
    end
end

local function DrawLobbyCheckpoints(checkpoints)
    if not checkpoints or #checkpoints == 0 then return end
    local total = #checkpoints
    for i, cp in ipairs(checkpoints) do
        local cx, cy = tonumber(cp.x), tonumber(cp.y)
        local gz = GroundZ(cx, cy, tonumber(cp.z))
        local isFinish = (i == total)
        if isFinish then
            DrawRedmMarker(MARKER_RING, cx, cy, gz + 0.05, 5.0, 5.0, 0.15, 255, 255, 255, 110)
        else
            DrawRedmMarker(MARKER_RING, cx, cy, gz + 0.05, 4.0, 4.0, 0.12, 255, 200, 0, 90)
        end
    end
end

function BuildBlips()
    ClearBlips()
    if not raceData then return end
    for i, cp in ipairs(raceData.checkpoints) do
        local isFinish = (i == #raceData.checkpoints)
        local b = AddRedmBlip(isFinish and BLIP_FINISH or BLIP_CP,
            tonumber(cp.x), tonumber(cp.y), tonumber(cp.z),
            ('CP %d | Lap %d'):format(i, currentLap))
        cpBlips[i] = b
    end
    local c = raceData.checkpoints[myCheckpoint]
    if c and SetNewWaypoint then
        pcall(SetNewWaypoint, tonumber(c.x), tonumber(c.y))
    end
    StartGpsRouteFromCheckpoints(raceData.checkpoints, myCheckpoint)
end

function AdvanceBlip()
    local c = raceData and raceData.checkpoints[myCheckpoint]
    if c and SetNewWaypoint then
        pcall(SetNewWaypoint, tonumber(c.x), tonumber(c.y))
    end
    if raceData then
        StartGpsRouteFromCheckpoints(raceData.checkpoints, myCheckpoint)
    end
end

-- ============================================================
-- START COUNTDOWN
-- ============================================================
RegisterNetEvent('race:startCountdown')
AddEventHandler('race:startCountdown', function(data)
    raceData     = data
    participants = data.participants or {}
    myCheckpoint = 1
    currentLap   = 1
    totalLaps    = tonumber(data.laps) or 1
    inRace       = false
    raceType     = (data.raceType or 'circuit'):lower()
    bestLapTime  = nil
    lapStartTime = nil

    local col = data.collision
    noCollision = (col == false or col == 0)

    lib.notify({ title='Racing', description='🏁 ' .. (data.raceName or 'Race') .. ' — get ready!', type='success', duration=4000 })

    lobbyStartPos = nil; lobbyCheckpoints = nil
    ClearLobbyBlips()
    ClearProps(lobbyRaceProps)
    BuildBlips()
    SpawnRaceFlags(data.startPos, raceData and raceData.checkpoints, raceProps)

    local ped = PlayerPedId()
    local ent = GetMountOrVehicle(ped)
    if ent ~= 0 then FreezeEntityPosition(ent, true) end

    CreateThread(function()
        Wait(1000)
        for i = 5, 1, -1 do
            lib.notify({ title='Racing', description = tostring(i), type='inform', duration=900 })
            SendNUIMessage({ action='countdown', value = i })
            -- Synchronized countdown tick + spoken number (all clients receive the event together)
            pcall(function()
                Citizen.InvokeNative(0x67C540AA08E4A6F5, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAMES_SOUNDSET', true, 0)
                -- Spoken number speech on the local ped
                local ped = PlayerPedId()
                local speech = ('NUMBER_%d'):format(i)
                Citizen.InvokeNative(0x8E04FEDD28D42462, ped, speech, 'GENERIC_GROUP', 'Speech_Params_Force_Shouted_Critical', 0)
            end)
            Wait(1000)
        end
        SendNUIMessage({ action='countdown', value = 'GO!' })
        lib.notify({ title='Racing', description='🟢 GO!', type='success', duration=1500 })
        -- Race start horn / GO sound + spoken "GO!"
        pcall(function()
            Citizen.InvokeNative(0x67C540AA08E4A6F5, 'Bell_Hit', 'GANG_HIDEOUT_RAID_SOUNDS', true, 0)
            Citizen.InvokeNative(0x67C540AA08E4A6F5, 'RACE_START', 'HUD_MINI_GAMES_SOUNDSET', true, 0)
            Citizen.InvokeNative(0x67C540AA08E4A6F5, 'Event_Start', 'HUD_MINI_GAMES_SOUNDSET', true, 0)
            local ped = PlayerPedId()
            Citizen.InvokeNative(0x8E04FEDD28D42462, ped, 'GENERIC_HI', 'GENERIC_GROUP', 'Speech_Params_Force_Shouted_Critical', 0)
        end)

        local ent2 = GetMountOrVehicle(PlayerPedId())
        if ent2 ~= 0 then FreezeEntityPosition(ent2, false) end

        Wait(200)
        inRace        = true
        raceStartTime = GetGameTimer()
        lapStartTime  = GetGameTimer()
        TriggerServerEvent('race:raceActuallyStarted')
        StartTracking()
    end)
end)

-- ============================================================
-- CHECKPOINT TRACKING (multi-lap aware)
-- ============================================================
function StartTracking()
    CreateThread(function()
        while inRace and raceData do
            Wait(50)
            if not raceData or not raceData.checkpoints then break end
            if myCheckpoint > #raceData.checkpoints then break end

            local ped  = PlayerPedId()
            local ent  = GetMountOrVehicle(ped)
            local pos  = ent ~= 0 and GetEntityCoords(ent) or GetEntityCoords(ped)
            local cp   = raceData.checkpoints[myCheckpoint]
            if not cp then break end

            local dist = #(pos - vector3(tonumber(cp.x), tonumber(cp.y), tonumber(cp.z)))
            if dist < (Config.CheckpointRadius or 12.0) then
                local globalCp = (currentLap - 1) * #raceData.checkpoints + myCheckpoint
                TriggerServerEvent('race:checkpointPassed', globalCp)
                PlayCheckpointSound()

                myCheckpoint = myCheckpoint + 1
                AdvanceBlip()

                if myCheckpoint > #raceData.checkpoints then
                    if currentLap < totalLaps then
                        if raceType == 'timetrial' and lapStartTime then
                            local lapMs = GetGameTimer() - lapStartTime
                            if bestLapTime == nil or lapMs < bestLapTime then
                                bestLapTime = lapMs
                                lib.notify({ title='Racing', description='🏁 BEST LAP!', type='success', duration=2500 })
                            end
                        end
                        lapStartTime = GetGameTimer()
                        currentLap   = currentLap + 1
                        myCheckpoint = 1
                        BuildBlips()
                        lib.notify({ title='Racing', description='LAP ' .. currentLap, type='inform', duration=2200 })
                    else
                        inRace = false; raceData = nil
                        noCollision = false
                        lobbyStartPos = nil
                        ClearBlips()
                        ClearProps(raceProps)
                        participants = {}
                        SendNUIMessage({ action = 'raceHUD', show = false })
                        break
                    end
                end
            end
        end
    end)
end

-- ============================================================
-- MAIN RENDER THREAD — markers
-- ============================================================
CreateThread(function()
    while true do
        Wait(0)
        if inRace and raceData then
            local totalCPs = #(raceData.checkpoints or {})
            if myCheckpoint <= totalCPs then
                DrawCheckpointGate(myCheckpoint)
            end
            if totalCPs > 0 and myCheckpoint < totalCPs then
                DrawCheckpointGate(totalCPs)
            end
        elseif lobbyCheckpoints or lobbyStartPos then
            if lobbyCheckpoints then DrawLobbyCheckpoints(lobbyCheckpoints) end
            if lobbyStartPos    then DrawLobbyFlag(lobbyStartPos) end
        else
            Wait(300)
        end
    end
end)

-- HUD update thread
CreateThread(function()
    while true do
        if inRace then
            Wait(100); UpdateRaceHUD()
        else
            Wait(500)
            SendNUIMessage({ action = 'raceHUD', show = false })
        end
    end
end)

-- ============================================================
-- NET EVENTS
-- ============================================================
RegisterNetEvent('race:updateParticipants', function(list)
    participants = list or {}
end)

RegisterNetEvent('race:lobbySelected', function(data)
    if data and data.raceData then
        lobbyStartPos    = (data.startPos    and #data.startPos    > 0) and data.startPos    or nil
        lobbyCheckpoints = (data.checkpoints and #data.checkpoints > 0) and data.checkpoints or nil
        BuildLobbyBlips(lobbyCheckpoints, lobbyStartPos)
        SpawnRaceFlags(lobbyStartPos, lobbyCheckpoints, lobbyRaceProps)
    else
        lobbyStartPos = nil; lobbyCheckpoints = nil
        ClearLobbyBlips()
        ClearProps(lobbyRaceProps)
    end
end)

RegisterNetEvent('race:showResults', function()
    inRace = false; raceData = nil
    noCollision = false
    lobbyStartPos = nil; lobbyCheckpoints = nil
    ClearBlips(); ClearLobbyBlips()
    ClearProps(raceProps); ClearProps(lobbyRaceProps)
    participants = {}
    SendNUIMessage({ action = 'raceHUD', show = false })
end)

RegisterNetEvent('race:cancelled', function()
    inRace = false; raceData = nil
    noCollision = false
    lobbyStartPos = nil; lobbyCheckpoints = nil
    ClearBlips(); ClearLobbyBlips()
    ClearProps(raceProps); ClearProps(lobbyRaceProps)
    SendNUIMessage({ action = 'raceHUD', show = false })
    lib.notify({ title='Racing', description='Race Cancelled', type='warning', duration=4000 })
end)

RegisterNetEvent('race:showAnnounce', function(lines)
    local racersNUI = {}
    for i = 2, #lines do
        racersNUI[#racersNUI + 1] = {
            position = i - 1, name = lines[i], isMe = false, gap = '',
        }
    end
    SendNUIMessage({ action = 'raceAnnounce', show = true, raceName = lines[1] or '', racers = racersNUI })
    SetTimeout(12000, function()
        SendNUIMessage({ action = 'raceAnnounce', show = false })
    end)
end)
