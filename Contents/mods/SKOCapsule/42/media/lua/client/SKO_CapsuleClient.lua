require "Vehicles/ISUI/ISVehicleMenu"
require "UI/SKO_CapsuleCloudUI"

if not SKO_CapsuleClient then SKO_CapsuleClient = {} end

function SKO_initCapsuleData()
    local player = getPlayer()
    local modData = player:getModData()
    if not modData.storedVehicles then modData.storedVehicles = {} end
end

function SKO_getCapsuleData()
    SKO_initCapsuleData()
    return getPlayer():getModData().storedVehicles
end

function SKO_setCapsuleData(data)
    local player = getPlayer()
    player:getModData().storedVehicles = data
end

function SKO_copyTable(t, _depth)
    if not t or type(t) ~= 'table' then return t end
    _depth = (_depth or 0) + 1
    if _depth > 10 then return nil end
    local res = {}
    for k, v in pairs(t) do
        local vt = type(v)
        if vt == 'table' then
            res[k] = SKO_copyTable(v, _depth)
        elseif vt == 'string' or vt == 'number' or vt == 'boolean' then
            res[k] = v
        end
    end
    return res
end

function SKO_getVehicleVisual(vehicle)
    if not vehicle then return nil end
    local visual = nil
    if vehicle.getVisual and type(vehicle.getVisual) == "function" then
        pcall(function() visual = vehicle:getVisual() end)
    end
    if not visual and vehicle.getVehicleVisual and type(vehicle.getVehicleVisual) == "function" then
        pcall(function() visual = vehicle:getVehicleVisual() end)
    end
    return visual
end

function SKO_createItem(itemType)
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

function storeVehicleInContainer(vehicle, itemEquiped)
    local storedVehicles = SKO_getCapsuleData()
    local id = vehicle:getScript():getName() .. vehicle:getID()
    
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
        fuel = 0,
        fuelCapacity = 0,
        hasKey = vehicle:isKeysInIgnition(),
        hotwired = vehicle:isHotwired(),
        keyId = vehicle:getKeyId(),
        trunkLocked = vehicle:isTrunkLocked(),
        batteryCharge = 0,
        fuelTanks = {},
        engineQuality = vehicle:getEngineQuality(),
        engineLoudness = vehicle:getEngineLoudness(),
        rust = vehicle:getRust(),
        color = { h = vehicle:getColorHue(), s = vehicle:getColorSaturation(), v = vehicle:getColorValue() },
        doors = {},
        windows = {},
        skinIndex = capturedSkinIndex,
        modData = SKO_copyTable(vehicle:getModData())
    }

    print("[SKOCapsule] Capturando vehiculo: " .. vehicleData.name)

    for i = 1, vehicle:getPartCount() do
        local part = vehicle:getPartByIndex(i - 1)
        if part then
            local partId = part:getId()
            local invItem = part:getInventoryItem()
            
            vehicleData.parts[partId] = {
                condition = part:getCondition(),
                serializedItem = invItem and SKOLib.Serializer.serializeItemData(invItem) or nil
            }

            local container = part:getItemContainer()
            if container then 
                vehicleData.inventory[partId] = processVehicleInventory(container, partId) 
                local cap = container:getCapacity()
                if cap > 0 then
                    vehicleData.fuelTanks[partId] = {
                        fuel = container:getContentAmount(),
                        capacity = cap
                    }
                end
            end
            
            if partId == "Battery" and invItem then 
                local batCharge = 0
                if type(invItem.getCurrentUsesFloat) == "function" then 
                    batCharge = invItem:getCurrentUsesFloat()
                elseif type(invItem.getUsedDelta) == "function" then 
                    batCharge = 1 - invItem:getUsedDelta() -- Invertir delta consumido
                end
                vehicleData.batteryCharge = batCharge
            end
            local door = part:getDoor()
            if door then vehicleData.doors[partId] = { isOpen = door:isOpen(), isLocked = door:isLocked() } end
            local window = part:getWindow()
            if window then vehicleData.windows[partId] = { isOpen = window:isOpen() } end
        end
    end

    storedVehicles[id] = vehicleData
    SKO_setCapsuleData(storedVehicles)
    itemEquiped:setName("Contenedor de vehiculos") -- Mantener nombre genérico para la nube

    if isClient() then
        sendClientCommand(getPlayer(), "SKO_Capsule", "removeVehicle", { vehicleId = vehicle:getId() })
    else
        vehicle:permanentlyRemove()
    end
end

