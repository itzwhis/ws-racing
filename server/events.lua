-- ============================================================
-- WS Racing — Server Events (adapted from qb-core)
-- ============================================================
 -- ============================================================
-- Reselling is NOT allowed.
-- ============================================================
local RSGCore = exports['rsg-core']:GetCoreObject()

local endRaceLock = false

local function sendRaceLobbyState(target)
    TriggerClientEvent('race:lobbySelected', target, {
        active       = RaceState.active,
        raceId       = RaceState.raceId,
        raceData     = RaceState.raceData,
        participants = RaceState.participants,
        betAmount    = RaceState.betAmount,
        startPos     = RaceState.startPos,
        checkpoints  = RaceState.checkpoints,
    })
end

local function sendStartCountdown(data)
    local sent = {}
    for _, p in ipairs(RaceState.participants) do
        if p.source and not sent[p.source] then
            TriggerClientEvent('race:startCountdown', p.source, data); sent[p.source] = true
        end
    end
    if RaceState.adminSource and not sent[RaceState.adminSource] then
        TriggerClientEvent('race:startCountdown', RaceState.adminSource, data)
    end
end

local function CheckRaceComplete()
    if not RaceState.active or endRaceLock then return end
    local stillRacing = 0
    for _, p in ipairs(RaceState.participants) do
        if not p.finishTime and not p.dnf then stillRacing = stillRacing + 1 end
    end
    if stillRacing == 0 then TriggerEvent('race:endRace') end
end

-- ============================================================
-- ADMIN: Save new race
-- ============================================================
RegisterNetEvent('race:saveRace', function(d)
    local src = source
    if not IsAdmin(src) then return end

    local raceId = Database.CreateRace({
        name            = d.name,
        raceType        = d.raceType or 'circuit',
        maxParticipants = d.maxParticipants or 10,
        minLevel        = d.minLevel or 0,
        collision       = d.collision,
        blacklist       = d.blacklist or {},
        laps            = tonumber(d.laps) or 1,
        mountClass      = d.mountClass or 'open',
    })
    if not raceId or raceId == 0 then
        Notify(src, 'Failed to save race', 'error'); return
    end
    if d.checkpoints and #d.checkpoints > 0 then
        Database.SaveCheckpoints(raceId, d.checkpoints)
    end
    if d.startPositions and #d.startPositions > 0 then
        Database.SaveStartPositions(raceId, d.startPositions)
    end
    Notify(src, '✅ Race saved: ' .. d.name, 'success')
end)

-- ============================================================
-- ADMIN: Delete race
-- ============================================================
RegisterNetEvent('race:deleteRace', function(raceId)
    local src = source
    if not IsAdmin(src) then return end
    if RaceState.raceId == raceId then
        TriggerClientEvent('race:cancelled', -1)
        HardResetRaceState()
    end
    Database.DeleteRace(raceId)
    Notify(src, 'Race deleted', 'success')
end)

RegisterNetEvent('race:adminGetRaces', function()
    local src = source
    if not IsAdmin(src) then return end
    TriggerClientEvent('race:adminReceiveRaces', src, Database.GetAllRaces())
end)

-- ============================================================
-- ADMIN: Select race
-- ============================================================
RegisterNetEvent('race:adminSelectRace', function(raceId)
    local src = source
    if not IsAdmin(src) then return end

    if RaceState.active or endRaceLock then
        Notify(src, '⚠️ Clearing previous race state...', 'warning')
        endRaceLock = false
        TriggerClientEvent('race:cancelled', -1)
        HardResetRaceState()
    end

    local race = Database.GetRaceById(raceId)
    if not race then Notify(src, 'Race not found', 'error'); return end

    local checkpoints = Database.GetCheckpoints(raceId)
    local startPos    = Database.GetStartPositions(raceId)
    if #checkpoints == 0 then Notify(src, 'Race has no checkpoints', 'error'); return end

    HardResetRaceState()
    RaceState.raceId      = raceId
    RaceState.raceData    = race
    RaceState.checkpoints = checkpoints
    RaceState.startPos    = startPos
    RaceState.adminSource = src

    Notify(src, '✅ Selected race: ' .. race.name, 'success')
    sendRaceLobbyState(src)
end)

