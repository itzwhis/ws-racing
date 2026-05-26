-- ============================================================
-- WS Racing — Database Layer (oxmysql)
-- ============================================================
 -- ============================================================
-- Reselling is NOT allowed.
-- ============================================================
Database = {}

function Database.Initialize()
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS `ws_races` (
            `id`               INT AUTO_INCREMENT PRIMARY KEY,
            `name`             VARCHAR(100) UNIQUE NOT NULL,
            `race_type`        VARCHAR(50)  NOT NULL DEFAULT 'circuit',
            `max_participants` INT          NOT NULL DEFAULT 10,
            `min_level`        INT          NOT NULL DEFAULT 0,
            `collision`        TINYINT      NOT NULL DEFAULT 1,
            `laps`             INT          NOT NULL DEFAULT 1,
            `blacklist_models` JSON,
            `mount_class`      VARCHAR(50)  NOT NULL DEFAULT 'open',
            `created_at`       TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]], {})
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS `ws_checkpoints` (
            `id`         INT AUTO_INCREMENT PRIMARY KEY,
            `race_id`    INT   NOT NULL,
            `sort_order` INT   NOT NULL,
            `x`          FLOAT NOT NULL,
            `y`          FLOAT NOT NULL,
            `z`          FLOAT NOT NULL,
            FOREIGN KEY (`race_id`) REFERENCES `ws_races`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]], {})
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS `ws_startpos` (
            `id`         INT AUTO_INCREMENT PRIMARY KEY,
            `race_id`    INT   NOT NULL,
            `sort_order` INT   NOT NULL,
            `x`          FLOAT NOT NULL,
            `y`          FLOAT NOT NULL,
            `z`          FLOAT NOT NULL,
            `heading`    FLOAT NOT NULL DEFAULT 0,
            FOREIGN KEY (`race_id`) REFERENCES `ws_races`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]], {})
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS `ws_race_results` (
            `id`          INT AUTO_INCREMENT PRIMARY KEY,
            `race_id`     INT          NOT NULL,
            `citizen_id`  VARCHAR(50)  NOT NULL,
            `player_name` VARCHAR(100) NOT NULL,
            `finish_time` INT          NOT NULL DEFAULT 0,
            `bet`         INT          NOT NULL DEFAULT 0,
            `prize`       INT          NOT NULL DEFAULT 0,
            `position`    INT          NOT NULL DEFAULT 0,
            `finished_at` TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (`race_id`) REFERENCES `ws_races`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]], {})
    -- Migrations (safe if column already exists on MariaDB 10.2+)
    exports.oxmysql:execute('ALTER TABLE `ws_races`   ADD COLUMN IF NOT EXISTS `laps`        INT         NOT NULL DEFAULT 1', {})
    exports.oxmysql:execute("ALTER TABLE `ws_races`   ADD COLUMN IF NOT EXISTS `mount_class` VARCHAR(50) NOT NULL DEFAULT 'open'", {})
    exports.oxmysql:execute('ALTER TABLE `ws_race_results` ADD COLUMN IF NOT EXISTS `race_id`     INT          NOT NULL DEFAULT 0', {})
    exports.oxmysql:execute("ALTER TABLE `ws_race_results` ADD COLUMN IF NOT EXISTS `citizen_id`  VARCHAR(50)  NOT NULL DEFAULT ''", {})
    exports.oxmysql:execute("ALTER TABLE `ws_race_results` ADD COLUMN IF NOT EXISTS `player_name` VARCHAR(100) NOT NULL DEFAULT ''", {})
    exports.oxmysql:execute('ALTER TABLE `ws_race_results` ADD COLUMN IF NOT EXISTS `finish_time` INT          NOT NULL DEFAULT 0', {})
    exports.oxmysql:execute('ALTER TABLE `ws_race_results` ADD COLUMN IF NOT EXISTS `bet`         INT          NOT NULL DEFAULT 0', {})
    exports.oxmysql:execute('ALTER TABLE `ws_race_results` ADD COLUMN IF NOT EXISTS `prize`       INT          NOT NULL DEFAULT 0', {})
    exports.oxmysql:execute('ALTER TABLE `ws_race_results` ADD COLUMN IF NOT EXISTS `position`    INT          NOT NULL DEFAULT 0', {})
    exports.oxmysql:execute('ALTER TABLE `ws_race_results` ADD COLUMN IF NOT EXISTS `finished_at` TIMESTAMP    DEFAULT CURRENT_TIMESTAMP', {})
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS `ws_race_stats` (
            `player_id` VARCHAR(50)  NOT NULL PRIMARY KEY,
            `name`      VARCHAR(100) NOT NULL,
            `wins`      INT          NOT NULL DEFAULT 0,
            `races`     INT          NOT NULL DEFAULT 0,
            `best_time` INT          NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]], {})
    print('^2[ws-racing]^7 Database initialized')
