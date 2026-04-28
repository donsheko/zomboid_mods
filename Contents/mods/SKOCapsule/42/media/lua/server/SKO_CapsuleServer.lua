if not SKO_Capsule then SKO_Capsule = {} end
SKO_Capsule.DEBUG = false

local function debugLog(msg)
    if SKO_Capsule.DEBUG then
        print("[SKOCapsule-Server] " .. tostring(msg))
    end
end

function SKO_serverCreateItem(itemType)
    local item = nil
    pcall(function() item = InventoryItemFactory.CreateItem(itemType) end)
    if not item then pcall(function() item = instanceItem(itemType) end) end
    return item
end

function SKO_ServerApplyVehicleData(vehicle, vData)
    if not vehicle or not vData then return end
    print("[SKOCapsule-Server] Restaurando vehiculo: " .. tostring(vData.name) .. " | Skin: " .. tostring(vData.skinIndex) .. " | ID: " .. tostring(vData.id))
    
    -- Limpieza total de partes generadas aleatoriamente por el spawn
    for i = 1, vehicle:getPartCount() do
        local part = vehicle:getPartByIndex(i - 1)
        if part then pcall(function() part:setInventoryItem(nil) end) end
    end

    local vModData = vehicle:getModData()
    if vData.modData then
        for k, v in pairs(vData.modData) do vModData[k] = v end
    end

    -- Engine B42
    if vData.engineQuality or vData.enginePower then
        pcall(function()
            local q = vData.engineQuality or vehicle:getEngineQuality()
            local l = vData.engineLoudness or vehicle:getEngineLoudness()
            local p = vData.enginePower or vehicle:getEnginePower()
            vehicle:setEngineFeature(q, l, p)
        end)
    end
    if vData.rust then pcall(function() vehicle:setRust(vData.rust) end) end

    if vData.parts then
        for i = 1, vehicle:getPartCount() do
            local part = vehicle:getPartByIndex(i - 1)
            if part then
                local partId = part:getId()
                local pData = vData.parts[partId]
                
                if pData then
                    if pData.hasItem and pData.itemData then
                        -- Forzamos la reinstalación del ítem para asegurar integridad visual y de estado
                        local newItem = SKOLib.Serializer.deserializeItemData(pData.itemData)
                        if newItem then
                            part:setInventoryItem(newItem)
                            -- Restauración de fluidos diferida (B42)
                            if SKOLib and SKOLib.Serializer and SKOLib.Serializer.applyDeferredRestoration then
                                SKOLib.Serializer.applyDeferredRestoration(newItem)
                            end
                        end
                    else
                        part:setInventoryItem(nil)
                    end
                    pcall(function() part:setCondition(pData.condition or 0) end)

                    -- Part ModData (Mods Support)
                    if pData.modData then
                        local pModData = part:getModData()
                        for k, v in pairs(pData.modData) do pModData[k] = v end
                    end

                    -- Items inside (Trunk, Seats)
                    local container = part:getItemContainer()
                    if container then
                        container:clear()
                        local invData = vData.inventory and vData.inventory[partId]
                        if invData then
                            if invData.capacity then
                                pcall(function() container:setCapacity(invData.capacity) end)
                            end
                            if type(invData.items) == "table" then
                                restoreItemsToContainer(container, invData.items, vehicle:getSquare())
                            end
                        end
                    end
                end
            end
        end
    end

    -- Restoration of Containers (Fuel/Air)
    if vData.fuelTanks then
        for pId, tData in pairs(vData.fuelTanks) do
            local p = vehicle:getPartById(pId)
            if p then
                pcall(function() 
                    if tData.capacity and p.setContainerCapacity then
                        p:setContainerCapacity(tData.capacity)
                    end
                    p:setContainerContentAmount(tData.fuel) 
                end)
            end
        end
    end
    
    local battery = vehicle:getPartById("Battery")
    if battery and vData.batteryCharge then
        local bItem = battery:getInventoryItem()
        if bItem and type(bItem.setCurrentUsesFloat) == "function" then 
            pcall(function() bItem:setCurrentUsesFloat(vData.batteryCharge) end)
        end
    end

    pcall(function() vehicle:setHotwired(vData.hotwired == true) end)
    pcall(function() vehicle:setKeysInIgnition(vData.hasKey == true) end)
    pcall(function() vehicle:setTrunkLocked(vData.trunkLocked == true) end)
    if vData.keyId then pcall(function() vehicle:setKeyId(vData.keyId) end) end

    -- APLICACIÓN FINAL DE COLOR Y SKIN (Posterior a las piezas)
    pcall(function()
        local visual = nil
        if vehicle.getVisual and type(vehicle.getVisual) == "function" then visual = vehicle:getVisual() 
        elseif vehicle.getVehicleVisual and type(vehicle.getVehicleVisual) == "function" then visual = vehicle:getVehicleVisual() end

        if vData.color then
            print("[SKOCapsule-Server] Restaurando Color HSV (Vehicle): " .. tostring(vData.color.h) .. "," .. tostring(vData.color.s) .. "," .. tostring(vData.color.v))
            vehicle:setColorHSV(vData.color.h, vData.color.s, vData.color.v)
        end
        if vData.colorRGB and vehicle.setColor then
            print("[SKOCapsule-Server] Restaurando Color RGB (Vehicle): " .. tostring(vData.colorRGB.r) .. "," .. tostring(vData.colorRGB.g) .. "," .. tostring(vData.colorRGB.b))
            vehicle:setColor(ImmutableColor.new(vData.colorRGB.r, vData.colorRGB.g, vData.colorRGB.b, 1))
        end
        if vData.colorIndex and vehicle.setColorIndex then
            print("[SKOCapsule-Server] Restaurando Color Index: " .. tostring(vData.colorIndex))
            vehicle:setColorIndex(vData.colorIndex)
        end

        -- SkinIndex es autoritativo en el vehículo
        if vData.skinIndex then 
            print("[SKOCapsule-Server] Restaurando SkinIndex: " .. tostring(vData.skinIndex))
            if vehicle.setSkinIndex then 
                vehicle:setSkinIndex(vData.skinIndex) 
            end
            if visual and visual.setSkinIndex then 
                visual:setSkinIndex(vData.skinIndex) 
            end
            if vehicle.updateSkin then vehicle:updateSkin() end
        end

        -- VisualData (Propiedades internas del objeto visual)
        if visual and vData.visualData then
            print("[SKOCapsule-Server] Restaurando VisualData: H=" .. tostring(vData.visualData.hue) .. " S=" .. tostring(vData.visualData.saturation) .. " V=" .. tostring(vData.visualData.value))
            if visual.setHue then visual:setHue(vData.visualData.hue) end
            if visual.setSaturation then visual:setSaturation(vData.visualData.saturation) end
            if visual.setValue then visual:setValue(vData.visualData.value) end
            if vData.visualData.tint and visual.setTint then
                visual:setTint(ImmutableColor.new(vData.visualData.tint.r, vData.visualData.tint.g, vData.visualData.tint.b, 1))
            end
        end
    end)

    if vehicle.updatePartModels then pcall(function() vehicle:updatePartModels() end)
    elseif vehicle.updateVisuals then pcall(function() vehicle:updateVisuals() end) end