-- ============================================================
-- ADMIN: Open lobby
-- ============================================================
RegisterNetEvent('race:adminOpenLobby', function(d)
    local src = source
    if not IsAdmin(src) then return end

    if RaceState.active then
        Notify(src, '⚠️ Clearing previous race...', 'warning')
        endRaceLock = false
        TriggerClientEvent('race:cancelled', -1)
        HardResetRaceState()
    end

    local raceId = tonumber(d.raceId)
    local race   = Database.GetRaceById(raceId)
    if not race then Notify(src, 'Race not found', 'error'); return end

    local checkpoints = Database.GetCheckpoints(raceId)
    local startPos    = Database.GetStartPositions(raceId)
    if #checkpoints == 0 then Notify(src, 'Race has no checkpoints', 'error'); return end

    race.max_participants = d.maxParticipants or race.max_participants or 10
    race.laps             = d.laps or race.laps or 1
    race.race_type        = d.raceType or race.race_type or 'circuit'
    race.collision        = d.collision

    HardResetRaceState()
    RaceState.raceId      = raceId
    RaceState.raceData    = race
    RaceState.checkpoints = checkpoints
    RaceState.startPos    = startPos
    RaceState.adminSource = src
    RaceState.betAmount   = d.betAmount or 0

    -- Auto-add admin as participant
    local adminPlayer = RSGCore.Functions.GetPlayer(src)
    if adminPlayer then
        local adminName = adminPlayer.PlayerData.charinfo.firstname .. ' ' .. adminPlayer.PlayerData.charinfo.lastname
        table.insert(RaceState.participants, {
            source     = src,
            citizenId  = adminPlayer.PlayerData.citizenid,
            name       = adminName,
            cpDone     = 0,
            finishTime = nil,
            dnf        = false,
        })
    end

    Notify(src, '✅ Lobby opened: ' .. race.name, 'success')
    TriggerClientEvent('race:lobbyOpened', src)
    TriggerClientEvent('race:lobbySelected', -1, {
        active=false, raceId=RaceState.raceId, raceData=RaceState.raceData,
        participants=RaceState.participants, betAmount=RaceState.betAmount,
        startPos=RaceState.startPos, checkpoints=RaceState.checkpoints,
    })
    TriggerClientEvent('race:updateParticipants', -1, RaceState.participants)
end)

