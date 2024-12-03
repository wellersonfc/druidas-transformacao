fx_version 'cerulean'
game 'gta5'

author 'Wellerson Carvalho'
description 'Script de transformacao'
version '1.0.0'

-- Página NUI para tocar sons
ui_page 'html/index.html'

-- Arquivos necessários
files {
    'html/index.html',
    'html/som_teste.ogg'
}

-- Scripts cliente
client_scripts {
    'client.lua'    -- Lógica do cliente
}

-- Scripts servidor
server_scripts {
    'server.lua'    -- Lógica do servidor para sincronização
}