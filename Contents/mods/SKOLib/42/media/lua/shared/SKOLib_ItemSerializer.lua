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
    local data = {}
    
    -- 1. Atributos Base (pz-serialization-base)
    data.fullType = item:getFullType()
    data.condition = item:getCondition()
    data.favorite = item:isFavorite()
    data.customName = item:getName() ~= item:getScriptItem():getDisplayName() and item:getName() or nil
    
    -- World Sprite (Muebles B42)
    if type(item.getWorldSprite) == "function" then
        local wsOk, ws = pcall(function() return item:getWorldSprite() end)
        if wsOk and ws and ws ~= "" then data.worldSprite = ws end
    end

    -- 2. ModData
    local itemModData = item:getModData()
    if itemModData then
        data.modData = {}
        for k,v in pairs(itemModData) do
            if type(v) ~= "userdata" and type(v) ~= "function" then
                data.modData[k] = v
            end
        end
    end

    -- 3. Especializaciones por Tipo
    
    -- Fluidos (pz-serialization-fluid - B42)
    if item:getFluidContainer() then
        local fc = item:getFluidContainer()
        data.fluid = {
            amount = fc:getAmount(),
            type = fc:getContainerType(),
            tainted = fc:isTainted()
        }
    end

    -- Ropa (pz-serialization-clothing)
    if instanceof(item, "Clothing") then
        local visual = item:getVisual()
        local coveredParts = item:getCoveredParts()
        data.clothing = {
            wetness = item:getWetness(),
            dirtyness = item:getDirtyness(),
            blood = item:getBloodlevel(),
            parts = {},
            tint = { r = visual:getTint():getR(), g = visual:getTint():getG(), b = visual:getTint():getB() }
        }
        for i=0, coveredParts:size()-1 do
            local part = coveredParts:get(i)
            local partID = part:toString()
            data.clothing.parts[partID] = {
                hole = visual:getHole(part) > 0,
                blood = item:getBloodlevelForPart(part),
                patch = item:getPatchType(part) and item:getPatchType(part):getType() or nil
            }
        end
    end

    -- Armas (pz-serialization-weapon)
    if instanceof(item, "HandWeapon") then
        data.weapon = {
            ammo = item:getCurrentAmmoCount(),
            jammed = item:isJammed(),
            chambered = item:isRoundChambered(),
            spentRound = item:isSpentRoundChambered(),
            spentCount = item:getSpentRoundCount(),
            fireMode = item:getFireMode(),
            parts = {}
        }
        local partSlots = {"Scope", "Clip", "Sling", "Stock", "Canon", "RecoilPad"}
        for _, slot in ipairs(partSlots) do
            local part = item:getWeaponPart(slot)
            if part then
                data.weapon.parts[slot] = SKOLib.Serializer.serializeItemData(part)
            end
        end
    end

    -- Comida (pz-serialization-food)
    if instanceof(item, "Food") then
        data.food = {
            age = item:getAge(),
            cooked = item:isCooked(),
            burnt = item:isBurnt(),
            frozenTime = item:getFrozenTime(),
            poison = item:getPoisonPower(),
            hung = item:getHungChange(),
            calories = item:getCalories(),
            carbs = item:getCarbohydrates(),
            lipids = item:getLipids(),
            proteins = item:getProteins()
        }
    end

    -- Literatura y Medios (pz-serialization-literature)
    if item:getNumberOfPages() > 0 then
        data.literature = { pages = item:getAlreadyReadPages() }
    end
    if item.getMediaData and item:getMediaData() then
        data.mediaID = item:getMediaData():getId()
    end

    -- Extras: Llaves y Dispositivos (pz-serialization-extras)
    if instanceof(item, "Key") then
        data.keyId = item:getKeyId()
    end
    if item:getDeviceData() then
        local dd = item:getDeviceData()
        data.device = {
            channel = dd:getChannel(),
            turnedOn = dd:getIsTurnedOn(),
            battery = dd:getBattery()
        }
    end
    
    -- Drainables clásicos (si no son fluidos)
    if not data.fluid and instanceof(item, "DrainableComboItem") then
        data.usedDelta = item:getUsedDelta()
    end

    -- 4. Contenedores (pz-serialization-container - Recursivo)
    if item:IsInventoryContainer() then
        data.inventory = {}
        local inv = item:getInventory()
        if inv then
            local items = inv:getItems()
            for i = 0, items:size() - 1 do
                local innerItem = items:get(i)
                if innerItem then
                    table.insert(data.inventory, SKOLib.Serializer.serializeItemData(innerItem))
                end
            end
        end
    end

    return data
end

