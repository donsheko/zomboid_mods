-- ======================================================================
-- SKO Lib: Core de Serialización Zomboid Build 42
-- Autores: SKO Mods
-- Descripción: Desarma y Reconstruye instancias de Items a Tablas Lua 
-- transmitibles (modData / Nube / MultiPlayer).
-- ======================================================================

SKOLib = SKOLib or {}
SKOLib.Serializer = SKOLib.Serializer or {}
SKOLib.Serializer.DEBUG = false

local function debugLog(msg)
    if SKOLib.Serializer.DEBUG then
        print("[SKOLib-Serializer] " .. tostring(msg))
    end
end

-- Aplica fluidos guardados en modData (deferred restoration)
function SKOLib.Serializer.applyDeferredRestoration(item, worldObj)
    if not item then return end
    local mData = item:getModData()
    local fluidData = mData.skoRestoreFluid
    
    if fluidData then
        -- En B42 el contenedor puede estar en el Item O en el WorldObject (si está en el suelo)
        local fc = nil
        if item.getFluidContainer then fc = item:getFluidContainer() end
        if not fc and worldObj and worldObj.getFluidContainer then
            fc = worldObj:getFluidContainer()
        end

        if fc then
            print("[SKOLib-Fluid] Applying DEFERRED restoration: " .. tostring(fluidData.amount) .. " | Type: " .. tostring(fluidData.type))
            
            -- Vaciado absoluto
            pcall(function() fc:Empty() end)
            
            -- REFUERZO B42 SUELO: Si el WorldObject tiene otro componente interno
            if worldObj and type(worldObj) == "userdata" and type(worldObj.getItem) == "function" then
                pcall(function()
                    local itemInWorld = worldObj:getItem()
                    if itemInWorld and itemInWorld.getFluidContainer then
                        local fcInner = itemInWorld:getFluidContainer()
                        if fcInner then
                            -- Usamos adjustAmount(0) que es más seguro que indexar Empty directamente
                            pcall(function() fcInner:adjustAmount(0.0) end)
                            pcall(function() fcInner:Empty() end)
                        end
                    end
                end)
            end

            if fluidData.amount and fluidData.amount > 0 and fluidData.type and fluidData.type ~= "" then
                local fluidTypeObj = nil
                local ftOk, ft = pcall(function() 
                    if FluidType and FluidType.FromNameLower then
                        return FluidType.FromNameLower(fluidData.type)
                    end
                end)
                if ftOk and ft then fluidTypeObj = ft end
                if not fluidTypeObj then
                    local fOk, fl = pcall(function() return Fluid[fluidData.type] end)
                    if fOk and fl then fluidTypeObj = fl end
                end

                if fluidTypeObj then
                    local targetAmount = fluidData.amount
                    local currentCap = fc:getCapacity()
                    
                    print("[SKOLib-Fluid] Restoring. Target: " .. tostring(targetAmount) .. " | CurrentCap: " .. tostring(currentCap))

                    if targetAmount > 0 and targetAmount <= 1.0 and currentCap > 1.0 then
                        print("[SKOLib-Fluid] Amount looks like a RATIO. Converting to Absolute ml.")
                        targetAmount = targetAmount * currentCap
                    end

                    pcall(function() fc:addFluid(fluidTypeObj, targetAmount) end)
                    pcall(function() fc:adjustAmount(targetAmount) end)
                    
                    if instanceof(item, "DrainableComboItem") and currentCap > 0 then
                        pcall(function() item:setUsedDelta(targetAmount / currentCap) end)
                    end
                end
            end

            if fluidData.tainted then pcall(function() fc:setTainted(true) end) end
            
            -- Limpiar modData para no re-aplicar
            mData.skoRestoreFluid = nil
            
            -- Sincronizar
            pcall(function() item:syncItemFields() end)
            print("[SKOLib-Fluid] Deferred Restoration Complete. Final Amount: " .. tostring(fc:getAmount()))
        end
    end
end

