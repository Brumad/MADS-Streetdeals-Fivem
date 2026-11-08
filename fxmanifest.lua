fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mads_streetdeals'
author 'MADS'
description 'Negociacao com pedestres ambientais (Qbox) - IA, combos, rara, confronto, ledger seguro'
version '0.1.0'

dependencies {
    '/server:7290',
    '/onesync',
    'ox_lib',
    'qbx_core',
    'ox_inventory',
    'ox_target',
    'oxmysql',
}

shared_script '@ox_lib/init.lua'

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

ui_page 'nui/index.html'

files {
    'config/config.lua',
    'nui/index.html',
    'nui/style.css',
    'nui/app.js',
}
