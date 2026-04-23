if not SKO_CapsuleClient then SKO_CapsuleClient = {} end

-- Global helpers
function SKO_getCapsuleData()
    local modData = getPlayer():getModData()
    if not modData.skoCapsuleCloud then modData.skoCapsuleCloud = {} end
    return modData.skoCapsuleCloud
end

function SKO_setCapsuleData(data)
    local modData = getPlayer():getModData()
    modData.skoCapsuleCloud = data
end

function SKO_copyTable(ori)
    if type(ori) ~= "table" then return ori end
    local res = {}
    for k, v in pairs(ori) do res[k] = SKO_copyTable(v) end
    return res
end

function SKO_getVehicleVisual(vehicle)
    if vehicle.getVisual and type(vehicle.getVisual) == "function" then return vehicle:getVisual() end
    if vehicle.getVehicleVisual and type(vehicle.getVehicleVisual) == "function" then return vehicle:getVehicleVisual() end
    return nil
end

function SKO_createItem(itemType)
    if not itemType then return nil end
    local item = nil
    if InventoryItemFactory then
        pcall(function() item = InventoryItemFactory.CreateItem(itemType) end)
    end
    if not item and instanceItem then
        pcall(function() item = instanceItem(itemType) end)
    end
    return item
end

-- MAIN LOGIC
function storeVehicleInContainer(vehicle, itemEquiped)
    local storedVehicles = SKO_getCapsuleData()
    local id = vehicle:getScript():getName() .. vehicle:getID() .. "_" .. os.time()
    
    local capturedSkinIndex = 0
    local visual = SKO_getVehicleVisual(vehicle)
    if visual and visual.getSkinIndex then
        pcall(function() capturedSkinIndex = visual:getSkinIndex() end)
    end

    local vehicleData = {
        id = id,
        name = vehicle:getScript():getName(),
        parts = {},
        inventory = {},
        fuelTanks = {},
        hasKey = vehicle:isKeysInIgnition(),
        hotwired = vehicle:isHotwired(),
        keyId = vehicle:getKeyId(),
        trunkLocked = vehicle:isTrunkLocked(),
        batteryCharge = 0,
        engineQuality = vehicle:getEngineQuality(),
        engineLoudness = vehicle:getEngineLoudness(),
        enginePower = vehicle:getEnginePower(),
        rust = vehicle:getRust(),
        color = { h = vehicle:getColorHue(), s = vehicle:getColorSaturation(), v = vehicle:getColorValue() },
        skinIndex = capturedSkinIndex,
        doors = {},
        windows = {},
        modData = SKO_copyTable(vehicle:getModData())
    }

    for i = 1, vehicle:getPartCount() do
        local part = vehicle:getPartByIndex(i - 1)
        if part then
            local partId = part:getId()
            local invItem = part:getInventoryItem()
            
            vehicleData.parts[partId] = {
                condition = part:getCondition(),
                hasItem = invItem ~= nil,
                itemType = invItem and invItem:getFullType() or nil,
                itemModData = invItem and SKO_copyTable(invItem:getModData()) or nil
            }

            -- Items inside (Trunk, Seats)
            local container = part:getItemContainer()
            if container then
                local capacity = container:getCapacity()
                local inventario = { capacity = capacity, items = {} }
                for j = 0, container:getItems():size() - 1 do
                    local it = container:getItems():get(j)
                    if it then table.insert(inventario.items, SKOLib.Serializer.serializeItemData(it)) end
                end
                vehicleData.inventory[partId] = inventario
            end
            
            -- Fluids (Fuel, Tire Air)
            if part:isContainer() and part:getContainerContentType() then
                local cap = part:getContainerCapacity()
                if cap > 0 then
                    vehicleData.fuelTanks[partId] = {
                        fuel = part:getContainerContentAmount(),
                        capacity = cap,
                        type = part:getContainerContentType()
                    }
                end
            end

            -- Battery
            if partId == "Battery" and invItem then 
                if type(invItem.getCurrentUsesFloat) == "function" then vehicleData.batteryCharge = invItem:getCurrentUsesFloat()
                elseif type(invItem.getUsedDelta) == "function" then vehicleData.batteryCharge = 1 - invItem:getUsedDelta() end
            end
            
            local door = part:getDoor()
            if door then vehicleData.doors[partId] = { isOpen = door:isOpen(), isLocked = door:isLocked() } end
            local window = part:getWindow()
            if window then vehicleData.windows[partId] = { isOpen = window:isOpen() } end
        end
    end

    storedVehicles[id] = vehicleData
    SKO_setCapsuleData(storedVehicles)
    
    if isClient() then
        sendClientCommand(getPlayer(), "SKO_Capsule", "removeVehicle", { vehicleId = vehicle:getId() })
    else
        vehicle:permanentlyRemove()
    end
