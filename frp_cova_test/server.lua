-- server.lua
print('[FRP_COVA] server.lua carregou')

-- CONFIG
local TEMPO_MIN = 30        -- tempo mínimo roubando (segundos)
local COOLDOWN_SEG = 120    -- cooldown por player
local DIST_MAX = 5.0        -- reservado p/ validação futura

-- CONTROLE
local lastRob = {}   -- lastRob[src] = os.time()
local active  = {}   -- active[src] = { startedAt = os.time(), cova = X }

-- LOOT TABLE
local lootTable = {
  { item = "moedas_antigas",    min = 1, max = 5, weight = 30 },
  { item = "moedas_prata",      min = 1, max = 3, weight = 25 },
  { item = "cachimbo_antigo",   min = 1, max = 1, weight = 15 },
  { item = "fivela_cinto",      min = 1, max = 1, weight = 15 },
  { item = "documentos_velhos", min = 1, max = 1, weight = 10 },

  { item = "anel_ouro",         min = 1, max = 1, weight = 6 },
  { item = "colar_ouro",        min = 1, max = 1, weight = 4 },
  { item = "moedas_ouro",       min = 1, max = 2, weight = 3 },
  { item = "reliquia_antiga",   min = 1, max = 1, weight = 2 },
}

-- UTIL
local function notify(src, msg)
  TriggerClientEvent("covas:notify", src, msg)
end

local function weightedRandom(tbl)
  local total = 0
  for _, v in ipairs(tbl) do
    total = total + (v.weight or 1)
  end

  local r = math.random(1, total)
  local acc = 0

  for _, v in ipairs(tbl) do
    acc = acc + (v.weight or 1)
    if r <= acc then
      return v
    end
  end

  return tbl[#tbl]
end

local function giveItem(src, itemName, amount)
  exports.vorp_inventory:addItem(src, itemName, amount)
  notify(src, ("Você recebeu: ~g~%sx%d~s~"):format(itemName, amount))
end


-- INVENTÁRIO
local function verifyShovel(src)
  local count = exports.vorp_inventory:getItemCount(src, "shovel")
  return count and count > 0
end

-- TRY START (client → server)
RegisterNetEvent("covas:tryStart", function(covaIndex)
  local src = source
  local now = os.time()

  -- valida pá
  if not verifyShovel(src) then
    notify(src, "Você precisa de uma ~r~PÁ~s~ para cavar.")
    TriggerClientEvent("covas:cancelarRoubo", src)
    return
  end

  -- cooldown
  if lastRob[src] and (now - lastRob[src]) < COOLDOWN_SEG then
    local falta = COOLDOWN_SEG - (now - lastRob[src])
    notify(src, ("~r~Aguarde %ds para roubar novamente.~s~"):format(falta))
    return
  end

  -- já está roubando
  if active[src] then
    notify(src, "~r~Você já está roubando uma cova.~s~")
    return
  end

  -- autoriza client iniciar
  TriggerClientEvent("covas:startClient", src, covaIndex)
end)


-- CLIENT CONFIRMA START
RegisterNetEvent("covas:serverStarted", function(covaIndex)
  local src = source
  active[src] = {
    startedAt = os.time(),
    cova = tonumber(covaIndex)
  }

  notify(src, "~b~Você começou a roubar a cova...~s~")
end)

-- FINALIZA ROUBO
RegisterNetEvent("covas:finalizarRoubo", function(covaIndex)
  local src = source
  local now = os.time()

  local st = active[src]
  if not st then
    notify(src, "~r~Roubo inválido.~s~")
    return
  end

  -- tempo mínimo
  if (now - st.startedAt) < TEMPO_MIN then
    notify(src, "~r~Roubo cancelado (tempo insuficiente).~s~")
    active[src] = nil
    return
  end

  -- cova divergente
  if tonumber(covaIndex) ~= st.cova then
    notify(src, "~r~Roubo inválido (cova divergente).~s~")
    active[src] = nil
    return
  end

  -- revalida pá (anti-exploit)
  if not verifyShovel(src) then
    notify(src, "~r~Você perdeu sua pá durante o roubo.~s~")
    active[src] = nil
    return
  end

  -- encerra estado e aplica cooldown
  active[src] = nil
  lastRob[src] = now

  -- chance de não achar nada
  if math.random(1, 100) <= 20 then
    notify(src, "~y~Você não encontrou nada dessa vez.~s~")
    return
  end

  -- sorteio
  local picked = weightedRandom(lootTable)
  local amount = math.random(picked.min, picked.max)

  giveItem(src, picked.item, amount)
end)


-- CANCELAMENTO
RegisterNetEvent("covas:cancelarRoubo", function()
  local src = source
  active[src] = nil
end)

-- CLEANUP
AddEventHandler("playerDropped", function()
  local src = source
  active[src] = nil
end)
