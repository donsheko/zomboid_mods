if not SKO_Capsule then SKO_Capsule = {} end
SKO_Capsule.DEBUG = false

SKO_Capsule.CAPSULE_TYPE = "SKOCapsule.ContenedorVehiculos"
-- Idempotencia MP: solo una restauración pendiente por jugador
SKO_Capsule.pendingRestore = {}

local function debugLog(msg)
    if SKO_Capsule.DEBUG then
        print("[SKOCapsule-Server] " .. tostring(msg))
    end
end

-- Consume exactamente 1 cápsula del inventario del jugador (autoritativo server-side).
-- Devuelve true solo si existía y fue eliminada correctamente.
function SKO_Capsule.consumeCapsule(player)
    if not player then return false end
    local capsule = player:getInventory():getFirstTypeRecurse(SKO_Capsule.CAPSULE_TYPE)
    if not capsule then
        debugLog("Consumo de cápsula: no encontrada en el inventario del jugador.")
        return false
    end
    local ok = pcall(function() player:getInventory():Remove(capsule) end)
    if not ok then
        print("[SKOCapsule-Server] Error al consumir cápsula del inventario del jugador.")
        return false
    end
    debugLog("Cápsula consumida del inventario del jugador.")
    return true
end

-- Crea y añade exactamente 1 cápsula al inventario del jugador (autoritativo server-side).
-- Devuelve el item creado o nil si falló.
function SKO_Capsule.giveCapsule(player)
    if not player then return nil end
    local ok, item = pcall(function()
        return player:getInventory():AddItem(SKO_Capsule.CAPSULE_TYPE)
    end)
    if not ok or not item then
        print("[SKOCapsule-Server] Error al crear cápsula para el jugador.")
        return nil
    end
    debugLog("Cápsula entregada al inventario del jugador.")
    return item
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
    if module ~= "SKO_Capsule" then return end

    if command == "removeVehicle" then
        -- SUBIDA (MP): el servidor valida la cápsula, elimina el vehículo y consume
        -- de forma autoritativa. Solo se consume si la eliminación fue exitosa.
        local vehicleId = args and args.vehicleId
        local dataId = args and args.dataId or nil
        local vehicle = getVehicleById(vehicleId)

        if not vehicle then
            debugLog("removeVehicle: vehículo no encontrado. No se consume cápsula.")
            sendServerCommand(player, "SKO_Capsule", "vehicleRemoved", { ok = false, dataId = dataId })
            return
        end

        -- El jugador debe tener cápsula ANTES de eliminar el vehículo (evita pérdida sin compensación)
        local capsule = player:getInventory():getFirstTypeRecurse(SKO_Capsule.CAPSULE_TYPE)
        if not capsule then
            debugLog("removeVehicle: jugador sin cápsula. No se elimina el vehículo.")
            sendServerCommand(player, "SKO_Capsule", "vehicleRemoved", { ok = false, dataId = dataId })
            return
        end

        local removedOk = pcall(function() vehicle:permanentlyRemove() end)
        if removedOk then
            local consumed = SKO_Capsule.consumeCapsule(player)
            print("[SKOCapsule-Server] Vehiculo " .. tostring(vehicleId) .. " eliminado. Cápsula consumida: " .. tostring(consumed))
            sendServerCommand(player, "SKO_Capsule", "vehicleRemoved", { ok = true, dataId = dataId })
        else
            print("[SKOCapsule-Server] Error al eliminar el vehículo. No se consume cápsula.")
            sendServerCommand(player, "SKO_Capsule", "vehicleRemoved", { ok = false, dataId = dataId })
        end

    elseif command == "spawnVehicle" then
        -- RESTAURACIÓN (MP): spawn + aplicación de datos; la cápsula se devuelve SOLO
        -- tras confirmar spawn y aplicación exitosos. El cliente retira la entrada al
        -- recibir "doRestore"; en caso de fallo recibe "restoreFailed" y la conserva.
        if not args or not args.data or not args.data.id or not args.name then
            debugLog("spawnVehicle ignorado: argumentos incompletos.")
            sendServerCommand(player, "SKO_Capsule", "restoreFailed", { ok = false })
            return
        end
        local username = player:getUsername()
        if SKO_Capsule.pendingRestore[username] then
            debugLog("spawnVehicle ignorado: restauración ya en curso para " .. tostring(username))
            return
        end
        SKO_Capsule.pendingRestore[username] = true

        local sq = getCell():getGridSquare(args.x, args.y, args.z)
        local vehicle = addVehicleDebug(args.name, args.dir, 0, sq)
        if not vehicle then
            SKO_Capsule.pendingRestore[username] = nil
            sendServerCommand(player, "SKO_Capsule", "restoreFailed", { ok = false })
            print("[SKOCapsule-Server] spawnVehicle fallido: no se pudo crear el vehículo.")
            return
        end

        print("[SKOCapsule-Server] Vehiculo spawneado: " .. tostring(vehicle:getId()) .. ". Iniciando restauración diferida (60 ticks)...")
        
        local ticks = 0
        local function onSpawnTick()
            ticks = ticks + 1
            if ticks >= 60 then
                Events.OnTick.Remove(onSpawnTick)
                SKO_Capsule.pendingRestore[username] = nil

                local appliedOk = pcall(function() SKO_ServerApplyVehicleData(vehicle, args.data) end)
                if appliedOk and vehicle then
                    -- Confirmación de spawn + aplicación: devolvemos la cápsula
                    local given = SKO_Capsule.giveCapsule(player)
                    print("[SKOCapsule-Server] Restauración diferida completada para ID: " .. tostring(vehicle:getId()) .. ". Cápsula devuelta: " .. tostring(given ~= nil))
                    sendServerCommand(player, "SKO_Capsule", "doRestore", { 
                        vehicleIdStr = tostring(vehicle:getId()), 
                        data = args.data
                    })
                else
                    -- Fallo de aplicación: no devolver cápsula; conservar la entrada en la
                    -- nube del cliente y eliminar el vehículo a medio restaurar (evita duplicados)
                    pcall(function() vehicle:permanentlyRemove() end)
                    print("[SKOCapsule-Server] Error aplicando datos del vehículo. Vehículo eliminado; entrada conservada.")
                    sendServerCommand(player, "SKO_Capsule", "restoreFailed", { ok = false })
                end
            end
        end
        Events.OnTick.Add(onSpawnTick)
    end
end

Events.OnClientCommand.Add(SKO_Capsule.OnClientCommand)