end

function Database.CreateRace(d)
    return exports.oxmysql:insert_async(
        'INSERT INTO ws_races (name,race_type,max_participants,min_level,collision,laps,blacklist_models,mount_class) VALUES (?,?,?,?,?,?,?,?)',
        { d.name, d.raceType, d.maxParticipants, d.minLevel, d.collision and 1 or 0, tonumber(d.laps) or 1, json.encode(d.blacklist or {}), d.mountClass or 'open' }
    )
end

function Database.GetAllRaces()
    local rows = exports.oxmysql:query_async('SELECT * FROM ws_races ORDER BY name', {}) or {}
    for _, r in ipairs(rows) do
        r.blacklist_models = json.decode(r.blacklist_models or '[]')
        r.collision = (r.collision == 1 or r.collision == true)
    end
    return rows
end

function Database.GetRaceById(id)
    local r = exports.oxmysql:single_async('SELECT * FROM ws_races WHERE id=?', { id })
    if r then
        r.blacklist_models = json.decode(r.blacklist_models or '[]')
        r.collision = (r.collision == 1 or r.collision == true)
    end
    return r
end

function Database.DeleteRace(id)
    exports.oxmysql:execute_async('DELETE FROM ws_races WHERE id=?', { id })
end

function Database.SaveCheckpoints(raceId, cps)
    exports.oxmysql:execute_async('DELETE FROM ws_checkpoints WHERE race_id=?', { raceId })
    for i, cp in ipairs(cps) do
        exports.oxmysql:insert_async(
            'INSERT INTO ws_checkpoints (race_id,sort_order,x,y,z) VALUES (?,?,?,?,?)',
            { raceId, i, cp.x, cp.y, cp.z }
        )
    end
end

function Database.GetCheckpoints(raceId)
    return exports.oxmysql:query_async(
        'SELECT * FROM ws_checkpoints WHERE race_id=? ORDER BY sort_order', { raceId }
    ) or {}
end

function Database.SaveStartPositions(raceId, positions)
    exports.oxmysql:execute_async('DELETE FROM ws_startpos WHERE race_id=?', { raceId })
    for i, p in ipairs(positions) do
        exports.oxmysql:insert_async(
            'INSERT INTO ws_startpos (race_id,sort_order,x,y,z,heading) VALUES (?,?,?,?,?,?)',
            { raceId, i, p.x, p.y, p.z, p.heading or 0 }
        )
    end
end

function Database.GetStartPositions(raceId)
    return exports.oxmysql:query_async(
        'SELECT * FROM ws_startpos WHERE race_id=? ORDER BY sort_order', { raceId }
    ) or {}
end

function Database.SaveResult(raceId, citizenId, name, finishTime, bet, prize, position)
    exports.oxmysql:insert_async(
        'INSERT INTO ws_race_results (race_id,citizen_id,player_name,finish_time,bet,prize,position) VALUES (?,?,?,?,?,?,?)',
        { raceId, citizenId, name, finishTime, bet, prize, position or 0 }
    )
    Database.UpsertPlayerStats(citizenId, name, finishTime, position)
end

-- Aggregated per-player stats table (player_id, name, wins, races, best_time)
function Database.UpsertPlayerStats(citizenId, name, finishTime, position)
    if not citizenId then return end
    local finished = (finishTime and finishTime > 0 and position and position > 0)
    local isWin    = (position == 1) and finished
    local bt       = finished and finishTime or nil
    exports.oxmysql:execute_async([[
        INSERT INTO ws_race_stats (player_id, name, wins, races, best_time)
        VALUES (?, ?, ?, 1, ?)
        ON DUPLICATE KEY UPDATE
            name = VALUES(name),
            races = races + 1,
            wins  = wins + VALUES(wins),
            best_time = CASE
                WHEN VALUES(best_time) IS NULL THEN best_time
                WHEN best_time IS NULL OR best_time = 0 THEN VALUES(best_time)
                WHEN VALUES(best_time) < best_time THEN VALUES(best_time)
                ELSE best_time
            END
    ]], { citizenId, name or 'Unknown', isWin and 1 or 0, bt })
