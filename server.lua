RegisterServerEvent("syncEffectsAndSoundForPlayer")
AddEventHandler("syncEffectsAndSoundForPlayer", function(playerCoords)
    local radius = 30.0  -- Define o raio de 30 unidades
    local sourcePlayer = source  -- O jogador que disparou o evento
    local players = GetPlayers()  -- Obtém todos os jogadores conectados ao servidor

    -- Para cada jogador no servidor
    for _, playerId in ipairs(players) do
        -- Ignora o jogador que disparou o evento
        if playerId ~= sourcePlayer then
            -- Obtém as coordenadas do jogador
            local targetPlayerPed = GetPlayerPed(playerId)
            local targetPlayerCoords = GetEntityCoords(targetPlayerPed)

            -- Calcula a distância entre o jogador que disparou o comando e o jogador alvo manualmente
            local dx = playerCoords.x - targetPlayerCoords.x
            local dy = playerCoords.y - targetPlayerCoords.y
            local dz = playerCoords.z - targetPlayerCoords.z
            local distance = math.sqrt(dx * dx + dy * dy + dz * dz)

            -- Se a distância for menor que o raio, envia o evento para esse jogador
            if distance <= radius then
                TriggerClientEvent("syncEffectsAndSoundForAll", playerId, playerCoords)
            end
        end
    end
end)