-- Función recursiva profunda
function SKOLib.Serializer.serializeItemData(item, worldObj)
    if not item then return nil end
    debugLog("Serializing: " .. tostring(item:getFullType()))
    local data = {}
    
    -- 1. Atributos Base
    data.fullType = item:getFullType()
    data.name = item:getDisplayName()
    data.condition = item:getCondition()
    data.favorite = item:isFavorite()
    data.customName = item:getName() ~= item:getScriptItem():getDisplayName() and item:getName() or nil
    
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
    local fc = nil
    if item.getFluidContainer then fc = item:getFluidContainer() end
    if not fc and worldObj and worldObj.getFluidContainer then
        fc = worldObj:getFluidContainer()
    end

    if fc then
        local fType = ""
        if type(fc.getContainerType) == "function" then
            fType = fc:getContainerType()
        elseif not fc:isEmpty() and fc:getPrimaryFluid() then
            fType = fc:getPrimaryFluid():getFluidTypeString()
        end
        
        data.fluid = {
            amount = fc:getAmount(),
            type = fType,
            tainted = fc:isTainted()
        }
        print("[SKOLib-Fluid] Serialized: " .. tostring(data.fluid.amount) .. " | Type: " .. tostring(data.fluid.type))
    end

    if instanceof(item, "Clothing") then
        local visual = item:getVisual()
        local coveredParts = item:getCoveredParts()
        data.clothing = {
            wetness = type(item.getWetness) == "function" and item:getWetness() or 0,
            dirtyness = type(item.getDirtyness) == "function" and item:getDirtyness() or 0,
            blood = type(item.getBloodlevel) == "function" and item:getBloodlevel() or 0,
            parts = {},
            tint = { r = 1, g = 1, b = 1 }
        }
        
        if visual and visual:getTint() then
            local tint = visual:getTint()
            if type(tint.getR) == "function" then
                data.clothing.tint = { r = tint:getR(), g = tint:getG(), b = tint:getB() }
            elseif tint.r then
                data.clothing.tint = { r = tint.r, g = tint.g, b = tint.b }
            end
        end

        if coveredParts then
            for i=0, coveredParts:size()-1 do
                local part = coveredParts:get(i)
                if part then
                    local partID = part:toString()
                    data.clothing.parts[partID] = {
                        hole = visual and visual:getHole(part) > 0 or false,
                        blood = type(item.getBloodlevelForPart) == "function" and item:getBloodlevelForPart(part) or 0,
                        patch = (type(item.getPatchType) == "function" and item:getPatchType(part) and item:getPatchType(part):getType()) or nil
                    }
                end
            end
        end
    end

    if instanceof(item, "HandWeapon") then
        data.weapon = { parts = {} }
        if item:isRanged() then
            data.weapon.ammo = item:getCurrentAmmoCount()
            data.weapon.jammed = item:isJammed()
            data.weapon.chambered = item:isRoundChambered()
            data.weapon.spentRound = item:isSpentRoundChambered()
            data.weapon.spentCount = item:getSpentRoundCount()
            data.weapon.fireMode = item:getFireMode()
        end
        local partSlots = {"Scope", "Clip", "Sling", "Stock", "Canon", "RecoilPad"}
        for _, slot in ipairs(partSlots) do
            local part = item:getWeaponPart(slot)
            if part then data.weapon.parts[slot] = SKOLib.Serializer.serializeItemData(part) end
        end
    end

    if instanceof(item, "Food") then
        data.food = {
            age = item:getAge(), cooked = item:isCooked(), burnt = item:isBurnt(),
            frozenTime = item:getFrozenTime(), poison = item:getPoisonPower(),
            hung = item:getHungChange()
        }
        pcall(function()
            data.food.calories = item:getCalories()
            data.food.carbs = item:getCarbohydrates()
            data.food.lipids = item:getLipids()
            data.food.proteins = item:getProteins()
        end)
    end

    if item.getNumberOfPages and item:getNumberOfPages() > 0 then
        data.literature = { pages = item:getAlreadyReadPages() }
    end
    if item.getMediaData and item:getMediaData() then
        data.mediaID = item:getMediaData():getId()
    end

    if item.getKeyId and instanceof(item, "Key") then
        data.keyId = item:getKeyId()
    end
    if item.getDeviceData and item:getDeviceData() then
        local dd = item:getDeviceData()
        data.device = {}
        -- B42: Los dispositivos electrónicos son extremadamente inestables en serialización directa
        pcall(function() 
            local channel = dd:getChannel()
            if channel then data.device.channel = channel end
        end)
        pcall(function() 
            local turnedOn = dd:getIsTurnedOn()
            if turnedOn ~= nil then data.device.turnedOn = turnedOn end
        end)
        -- Saltamos getBattery por ahora para evitar crash persistente en B42
        -- pcall(function() data.device.battery = dd:getBattery() end)
        debugLog("Serialized DeviceData for " .. tostring(data.fullType))
    end
    
    if instanceof(item, "DrainableComboItem") then
        if type(item.getUsedDelta) == "function" then
            data.usedDelta = item:getUsedDelta()
        elseif type(item.getCurrentUsesFloat) == "function" then
            data.usedDelta = item:getCurrentUsesFloat()
        end
    end

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

