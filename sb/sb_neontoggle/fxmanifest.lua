fx_version 'cerulean'
game 'gta5'

name 'sb_neontoggle'
author 'you'
version '2.0.0'
description 'Toggle vehicle underglow (installed sides only) with oxmysql persistence by plate'

shared_script 'config.lua'

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}
