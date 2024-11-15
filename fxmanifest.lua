fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

author 'Coolone95'
description 'cools-trashcan edited for redm by phil'

escrow_ignore {
    'config.lua'
}

shared_scripts {
    'config.lua',
	'@ox_lib/init.lua'
}

client_scripts {
    'client/*.lua'
}

dependencies {
    'rsg-core',
    'ox_lib',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}

lua54 'yes'