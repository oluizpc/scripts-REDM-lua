-- server.lua
print('[FRP_COVA] server.lua carregou')

local TEMPO_MAX = 3                 -- tem que bater com o client
local COOLDOWN_SEG = 60             -- cooldown por COVA (por player)
local DIST_MAX = 5.0                -- validação extra (não usada aqui)

-- tabelas de controle
local lastRob = {}   -- lastRob[src][covaIndex] = os.time()
local active = {}    -- active[src] = { startedAt = os.time(), cova = X }

-- itens / pesos (quanto maior o peso, mais chance)
local lootTable = {
  -- comuns
  { item = "moedas_antigas",    min = 1, max = 5, weight = 30 },
  { item = "moedas_prata",      min = 1, max = 3, weight = 25 },
  { item = "cachimbo_antigo",   min = 1, max = 1, weight = 15 },
  { item = "fivela_cinto",      min = 1, max = 1, weight = 15 },
  { item = "documentos_velhos", min = 1, max = 1, weight = 10 },

  -- raros
  { item = "anel_ouro",         min = 1, max = 1, weight = 6 },
  { item = "colar_ouro",        min = 1, max = 1, weight = 4 },
  { item = "moedas_ouro",       min = 1, max = 2, weight = 3 },
  { item = "reliquia_antiga",   min = 1, max = 1, weight = 2 },
}

local function weightedRandom(tbl)
  local total = 0
  for _, v in ipairs(tbl) do total = total + (v.weight or 1) end
  local r = math.random(1, total)
  local acc = 0
  for _, v in ipairs(tbl) do
    acc = acc + (v.weight or 1)
    if r <= acc then return v end
  end
  return tbl[#tbl]
end

local function notify(src, msg)
  TriggerClientEvent("covas:notify", src, msg)
end

local function giveItem(src, itemName, amount)
  -- padrão que você usa
  TriggerEvent("vorpCore:addItem", src, itemName, amount)
  print(("[COVAS] Dar item %s x%d para %d"):format(itemName, amount, src))

  -- feedback pro client
  TriggerClientEvent("covas:notify", src, ("Você recebeu: ~g~%sx%d~s~"):format(itemName, amount))
end

local SHOVEL_ITEM = "shovel"

local function hasItem(src, item, amount)
  amount = amount or 1

  local p = promise.new()
  local resolved = false

  local ok = pcall(function()
    exports.vorp_inventory:getItemCount(src, function(count)
      if resolved then return end
      resolved = true
      p:resolve(tonumber(count) or 0)
    end, item)
  end)

  if not ok then
    return false
  end

  -- timeout de 1500ms pra evitar await infinito
  SetTimeout(1500, function()
    if resolved then return end
    resolved = true
    p:resolve(0)
  end)

  local count = Citizen.Await(p)
  return count >= amount
end

-- ==========================
-- INICIAR ROUBO
-- ==========================
RegisterNetEvent("covas:iniciarRoubo", function(covaIndex)
  local src = source
  local now = os.time()

  local idx = tonumber(covaIndex) or 0
  print(("[COVAS] iniciarRoubo recebido: src=%d cova=%s"):format(src, tostring(covaIndex)))

  if idx <= 0 then
    notify(src, "~r~Cova inválida.~s~")
    TriggerClientEvent("covas:cancelarRoubo", src)
    return
  end

  -- precisa de pá
  if not hasItem(src, SHOVEL_ITEM, 1) then
    notify(src, "~r~Você precisa de uma pá (shovel) para cavar esta cova.~s~")
    TriggerClientEvent("covas:cancelarRoubo", src)
    return
  end

  -- cooldown POR COVA (por player)
  lastRob[src] = lastRob[src] or {}
  local last = lastRob[src][idx]
  if last and (now - last) < COOLDOWN_SEG then
    local falta = COOLDOWN_SEG - (now - last)

    --  manda cooldown dessa cova pro client (pra mostrar 3D)
    TriggerClientEvent("covas:cooldown", src, idx, falta)

    -- (opcional) se quiser mostrar no canto direito, descomenta:
    -- notify(src, ("~r~Aguarde %ds para roubar novamente.~s~"):format(falta))

    TriggerClientEvent("covas:cancelarRoubo", src)
    return
  end

  active[src] = { startedAt = now, cova = idx }
  print(("[COVAS] APROVADO: src=%d cova=%d"):format(src, idx))

  TriggerClientEvent("covas:inicioAprovado", src, idx)
  notify(src, "~b~Você começou a roubar a cova...~s~")
end)

-- FINALIZAR ROUBO
RegisterNetEvent("covas:finalizarRoubo", function(covaIndex)
  local src = source
  local now = os.time()
  local idx = tonumber(covaIndex) or 0

  local st = active[src]
  if not st then
    notify(src, "~r~Roubo inválido (não iniciado).~s~")
    return
  end

  -- revalida shovel (anti-drop)
  if not hasItem(src, SHOVEL_ITEM, 1) then
    notify(src, "~r~Roubo cancelado: pá não encontrada.~s~")
    active[src] = nil
    return
  end

  local elapsed = now - st.startedAt
  if elapsed < TEMPO_MAX then
    notify(src, "~r~Roubo inválido (tempo insuficiente).~s~")
    active[src] = nil
    return
  end

  if idx <= 0 or idx ~= st.cova then
    notify(src, "~r~Roubo inválido (cova divergente).~s~")
    active[src] = nil
    return
  end

  --  seta cooldown POR COVA (por player)
  lastRob[src] = lastRob[src] or {}
  lastRob[src][idx] = now

  -- sincroniza com o client (mostra 3D)
  TriggerClientEvent("covas:cooldown", src, idx, COOLDOWN_SEG)

  active[src] = nil

  -- chance de não achar nada (mesmo assim entra em cooldown, pra evitar spam)
  if math.random(1, 100) <= 20 then
    notify(src, "~y~Você não encontrou nada dessa vez.~s~")
    return
  end

  local picked = weightedRandom(lootTable)
  local amount = math.random(picked.min or 1, picked.max or 1)
  giveItem(src, picked.item, amount)
end)

-- CANCELAR ROUBO
RegisterNetEvent("covas:cancelarRoubo", function()
  local src = source

  if active[src] then
    active[src] = nil
    TriggerClientEvent("covas:cancelarRoubo", src)
    notify(src, "~r~Você cancelou o roubo de covas!~s~")
  end
end)

AddEventHandler("playerDropped", function()
  local src = source
  active[src] = nil
  lastRob[src] = nil
end)

-- COMANDOS TESTE
RegisterCommand("testcova", function(source)
  if source == 0 then
    print("[FRP_COVA] /testcova foi executado no CONSOLE. Use no chat do jogador: /testcova")
    return
  end

  local src = source
  local picked = weightedRandom(lootTable)
  local amount = math.random(picked.min or 1, picked.max or 1)

  print(("[FRP_COVA] CMD /testcova -> %s x%d para %d"):format(picked.item, amount, src))

  exports.vorp_inventory:addItem(src, picked.item, amount)
  TriggerClientEvent("covas:notify", src, ("(TESTE) Você recebeu: ~g~%sx%d~s~"):format(picked.item, amount))
end, false)

RegisterCommand("darpá", function(source)
  if source == 0 then return end
  local src = source

  TriggerEvent("vorpCore:addItem", src, "shovel", 1)
  TriggerClientEvent("covas:notify", src, "~g~Você recebeu uma pá (shovel).~s~")
end, false)
