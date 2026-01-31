-- frp_cova/client.lua
print('[FRP_COVA] client.lua carregou')

local KEY_E   = 0xCEFD9220 -- E
local KEY_ALT = 0xE8342FF2 -- ALT

-- config
local TEMPO_MAX = 3
local HINT_TIME = 1500 
local ROB_HINT_COOLDOWN = 1000 

-- state
local hintVisible = false
local lastRobHint = 0
local roubando = false
local startTimeRoubando = 0
local covaAtual = 0
local aguardandoAprovacao = false
local aguardoStartedAt = 0

-- Coordenadas (Exatamente as que o seu /tpcova utiliza)
local covas = {
    vector3(2401.10, -1112.33, 46.48),
    vector3(2391.55, -1104.50, 46.45),
    vector3(-960.07, -1209.21, 55.05),
    vector3(-961.69, -1203.33, 55.99),
    vector3(-959.74, -1197.96, 56.28),
    vector3(-246.20, 812.63, 122.58),
    vector3(-954.60, -1203.91, 55.53),
    -- Valentine
    vector3(-241.07, 809.29, 122.86), 
    vector3(-248.60, 817.72, 122.42),
    vector3(-234.05, 818.74, 124.28),
}

-- Função de desenho (Lógica idêntica ao markertest que funcionou)
local function DrawCovaMarker(x, y, z)
    Citizen.InvokeNative(0x2A32FAA57B937173, 0x6903B113, 
        x, y, z - 1.0, -- Subimos um pouco (era -1.0) para compensar coordenadas enterradas
        0.0, 0.0, 0.0, 
        0.0, 0.0, 0.0, 
        2.0, 2.0, 1.5, -- Aumentei um pouco a altura do cilindro (1.5) para ele atravessar o chão se necessário
        0, 0, 255, 180, 
        false, true, 2, 
        false, nil, nil, false
    )
end


-- EVENTOS E FUNÇÕES
RegisterNetEvent("covas:notify", function(msg)
    TriggerEvent("vorp:TipRight", msg, 4000)
end)

local function LockPlayerControls()
    DisableAllControlActions(0)
    EnableControlAction(0, 0xA987235F, true) -- LOOK_LR
    EnableControlAction(0, 0xD2047988, true) -- LOOK_UD
    EnableControlAction(0, KEY_ALT, true)
end

local function StartRoubo(ped, idx)
    roubando = true
    startTimeRoubando = GetGameTimer()
    covaAtual = idx
    FreezeEntityPosition(ped, true)
end

local function StopRoubo(ped)
    roubando = false
    startTimeRoubando = 0
    covaAtual = 0
    FreezeEntityPosition(ped, false)
end

RegisterNetEvent("covas:inicioAprovado", function(idx)
    aguardandoAprovacao = false
    StartRoubo(PlayerPedId(), tonumber(idx))
end)

RegisterNetEvent("covas:cancelarRoubo", function()
    aguardandoAprovacao = false
    if roubando then StopRoubo(PlayerPedId()) end
end)


-- LOOP PRINCIPAL
Citizen.CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local p = GetEntityCoords(ped)

        if not roubando then
            local nearAnyCova = false

            for i = 1, #covas do
                local c = covas[i]
                local dist = Vdist(p.x, p.y, p.z, c.x, c.y, c.z)

                -- Desenhar marker se estiver a menos de 8 metros
                if dist < 8.0 then
                    sleep = 0
                    DrawCovaMarker(c.x, c.y, c.z)

                    -- Interação
                    if dist < 2.0 then -- Raio um pouco maior para facilitar a detecção
                        nearAnyCova = true
                        
                        if not hintVisible then
                            hintVisible = true
                            TriggerEvent("vorp:TipRight", "Pressione [E] para roubar a cova", HINT_TIME)
                        end

                        if IsControlJustReleased(0, KEY_E) and not aguardandoAprovacao then
                            aguardandoAprovacao = true
                            aguardoStartedAt = GetGameTimer()
                            covaAtual = i
                            TriggerServerEvent("covas:iniciarRoubo", i)
                        end
                    end
                end
            end

            if not nearAnyCova then hintVisible = false end

            -- Timeout de segurança para aprovação
            if aguardandoAprovacao and (GetGameTimer() - aguardoStartedAt > 3000) then
                aguardandoAprovacao = false
            end
        else
            -- Lógica enquanto rouba
            sleep = 0
            LockPlayerControls()
            
            local calculaTimer = (GetGameTimer() - startTimeRoubando) / 1000.0
            local now = GetGameTimer()

            if now - lastRobHint > ROB_HINT_COOLDOWN then
                lastRobHint = now
                TriggerEvent("vorp:TipRight", ("Roubando... %ds/%ds | ALT cancelar"):format(math.floor(calculaTimer), TEMPO_MAX), 1000)
            end

            if IsControlJustPressed(0, KEY_ALT) then
                StopRoubo(ped)
                TriggerServerEvent("covas:cancelarRoubo")
                TriggerEvent("vorp:TipRight", "~r~Você cancelou o roubo!", 3000)
            end

            if calculaTimer >= TEMPO_MAX then
                local idx = covaAtual
                StopRoubo(ped)
                TriggerEvent("vorp:TipRight", "~g~Você terminou de roubar a cova!", 3000)
                TriggerServerEvent("covas:finalizarRoubo", idx)
            end
        end
        Citizen.Wait(sleep)
    end
end)

-- COMANDOS DE UTILIDADE (TEST)
RegisterCommand("tpcova", function(source, args)
    local idx = tonumber(args[1]) -- Pega o número que você digitar
    if idx and covas[idx] then
        local coords = covas[idx]
        SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, true)
        print("[FRP_COVA] Teleportado para a cova #" .. idx)
    else
        -- Se não digitar número, vai para a primeira por padrão
        local coords = covas[1]
        SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, true)
        TriggerEvent("vorp:TipRight", "Use /tpcova [1 a " .. #covas .. "]", 4000)
    end
end)
-- Blips (Mantidos da versão original)
local covaBlips = {}
local function CreateCovaBlips()
    for _, b in ipairs(covaBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    covaBlips = {}
    for i = 1, #covas do
        local c = covas[i]
        local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, c.x, c.y, c.z)
        SetBlipSprite(blip, 587827268, true)
        SetBlipScale(blip, 0.8)
        Citizen.InvokeNative(0x9CB1A1623062F402, blip, ("Cova Suspeita #%d"):format(i))
        table.insert(covaBlips, blip)
    end
end

Citizen.CreateThread(function()
    Citizen.Wait(2000)
    CreateCovaBlips()
end)


RegisterCommand("pegarcoords", function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    -- Formata a string exatamente como você usa na sua tabela
    -- Adicionamos um comentário com o heading e um lembrete do Z
    local formatado = string.format("vector3(%.2f, %.2f, %.2f), -- Heading: %.2f", coords.x, coords.y, coords.z, heading)

    -- Imprime no console (F8) para copiar
    print("------------------------------------------")
    print("[FRP_COVA] COORDENADA COLETADA:")
    print(formatado)
    print("------------------------------------------")

    -- Notificação na tela para confirmar que pegou
    TriggerEvent("vorp:TipRight", "Coordenada enviada para o F8!", 3000)
end)