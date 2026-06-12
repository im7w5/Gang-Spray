fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Ahmed'
description 'Gang Spray'
version '1.1.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/items.lua',
}

ui_page 'html/index.html'

files {
    'spray_logos/elmundo.png',
    'spray_logos/trickster.png',
    'spray_logos/ballas.png',
    'html/index.html',
    'html/sounds/gang_alert.ogg',
}
