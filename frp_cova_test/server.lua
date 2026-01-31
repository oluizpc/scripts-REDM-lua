-- server.lua
print('[FRP_COVA] server.lua carregou')

local TEMPO_MAX = 3                 -- tem que bater com o client
local COOLDOWN_SEG = 10             -- 10 seg por player
local DIST_MAX = 5.0                 -- validação extra

-- tabela simples de controle
local lastRob = {}   -- lastRob[src] = os.time()
local active = {}    -- active[src] = { startedAt = os.time(), cova = X }

-- itens / pesos (quanto maior o peso, mais chance)
--ajuste ideal com o dono do servidor
local lootTable = {
  -- comuns
  { item = "moedas_antigas",  min = 1, max = 5, weight = 30 },
  { item = "moedas_prata",    min = 1, max = 3, weight = 25 },
  { item = "cachimbo_antigo", min = 1, max = 1, weight = 15 },
  { item = "fivela_cinto",    min = 1, max = 1, weight = 15 },
  { item = "documentos_velhos", min = 1, max = 1, weight = 10 },

  -- raros
  { item = "anel_ouro",       min = 1, max = 1, weight = 6 },
  { item = "colar_ouro",      min = 1, max = 1, weight = 4 },
  { item = "moedas_ouro",     min = 1, max = 2, weight = 3 },
  { item = "reliquia_antiga", min = 1, max = 1, weight = 2 },
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




local function giveItem(src, itemName, amount)
  -- exports.vorp_inventory:addItem(src, itemName, amount)
  TriggerEvent("vorpCore:addItem", src, itemName, amount)
  print(("[COVAS] Dar item %s x%d para %d (placeholder)"):format(itemName, amount, src))

  -- feedback pro client (opcional)
  TriggerClientEvent("covas:notify", src, ("Você recebeu: ~g~%sx%d~s~"):format(itemName, amount))
end

local function notify(src, msg)
  TriggerClientEvent("covas:notify", src, msg)
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

-- client pode chamar quando começa (opcional, mas recomendado)
RegisterNetEvent("covas:iniciarRoubo", function(covaIndex)
  local src = source
  local now = os.time()

  print(("[COVAS] iniciarRoubo recebido: src=%d cova=%s"):format(src, tostring(covaIndex)))
  
  if not hasItem(src, SHOVEL_ITEM, 1) then
    notify(src, "~r~Você precisa de uma pá (shovel) para cavar esta cova.~s~")
    TriggerClientEvent("covas:cancelarRoubo", src)
    return
  end

  if lastRob[src] and (now - lastRob[src]) < COOLDOWN_SEG then
    local falta = COOLDOWN_SEG - (now - lastRob[src])
    notify(src, ("~r~Aguarde %ds para roubar novamente.~s~"):format(falta))
    TriggerClientEvent("covas:cancelarRoubo", src)
    return
  end

  active[src] = { startedAt = now, cova = tonumber(covaIndex) or 0 }
  print(("[COVAS] APROVADO: src=%d cova=%d"):format(src, active[src].cova))
  TriggerClientEvent("covas:inicioAprovado", src, active[src].cova)
  notify(src, "~b~Você começou a roubar a cova...~s~")
end)

-- chamado no final do roubo (obrigatório)
RegisterNetEvent("covas:finalizarRoubo", function(covaIndex)
  local src = source
  local now = os.time()

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

  if tonumber(covaIndex) ~= st.cova then
    notify(src, "~r~Roubo inválido (cova divergente).~s~")
    active[src] = nil
    return
  end

  lastRob[src] = now
  active[src] = nil

  if math.random(1, 100) <= 20 then
    notify(src, "~y~Você não encontrou nada dessa vez.~s~")
    return
  end

  local picked = weightedRandom(lootTable)
  local amount = math.random(picked.min or 1, picked.max or 1)
  giveItem(src, picked.item, amount)
end)

-- cancelamento (opcional)
RegisterNetEvent("covas:cancelarRoubo", function()
  local src = source
  active[src] = nil
end)

AddEventHandler("playerDropped", function()
  local src = source
  active[src] = nil
end)


RegisterCommand("testcova", function(source)
  if source == 0 then
    print("[FRP_COVA] /testcova foi executado no CONSOLE. Use no chat do jogador: /testcova")
    return
  end

  local src = source
  local picked = weightedRandom(lootTable)
  local amount = math.random(picked.min or 1, picked.max or 1)

  print(("[FRP_COVA] CMD /testcova -> %s x%d para %d"):format(picked.item, amount, src))

  -- usa o export (mais confiável no VORP recipe)
  exports.vorp_inventory:addItem(src, picked.item, amount)

  -- notify (só vai aparecer se seu client tiver covas:notify)
  TriggerClientEvent("covas:notify", src, ("(TESTE) Você recebeu: ~g~%sx%d~s~"):format(picked.item, amount))
end, false)


RegisterCommand("darpá", function(source)
  if source == 0 then return end
  local src = source

  -- padrão que você já usa no script
  TriggerEvent("vorpCore:addItem", src, "shovel", 1)

  TriggerClientEvent("covas:notify", src, "~g~Você recebeu uma pá (shovel).~s~")
end, false)
