

<h1 align="center">WS Racing — Horse & Wagon Race System for RedM</h1>

<p align="center">
  <b>Developed by <a href="https://discord.gg/5fasym92pm">WS Scripts</a></b><br/>
  <i>Premium RedM & FiveM scripts — cowboys by day, coders by night.</i>
</p>

<p align="center">
  <a href="https://discord.gg/5fasym92pm"><img src="https://img.shields.io/badge/Discord-Join%20WS%20Scripts-5865F2?logo=discord&logoColor=white" alt="Discord"/></a>
<a href="https://github.com/Rexshack-RedM">
  <img src="https://img.shields.io/badge/framework-rsg--core-blue.svg" alt="rsg-core"/>
</a>
  <img src="https://img.shields.io/badge/version-1.0.6-green.svg" alt="Version"/>
  <img src="https://img.shields.io/badge/Lua-5.4-2C2D72.svg" alt="Lua"/>
</p>

A full-featured **horse, wagon and on-foot** racing system for **RedM** built on **rsg-core**.
Create custom tracks, race against other players, climb the leaderboard, and earn rewards —
all from an immersive in-game NUI menu.

> Ported from the original FiveM `ws-racing` (GTA V vehicle racing) and rebuilt for RDR2 / RedM by **WS Scripts**.

---


## ✨ Features

- 🐎 **Three race types** — Horseback, Wagons & Coaches, On-foot Foot Race, plus Open class
- 🏁 **Custom track builder** — Place start line, checkpoints and finish on the fly with F5 / F6 / F7
- 🚩 **Animated race flags** at the start line (left + right, configurable gap)
- 🗺️ **Mini-map blips** for every checkpoint + **persistent GPS route line** to the next checkpoint
- 🎯 **Smooth proximity checkpoints** (no flickering, no GPS rebuilds)
- 🔔 **Synchronized 5-4-3-2-1-GO countdown** with spoken numbers and start-bell SFX
- 🏆 **Leaderboards & personal stats** stored in MySQL (oxmysql)
- 🛡️ **License-based admin permissions** + automatic detection of `rsg-core` admin/god group
- 💬 **Discord webhook** logging for race events
- 📊 **Live race HUD** (NUI) with position, lap, speed (MPH / KM/H toggle), next checkpoint
- 💰 **Entry fees + prize pool payouts** (server-side, anti-cheat friendly)
- 🌐 **ox_lib notifications & keybinds** (RedM-compatible)

---

## 📦 Requirements

| Dependency | Purpose            |
| ---------- | ------------------ |
| `rsg-core` | Framework          |
| `ox_lib`   | UI / notify / keys |
| `oxmysql`  | Database           |

RedM server with `rdr3_warning` acknowledged.

---

## 🧩 Framework — RSG Core

