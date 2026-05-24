Config = {}

-- ============================================================
-- RACE PERMISSIONS — License based
-- License format: "license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
-- Find your license via console: print(GetPlayerIdentifiers(source))
-- ============================================================
Config.AllowedLicenses = {
    -- ["license:1e6fd046242681efb4d9087432c230505738d324"] = true,
}

-- Allow rsg-core admin group (admin/god) automatically (true/false)
Config.UseRSGAdminGroup = true

-- ============================================================
-- GENERAL SETTINGS
-- ============================================================
Config.CheckpointRadius = 12.0       -- horse races: tighter than cars
Config.NotifyDuration   = 5000
Config.MinParticipants  = 0
Config.UseMPH           = true       -- true = MPH, false = KM/H

Config.CheckpointColor = { 255, 200, 0,   180 }
Config.StartColor      = { 0,   255, 100, 200 }
Config.FinishColor     = { 255, 50,  50,  200 }

-- ============================================================
-- MOUNT CLASS RESTRICTIONS (replaces FiveM vehicle classes)
-- ============================================================
-- open    = anything (horse, wagon, on-foot)
-- horse   = must be mounted on a horse
-- wagon   = must be driving a wagon/coach/cart
-- onfoot  = must be on foot (foot-race)
Config.MountClasses = {
    open   = 'Open ',
    horse  = 'Horseback ',
    wagon  = 'Wagons & Coaches ',
    onfoot = 'On-foot Foot Race ',
}

-- ============================================================
-- DISCORD WEBHOOK
-- ============================================================
Config.DiscordWebhook = 'YOUR_WEBHOOK_URL_HERE'
Config.DiscordBotName = 'WS Racing'
Config.DiscordAvatar  = 'https://i.imgur.com/4M34hi2.png'
