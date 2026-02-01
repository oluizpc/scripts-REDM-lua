-- frp_cova/client.lua
print('[FRP_COVA] client.lua carregou')

local KEY_E   = 0xCEFD9220 -- E
local KEY_ALT = 0xE8342FF2 -- ALT

-- config
local TEMPO_MAX = 15

-- state
local roubando = false
local startTimeRoubando = 0
local covaAtual = 0
local aguardandoAprovacao = false
local aguardoStartedAt = 0
local paObjeto = nil

-- Coordenadas
local covas = {
    vector3(2401.10, -1112.33, 46.48),
    vector3(2391.55, -1104.50, 46.45),
    vector3(-960.07, -1209.21, 55.05),
    vector3(-961.69, -1203.33, 55.99),
    vector3(-959.74, -1197.96, 56.28),
    vector3(-246.20, 812.63, 122.58),
    vector3(-954.60, -1203.91, 55.53),
    vector3(-241.07, 809.29, 122.86),
    vector3(-248.60, 817.72, 122.42),
    vector3(-234.05, 818.74, 124.28),
}

-- TEXTO 3D REAL (REDM SAFE) - FLUTUANDO
local function DrawText3DWorld(x, y, z, text)
    local camCoords = GetGameplayCamCoord()
    local dist = #(vector3(x, y, z) - camCoords)
    if dist < 0.5 then dist = 0.5 end

    local scale = (1.0 / dist) * 2.0
    local fov = (1.0 / GetGameplayCamFov()) * 100.0
    scale = scale * fov

    -- texto
    SetTextScale(0.0 * scale, 0.30 * scale)
    SetTextFontForCurrentCommand(0)
    SetTextColor(255, 255, 255, 215) -- ✅ RedM: SetTextColor (não SetTextColour)
    SetTextCentre(true)

    SetDrawOrigin(x, y, z, 0)
    local str = CreateVarString(10, "LITERAL_STRING", text)
    DisplayText(str, 0.0, 0.0)
    ClearDrawOrigin()
end

-- FUNÇÕES DE ANIMAÇÃO / PÁ
local function IniciarAnimacaoEscavar(ped)
    local shovelHash = GetHashKey("p_shovel01x")
    RequestModel(shovelHash)
    while not HasModelLoaded(shovelHash) do Citizen.Wait(10) end

    local coords = GetEntityCoords(ped)
    paObjeto = CreateObject(shovelHash, coords.x, coords.y, coords.z, true, true, false)
    AttachEntityToEntity(
        paObjeto,
        ped,
        GetEntityBoneIndexByName(ped, "SKEL_R_HAND"),
        0.0, 0.0, 0.0,
        0.0, 90.0, 0.0,
        true, true, false, true, 1, true
    )

    local animDict = "amb_camp@world_camp_dynamic_fire@loghold@male_a@react_look@loop@generic"
    local animName = "react_look_front_loop"

    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Citizen.Wait(50)
    end

    ClearPedTasksImmediately(ped)
    TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, -1, 1, 0, false, false, false)
end

local function PararAnimacao(ped)
    ClearPedTasksImmediately(ped)
    if paObjeto and DoesEntityExist(paObjeto) then
        DeleteObject(paObjeto)
        paObjeto = nil
    end
end


-- CONTROLES
local function LockPlayerControls()
    DisableAllControlActions(0)
    EnableControlAction(0, 0xA987235F, true) -- LOOK_LR
    EnableControlAction(0, 0xD2047988, true) -- LOOK_UD
    EnableControlAction(0, KEY_ALT, true)    -- ALT cancelar
end

-- ROUBO (STATE)
local function StartRoubo(ped, idx)
    roubando = true
    startTimeRoubando = GetGameTimer()
    covaAtual = idx
    IniciarAnimacaoEscavar(ped)
end

local function StopRoubo(ped)
    roubando = false
    startTimeRoubando = 0
    covaAtual = 0
    FreezeEntityPosition(ped, false)
    PararAnimacao(ped)
end

-- EVENTOS DO SERVER
RegisterNetEvent("covas:inicioAprovado", function(idx)
    aguardandoAprovacao = false
    StartRoubo(PlayerPedId(), tonumber(idx))
end)    

RegisterNetEvent("covas:cancelarRoubo", function()
    aguardandoAprovacao = false
    if roubando then StopRoubo(PlayerPedId()) end
end)

RegisterNetEvent("covas:notify", function(msg, tempo)
    -- TipRight no canto direito (igual era)
    TriggerEvent("vorp:TipRight", msg, tempo or 4000)
end)

-- LOOP PRINCIPAL
Citizen.CreateThread(function()
    while true do
        local sleep = 900
        local ped = PlayerPedId()
        local p = GetEntityCoords(ped)

        if not roubando then
            -- timeout da aprovação
            if aguardandoAprovacao and (GetGameTimer() - aguardoStartedAt > 3000) then
                aguardandoAprovacao = false
                covaAtual = 0
            end

            for i = 1, #covas do
                local c = covas[i]
                local dist = Vdist(p.x, p.y, p.z, c.x, c.y, c.z)

                if dist < 5.0 then
                    sleep = 0

                    DrawText3DWorld(c.x, c.y, c.z + 0.10, "PRESSIONE [E] PARA ROUBAR A COVA")

                    if aguardandoAprovacao and covaAtual == i then
                        DrawText3DWorld(c.x, c.y, c.z + 0.95, "Aguardando aprovacao...")
                    end

                    if dist < 2.0 and IsControlJustReleased(0, KEY_E) and not aguardandoAprovacao then
                        aguardandoAprovacao = true
                        aguardoStartedAt = GetGameTimer()
                        covaAtual = i
                        TriggerServerEvent("covas:iniciarRoubo", i)
                    end
                end
            end
        else
            sleep = 0
            LockPlayerControls()

            local calculaTimer = (GetGameTimer() - startTimeRoubando) / 1000.0
            local c = covas[covaAtual]

            if c then
                DrawText3DWorld(c.x, c.y, c.z + .15, ("ESCAVANDO... %ds/%ds"):format(math.floor(calculaTimer), TEMPO_MAX))
                DrawText3DWorld(c.x, c.y, c.z + 0.10, "ALT para cancelar")
            end

            if IsControlJustPressed(0, KEY_ALT) then
                StopRoubo(ped)
                TriggerServerEvent("covas:cancelarRoubo")
            end

            if calculaTimer >= TEMPO_MAX then
                local idx = covaAtual
                StopRoubo(ped)
                TriggerServerEvent("covas:finalizarRoubo", idx)
            end
        end

        -- quando estiver desenhando texto, precisa rodar todo frame
        if sleep == 0 then
            Citizen.Wait(0)
        else
            Citizen.Wait(sleep)
        end
    end
end)

-- ==============================
-- COMANDOS (UTILIDADE)
-- ==============================
RegisterCommand("tpcova", function(source, args)
    local idx = tonumber(args[1])
    if idx and covas[idx] then
        local coords = covas[idx]
        SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, true)
    else
        local coords = covas[1]
        SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, true)
        TriggerEvent("vorp:TipRight", "Use /tpcova [1 a " .. #covas .. "]", 4000)
    end
end)

RegisterCommand("pegarcoords", function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local formatado = string.format("vector3(%.2f, %.2f, %.2f), -- Heading: %.2f", coords.x, coords.y, coords.z, heading)
    print("------------------------------------------")
    print(formatado)
    print("------------------------------------------")
    TriggerEvent("vorp:TipRight", "Coordenada no F8!", 3000)
end)
