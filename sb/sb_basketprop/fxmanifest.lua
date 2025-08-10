fx_version 'cerulean'
game 'gta5'

description 'A rescue basket script, specifically made to work with LAFDs AW139 helicopter'
author 'SeanyBoi'

files {
  'stream/rescue_basket.yft',
  'stream/rescue_basket.ytd',
  'stream/rescue_basket.ytyp'
}

data_file 'DLC_ITYP_REQUEST' 'rescue_basket.ytyp'

client_script "client.lua"
server_script "server.lua"
shared_script "config.lua"
