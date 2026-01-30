-- server.lua

local TEMPO_MAX = 30                 -- tem que bater com o client
local COOLDOWN_SEG = 120             -- 2 minutos por player
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
  -- TriggerEvent("vorpCore:addItem", src, itemName, amount)
  print(("[COVAS] Dar item %s x%d para %d (placeholder)"):format(itemName, amount, src))

  -- feedback pro client (opcional)
  TriggerClientEvent("covas:notify", src, ("Você recebeu: ~g~%sx%d~s~"):format(itemName, amount))
end

local function notify(src, msg)
  TriggerClientEvent("covas:notify", src, msg)
end

-- client pode chamar quando começa (opcional, mas recomendado)
RegisterNetEvent("covas:iniciarRoubo", function(covaIndex)
  local src = source
  local now = os.time()

  if lastRob[src] and (now - lastRob[src]) < COOLDOWN_SEG then
    local falta = COOLDOWN_SEG - (now - lastRob[src])
    notify(src, ("~r~Aguarde %ds para roubar novamente.~s~"):format(falta))
    return
  end

  active[src] = { startedAt = now, cova = tonumber(covaIndex) or 0 }
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

  -- valida tempo mínimo
  local elapsed = now - st.startedAt
  if elapsed < TEMPO_MAX then
    notify(src, "~r~Roubo inválido (tempo insuficiente).~s~")
    active[src] = nil
    return
  end

  -- valida o índice (opcional)
  if tonumber(covaIndex) ~= st.cova then
    notify(src, "~r~Roubo inválido (cova divergente).~s~")
    active[src] = nil
    return
  end

  -- aplica cooldown
  lastRob[src] = now
  active[src] = nil

  -- chance de não vir nada (ex: 20%)
  if math.random(1, 100) <= 20 then
    notify(src, "~y~Você não encontrou nada dessa vez.~s~")
    return
  end

  -- sorteio ponderado
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