-- Re-escribe Item a Objeto Físico desde Tabla
function SKOLib.Serializer.deserializeItemData(itemData)
    if not itemData then return nil end
    
    -- 1. Instanciación Segura
    local ok, newItem = pcall(instanceItem, itemData.fullType)
    if not ok or not newItem then 
        print("[SKOLib] Error: No se pudo instanciar item " .. tostring(itemData.fullType))
        return nil 
    end

    -- 2. Restauración Base
    newItem:setCondition(itemData.condition or newItem:getConditionMax())
    newItem:setFavorite(itemData.favorite or false)
    if itemData.customName then newItem:setName(itemData.customName) end
    
    if itemData.modData then
        local mData = newItem:getModData()
        for k,v in pairs(itemData.modData) do mData[k] = v end
    end

    -- 3. Restauración Especializada
    
    -- Fluidos (B42)
    if itemData.fluid and newItem:getFluidContainer() then
        local fc = newItem:getFluidContainer()
        fc:empty()
        if itemData.fluid.amount > 0 then
            fc:addFluid(itemData.fluid.type, itemData.fluid.amount)
            if itemData.fluid.tainted then fc:setTainted(true) end
        end
    end

    -- Ropa
    if itemData.clothing and instanceof(newItem, "Clothing") then
        local c = itemData.clothing
        newItem:setWetness(c.wetness or 0)
        newItem:setDirtyness(c.dirtyness or 0)
        newItem:setBloodLevel(c.blood or 0)
        if c.tint then
            newItem:getVisual():setTint(ImmutableColor.new(c.tint.r, c.tint.g, c.tint.b, 1))
        end
        for partID, pData in pairs(c.parts or {}) do
            local part = BloodBodyPartType.FromString(partID)
            if part then
                if pData.hole then newItem:getVisual():setHole(part) end
                newItem:setBlood(part, pData.blood or 0)
            end
        end
    end

    -- Armas
    if itemData.weapon and instanceof(newItem, "HandWeapon") then
        local w = itemData.weapon
        newItem:setCurrentAmmoCount(w.ammo or 0)
        newItem:setJammed(w.jammed or false)
        newItem:setRoundChambered(w.chambered or false)
        newItem:setSpentRoundChambered(w.spentRound or false)
        newItem:setSpentRoundCount(w.spentCount or 0)
        if w.fireMode then newItem:setFireMode(w.fireMode) end
        for slot, pData in pairs(w.parts or {}) do
            local part = SKOLib.Serializer.deserializeItemData(pData)
            if part then newItem:attachWeaponPart(part) end
        end
    end

    -- Comida
    if itemData.food and instanceof(newItem, "Food") then
        local f = itemData.food
        newItem:setAge(f.age or 0)
        newItem:setCooked(f.cooked or false)
        newItem:setBurnt(f.burnt or false)
        newItem:setFrozenTime(f.frozenTime or 0)
        newItem:setPoisonPower(f.poison or 0)
        newItem:setHungChange(f.hung or newItem:getHungChange())
        newItem:setCalories(f.calories or 0)
        newItem:setCarbohydrates(f.carbs or 0)
        newItem:setLipids(f.lipids or 0)
        newItem:setProteins(f.proteins or 0)
    end

    -- Literatura y Medios
    if itemData.literature and newItem:getNumberOfPages() > 0 then
        newItem:setAlreadyReadPages(itemData.literature.pages or 0)
    end
    if itemData.mediaID and newItem.setMediaData then
        local mediaData = getZomboidRadio():getRecordedMedia():getMediaDataFromID(itemData.mediaID)
        if mediaData then newItem:setMediaData(mediaData) end
    end

    -- Extras
    if itemData.keyId and instanceof(newItem, "Key") then
        newItem:setKeyId(itemData.keyId)
    end
    if itemData.device and newItem:getDeviceData() then
        local dd = newItem:getDeviceData()
        dd:setChannel(itemData.device.channel)
        dd:setIsTurnedOn(itemData.device.turnedOn)
        dd:setBattery(itemData.device.battery)
    end
    
    -- Drainables
    if itemData.usedDelta and instanceof(newItem, "DrainableComboItem") then
        newItem:setUsedDelta(itemData.usedDelta)
    end

    -- 4. Contenedores (Recursivo)
    if newItem:IsInventoryContainer() and itemData.inventory then
        local inv = newItem:getInventory()
        for _, innerData in ipairs(itemData.inventory) do
            local innerItem = SKOLib.Serializer.deserializeItemData(innerData)
            if innerItem then inv:AddItem(innerItem) end
        end
    end

    return newItem
end
