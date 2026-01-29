-- frp_drugdealler/server.lua
-- Adaptado (FRP/_core) para VORP
-- Compatível com variações comuns de VORPcore + vorp_inventory

local quantidade = {}

local function Quantidade(src)
    if quantidade[src] == nil then
        quantidade[src] = math.random(1, 3)
    end
end

-- =========================
-- VORP CORE
-- =========================
local VorpCore = nil
TriggerEvent("getCore", function(core)
    VorpCore = core
end)

-- =========================
-- HELPERS (Compat)
-- =========================

-- chama método com segurança (tenta obj:method(...) e obj.method(...))
local function CallMethod(obj, methodName, ...)
    if not obj then return false end
    local m = obj[methodName]
    if type(m) ~= "function" then
        return false
    end

    -- tenta como método (self)
    local ok = pcall(m, obj, ...)
    if ok then return true end

    -- tenta sem self
    ok = pcall(m, ...)
    return ok
end

local function GetCharacter(user)
    if not user then return nil end

    -- caso 1: getUsedCharacter é função
    if type(user.getUsedCharacter) == "function" then
        local ok, ch = pcall(user.getUsedCharacter) -- normalmente sem args
        if ok then return ch end

        -- fallback: algumas builds aceitam self
        ok, ch = pcall(user.getUsedCharacter, user)
        if ok then return ch end

        return nil
    end

    -- caso 2: já é objeto/tabela
    return user.getUsedCharacter
end

local function AddItem(src, item, amount)
    amount = tonumber(amount) or 1
    if amount <= 0 then return false end

    -- 1) Export do vorp_inventory (muito comum)
    if exports and exports.vorp_inventory and exports.vorp_inventory.addItem then
        exports.vorp_inventory:addItem(src, item, amount)
        return true
    end

    -- 2) Fallback: tentar via character
    if not VorpCore then return false end
    local user = VorpCore.getUser(src)
    if not user then return false end
    local character = GetCharacter(user)
    if not character then return false end

    if CallMethod(character, "addItem", item, amount) then return true end
    if CallMethod(character, "addInventoryItem", item, amount) then return true end

    return false
end

local function GetItemCount(src, item)
    -- 1) se tiver export pra count (nem sempre tem)
    if exports and exports.vorp_inventory and exports.vorp_inventory.getItemCount then
        local c = exports.vorp_inventory:getItemCount(src, item)
        return tonumber(c) or 0
    end

    -- 2) via character
    if not VorpCore then return 0 end
    local user = VorpCore.getUser(src)
    if not user then return 0 end
    local character = GetCharacter(user)
    if not character then return 0 end

    if type(character.getItemCount) == "function" then
        local ok, v = pcall(character.getItemCount, character, item)
        if ok then return tonumber(v) or 0 end
    end

    if type(character.getItemAmount) == "function" then
        local ok, v = pcall(character.getItemAmount, character, item)
        if ok then return tonumber(v) or 0 end
    end

    return 0
end

local function RemoveItem(src, item, amount)
    amount = tonumber(amount) or 1
    if amount <= 0 then return false end

    -- 1) export do vorp_inventory (prioridade)
    if exports and exports.vorp_inventory then
        if exports.vorp_inventory.subItem then
            exports.vorp_inventory:subItem(src, item, amount)
            return true
        end
        if exports.vorp_inventory.removeItem then
            exports.vorp_inventory:removeItem(src, item, amount)
            return true
        end
    end

    -- 2) via character (fallback)
    if not VorpCore then return false end
    local user = VorpCore.getUser(src)
    if not user then return false end
    local character = GetCharacter(user)
    if not character then return false end

    -- IMPORTANTÍSSIMO: NÃO chamar character.subItem direto (na sua build é tabela)
    if CallMethod(character, "removeItem", item, amount) then return true end
    if CallMethod(character, "removeInventoryItem", item, amount) then return true end

    return false
end

