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

-- Debug marker (precisa ser NÃO-local pq você toggla no command)
SHOW_MARKER = true

-- Marker config (igual seu contrabando)
local MARKER_DIST = 5.0
local MARKER_SIZE = 1.5
local MARKER_COLOR = { r = 255, g = 80, b = 80, a = 90 } -- vermelho clarinho

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

-- =========================
-- MARKER (igual contrabando)
-- =========================
local function DrawCovaMarker(covaVec3)
  local _, groundZ = GetGroundZAndNormalFor_3dCoord(covaVec3.x, covaVec3.y, covaVec3.z, 1)

  Citizen.InvokeNative(
    0x2A32FAA57B937173,
    0x6903B113,
    covaVec3.x, covaVec3.y, groundZ - 0.97,
    0.0, 0.0, 0.0,
    0.0, 0.0, 0.0,
    MARKER_SIZE, MARKER_SIZE, MARKER_SIZE,
    MARKER_COLOR.r, MARKER_COLOR.g, MARKER_COLOR.b, MARKER_COLOR.a,
    0, 0, 2,
    0, 0, 0,
    false
  )
end

-- =========================
-- ROUBO
-- =========================
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

-- =========================
-- EVENTOS DO SERVER (fluxo correto)
-- =========================

-- Server autorizou iniciar (depois das validações: pá, cooldown, etc.)
RegisterNetEvent("covas:startClient", function(covaIndex)
  local ped = PlayerPedId()
  local idx = tonumber(covaIndex) or 0
  if idx <= 0 or not covas[idx] then return end

  -- inicia no client
  StartRoubo(ped, idx)

  -- confirma pro server que começou (ele marca active/startedAt)
  TriggerServerEvent("covas:serverStarted", idx)
end)

-- Server mandou cancelar (se você quiser cortar animação/estado na hora)
RegisterNetEvent("covas:cancelarRoubo", function()
  local ped = PlayerPedId()
  if roubando then
    StopRoubo(ped)
  end
end)

-- =========================
-- LOOP PRINCIPAL
-- =========================
Citizen.CreateThread(function()
  while true do
    local sleep = 1000
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)

    if not roubando then
      local nearAnyCova = false

      for i = 1, #covas do
        -- distância XY (evita Z zoado)
        local dist = #(vector2(playerCoords.x, playerCoords.y) - vector2(covas[i].x, covas[i].y))

        -- MARKER: só aparece até 5m (como você pediu)
        if SHOW_MARKER and dist <= MARKER_DIST then
          sleep = 0
          DrawCovaMarker(covas[i])
        end

        -- área de interação (2m)
        if dist < 2.0 then
          nearAnyCova = true
          sleep = 0

          if not hintVisible then
            hintVisible = true
            TriggerEvent("vorp:TipRight", "Pressione [E] para roubar a cova", HINT_TIME)
          end

          if IsControlJustReleased(0, KEY_E) then
            -- NÃO inicia no client aqui.
            -- Só pede pro server validar e autorizar:
            TriggerServerEvent("covas:tryStart", i)
          end

          break
        end
      end

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
        TriggerEvent("vorp:TipRight",
          ("Roubando... %ds/%ds | ALT cancelar"):format(math.floor(calculaTimer), TEMPO_MAX),
          1000
        )
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

RegisterCommand("covamarker", function()
  SHOW_MARKER = not SHOW_MARKER
  TriggerEvent("vorp:TipRight", ("Marker: %s"):format(SHOW_MARKER and "ON" or "OFF"), 2000)
end)