end

function SKO_applyVehicleData(vehicle, vData)
    if not vehicle or not vData then return end
    
    local vModData = vehicle:getModData()
    if vData.modData then
        for k, v in pairs(vData.modData) do vModData[k] = v end
    end

    pcall(function()
        vehicle:setColorHSV(vData.color.h, vData.color.s, vData.color.v)
        local visual = SKO_getVehicleVisual(vehicle)
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
                    if pData.hasItem and pData.itemType then
                        local existing = part:getInventoryItem()
                        if not existing or existing:getFullType() ~= pData.itemType then
                            local newItem = SKO_createItem(pData.itemType)
                            if newItem then
                                pcall(function() newItem:setCondition(pData.condition or 0) end)
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
                    pcall(function() part:setCondition(pData.condition or 0) end)

                    -- Items inside
                    local container = part:getItemContainer()
                    if container then
                        container:clear()
                        local invData = vData.inventory and vData.inventory[partId]
                        if invData then
                            if invData.capacity then
                                pcall(function() container:setCapacity(invData.capacity) end)
                            end
                            if type(invData.items) == "table" then
                                restoreItemsToContainer(container, invData.items)
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

    if vehicle.updatePartModels then pcall(function() vehicle:updatePartModels() end)
    elseif vehicle.updateVisuals then pcall(function() vehicle:updateVisuals() end) end
end

function restoreVehicle(vehicleData, itemEquiped)
    if not vehicleData then return end
    local player = getPlayer()
    local x, y, z = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    local sq = getCell():getGridSquare(x, y, z)
    if z > 0 or not sq or sq:getRoom() or not sq:isOutside() then player:Say("Espacio bloqueado.") return end

    if isClient() then
        sendClientCommand(getPlayer(), "SKO_Capsule", "spawnVehicle", { 
            name = vehicleData.name, dir = player:getDir(), status = 0, 
            x = x, y = y, z = z, data = vehicleData, itemId = itemEquiped:getID() 
        })
        return
    end

    local vehicle = addVehicleDebug(vehicleData.name, player:getDir(), 0, sq)
    if vehicle then
        SKO_applyVehicleData(vehicle, vehicleData)
        local stored = SKO_getCapsuleData()
        stored[vehicleData.id] = nil
        SKO_setCapsuleData(stored)
    end
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

-- UTILS
SKO_CapsuleClient.getCapsuleFromInventory = function(player)
    local inv = player:getInventory()
    return inv:getFirstTypeRecurse("SKOCapsule.ContenedorVehiculos")
end

SKO_CapsuleClient.openCloudUI = function()
    local player = getPlayer()
    
    -- Toggle logic: Si ya existe una instancia, la cerramos
    if SKO_CapsuleCloudUI.instance then
        SKO_CapsuleCloudUI.instance:close()
        return
    end

    local capsule = SKO_CapsuleClient.getCapsuleFromInventory(player)
    if not capsule then
        player:Say("Necesito tener la Capsula en mi inventario para acceder a la Red Cloud.")
        return
    end

    local ui = SKO_CapsuleCloudUI:new(200, 200, 800, 500)
    ui:initialise()
    ui:addToUIManager()
end

-- EVENTS
function SKO_CapsuleClient.OnFillWorldObjectContextMenu(player, context, worldobjects)
    local jugador = getPlayer()
    local capsule = SKO_CapsuleClient.getCapsuleFromInventory(jugador)
    if not capsule then return end

    local vehicle = nil
    for _, v in ipairs(worldobjects) do
        if v and v:getSquare() then
            vehicle = v:getSquare():getVehicleContainer()
            if vehicle then break end
        end
    end

    if vehicle then
        context:addOption("Subir a la Nube (SKO)", vehicle, function() storeVehicleInContainer(vehicle, capsule) end)
    end
end

function SKO_CapsuleClient.OnKeyPressed(key)
    if key == Keyboard.KEY_NUMPAD3 then
        if getCore():isKey("Chat") then return end
        SKO_CapsuleClient.openCloudUI()
    end
end

function SKO_CapsuleClient.OnServerCommand(module, command, args)
    if module == "SKO_Capsule" and command == "doRestore" then
        local vehicle = getVehicleById(tonumber(tostring(args.vehicleIdStr)))
        if vehicle then
            SKO_applyVehicleData(vehicle, args.data)
            local stored = SKO_getCapsuleData()
            stored[args.data.id] = nil
            SKO_setCapsuleData(stored)
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(SKO_CapsuleClient.OnFillWorldObjectContextMenu)
Events.OnKeyPressed.Add(SKO_CapsuleClient.OnKeyPressed)
Events.OnServerCommand.Add(SKO_CapsuleClient.OnServerCommand)