fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'WS Scripts — WS Racing | Not allowed for resale'
description 'WS Racing — Horse & Wagon Race System (RedM)'
version '1.0.6'

dependencies { 'rsg-core', 'ox_lib', 'oxmysql' }

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/wscore.png',
    'html/racecar.png',
    'html/wsscripts-logo.png',
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

server_scripts {
    'server/database.lua',
    'server/main.lua',
    'server/events.lua',
    'server/commands.lua',
}

client_scripts {
    'client/menu.lua',
    'client/race.lua',
    'client/main.lua',
}

lua54 'yes'
