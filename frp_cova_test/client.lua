-- frp_cova/client.lua
print('[FRP_COVA] client.lua carregou')

local KEY_E   = 0xCEFD9220 -- E
local KEY_ALT = 0xE8342FF2 -- ALT

-- config
local TEMPO_MAX = 30

-- Hint para (não spammar)
local hintVisible = false
local HINT_TIME = 1500 -- 1.5s

-- Hint durante roubo (não spammar)
local lastRobHint = 0
local ROB_HINT_COOLDOWN = 1000 -- 1s

-- Debug marker
local SHOW_MARKER = true

-- notify (do server)
RegisterNetEvent("covas:notify", function(msg)
  TriggerEvent("vorp:TipRight", msg, 4000)
end)

-- controles
local function LockPlayerControls()
  DisableAllControlActions(0)

  -- liberar camera (look)
  EnableControlAction(0, 0xA987235F, true) -- LOOK_LR
  EnableControlAction(0, 0xD2047988, true) -- LOOK_UD

  -- liberar ALT para cancelar
  EnableControlAction(0, KEY_ALT, true)
end

-- covas --coords
local covas = {
  -- Saint Denis
  vector3(2401.0, -1113.0, 46.2),
  vector3(2392.0, -1105.0, 46.1),
  vector3(2410.0, -1098.0, 46.3),

  -- Blackwater
  vector3(-875.6, -1334.4, 43.0),
  vector3(-864.2, -1326.7, 43.0),
  vector3(-884.1, -1322.9, 43.1),

  -- usando essa de teste
  vector3(-954.60, -1203.91, 55.53),

  -- Valentine
  vector3(-240.5, 809.6, 121.4),
  vector3(-248.2, 818.9, 121.3),
  vector3(-232.8, 800.9, 121.2),
}

-- blips por cova
local covaBlips = {}

