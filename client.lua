local originalAttributes = {
    model = nil,  -- Armazena o modelo original
    health = nil, -- Armazena a vida original
    stamina = nil, -- Armazena a estamina original
    armor = nil, -- Armazena a armadura original
    speed = nil, -- Armazena a velocidade original
}

local currentAnimal = nil  -- Armazena o animal atual
local currentPlayer = nil  -- Armazena o player atual (quem executou a transformação)

local animals = {
    {name = "Cachorro P", model = "a_c_poodle"},
    {name = "Cachorro W", model = "a_c_westy"},
    {name = "Gato", model = "a_c_cat_01"},
    {name = "Veado", model = "a_c_deer"},
    {name = "Porco", model = "a_c_pig"},
    {name = "Rato", model = "a_c_rat"},
    {name = "Galinha", model = "a_c_hen"},
    {name = "Vaca", model = "a_c_cow"},
    {name = "Coelho", model = "a_c_rabbit_01"},
    {name = "Coiote", model = "a_c_coyote"},
    {name = "Puma", model = "A_C_MtLion_02"}
}
local efeitos = {
    {effect = "ent_sht_telegraph_pole", scale = 1.5, speed = 0.00, direction = "parado"},
    {effect = "ent_amb_falling_cherry_bloss", scale = 3.0, speed = 0.05, direction = "parado"},
    {effect = "ent_amb_falling_cherry_bloss", scale = 3.0, speed = 0.05, direction = "vertical"},
    {effect = "ent_amb_falling_cherry_bloss", scale = 3.0, speed = 0.05, direction = "diagonal_right"},
    {effect = "ent_amb_falling_cherry_bloss", scale = 3.0, speed = 0.05, direction = "diagonal_left"},
    {effect = "ent_amb_falling_cherry_bloss", scale = 3.0, speed = 0.05, direction = "horizontal"}
}

local isEffectActive = false
local activeEffectHandles = {}

-- Função para obter o modelo base do jogador
function GetBasePlayerSkin(playerId)
    return GetEntityModel(GetPlayerPed(playerId))
end

-- Comando para ativar a transformação
RegisterCommand("transform", function()
    currentPlayer = PlayerId()  -- Marca o jogador que executou o comando
    ShowAnimalMenu()  -- Chama o menu de transformação
end)

-- Função para mostrar o menu de transformação
function ShowAnimalMenu()
    local elements = {}

    -- Se o jogador já está transformado, adiciona a opção de reverter à forma humana
    if currentAnimal then
        table.insert(elements, {
            header = "Voltar à Forma Humana", 
            txt = "Reverter para a versão humana", 
            params = {event = 'animal:returntohuman'}
        })
    else
        -- Se não, mostra as opções para transformação em cada animal
        for _, animal in ipairs(animals) do
            table.insert(elements, {
                header = animal.name,
                txt = "Transforme-se em " .. animal.name,
                params = {
                    event = 'animal:transform', 
                    args = {model = animal.model}
                }
            })
        end
    end

    -- Adiciona a opção de fechar o menu
    table.insert(elements, {
        header = "Fechar", 
        txt = "Fechar o menu sem transformação", 
        params = {event = 'qb-menu:client:closeMenu'}
    })

    -- Abre o menu
    TriggerEvent('qb-menu:client:openMenu', elements)
end

-- Evento para transformação em animal
RegisterNetEvent('animal:transform')
AddEventHandler('animal:transform', function(data)
    if not currentAnimal then
        TransformIntoAnimal(data.model)
    else
        TriggerEvent('chat:addMessage', { args = { "[Erro]", "Você já está transformado! Primeiro cancele a transformação." } })
    end
end)

-- Evento para retornar à forma humana
RegisterNetEvent('animal:returntohuman')
AddEventHandler('animal:returntohuman', function()
    if currentAnimal then
        RevertToHuman()
    else
        TriggerEvent('chat:addMessage', { args = { "[Erro]", "Você já está na versão humana." } })
    end
end)

-- Função para transformar o jogador em um animal
function TransformIntoAnimal(model)
    local playerPed = PlayerPedId()

    -- Armazena os atributos do jogador original antes da transformação
    originalAttributes.model = GetEntityModel(playerPed)
    originalAttributes.health = GetEntityHealth(playerPed)
    originalAttributes.stamina = GetPlayerStamina(playerPed)
    originalAttributes.armor = GetPedArmour(playerPed)
    originalAttributes.speed = GetEntitySpeed(playerPed)

    RequestModel(model)

    local startTime = GetGameTimer()
    while not HasModelLoaded(model) do
        Citizen.Wait(500)
        if GetGameTimer() - startTime > 5000 then
            TriggerEvent('chat:addMessage', { args = { "[Erro]", "Falha ao carregar o modelo. Tente novamente." } })
            return
        end
    end

    SetPlayerModel(PlayerId(), model)
    playerPed = PlayerPedId()

    -- Configura a posição e visibilidade do jogador
    NetworkRequestControlOfEntity(playerPed)
    SetEntityVisible(playerPed, true, false)
    SetEntityCollision(playerPed, true, true)
    FreezeEntityPosition(playerPed, false)
    SetEntityAlpha(playerPed, 255, false)
    SetModelAsNoLongerNeeded(model)

    Citizen.Wait(100)
    currentAnimal = model

    -- Aplica os buffs do animal imediatamente após a transformação
    ApplyAnimalBuffs(playerPed)

    -- Inicia o efeito visual
    local playerCoords = GetEntityCoords(PlayerPedId()) 
    TriggerServerEvent("syncEffectsAndSoundForPlayer", playerCoords)
