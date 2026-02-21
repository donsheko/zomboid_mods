-- ======================================================================
-- SKO Lib: Core de Serialización Zomboid Build 42
-- Autores: SKO Mods
-- Descripción: Desarma y Reconstruye instancias de Items a Tablas Lua 
-- transmitibles (modData / Nube / MultiPlayer).
-- ======================================================================

SKOLib = SKOLib or {}
SKOLib.Serializer = SKOLib.Serializer or {}

-- Función recursiva profunda
function SKOLib.Serializer.serializeItemData(item)
    if not item then return nil end
    local customData = {}
    
    -- Preserve custom names explicitly given to items (vital for SKO Capsules)
    customData.customName = item:getName()

    if instanceof(item, "DrainableComboItem") then
        if type(item.getCurrentUsesFloat) == "function" then
            customData.uses = item:getCurrentUsesFloat()
        elseif type(item.getUsedDelta) == "function" then
            customData.uses = item:getUsedDelta()
        end
    end

    if instanceof(item, "HandWeapon") then
        customData.ammo = item:getCurrentAmmoCount()
        -- Guardar posibles aditamentos del arma
        customData.parts = {}
        if type(item.getWeaponPart) == "function" then
            local pScope = item:getWeaponPart("Scope")
            if pScope then customData.parts.Scope = SKOLib.Serializer.serializeItemData(pScope) end
            local pClip = item:getWeaponPart("Clip")
            if pClip then customData.parts.Clip = SKOLib.Serializer.serializeItemData(pClip) end
            local pSling = item:getWeaponPart("Sling")
            if pSling then customData.parts.Sling = SKOLib.Serializer.serializeItemData(pSling) end
            local pStock = item:getWeaponPart("Stock")
            if pStock then customData.parts.Stock = SKOLib.Serializer.serializeItemData(pStock) end
            local pCanon = item:getWeaponPart("Canon")
            if pCanon then customData.parts.Canon = SKOLib.Serializer.serializeItemData(pCanon) end
            local pRecoilpad = item:getWeaponPart("RecoilPad")
            if pRecoilpad then customData.parts.Recoilpad = SKOLib.Serializer.serializeItemData(pRecoilpad) end
        end
    end

    if instanceof(item, "Food") then
        customData.food = {
            hungerChange = item:getHungChange(),
            thirst = item:getThirstChange(),
            boredom = item:getBoredomChange(),
            unhappy = item:getUnhappyChange(),
            carbs = item:getCarbohydrates(),
            lipids = item:getLipids(),
            proteins = item:getProteins(),
            calories = item:getCalories(),
            cooked = item:isCooked(),
            burn = item:isBurnt(),
            freshness = item:getAge(),
            rotten = item:isRotten(),
        }
    end

    -- Respaldar posibles custom properties inyectadas por otros mods
    local modDataOut = nil
    local itemModData = item:getModData()
    if itemModData then
        modDataOut = {}
        for k,v in pairs(itemModData) do
            if type(v) ~= "userdata" and type(v) ~= "function" then
                modDataOut[k] = v
            end
        end
    end

    local serialized = {
        fullType = item:getFullType(),
        name = item:getDisplayName(),
        condition = item:getCondition(),
        customData = customData,
        modData = modDataOut,
        inventory = {}
    }

    -- Guardar de forma recursiva todo el inventario de las mochilas/recipientes
    if item:IsInventoryContainer() then
        local inv = item:getInventory()
        if inv then
            for i = 0, inv:getItems():size() - 1 do
                local innerItem = inv:getItems():get(i)
                if innerItem then
                    table.insert(serialized.inventory, SKOLib.Serializer.serializeItemData(innerItem))
                end
            end
        end
    end

    return serialized
end

-- Re-escribe Item a Objeto Físico desde Tabla
function SKOLib.Serializer.deserializeItemData(itemData)
    if not itemData then return nil end
    local newItem = instanceItem(itemData.fullType)
    if not newItem then return nil end

    if itemData.condition then
        newItem:setCondition(itemData.condition)
    end

    local cData = itemData.customData
    if cData then
        -- Restaurar el string Custom original si lo poseía (SKO Capsule vital injection)
        if cData.customName then
            newItem:setName(cData.customName)
        end
        
        if cData.uses and instanceof(newItem, "DrainableComboItem") then
            if type(newItem.setUsedDelta) == "function" then
                newItem:setUsedDelta(cData.uses)
            end
        end
        
        if cData.ammo and instanceof(newItem, "HandWeapon") then
            newItem:setCurrentAmmoCount(cData.ammo)
            if cData.parts and type(newItem.attachWeaponPart) == "function" then
                if cData.parts.Scope then newItem:attachWeaponPart(SKOLib.Serializer.deserializeItemData(cData.parts.Scope)) end
                if cData.parts.Clip then newItem:attachWeaponPart(SKOLib.Serializer.deserializeItemData(cData.parts.Clip)) end
                if cData.parts.Sling then newItem:attachWeaponPart(SKOLib.Serializer.deserializeItemData(cData.parts.Sling)) end
                if cData.parts.Stock then newItem:attachWeaponPart(SKOLib.Serializer.deserializeItemData(cData.parts.Stock)) end
                if cData.parts.Canon then newItem:attachWeaponPart(SKOLib.Serializer.deserializeItemData(cData.parts.Canon)) end
                if cData.parts.Recoilpad then newItem:attachWeaponPart(SKOLib.Serializer.deserializeItemData(cData.parts.Recoilpad)) end
            end
        end
        
        if cData.food and instanceof(newItem, "Food") then
            local f = cData.food
            if f.hungerChange then newItem:setHungChange(f.hungerChange) end
            if f.thirst then newItem:setThirstChange(f.thirst) end
            if f.boredom then newItem:setBoredomChange(f.boredom) end
            if f.unhappy then newItem:setUnhappyChange(f.unhappy) end
            if f.carbs then newItem:setCarbohydrates(f.carbs) end
            if f.lipids then newItem:setLipids(f.lipids) end
            if f.proteins then newItem:setProteins(f.proteins) end
            if f.calories then newItem:setCalories(f.calories) end
            if f.cooked ~= nil then newItem:setCooked(f.cooked) end
            if f.burn ~= nil then newItem:setBurnt(f.burn) end
            if f.freshness then newItem:setAge(f.freshness) end
            if f.rotten ~= nil then newItem:setRotten(f.rotten) end
        end
    end

    -- Regenerar ModData interna extra
    if itemData.modData then
        local mData = newItem:getModData()
        for k,v in pairs(itemData.modData) do
            mData[k] = v
        end
    end

    -- Rellenar recursivamente los inventarios del objeto (Mochilas)
    if itemData.inventory and #itemData.inventory > 0 and newItem:IsInventoryContainer() then
        local container = newItem:getInventory()
        if container then
            for _, innerData in ipairs(itemData.inventory) do
                local innerItem = SKOLib.Serializer.deserializeItemData(innerData)
                if innerItem then
                    container:AddItem(innerItem)
                end
            end
        end
    end

    return newItem
end