local function AddMoney(src, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return false end

    if not VorpCore then return false end
    local user = VorpCore.getUser(src)
    if not user then return false end
    local character = GetCharacter(user)
    if not character then return false end

    if CallMethod(character, "addCurrency", 0, amount) then return true end -- 0 = cash (comum)
    if CallMethod(character, "addMoney", amount) then return true end

    return false
end

local function Notify(src, msg)
    TriggerClientEvent("vorp:TipRight", src, msg, 4000)
end

-- =========================
-- CHECK PAYMENT (Venda do Ópio)
-- =========================
RegisterNetEvent("FRP:CONTRABANDO:checkPayment")
AddEventHandler("FRP:CONTRABANDO:checkPayment", function()
    local src = source
    Quantidade(src)

    if not VorpCore then
        print("[frp_drugdealler] VorpCore ainda não carregou (getCore).")
        return
    end

    local need = quantidade[src]
    local count = GetItemCount(src, "opio")

    if count >= need then
        local okRemove = RemoveItem(src, "opio", need)
        if not okRemove then
            print("[frp_drugdealler] Não consegui remover item (opio). Verifique API do inventário.")
            return
        end

        local pay = math.random(25, 35) * need
        local okPay = AddMoney(src, pay)
        if not okPay then
            print("[frp_drugdealler] Não consegui adicionar dinheiro. Verifique API do character.")
            return
        end

        Notify(src, ("Você vendeu %dx Ópio e recebeu $%d."):format(need, pay))
        quantidade[src] = nil

        TriggerClientEvent("FRP:CONTRABANDO:checkPayment", src, true)
    else
        Notify(src, ("Você precisa de %dx Ópio."):format(need))
    end
end)

-- =========================
-- OCORRÊNCIA / DENÚNCIA
-- =========================
RegisterNetEvent("FRP:CONTRABANDO:ocorrencia")
AddEventHandler("FRP:CONTRABANDO:ocorrencia", function()
    local src = source
    if not VorpCore then return end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end

    local coords = GetEntityCoords(ped)

    local policeList = {}
    if VorpCore.getUsersByGroup then
        policeList = VorpCore.getUsersByGroup("trooper") or {}
    end

    if #policeList > 0 then
        for i = 1, #policeList do
            local ps = policeList[i].getSource and policeList[i].getSource() or nil
            if ps then
                TriggerClientEvent("FRP:TOAST:New", ps, "alert", "Recebemos uma denúncia do tráfico de Ópio, verifique o ocorrido.")
                TriggerClientEvent("FRP:WANTED:denuncia", ps, vector3(coords.x, coords.y, coords.z))
            end
        end
    else
        TriggerClientEvent("FRP:TOAST:New", -1, "alert", "Recebemos uma denúncia do tráfico de Ópio, verifique o ocorrido.")
        TriggerClientEvent("FRP:WANTED:denuncia", -1, vector3(coords.x, coords.y, coords.z))
    end
end)

-- =========================
-- COMANDO DE TESTE
-- =========================
-- /giveitem opio 5
RegisterCommand("giveitem", function(source, args)
    local src = source
    local item = args[1] or "opio"
    local qtd = tonumber(args[2]) or 1

    local ok = AddItem(src, item, qtd)
    if ok then
        TriggerClientEvent("chat:addMessage", src, {
            args = { "^2SERVER", ("Você recebeu %dx %s"):format(qtd, item) }
        })
    else
        TriggerClientEvent("chat:addMessage", src, {
            args = { "^1SERVER", "Falha ao adicionar item. (API do inventário diferente)" }
        })
        print("[frp_drugdealler] AddItem falhou. Verifique exports do vorp_inventory ou métodos do character.")
    end
end, false)


RegisterCommand("tpcontrabando", function(source)
    print("[contrabando] comando tpcontrabando chamado no server")
    TriggerClientEvent("FRP:CONTRABANDO:tp", source)
end, false)