local function CreateCovaBlips()
  -- limpa se já existir
  for _, b in ipairs(covaBlips) do
    if DoesBlipExist(b) then
      RemoveBlip(b)
    end
  end
  covaBlips = {}

  for i = 1, #covas do
    local c = covas[i]
    -- RedM native blip
    local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, c.x, c.y, c.z) -- BLIP_STYLE / hash comum

    SetBlipSprite(blip, 587827268, true) -- sprite genérico (pode variar por build)
    SetBlipScale(blip, 0.8)
    Citizen.InvokeNative(0x9CB1A1623062F402, blip, ("Cova Suspeita #%d"):format(i)) -- SetBlipName

    table.insert(covaBlips, blip)
  end

  print(("[FRP_COVA] Blips criados: %d"):format(#covaBlips))
end

-- cria blips quando resource inicia
Citizen.CreateThread(function()
  Citizen.Wait(2000)
  CreateCovaBlips()
end)

-- comando pra recriar blips se você mudar coords em runtime
RegisterCommand("cova_blips", function()
  CreateCovaBlips()
  TriggerEvent("vorp:TipRight", "Blips das covas recriados!", 2500)
end)

-- roubo
local roubando = false
local startTimeRoubando = 0
local covaAtual = 0

local function StartRoubo(ped, idx)
  roubando = true
  startTimeRoubando = GetGameTimer()
  covaAtual = idx

  FreezeEntityPosition(ped, true)

  -- animação (opcional)
  -- TaskStartScenarioInPlace(ped, joaat("WORLD_HUMAN_CROUCH_INSPECT"), 0, true)
end

local function StopRoubo(ped)
  roubando = false
  startTimeRoubando = 0
  covaAtual = 0

  FreezeEntityPosition(ped, false)

  -- ClearPedTasks(ped)
end

-- loop principal
Citizen.CreateThread(function()
  while true do
    local sleep = 1000
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)

    if not roubando then
      local nearAnyCova = false

      for i = 1, #covas do
        -- distância só XY (evita Z zoado)
        local dist = #(vector2(playerCoords.x, playerCoords.y) - vector2(covas[i].x, covas[i].y))

        -- marker de debug quando perto
        if SHOW_MARKER and dist < 20.0 then
          sleep = 0
          DrawMarker(
            1,
            covas[i].x, covas[i].y, covas[i].z - 1.0,
            0.0, 0.0, 0.0,
            0.0, 0.0, 0.0,
            0.55, 0.55, 0.55,
            0, 255, 0, 140,
            false, true, 2, nil, nil, false
          )
        end

        if dist < 2.0 then
          nearAnyCova = true
          sleep = 0

          -- mostra só 1 vez ao entrar na área
          if not hintVisible then
            hintVisible = true
            TriggerEvent("vorp:TipRight", "Pressione [E] para roubar a cova", HINT_TIME)
          end

          if IsControlJustReleased(0, KEY_E) then
            StartRoubo(ped, i)
            TriggerServerEvent("covas:iniciarRoubo", i)
          end

          break
        end
      end

      -- saiu da região → permite mostrar novamente quando entrar
      if not nearAnyCova then
        hintVisible = false
      end
    else
      sleep = 0
      LockPlayerControls()

      local calculaTimer = (GetGameTimer() - startTimeRoubando) / 1000

      -- hint do roubo (sem spam)
      local now = GetGameTimer()
      if now - lastRobHint > ROB_HINT_COOLDOWN then
        lastRobHint = now
        TriggerEvent("vorp:TipRight", ("Roubando... %ds/%ds | ALT cancelar"):format(math.floor(calculaTimer), TEMPO_MAX), 1000)
      end

      -- cancelar por ALT
      if IsControlJustPressed(0, KEY_ALT) then
        StopRoubo(ped)
        TriggerServerEvent("covas:cancelarRoubo")
        TriggerEvent("vorp:TipRight", "~r~Você cancelou o roubo!", 3000)
      end

      -- finalizar pelo tempo
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



-- =========================
-- COMANDOS DE TESTE
-- =========================
RegisterCommand("tpcova", function()
  local ped = PlayerPedId()
  local idx = 1
  local coords = covas[idx]

  if coords then
    SetEntityCoords(ped, coords.x, coords.y, coords.z + 0.5, false, false, false, true)
    print("[FRP_COVA] Teleportado para a cova", idx)
  else
    print("[FRP_COVA] Índice de cova inválido")
  end
end)

RegisterCommand("tpbw", function()
  local ped = PlayerPedId()
  local coords = vector3(-875.6, -1334.4, 43.0)
  SetEntityCoords(ped, coords.x, coords.y, coords.z + 0.5, false, false, false, true)
  print("[FRP_COVA] Teleportado para BW (cova)")
end)

RegisterCommand("coords", function()
  local ped = PlayerPedId()
  local coords = GetEntityCoords(ped)
  local heading = GetEntityHeading(ped)

  local text = string.format(
    "vector3(%.2f, %.2f, %.2f), -- heading %.2f",
    coords.x, coords.y, coords.z, heading
  )

  print("[FRP_COVA] Coordenadas:", text)
  TriggerEvent("vorp:TipRight", "Coords no F8 (console)", 4000)
end)

RegisterCommand("distcova", function()
  local ped = PlayerPedId()
  local p = GetEntityCoords(ped)

  local bestI, bestD = -1, 999999.0
  for i = 1, #covas do
    local d = #(vector2(p.x, p.y) - vector2(covas[i].x, covas[i].y))
    if d < bestD then
      bestD = d
      bestI = i
    end
  end

  print(("[FRP_COVA] Cova mais próxima: %d | distXY=%.2f | player=(%.2f,%.2f,%.2f)"):format(bestI, bestD, p.x, p.y, p.z))
end)

-- toggle marker
RegisterCommand("covamarker", function()
  SHOW_MARKER = not SHOW_MARKER
  TriggerEvent("vorp:TipRight", ("Marker: %s"):format(SHOW_MARKER and "ON" or "OFF"), 2000)
end)