function processVehicleInventory(container, partId)
    local capacity = container:getCapacity()
    local inventario = { capacity = capacity, items = {} }
    for j = 0, container:getItems():size() - 1 do
        local item = container:getItems():get(j)
        if item then table.insert(inventario.items, SKOLib.Serializer.serializeItemData(item)) end
    end
    return inventario
end

function SKO_applyVehicleData(vehicle, vData)
    if not vehicle or not vData then return end
    print("[SKOCapsule] Restaurando datos: " .. vData.name)

    local vModData = vehicle:getModData()
    if vData.modData then
        for k, v in pairs(vData.modData) do vModData[k] = v end
    end

    pcall(function()
        vehicle:setColorHSV(vData.color.h, vData.color.s, vData.color.v)
        local visual = SKO_getVehicleVisual(vehicle)
        if visual and vData.skinIndex and visual.setSkinIndex then
            visual:setSkinIndex(vData.skinIndex)
        end
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

                local container = part:getItemContainer()
                if container then
                    container:clear()
                    local invData = vData.inventory and vData.inventory[partId]
                    if invData and invData.items then restoreItemsToContainer(container, invData.items) end
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
        itemEquiped:setName("Contenedor de vehiculos")
        local stored = SKO_getCapsuleData()
        stored[vehicleData.id] = nil
        SKO_setCapsuleData(stored)
    end
end

function restoreItemsToContainer(container, items)
    for _, itemData in ipairs(items) do
        if itemData.fullType then
            local item = SKOLib.Serializer.deserializeItemData(itemData)
            if item then container:AddItem(item) end
        end
    end
end

function createRestoreButton(context, vehicleData, itemEquiped)
    context:addOption("Restaurar: " .. vehicleData.name, nil, function() restoreVehicle(vehicleData, itemEquiped) end)
end

function AgregarOpcionVehiculo(player, context, worldobjects)
    local jugador = getPlayer()
    local capsule = SKO_CapsuleClient.getCapsuleFromInventory(jugador)
    if not capsule then return end

    for _,v in ipairs(worldobjects) do
        if v and v:getSquare() and v:getSquare():getVehicleContainer() then
            local vehicle = v:getSquare():getVehicleContainer()
            context:addOption("Encapsular: " .. vehicle:getScript():getName(), player, function() storeVehicleInContainer(vehicle, capsule) end)
            break
        end
    end
end

function OnServerCommand(module, command, args)
    if module == "SKO_Capsule" and command == "doRestore" then
        local vehicle = getVehicleById(tonumber(tostring(args.vehicleIdStr)))
        if vehicle then
            local p = getPlayer()
            local itemEquiped = p:getInventory():getItemById(tonumber(args.itemId)) or p:getSecondaryHandItem()
            if itemEquiped then
                SKO_applyVehicleData(vehicle, args.data)
                itemEquiped:setName("Contenedor de vehiculos")
                local stored = SKO_getCapsuleData()
                stored[args.data.id] = nil
                SKO_setCapsuleData(stored)
            end
        end
    end
end

function SKO_CapsuleClient.getCapsuleFromInventory(player)
    local inv = player:getInventory()
    if not inv then return nil end
    return inv:getFirstTypeRecurse("SKOCapsule.ContenedorVehiculos")
end

function SKO_CapsuleClient.playerHasCapsule(player)
    return SKO_CapsuleClient.getCapsuleFromInventory(player) ~= nil
end

function SKO_CapsuleClient.onKeyStartPressed(key)
    if key == Keyboard.KEY_NUMPAD3 then
        local ok, gui = pcall(getCore().getGameGui, getCore())
        if ok and gui and (gui:isTypeing() or gui:isSearching()) then return end

        local player = getPlayer()
        if not player or player:isDead() then return end

        if SKO_CapsuleClient.playerHasCapsule(player) then
            SKO_CapsuleClient.openCloudUI()
        else
            player:setHaloNote("Necesitas una cápsula de vehículos", 255, 255, 255, 300)
        end
    end
end

function SKO_CapsuleClient.openCloudUI()
    if not SKO_CapsuleCloudUI then
        print("[SKOCapsule] Error: SKO_CapsuleCloudUI no cargado.")
        return
    end
    
    if SKO_CapsuleCloudUI.instance then
        SKO_CapsuleCloudUI.instance:close()
        return
    end

    local ui = SKO_CapsuleCloudUI:new(200, 200, 800, 500)
    ui:initialise()
    ui:addToUIManager()
end

Events.OnKeyStartPressed.Add(SKO_CapsuleClient.onKeyStartPressed)

Events.OnServerCommand.Add(OnServerCommand)
Events.OnFillWorldObjectContextMenu.Add(AgregarOpcionVehiculo)