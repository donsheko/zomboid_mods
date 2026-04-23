if not SKO_Capsule then SKO_Capsule = {} end

function SKO_serverCreateItem(itemType)
    local item = nil
    if getInventoryItemFactory and type(getInventoryItemFactory) == "function" then
        pcall(function() item = getInventoryItemFactory():createItem(itemType) end)
    end
    if item then return item end
    if instanceItem and type(instanceItem) == "function" then
        pcall(function() item = instanceItem(itemType) end)
    end
    if item then return item end
    if InventoryItemFactory and InventoryItemFactory.CreateItem then
        pcall(function() item = InventoryItemFactory.CreateItem(itemType) end)
    end
    return item
end

function SKO_ServerApplyVehicleData(vehicle, vData)
    if not vehicle or not vData then return end
    print("[SKOCapsule Server] Restaurando vehiculo: " .. vData.name)

    local vModData = vehicle:getModData()
    if vData.modData then
        for k, v in pairs(vData.modData) do vModData[k] = v end
    end

    pcall(function()
        vehicle:setColorHSV(vData.color.h, vData.color.s, vData.color.v)
        local visual = nil
        if vehicle.getVisual and type(vehicle.getVisual) == "function" then visual = vehicle:getVisual() 
        elseif vehicle.getVehicleVisual and type(vehicle.getVehicleVisual) == "function" then visual = vehicle:getVehicleVisual() end
        if visual and vData.skinIndex and visual.setSkinIndex then visual:setSkinIndex(vData.skinIndex) end
    end)

    if vData.engineQuality then vehicle:setEngineQuality(vData.engineQuality) end
    if vData.engineLoudness then vehicle:setEngineLoudness(vData.engineLoudness) end
    if vData.rust then vehicle:setRust(vData.rust) end

    if vData.parts then
        for i = 1, vehicle:getPartCount() do
            local part = vehicle:getPartByIndex(i - 1)
            if part then
                local partId = part:getId()
                local pData = vData.parts[partId]
                
                if pData then
                    if pData.serializedItem then
                        local newItem = SKOLib.Serializer.deserializeItemData(pData.serializedItem)
                        if newItem then part:setInventoryItem(newItem) end
                    else
                        part:setInventoryItem(nil)
                    end
                    part:setCondition(pData.condition or 0)
                else
                    part:setInventoryItem(nil)
                end

                -- Limpieza autoritaria de maleteros (MANTENIDO: Funciona bien)
                local container = part:getItemContainer()
                if container then
                    container:clear()
                    local invData = vData.inventory and vData.inventory[partId]
                    if invData and invData.items then
                        for _, itemData in ipairs(invData.items) do
                            local item = SKOLib.Serializer.deserializeItemData(itemData)
                            if item then container:AddItem(item) end
                        end
                    end
                end
            end
        end
    end

    -- Restauracion de Tanques de Combustible (Multi-tanque)
    if vData.fuelTanks then
        for pId, tData in pairs(vData.fuelTanks) do
            local p = vehicle:getPartById(pId)
            if p then
                pcall(function() 
                    p:setContainerCapacity(tData.capacity) 
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

    vehicle:setHotwired(vData.hotwired == true)
    vehicle:setKeysInIgnition(vData.hasKey == true)
    vehicle:setTrunkLocked(vData.trunkLocked == true)
    if vData.keyId then vehicle:setKeyId(vData.keyId) end

    vehicle:transmitUpdatedFields()
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
                SKO_ServerApplyVehicleData(vehicle, args.data)
                sendServerCommand(player, "SKO_Capsule", "doRestore", { 
                    vehicleIdStr = tostring(vehicle:getId()), 
                    data = args.data, 
                    itemId = args.itemId 
                })
            end
        end
    end
end

Events.OnClientCommand.Add(SKO_Capsule.OnClientCommand)
