local originalAttributes = {
    model = nil,  -- Armazena o modelo original
    health = nil, -- Armazena a vida original
    stamina = nil, -- Armazena a estamina original
    armor = nil, -- Armazena a armadura original
    speed = nil, -- Armazena a velocidade original
}

local currentAnimal = false  -- Armazena o animal atual
local currentPlayer = nil  -- Armazena o player atual (quem executou a transformação)

local animals = {
    {name = "Cachorro", model = "a_c_westy"},
    {name = "Gato", model = "a_c_cat_01"},
    {name = "Veado", model = "a_c_deer"},
    {name = "Porco", model = "a_c_pig"},
    {name = "Rato", model = "a_c_rat"},
    {name = "Galinha", model = "a_c_hen"},
    {name = "Vaca", model = "a_c_cow"},
    {name = "Coelho", model = "a_c_rabbit_01"},
    {name = "Puma", model = "A_C_MtLion_02"},
    {name = "Javali", model = "A_C_Boar"}
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
local isVisionActive = false 

-- Função para obter o modelo base do jogador
function GetBasePlayerSkin(playerId)
    return GetEntityModel(GetPlayerPed(playerId))
end

RegisterCommand("transform", function(_, args)
    currentPlayer = PlayerId()  -- Marca o jogador que executou o comando
    local animalName = args[1]  -- Obtém o argumento fornecido após o comando

    if animalName then
        -- Converte o nome do animal para maiúsculas para evitar problemas de comparação
        local animalNameLower = string.lower(animalName)

        -- Procura o modelo correspondente ao nome do animal fornecido
        for _, animal in ipairs(animals) do
            if string.lower(animal.name) == animalNameLower then
                if not currentAnimal then
                    TransformIntoAnimal(animal.model)  -- Transforma diretamente no animal
                else
                    TriggerEvent('chat:addMessage', { args = { "[Erro]", "Você já está transformado! Primeiro cancele a transformação." } })
                end
                return
            end
        end

        -- Caso o animal não seja encontrado, exibe uma mensagem de erro
        TriggerEvent('chat:addMessage', { args = { "[Erro]", "Animal não encontrado. Use /transform para abrir o menu." } })
    else
        -- Sem argumento, exibe o menu de transformação
        ShowAnimalMenu()
    end
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

    -- Verifica o modelo do jogador transformado
    local currentModel = GetEntityModel(playerPed)
    if currentModel == GetHashKey("a_c_rat") or currentModel == GetHashKey("a_c_deer") or currentModel == GetHashKey("A_C_MtLion_02") then
        correrMaisRapido() -- Inicia o aumento de velocidade enquanto transformado
    end
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
    
    -- Para o aumento de velocidade
    SetPedMoveRateOverride(playerPed, 1.0)  -- Retorna a velocidade normal

    currentAnimal = nil
    currentPlayer = nil
end

function ApplyAnimalBuffs(playerPed)
    local player = PlayerId()
    
    -- Buffs iniciais
    local healthBonus, armorBonus, speedBonus = 4.0, 100, 1.49
    local staminaMultiplier, weaponDamageReduction = 50.0, 0.5
    local meleeDamageReduction = 0.5 -- Redução de dano de socos

    SetEntityHealth(playerPed, GetEntityMaxHealth(playerPed) * healthBonus)
    SetPedArmour(playerPed, armorBonus)

    -- Aplique os buffs de forma eficiente
    Citizen.CreateThread(function()
        while currentAnimal do
            -- Aplica buffs, caso ainda não aplicados
            SetRunSprintMultiplierForPlayer(player, speedBonus)
            RestorePlayerStamina(player, staminaMultiplier)
            SetPlayerWeaponDamageModifier(player, weaponDamageReduction)
            SetEntityProofs(playerPed, false, true, false, false, false, false, false, false)

            -- Aguarda antes de reaplicar
            Citizen.Wait(500)
        end

        -- Restaura valores padrão quando o buff termina
        SetRunSprintMultiplierForPlayer(player, 1.0)
        SetPlayerWeaponDamageModifier(player, 1.0)
        SetEntityProofs(playerPed, false, false, false, false, false, false, false, false)
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

-- Rastreamento enquanto transformado --
local trackingEnabled, trackingCooldown, activeBlips = false, 0, {}
local cooldownTime, trackingDuration = 5 * 60 * 1000, 60 * 1000

RegisterCommand("rastrear", function()
    if not currentAnimal then 
        TriggerEvent('chat:addMessage', { args = { "[Erro]", "Você precisa estar transformado para rastrear." } })
        return
    end

    -- Verifica o tempo de recarga em milissegundos
    if trackingCooldown > 0 then
        local remainingTime = math.floor((trackingCooldown - GetGameTimer()) / 1000)  -- Calculando o tempo restante em segundos
        if remainingTime > 0 then
            TriggerEvent('chat:addMessage', { args = { "[Rastreamento]", "Em recarga. Tempo restante: " .. remainingTime .. "s." } })
            return
        end
    end

    trackingEnabled = not trackingEnabled
    TriggerEvent('chat:addMessage', { args = { "[Rastreamento]", trackingEnabled and "Ativado." or "Desativado." } })

    if trackingEnabled then
        StartTracking()
        SetCooldown()
    else
        StopTracking()
    end
end)

function StartTracking()
    Citizen.CreateThread(function()
        local startTime = GetGameTimer()
        while trackingEnabled do
            if GetGameTimer() - startTime > trackingDuration then
                trackingEnabled = false
                StopTracking()
                TriggerEvent('chat:addMessage', { args = { "[Rastreamento]", "Desativado automaticamente." } })
                break
            end

            local playerCoords = GetEntityCoords(PlayerPedId())
            for _, playerId in ipairs(GetActivePlayers()) do
                local targetPed = GetPlayerPed(playerId)
                if Vdist(playerCoords, GetEntityCoords(targetPed)) <= 50.0 then
                    CreateBlip(targetPed, "player")
                end
            end

            for _, npcPed in ipairs(GetNearbyPeds(PlayerPedId(), 50.0)) do
                if npcPed ~= PlayerPedId() then
                    CreateBlip(npcPed, "npc")
                end
            end

            Citizen.Wait(5000)
        end
    end)
end

function GetNearbyPeds(playerPed, radius)
    local peds = {}
    for _, ped in ipairs(GetGamePool('CPed')) do
        if Vdist(GetEntityCoords(playerPed), GetEntityCoords(ped)) <= radius then
            table.insert(peds, ped)
        end
    end
    return peds
end

function CreateBlip(entity, entityType)
    if not BlipExistsForEntity(entity) then
        local blip = AddBlipForEntity(entity)
        SetBlipSprite(blip, 1)
        SetBlipColour(blip, entityType == "player" and 1 or 45)
        SetBlipScale(blip, 0.8)
        SetBlipAsShortRange(blip, false)
        table.insert(activeBlips, blip)
    end
end

function BlipExistsForEntity(entity)
    for _, blip in ipairs(activeBlips) do
        if GetBlipFromEntity(blip) == entity then return true end
    end
    return false
end

function StopTracking()
    for _, blip in ipairs(activeBlips) do
        RemoveBlip(blip)
    end
    activeBlips = {}
end

function SetCooldown()
    trackingCooldown = GetGameTimer() + cooldownTime  -- Define o tempo de recarga em milissegundos
end

function correrMaisRapido()
    while currentAnimal do
        Wait(0)
        SetPedMoveRateOverride(PlayerPedId(), 2.50)  -- Aumenta a velocidade de movimento
    end
end