end

function Database.GetLeaderboard(raceId)
    return exports.oxmysql:query_async(
        'SELECT * FROM ws_race_results WHERE race_id=? ORDER BY finish_time ASC LIMIT 20', { raceId }
    ) or {}
end

function Database.GetPlayerHistory(citizenId)
    return exports.oxmysql:query_async(
        'SELECT * FROM ws_race_results WHERE citizen_id=? ORDER BY finished_at DESC LIMIT 20', { citizenId }
    ) or {}
end

function Database.GetPlayerStats(citizenId)
    local row = exports.oxmysql:single_async([[
        SELECT
            COUNT(*)                                          AS total_races,
            SUM(CASE WHEN position = 1 THEN 1 ELSE 0 END)    AS wins,
            SUM(CASE WHEN position > 1 THEN 1 ELSE 0 END)    AS losses,
            SUM(CASE position
                WHEN 1 THEN 100 WHEN 2 THEN 75 WHEN 3 THEN 50
                WHEN 4 THEN 40  WHEN 5 THEN 30 WHEN 6 THEN 25
                WHEN 7 THEN 20  WHEN 8 THEN 15 WHEN 9 THEN 10
                ELSE 5 END)                                   AS score
        FROM ws_race_results
        WHERE citizen_id = ? AND finish_time > 0 AND position > 0
    ]], { citizenId })
    if not row then
        return { wins = 0, losses = 0, totalRaces = 0, score = 0 }
    end
    return {
        wins       = tonumber(row.wins)        or 0,
        losses     = tonumber(row.losses)      or 0,
        totalRaces = tonumber(row.total_races) or 0,
        score      = tonumber(row.score)       or 0,
    }
end

function Database.GetRecentRaces()
    local races = exports.oxmysql:query_async([[
        SELECT r.id, r.name, r.race_type, r.laps,
            MAX(res.finished_at) AS last_run,
            COUNT(DISTINCT res.citizen_id) AS total_finishers,
            MIN(res.finish_time) AS best_time,
            SUM(DISTINCT res.bet) AS total_pot
        FROM ws_races r
        INNER JOIN ws_race_results res ON res.race_id = r.id
        WHERE res.finish_time > 0 AND res.position > 0
        GROUP BY r.id, r.name, r.race_type, r.laps
        ORDER BY last_run DESC
        LIMIT 3
    ]], {}) or {}
    for _, race in ipairs(races) do
        race.top10 = exports.oxmysql:query_async([[
            SELECT t.player_name, t.finish_time, t.position, t.prize, t.bet
            FROM ws_race_results t
            INNER JOIN (
                SELECT citizen_id, MIN(finish_time) AS best_time
                FROM ws_race_results WHERE race_id=? AND finish_time>0 AND position>0
                GROUP BY citizen_id
            ) best ON t.citizen_id=best.citizen_id AND t.finish_time=best.best_time
            WHERE t.race_id=? AND t.finish_time>0 AND t.position>0
            GROUP BY t.citizen_id ORDER BY t.finish_time ASC LIMIT 10
        ]], { race.id, race.id }) or {}
    end
    return races
end

function Database.GetGlobalLeaderboard()
    return exports.oxmysql:query_async([[
        SELECT citizen_id, MAX(player_name) AS player_name,
            COUNT(*) AS total_races,
            SUM(CASE WHEN position=1 THEN 1 ELSE 0 END) AS wins,
            SUM(CASE position
                WHEN 1 THEN 100 WHEN 2 THEN 75 WHEN 3 THEN 50
                WHEN 4 THEN 40  WHEN 5 THEN 30 WHEN 6 THEN 25
                WHEN 7 THEN 20  WHEN 8 THEN 15 WHEN 9 THEN 10
                ELSE 5 END) AS score
        FROM ws_race_results WHERE finish_time>0 AND position>0
        GROUP BY citizen_id ORDER BY score DESC LIMIT 10
    ]], {}) or {}
end