This resource is built **natively for [rsg-core](https://github.com/Rexshack-RedM/rsg-core)**, the leading RedM framework maintained by the Rexshack community. All player data, money handling, permissions and notifications go through the RSG API — no QBCore / ESX / VORP shim is required (or supported).

**What we use from `rsg-core`:**

| RSG API                                  | Used for                                          |
| ---------------------------------------- | ------------------------------------------------- |
| `exports['rsg-core']:GetCoreObject()`    | Bootstrap on both client & server                 |
| `RSGCore.Functions.GetPlayer(src)`       | Resolve the racing player on the server           |
| `RSGCore.Functions.GetPlayerData()`      | Client-side citizenid, charinfo, job              |
| `Player.Functions.RemoveMoney('cash',…)` | Deduct race entry fee                             |
| `Player.Functions.AddMoney('cash',…)`    | Pay out prize pool to the winner(s)               |
| `Player.PlayerData.citizenid`            | Stored as the owner key in `rsg_race_results`     |
| `RSGCore.Functions.HasPermission()` / admin group detection | Gate `/addstart`, `/savrace`, `/resetrace` to staff |
| `RSGCore:Client:OnPlayerLoaded`          | Re-init HUD & menu after character select         |
| `RSGCore:Client:OnPlayerUnload`          | Cancel any active race & clear GPS route          |

**Server manifest (`fxmanifest.lua`):**

```lua
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM…'
fx_version 'cerulean'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    '@ox_lib/init.lua',
    'shared/config.lua',
}
```

**Load order in `server.cfg`:**

```cfg
ensure oxmysql
ensure rsg-core
ensure ox_lib
ensure ws-racing
```

> Not using RSG? This script will not start — it depends on `exports['rsg-core']` at runtime. For QBCore/VORP you would need a separate fork.

---

## 🚀 Installation

1. **Download / clone** this repository into your resources folder:
   ```bash
   cd resources/[rsg]
   git clone https://github.com/<your-user>/ws-racing.git
   ```

2. **Import the SQL** schema:
   ```bash
   mysql -u <user> -p <database> < ws-racing/ws-racing.sql
   ```

3. **Add to your `server.cfg`** (after rsg-core, ox_lib, oxmysql):
   ```cfg
   ensure ws-racing
   ```

4. **Set up admins** — open `shared/config.lua` and add your license:
   ```lua
   Config.AllowedLicenses = {
       ["license:1e6fd046242681efb4d9087432c230505738d324"] = true,
   }
   ```
   Find your license in the server console with `print(GetPlayerIdentifiers(source))`.

   Players in the `rsg-core` `admin` or `god` group are auto-recognized when
   `Config.UseRSGAdminGroup = true`.

5. **Restart your server** and run `/racemenu` in-game.

---

## 🎮 Commands & Keybinds

### Commands

| Command          | Access | Description                                    |
| ---------------- | ------ | ---------------------------------------------- |
| `/racemenu`      | All    | Open the racing UI                             |
| `/leaderboard`   | All    | Open leaderboard picker                        |
| `/mystats`       | All    | Show your personal race history                |
| `/addcheckpoint` | Admin  | Add a checkpoint at your current position      |
| `/addstart`      | Admin  | Add the start position at your current spot    |
| `/savrace`       | Admin  | Save the race currently being built            |
| `/cancelcreate`  | Admin  | Cancel race creation                           |
| `/resetrace`     | Admin  | Force-reset stuck race state                   |

### Keybinds (in creation mode)

| Key  | Action               |
| ---- | -------------------- |
| `F5` | Add Checkpoint       |
| `F6` | Add Start Position   |
| `F7` | Undo Last Checkpoint |

---

## ⚙️ Configuration

All settings live in `shared/config.lua`.

```lua
Config.CheckpointRadius = 12.0        -- Detection radius for checkpoint pass
Config.UseMPH           = true        -- true = MPH, false = KM/H
Config.MinParticipants  = 0           -- Min players to start
Config.UseRSGAdminGroup = true        -- Auto-allow rsg admin/god groups

-- Marker colors (R, G, B, A)
Config.CheckpointColor = { 255, 200, 0,   180 }
Config.StartColor      = { 0,   255, 100, 200 }
Config.FinishColor     = { 255, 50,  50,  200 }

-- Mount classes
Config.MountClasses = {
    open   = 'Open',
    horse  = 'Horseback',
    wagon  = 'Wagons & Coaches',
    onfoot = 'On-foot Foot Race',
}

-- Discord
Config.DiscordWebhook = 'YOUR_WEBHOOK_URL_HERE'
```

### Race flag spacing

Inside `client/race.lua`, the constant `HALF_GAP` controls how far apart the
two start-line flags sit (the horses pass between them). Default = `3.5`
(≈ 7 meters total).

### Custom blip sprites

Near the top of `client/race.lua`:
```lua
local BLIP_CP     = 1386031480   -- blip_ambient_ped_medium_higher
local BLIP_START  = -- your sprite
local BLIP_FINISH = -- your sprite
```

---

## 🏗️ How to Create a Race

1. Run `/racemenu` → **Create Race** (admin only).
2. Pick a mount class (`open` / `horse` / `wagon` / `onfoot`).
3. Walk / ride to where you want the start line and press **F6**.
4. Place each checkpoint along the track with **F5** (use **F7** to undo).
5. The last checkpoint you add becomes the finish line automatically.
6. Run `/savrace` (or use the menu button) to save it.
7. Players can now join from the **Available Races** tab.

---

## 🗺️ Race Experience

- A **GPS route line** (yellow) is drawn from your position to the next
  checkpoint and updates only when you pass one — no flicker, no rebuilds.
- Each checkpoint shows a **3D marker** + a **mini-map blip**.
- The start has **two flags** placed left and right of the road so mounts
  can pass freely between them.
- Before the green light, a synchronized **5-4-3-2-1-GO** countdown plays
  with spoken numbers and a start-bell sound for everyone in the race.

---

## 🗄️ Database

The SQL schema (`ws-racing.sql`) creates these tables:

| Table              | Purpose                                |
| ------------------ | -------------------------------------- |
| `rsg_races`        | Saved race definitions                 |
| `rsg_race_results` | Per-player race history + best times   |
| `rsg_race_stats`   | Aggregated leaderboard data            |

> Old `ws_*` tables from the original FiveM version are **not** migrated
> automatically. Export and re-insert into the new `rsg_*` tables if needed.

---

## 🛠️ Troubleshooting

| Issue                              | Fix                                                                                              |
| ---------------------------------- | ------------------------------------------------------------------------------------------------ |
| `/racemenu` does nothing           | Check that `rsg-core`, `ox_lib`, `oxmysql` are started **before** `ws-racing`                    |
| Admin commands denied              | Add your license to `Config.AllowedLicenses` or join the `admin` rsg group                       |
| Flags block horses at the start    | Increase `HALF_GAP` in `client/race.lua`                                                         |
| No GPS line on minimap             | Make sure `gps` natives are enabled in your build of RedM (default: yes)                         |
| Speed shown in wrong unit          | Toggle `Config.UseMPH` in `shared/config.lua`                                                    |
| Webhook not posting                | Set a valid `Config.DiscordWebhook` URL                                                          |

---

## 🔄 Changes vs. the original FiveM `ws-racing`

| Original (FiveM / qb-core)            | This port (RedM / rsg-core)                          |
| ------------------------------------- | ---------------------------------------------------- |
| `game 'gta5'`                         | `game 'rdr3'` + rdr3_warning                         |
| `qb-core`                             | `rsg-core`                                           |
| Vehicle classes (Super / Muscle / …)  | Mount classes: `open` / `horse` / `wagon` / `onfoot` |
| GTA V `bzzz_*.ydr` checkpoint props   | RedM markers + race flag props                       |
| Drift mode                            | Removed (irrelevant for horses)                      |
| FiveM `DrawMarker`                    | RedM `_DRAW_MARKER` with RDR2 hashes                 |
| `AddBlipForCoord` / `SetBlipSprite`   | RedM `BLIP_ADD_FOR_COORDS`                           |
| GTA V `CreateCheckpoint`              | Smooth proximity check + GPS multi-route             |
| Speed in KM/H                         | MPH default (toggle in config)                       |
| `QBCore:Notify`                       | `ox_lib:notify`                                      |
| GTA V particle FX / sounds            | RDR2 countdown + start-bell SFX                      |
| DB prefix `ws_*`                      | DB prefix `rsg_*`                                    |

---

## 🤝 Contributing

PRs welcome! Please:
1. Fork the repo and create a feature branch.
2. Keep edits focused — one feature / fix per PR.
3. Test on a clean RedM server with `rsg-core` before submitting.

---

## 📜 License

Released under the **MIT License**. Free to use, modify and distribute for
personal and commercial RedM servers. Credit appreciated but not required.

---

## 💛 Credits

- **[WS Scripts](https://discord.gg/5fasym92pm)** — developer & maintainer of this RedM edition
- **RedM / RSG community** — for the framework and natives reference
- **ox_lib** & **oxmysql** by Overextended

---

## 📣 Community & Support

Join the **WS Scripts** Discord for support, updates, custom requests and the rest of our RedM / FiveM script lineup:

<p align="center">
  <a href="https://discord.gg/5fasym92pm">
    <img src="https://img.shields.io/badge/Join%20our%20Discord-5fasym92pm-5865F2?logo=discord&logoColor=white&style=for-the-badge" alt="WS Scripts Discord"/>
  </a>
</p>

> 👉 **https://discord.gg/5fasym92pm**

> Built with passion for the RedM cowboy life by **WS Scripts**. Ride hard, race harder. 🐎💨