end

function restoreItemsToContainer(container, items, square)
    if not items or type(items) ~= "table" then return end
    for _, itemData in ipairs(items) do
        if itemData.fullType then
            local ok, item = pcall(SKOLib.Serializer.deserializeItemData, itemData)
            if ok and item then
                container:AddItem(item)
                -- Restauración de fluidos diferida (B42)
                if SKOLib and SKOLib.Serializer and SKOLib.Serializer.applyDeferredRestoration then
                    SKOLib.Serializer.applyDeferredRestoration(item)
                end
            else
                -- Fallback: Muebles recogibles de B42 que no pueden instanciarse como items
                local spriteName = itemData.worldSprite or (itemData.fullType and itemData.fullType:match("%.(.+)$"))
                if spriteName and square then
                    pcall(function()
                        local dummyItem = instanceItem("Base.Plank")
                        local props = ISMoveableSpriteProps.new(spriteName)
                        if props and props.isMoveable then
                            props:placeMoveableInternal(square, dummyItem, spriteName)
                        end
                    end)
                end
            end
        end
    end
end

SKO_Capsule.OnClientCommand = function(module, command, player, args)
    if module == "SKO_Capsule" then
        if command == "removeVehicle" then
            local vehicle = getVehicleById(args.vehicleId)
            if vehicle then vehicle:permanentlyRemove() end
        elseif command == "spawnVehicle" then
            local sq = getCell():getGridSquare(args.x, args.y, args.z)
            local vehicle = addVehicleDebug(args.name, args.dir, 0, sq)
            if vehicle then
                print("[SKOCapsule-Server] Vehiculo spawneado: " .. tostring(vehicle:getId()) .. ". Iniciando restauración diferida (60 ticks)...")
                
                -- Restauración diferida reforzada (60 ticks = ~1s)
                local ticks = 0
                local function onSpawnTick()
                    ticks = ticks + 1
                    if ticks >= 60 then
                        SKO_ServerApplyVehicleData(vehicle, args.data)
                        sendServerCommand(player, "SKO_Capsule", "doRestore", { 
                            vehicleIdStr = tostring(vehicle:getId()), 
                            data = args.data, 
                            itemId = args.itemId 
                        })
                        Events.OnTick.Remove(onSpawnTick)
                        print("[SKOCapsule-Server] Restauración diferida completada para ID: " .. tostring(vehicle:getId()))
                    end
                end
                Events.OnTick.Add(onSpawnTick)
            end
        end
    end
end

Events.OnClientCommand.Add(SKO_Capsule.OnClientCommand)