end

-- Função para reverter à forma humana
function RevertToHuman()
    -- Chama o comando fictício 'refreshskin' para reverter à forma humana
    ExecuteCommand('refreshskin')

    -- Inicia o efeito visual
    local playerCoords = GetEntityCoords(PlayerPedId()) 
    TriggerServerEvent("syncEffectsAndSoundForPlayer", playerCoords)

    -- Restaura os atributos do jogador original
    local playerPed = PlayerPedId()
    SetEntityHealth(playerPed, originalAttributes.health)
    SetPlayerStamina(playerPed, originalAttributes.stamina)
    SetPedArmour(playerPed, originalAttributes.armor)
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
    currentAnimal = nil
    currentPlayer = nil
end

function ApplyAnimalBuffs(playerPed)
    local healthBonus, armorBonus, speedBonus, staminaMultiplier = 4.0, 100, 1.49, 50.0
    local player = PlayerId()

    -- Buffs iniciais
    SetEntityHealth(playerPed, GetEntityMaxHealth(playerPed) * healthBonus)
    SetPedArmour(playerPed, armorBonus)

    -- Aplicação contínua do buff de velocidade e estamina
    Citizen.CreateThread(function()
        while currentAnimal do
            -- Garante que o buff de velocidade permaneça ativo
            SetRunSprintMultiplierForPlayer(player, speedBonus)

            -- Restaura estamina continuamente
            RestorePlayerStamina(player, staminaMultiplier)

            -- Espera antes de reaplicar os buffs
            Citizen.Wait(500)
        end

        -- Restaura o multiplicador de velocidade ao padrão
        SetRunSprintMultiplierForPlayer(player, 1.0)
    end)
end


-- Função para parar os efeitos de partículas
function stopEffect(effectHandle)
    if effectHandle then
        StopParticleFxLooped(effectHandle, 0)
    end
end

-- Receber os efeitos sincronizados do servidor
RegisterNetEvent("syncEffectsAndSoundForAll")
AddEventHandler("syncEffectsAndSoundForAll", function(playerCoords)
    local playerPed = PlayerPedId()
    local effectHandles = {}
    local soundName = "som_teste" -- Nome do som

    -- Verifique se o jogador está na posição correta (por segurança)
    local playerCurrentCoords = GetEntityCoords(playerPed)

    -- Envia o comando para o NUI tocar o som (executa apenas se não estiver tocando)
    SendNUIMessage({ action = "playSound", soundName = soundName })

    -- Agora cria o efeito no local do jogador
    Citizen.CreateThread(function()
        local offsets = {}
        for i, efeito in ipairs(efeitos) do
            offsets[i] = {
                angle = 0,
                speed = efeito.speed,
                direction = efeito.direction
            }
        end

        -- Iniciar o efeito com base nas coordenadas do jogador
        local effectHandle = nil
        for i, efeito in ipairs(efeitos) do
            offsets[i] = {
                angle = 0,
                speed = efeito.speed,
                direction = efeito.direction
            }

            local angle = offsets[i].angle
            local direction = efeito.direction

            -- Atualiza o ângulo para criar movimento circular
            if direction ~= "parado" then
                offsets[i].angle = math.fmod(offsets[i].angle + efeito.speed, 2 * math.pi)
            end

            local xOffset, yOffset, zOffset = 0, 0, 0
            if direction == "horizontal" then
                xOffset = math.cos(offsets[i].angle) * 1.0
                yOffset = math.sin(offsets[i].angle) * 1.0
            elseif direction == "vertical" then
                yOffset = math.cos(offsets[i].angle) * 1.0
                zOffset = math.sin(offsets[i].angle) * 1.0
            elseif direction == "diagonal_left" then
                xOffset = math.cos(offsets[i].angle) * 1.0
                zOffset = math.sin(offsets[i].angle) * 1.0
            elseif direction == "diagonal_right" then
                xOffset = -math.cos(offsets[i].angle) * 1.0
                zOffset = math.sin(offsets[i].angle) * 1.0
            end

            -- Calcular as coordenadas finais para o efeito
            local effectPosition = {x = playerCoords.x + xOffset, y = playerCoords.y + yOffset, z = playerCoords.z + zOffset}

            -- Criando o efeito no local especificado
            UseParticleFxAssetNextCall("core")
            effectHandle = StartParticleFxLoopedAtCoord(
                efeito.effect,
                effectPosition.x, effectPosition.y, effectPosition.z,
                0.0, 0.0, 0.0, -- Sem rotação extra
                efeito.scale, false, false, false
            )

            -- Salva o handle do efeito na lista
            table.insert(effectHandles, effectHandle)
        end

        -- Espera o tempo para limpar os efeitos
        Citizen.Wait(4000)  -- Espera 4 segundos

        -- Para e limpa os efeitos
        for _, handle in ipairs(effectHandles) do
            stopEffect(handle)
        end
    end)
end)
