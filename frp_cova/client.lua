local KEY_E   = 0xCEFD9220 -- E
local KEY_ALT = 0xE8342FF2 -- ALT 

-- funcao drawtext 
local function DrawText(msg)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- trava controles durante o roubo, mas deixa a câmera livre + ALT liberado
local function LockPlayerControls()
    DisableAllControlActions(0)

    -- liberar camera (look)
    EnableControlAction(0, 0xA987235F, true) -- LOOK_LR
    EnableControlAction(0, 0xD2047988, true) -- LOOK_UD

    -- liberar ALT para cancelar
    EnableControlAction(0, KEY_ALT, true)
end

-- lista de itens (sortear no server depois)
local itensRoubo = {
    { item = "anel_antigo",      label = "Anel Antigo" },
    { item = "colar_prata",      label = "Colar de Prata" },
    { item = "moedas_antigas",   label = "Moedas Antigas" },
    { item = "relogio_bolso",    label = "Relógio de Bolso" },
    { item = "brinco_ouro",      label = "Brinco de Ouro" },
    { item = "pulseira_prata",   label = "Pulseira de Prata" },
    { item = "botao_ouro",       label = "Botão de Ouro" },
    { item = "cachimbo_antigo",  label = "Cachimbo Antigo" },
    { item = "fivela_cinto",     label = "Fivela de Cinto" },
    { item = "medalhao_antigo",  label = "Medalhão Antigo" },
    { item = "moedas_prata",     label = "Moedas de Prata" },
    { item = "anel_ouro",        label = "Anel de Ouro" },
    { item = "colar_ouro",       label = "Colar de Ouro" },
    { item = "reliquia_antiga",  label = "Relíquia Antiga" },
}

-- covas (coords)
local covas = {
    vector3(2453.16, 4963.45, 46.81),
    vector3(2453.16, 4963.45, 46.81),
    vector3(2453.16, 4963.45, 46.81),
    vector3(2453.16, 4963.45, 46.81),
    vector3(2453.16, 4963.45, 46.81),
}

-- estado
local roubando = false
local startTimeRoubando = 0
local TEMPO_MAX = 30
local covaAtual = 0

local function StartRoubo(ped, idx)
    roubando = true
    startTimeRoubando = GetGameTimer()
    covaAtual = idx

    -- trava o boneco no lugar 
    FreezeEntityPosition(ped, true)

    -- entra animacao aqui (placeholder)
    -- TaskStartScenarioInPlace(ped, joaat("WORLD_HUMAN_CROUCH_INSPECT"), 0, true)
end

local function StopRoubo(ped)
    roubando = false
    startTimeRoubando = 0
    covaAtual = 0

    -- destrava
    FreezeEntityPosition(ped, false)

    -- limpar animacao quando você colocar
    -- ClearPedTasks(ped)
end

Citizen.CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local playerCoords = GetEntityCoords(ped)

        if not roubando then
            for i = 1, #covas do
                local dist = #(playerCoords - covas[i])

                if dist < 2.0 then
                    sleep = 1
                    DrawText("PRESSIONE ~b~E~w~ PARA ROUBAR A COVA")

                    if IsControlJustPressed(0, KEY_E) then
                        StartRoubo(ped, i)
                    end

                    break
                end
            end
        else
            sleep = 0

            -- bloqueia tudo, libera câmera e ALT
            LockPlayerControls()

            local calculaTimer = (GetGameTimer() - startTimeRoubando) / 1000
            DrawText(("ROUBANDO... ~b~%ds~w~ / %ds  |  ~b~ALT~w~ cancelar"):format(math.floor(calculaTimer), TEMPO_MAX))

            -- cancelar por ALT (única forma de sair antes do tempo)
            if IsControlJustPressed(0, KEY_ALT) then
                StopRoubo(ped)
                DrawText("~r~Você cancelou o roubo!")
            end

            -- finalizar pelo tempo
            if calculaTimer >= TEMPO_MAX then
                local sorteio = math.random(1, #itensRoubo)
                local itemSorteado = itensRoubo[sorteio]

                StopRoubo(ped)
                DrawText("~g~Você terminou de roubar a cova!")
                print("Item sorteado:", itemSorteado.item, itemSorteado.label)

                -- ideal: recompensa no server
                -- TriggerServerEvent("covas:darRecompensa", itemSorteado.item)
            end
        end

        Citizen.Wait(sleep)
    end
end)
