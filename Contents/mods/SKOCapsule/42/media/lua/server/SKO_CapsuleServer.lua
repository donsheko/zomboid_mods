if not SKO_Capsule then SKO_Capsule = {} end

function SKO_serverCreateItem(itemType)
    local item = nil
    pcall(function() item = InventoryItemFactory.CreateItem(itemType) end)
    if not item then pcall(function() item = instanceItem(itemType) end) end
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
                    part:setCondition(pData.condition or 0)
                    if pData.hasItem and pData.itemType then
                        local existing = part:getInventoryItem()
                        if not existing or existing:getFullType() ~= pData.itemType then
                            local newItem = SKO_serverCreateItem(pData.itemType)
                            if newItem then
                                if pData.itemModData then
                                    local imd = newItem:getModData()
                                    for k,v in pairs(pData.itemModData) do imd[k] = v end
                                end
                                part:setInventoryItem(newItem)
                            end
                        end
                    else
                        part:setInventoryItem(nil)
                    end

                    -- Items inside (Trunk, Seats)
                    local container = part:getItemContainer()
                    if container then
                        container:clear()
                        local invData = vData.inventory and vData.inventory[partId]
                        if invData and type(invData.items) == "table" then
                            restoreItemsToContainer(container, invData.items)
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

    vehicle:transmitUpdatedFields()
end

function restoreItemsToContainer(container, items)
    if not items or type(items) ~= "table" then return end
    for _, itemData in ipairs(items) do
        if itemData.fullType then
            local item = nil
            if SKOLib and SKOLib.Serializer then
                item = SKOLib.Serializer.deserializeItemData(itemData)
            end
            if item then container:AddItem(item) end
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