-- ============================================================
-- ADMIN: Start race
-- ============================================================
RegisterNetEvent('race:adminStartRace', function(raceId, betAmount)
    local src = source
    if not IsAdmin(src) then return end

    if RaceState.active then
        Notify(src, '⚠️ Race was stuck — force-cleared. Re-select the race.', 'warning')
        endRaceLock = false
        TriggerClientEvent('race:cancelled', -1)
        HardResetRaceState()
        sendRaceLobbyState(src)
        return
    end

    if not RaceState.raceData or RaceState.raceId ~= raceId then
        Notify(src, 'Select the race from Race List first', 'error'); return
    end
    if #RaceState.checkpoints == 0 then
        Notify(src, 'Race has no checkpoints', 'error'); return
    end
    if #RaceState.participants < Config.MinParticipants then
        Notify(src, ('Not enough participants (%d/%d)'):format(#RaceState.participants, Config.MinParticipants), 'error'); return
    end

    RaceState.active      = true
    RaceState.betAmount   = betAmount or 0
    RaceState.adminSource = src

    if betAmount and betAmount > 0 then
        local kept = {}
        for _, p in ipairs(RaceState.participants) do
            local player = RSGCore.Functions.GetPlayer(p.source)
            if player and player.Functions.GetMoney('cash') >= betAmount then
                player.Functions.RemoveMoney('cash', betAmount, 'race-bet')
                kept[#kept + 1] = p
            else
                Notify(p.source, 'Not enough cash for bet — removed from race', 'error')
            end
        end
        RaceState.participants = kept
        if #RaceState.participants < Config.MinParticipants then
            RaceState.active = false
            Notify(src, 'Not enough participants after bet check', 'error')
            sendRaceLobbyState(src)
            return
        end
    end

    local laps = tonumber(RaceState.raceData.laps) or 1
    RaceState.totalCPs = #RaceState.checkpoints * laps

    local payload = {
        raceId       = RaceState.raceId,
        raceName     = RaceState.raceData.name,
        checkpoints  = RaceState.checkpoints,
        startPos     = RaceState.startPos,
        betAmount    = RaceState.betAmount,
        participants = RaceState.participants,
        raceType     = RaceState.raceData.race_type,
        laps         = laps,
        collision    = RaceState.raceData.collision,
        mountClass   = RaceState.raceData.mount_class,
    }

    sendStartCountdown(payload)
    sendRaceLobbyState(-1)
    NotifyRace('🏁 Race starting: ' .. (RaceState.raceData.name or 'Race'), 'success')

    local safetyRaceId = RaceState.raceId
    SetTimeout(90 * 60 * 1000, function()
        if RaceState.active and RaceState.raceId == safetyRaceId then
            print('[ws-racing] Safety timeout: force-ending stuck race ' .. tostring(safetyRaceId))
            TriggerEvent('race:endRace')
        end
    end)
end)

-- ============================================================
-- ADMIN: Cancel
-- ============================================================
RegisterNetEvent('race:adminCancel', function()
    local src = source
    if not IsAdmin(src) then return end

    if RaceState.active and RaceState.betAmount > 0 then
        for _, p in ipairs(RaceState.participants) do
            local player = RSGCore.Functions.GetPlayer(p.source)
            if player then player.Functions.AddMoney('cash', RaceState.betAmount, 'race-refund') end
        end
    end

    endRaceLock = false
    TriggerClientEvent('race:cancelled', -1)
    HardResetRaceState()
    NotifyRace('Race cancelled', 'warning')

    TriggerClientEvent('race:lobbySelected', -1, {
        active=false, raceId=nil, raceData=nil, participants={},
        betAmount=0, startPos=nil, checkpoints=nil,
    })
end)

-- ============================================================
-- PLAYER: Join race
-- ============================================================
RegisterNetEvent('race:playerJoin', function(playerMountClass)
    local src    = source
    local player = RSGCore.Functions.GetPlayer(src)
    if not player then return end
    if RaceState.active then Notify(src, 'Race already started', 'error'); return end
    if not RaceState.raceData then Notify(src, 'No race available to join', 'error'); return end
    if GetParticipantIdx(src) then Notify(src, 'You already joined', 'warning'); return end
    if #RaceState.participants >= (RaceState.raceData.max_participants or 10) then
        Notify(src, 'Race is full', 'error'); return
    end

    -- Mount class restriction
    local restriction = RaceState.raceData.mount_class
    if restriction and restriction ~= '' and restriction ~= 'open' then
        local reqName = (Config.MountClasses[restriction] or restriction)
        if not playerMountClass or playerMountClass ~= restriction then
            Notify(src, ('⛔ This race is %s only. Your status: %s'):format(reqName, tostring(playerMountClass or 'unknown')), 'error')
            return
        end
    end

    local name = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
    table.insert(RaceState.participants, {
        source=src, citizenId=player.PlayerData.citizenid,
        name=name, cpDone=0, finishTime=nil, dnf=false,
    })

    Notify(src, '✅ Joined race: ' .. (RaceState.raceData.name or ''), 'success')
    if RaceState.adminSource then
        Notify(RaceState.adminSource, '👤 ' .. name .. ' joined (' .. #RaceState.participants .. ')', 'info')
        sendRaceLobbyState(RaceState.adminSource)
    end
    for _, p in ipairs(RaceState.participants) do
        if p.source and p.source ~= src then
            Notify(p.source, '👤 ' .. name .. ' joined', 'inform')
        end
    end
    sendRaceLobbyState(src)
    TriggerClientEvent('race:updateParticipants', -1, RaceState.participants)
end)

-- ============================================================
-- PLAYER: Leave race
-- ============================================================
RegisterNetEvent('race:playerLeave', function()
    local src = source
    local idx = GetParticipantIdx(src)
    if not idx then return end
    local name = RaceState.participants[idx].name

    if RaceState.active then
        RaceState.participants[idx].dnf = true
        TriggerClientEvent('race:updateParticipants', -1, RaceState.participants)
        CheckRaceComplete()
    else
        table.remove(RaceState.participants, idx)
        TriggerClientEvent('race:updateParticipants', -1, RaceState.participants)
    end

    Notify(src, 'You left the race', 'warning')
    if RaceState.adminSource then
        Notify(RaceState.adminSource, '👤 ' .. name .. ' left', 'warning')
        sendRaceLobbyState(RaceState.adminSource)
    end
end)

-- ============================================================
-- PLAYER: Checkpoint passed
-- ============================================================
RegisterNetEvent('race:checkpointPassed', function(globalCpIndex)
    local src = source
    local idx = GetParticipantIdx(src)
    if not idx or not RaceState.active then return end
    if RaceState.participants[idx].dnf then return end
    if RaceState.participants[idx].finishTime then return end

    RaceState.participants[idx].cpDone = globalCpIndex
    TriggerClientEvent('race:updateParticipants', -1, RaceState.participants)

    local totalCPs = RaceState.totalCPs
    if not totalCPs or totalCPs == 0 then totalCPs = #RaceState.checkpoints end

    if globalCpIndex >= totalCPs then
        local finishTime = os.time() - (RaceState.startTime or os.time())
        RaceState.participants[idx].finishTime = finishTime
        local m = math.floor(finishTime / 60)
        local s = finishTime % 60
        Notify(src, ('🏆 Finished! Time: %d:%02d'):format(m, s), 'success')
        CheckRaceComplete()
    end
end)

RegisterNetEvent('race:adminGetParticipants', function()
    local src = source
    if not IsAdmin(src) then return end
    sendRaceLobbyState(src)
end)

RegisterNetEvent('race:playerGetRaces', function()
    TriggerClientEvent('race:playerReceiveRaces', source, Database.GetAllRaces())
end)

RegisterNetEvent('race:getLeaderboard', function(raceId)
    TriggerClientEvent('race:receiveLeaderboard', source, Database.GetLeaderboard(raceId))
end)

RegisterNetEvent('race:getGlobalLeaderboard', function()
    TriggerClientEvent('race:receiveGlobalLeaderboard', source, Database.GetGlobalLeaderboard())
end)

RegisterNetEvent('race:getMyStats', function()
    local src    = source
    local player = RSGCore.Functions.GetPlayer(src)
    if not player then return end
    local stats  = Database.GetPlayerStats(player.PlayerData.citizenid)
    TriggerClientEvent('race:receiveMyStats', src, stats)
end)

RegisterNetEvent('race:requestRecentRaces', function()
    TriggerClientEvent('race:receiveRecentRaces', source, Database.GetRecentRaces())
end)

-- ============================================================
-- Internal: End race
-- ============================================================
AddEventHandler('race:endRace', function()
    if not RaceState.active or endRaceLock then return end
    endRaceLock      = true
    RaceState.active = false

    local raceId    = RaceState.raceId
    local raceName  = RaceState.raceData and RaceState.raceData.name or 'Race'
    local betAmount = RaceState.betAmount
    local startTime = RaceState.startTime or os.time()
    local parts     = {}
    for _, p in ipairs(RaceState.participants) do
        parts[#parts + 1] = {
            source=p.source, citizenId=p.citizenId, name=p.name,
            finishTime=p.finishTime, dnf=p.dnf, cpDone=p.cpDone,
        }
    end

    local savedAdmin = RaceState.adminSource

    table.sort(parts, function(a, b)
        if a.finishTime and b.finishTime then return a.finishTime < b.finishTime end
        return a.finishTime ~= nil
    end)

    local totalPot = betAmount * #parts
    local winner   = nil
    for _, p in ipairs(parts) do
        if p.finishTime then winner = p; break end
    end

    if winner and totalPot > 0 then
        local wp = RSGCore.Functions.GetPlayer(winner.source)
        if wp then wp.Functions.AddMoney('cash', totalPot, 'race-prize') end
    end

    for i, p in ipairs(parts) do
        if not p.dnf and p.citizenId then
            Database.SaveResult(raceId, p.citizenId, p.name,
                p.finishTime or 999, betAmount,
                i == 1 and totalPot or 0, i)
        end
    end

    local medals = { '🥇', '🥈', '🥉' }
    local announce = { '🏁  ' .. raceName .. '  🏁' }
    local top10Lines = {}
    for i, p in ipairs(parts) do
        local m = math.floor((p.finishTime or 0) / 60)
        local s = (p.finishTime or 0) % 60
        local t = p.finishTime and ('%d:%02d'):format(m, s) or 'DNF'
        if i <= 3 then
            announce[#announce+1] = (medals[i] or i..'.') .. '  ' .. (p.name or '?') .. '  —  ' .. t
        end
        if i <= 10 then
            top10Lines[#top10Lines+1] = '`' .. i .. '.` **' .. (p.name or '?') .. '**  —  `' .. t .. '`'
        end
    end

    local allTargets = {}
    for _, p in ipairs(parts) do if p.source then allTargets[p.source] = true end end
    if savedAdmin then allTargets[savedAdmin] = true end
    for tgt, _ in pairs(allTargets) do
        TriggerClientEvent('race:showAnnounce', tgt, announce)
    end

    TriggerClientEvent('race:showResults', -1, parts, winner and winner.name or 'N/A', totalPot)

    -- Discord webhook
    if Config.DiscordWebhook and Config.DiscordWebhook ~= '' and Config.DiscordWebhook ~= 'YOUR_WEBHOOK_URL_HERE' then
        local podium = ''
        for i = 1, math.min(3, #parts) do
            local p = parts[i]
            local m = math.floor((p.finishTime or 0)/60)
            local s = (p.finishTime or 0) % 60
            local t = p.finishTime and ('%d:%02d'):format(m, s) or 'DNF'
            podium = podium .. (medals[i] or i..'.') .. ' **' .. (p.name or '?') .. '** — `' .. t .. '`\n'
        end
        local prizeTxt = totalPot > 0 and ('💰 Prize Pool: **$' .. totalPot .. '**') or ''
        local payload = json.encode({
            username   = Config.DiscordBotName or 'WS Racing',
            avatar_url = Config.DiscordAvatar or nil,
            embeds = {{
                title       = '🏁 Race Finished — ' .. raceName,
                color       = 16766720,
                description = '**🏆 Top 3 Podium:**\n' .. podium .. '\n' .. prizeTxt,
                fields = {{ name = '📋 Top 10 Results', value = (table.concat(top10Lines, '\n') ~= '' and table.concat(top10Lines, '\n')) or 'No results', inline = false }},
                footer = { text = 'WS Racing System' },
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
            }}
        })
        PerformHttpRequest(Config.DiscordWebhook, function(code)
            if code ~= 204 and code ~= 200 then
                print('[ws-racing] Webhook error: ' .. tostring(code))
            end
        end, 'POST', payload, { ['Content-Type'] = 'application/json' })
    end

    HardResetRaceState()
    endRaceLock = false

    if savedAdmin then
        TriggerClientEvent('race:lobbySelected', savedAdmin, {
            active=false, raceId=nil, raceData=nil, participants={},
            betAmount=0, startPos=nil, checkpoints=nil,
        })
    end
    TriggerClientEvent('race:lobbySelected', -1, {
        active=false, raceId=nil, raceData=nil, participants={},
        betAmount=0, startPos=nil, checkpoints=nil,
    })
end)

RegisterNetEvent('race:raceActuallyStarted', function()
    RaceState.startTime = os.time()
end)

AddEventHandler('playerDropped', function()
    local src = source
    local idx = GetParticipantIdx(src)
    if not idx then return end
    if RaceState.active then
        RaceState.participants[idx].dnf = true
        TriggerClientEvent('race:updateParticipants', -1, RaceState.participants)
        if RaceState.adminSource then sendRaceLobbyState(RaceState.adminSource) end
        CheckRaceComplete()
    else
        table.remove(RaceState.participants, idx)
        if RaceState.adminSource then sendRaceLobbyState(RaceState.adminSource) end
        TriggerClientEvent('race:updateParticipants', -1, RaceState.participants)
    end
end)
