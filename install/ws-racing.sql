-- ============================================================
-- WS Racing — Database Schema (RedM port)
-- Tables auto-create on resource start, but here for manual install
-- ============================================================

CREATE TABLE IF NOT EXISTS `ws_races` (
    `id`                  INT AUTO_INCREMENT PRIMARY KEY,
    `name`                VARCHAR(100)  UNIQUE NOT NULL,
    `race_type`           VARCHAR(50)   NOT NULL DEFAULT 'circuit',
    `max_participants`    INT           NOT NULL DEFAULT 10,
    `min_level`           INT           NOT NULL DEFAULT 0,
    `collision`           TINYINT       NOT NULL DEFAULT 1,
    `laps`                INT           NOT NULL DEFAULT 1,
    `mount_class`         VARCHAR(50)   NOT NULL DEFAULT 'open',
    `blacklist_models`    JSON,
    `created_at`          TIMESTAMP     DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ws_checkpoints` (
    `id`          INT AUTO_INCREMENT PRIMARY KEY,
    `race_id`     INT   NOT NULL,
    `sort_order`  INT   NOT NULL,
    `x`           FLOAT NOT NULL,
    `y`           FLOAT NOT NULL,
    `z`           FLOAT NOT NULL,
    FOREIGN KEY (`race_id`) REFERENCES `ws_races`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ws_startpos` (
    `id`          INT AUTO_INCREMENT PRIMARY KEY,
    `race_id`     INT   NOT NULL,
    `sort_order`  INT   NOT NULL,
    `x`           FLOAT NOT NULL,
    `y`           FLOAT NOT NULL,
    `z`           FLOAT NOT NULL,
    `heading`     FLOAT NOT NULL DEFAULT 0,
    FOREIGN KEY (`race_id`) REFERENCES `ws_races`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ws_race_results` (
    `id`           INT AUTO_INCREMENT PRIMARY KEY,
    `race_id`      INT          NOT NULL,
    `citizen_id`   VARCHAR(50)  NOT NULL,
    `player_name`  VARCHAR(100) NOT NULL,
    `finish_time`  INT          NOT NULL DEFAULT 0,
    `bet`          INT          NOT NULL DEFAULT 0,
    `prize`        INT          NOT NULL DEFAULT 0,
    `position`     INT          NOT NULL DEFAULT 0,
    `finished_at`  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`race_id`) REFERENCES `ws_races`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ws_race_stats` (
    `player_id` VARCHAR(50)  NOT NULL PRIMARY KEY,
    `name`      VARCHAR(100) NOT NULL,
    `wins`      INT          NOT NULL DEFAULT 0,
    `races`     INT          NOT NULL DEFAULT 0,
    `best_time` INT          NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
