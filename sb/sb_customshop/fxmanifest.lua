fx_version 'cerulean'
game 'gta5'

name 'sb_hooddocshop'
author 'you'
description 'HoodDoc job-locked shop using ox_inventory'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client.lua',
}

server_scripts {
    'server.lua',
}

dependencies {
    'ox_inventory',
    'ox_lib',
    'ox_target' -- comment out if you don’t use ox_target
}