function SKOLib.Serializer.deserializeItemData(itemData)
    if not itemData then return nil end
    debugLog("Deserializing: " .. tostring(itemData.fullType))
    local ok, newItem = pcall(instanceItem, itemData.fullType)
    if not ok or not newItem then 
        debugLog("FAILED to instanceItem: " .. tostring(itemData.fullType))
        return nil 
    end

    newItem:setCondition(itemData.condition or newItem:getConditionMax())
    newItem:setFavorite(itemData.favorite or false)
    if itemData.customName then newItem:setName(itemData.customName) end
    
    if itemData.modData then
        local mData = newItem:getModData()
        for k,v in pairs(itemData.modData) do mData[k] = v end
    end

    if itemData.fluid and newItem:getFluidContainer() then
        local fc = newItem:getFluidContainer()
        itemData.fluid.capacity = fc:getCapacity()
        newItem:getModData().skoRestoreFluid = itemData.fluid
    end

    if itemData.clothing and instanceof(newItem, "Clothing") then
        local c = itemData.clothing
        if type(newItem.setWetness) == "function" then newItem:setWetness(c.wetness or 0) end
        if type(newItem.setDirtyness) == "function" then newItem:setDirtyness(c.dirtyness or 0) end
        if type(newItem.setBloodLevel) == "function" then newItem:setBloodLevel(c.blood or 0) end
        
        if c.tint and newItem:getVisual() then 
            local visual = newItem:getVisual()
            pcall(function() visual:setTint(ImmutableColor.new(c.tint.r, c.tint.g, c.tint.b, 1)) end)
        end

        for partID, pData in pairs(c.parts or {}) do
            local part = BloodBodyPartType.FromString(partID)
            if part then
                if pData.hole and newItem:getVisual() then 
                    local visual = newItem:getVisual()
                    pcall(function() visual:setHole(part) end)
                end
                if type(newItem.setBlood) == "function" then newItem:setBlood(part, pData.blood or 0) end
            end
        end
    end

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

    if itemData.literature and newItem:getNumberOfPages() > 0 then
        newItem:setAlreadyReadPages(itemData.literature.pages or 0)
    end
    if itemData.mediaID and newItem.setMediaData then
        local mediaData = getZomboidRadio():getRecordedMedia():getMediaDataFromID(itemData.mediaID)
        if mediaData then newItem:setMediaData(mediaData) end
    end

    if itemData.keyId and instanceof(newItem, "Key") then newItem:setKeyId(itemData.keyId) end
    if itemData.device and newItem:getDeviceData() then
        local dd = newItem:getDeviceData()
        if itemData.device.channel then pcall(dd.setChannel, dd, itemData.device.channel) end
        if itemData.device.turnedOn ~= nil then pcall(dd.setIsTurnedOn, dd, itemData.device.turnedOn) end
        if itemData.device.battery then pcall(dd.setBattery, dd, itemData.device.battery) end
    end
    
    if itemData.usedDelta and instanceof(newItem, "DrainableComboItem") then
        if not (itemData.fluid and newItem:getFluidContainer()) then
            if type(newItem.setUsedDelta) == "function" then
                newItem:setUsedDelta(itemData.usedDelta)
            end
        end
    end

    if newItem:IsInventoryContainer() and itemData.inventory then
        local inv = newItem:getInventory()
        for _, innerData in ipairs(itemData.inventory) do
            local innerItem = SKOLib.Serializer.deserializeItemData(innerData)
            if innerItem then inv:AddItem(innerItem) end
        end
    end

    return newItem
end
