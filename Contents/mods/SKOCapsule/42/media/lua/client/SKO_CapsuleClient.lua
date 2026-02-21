require "Vehicles/ISUI/ISVehicleMenu"

function initModData()
    local player = getPlayer()
    local modData = player:getModData()
    if not modData.storedVehicles then
        modData.storedVehicles = {}
    end
end

function getModData()
    initModData()
    return getPlayer():getModData().storedVehicles
end

function setModData(data)
    local player = getPlayer()
    player:getModData().storedVehicles = data
end

function storeVehicleInContainer(vehicle, itemEquiped)
    local storedVehicles = getModData()
    local id = vehicle:getScript():getName() .. vehicle:getID()
    -- Crear una tabla para almacenar los datos del vehículo
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
        color = {
            h = vehicle:getColorHue(),
            s = vehicle:getColorSaturation(),
            v = vehicle:getColorValue()
        },
        doors = {},
        windows = {},
    }

    print("Guardando vehiculo: " .. vehicle:getScript():getFullName())

    -- Cambiar el nombre del itemEquiped a "Contenedor de vehiculos"
    itemEquiped:setName("Contenedor vehiculo:" .. vehicleData.id)

    -- Almacenar los datos de cada parte del vehículo
    for i = 1, vehicle:getPartCount() do
        local part = vehicle:getPartByIndex(i - 1)
        local partId = part:getId()
        if part then
            -- Almacenar el inventario del vehículo
            local container = part:getItemContainer()
            if container then
                vehicleData.inventory[partId] = processVehicleInventory(container, partId)
            end

            -- Almacenar la capacidad y contenido del tanque de gasolina
            if part:getId() == "GasTank" then
                vehicleData.fuelCapacity = part:getContainerCapacity()
                vehicleData.fuel = part:getContainerContentAmount()
            end

            -- Almacenar la carga de la batería
            if part:getId() == "Battery" then
                local battery = part:getInventoryItem()
                if battery then
                    vehicleData.batteryCharge = battery:getCurrentUsesFloat()
                end
            end

            -- Almacenar la condición de la parte del vehículo
            vehicleData.parts[part:getId()] = {
                condition = part:getCondition(),
                hasItem = part:getInventoryItem() ~= nil,
                item = part:getInventoryItem()
            }

            -- Almacenar estado de puertas
            local door = part:getDoor()
            if door then
                vehicleData.doors[partId] = {
                    isOpen = door:isOpen(),
                    isLocked = door:isLocked(),
                }
            end

            -- Almacenar estado de ventanas
            local window = part:getWindow()
            if window then
                vehicleData.windows[partId] = {
                    isOpen = window:isOpen(),
                }
            end
        end
    end

    -- Almacenar los datos del vehículo en el ModData del jugador
    storedVehicles[id] = vehicleData
    setModData(storedVehicles)

    -- Eliminar el vehículo del mapa
    if isClient() then
        sendClientCommand(getPlayer(), "SKO_Capsule", "removeVehicle", { vehicleId = vehicle:getId() })
    else
        vehicle:permanentlyRemove()
    end
end

function processVehicleInventory(container, partId)
    local capacity = container:getCapacity()
    local inventario = {
        capacity = capacity,
        items = {}
    }

    for j = 0, container:getItems():size() - 1 do
        local item = container:getItems():get(j)
        inventario.items[j+1] = {
            type = item:getFullType(),
            condition = item:getCondition(),
            customData = getItemCustomData(item),
            inventario = {}
        }

        if item:IsInventoryContainer() then
            inventario.items[j+1].inventario = processInventoryContainer(item)
        end
    end
    return inventario
end

function processInventoryContainer(item)
    local container = item:getInventory()
    local itemsInContainer = {}
    for i = 0, container:getItems():size() - 1 do
        local itemC = container:getItems():get(i)
        itemsInContainer[i+1] = {
            type = itemC:getFullType(),
            condition = itemC:getCondition(),
            customData = getItemCustomData(itemC),
            inventario = {}
        }

        if itemC:IsInventoryContainer() then
            itemsInContainer[i+1].inventario = processInventoryContainer(itemC)
        end
    end
    return itemsInContainer
end

local function getItemDataForPart(partItem)
    if not partItem then return nil end
    return {
        type = partItem:getFullType(),
        condition = partItem:getCondition(),
        customData = getItemCustomData(partItem)
    }
end

function getItemCustomData(item)
    local customData = {
        uses = nil,
        ammo = nil,
        food = nil,
        parts = nil,
        modData = nil
    }

    if instanceof(item, "DrainableComboItem") then
        customData.uses = item:getUsedDelta()
    end

    if instanceof(item, "HandWeapon") then
        customData.ammo = item:getCurrentAmmoCount()
        customData.parts = {}
        if type(item.getWeaponPart) == "function" then
            local pScope = item:getWeaponPart("Scope")
            if pScope then customData.parts.Scope = getItemDataForPart(pScope) end
            local pClip = item:getWeaponPart("Clip")
            if pClip then customData.parts.Clip = getItemDataForPart(pClip) end
            local pSling = item:getWeaponPart("Sling")
            if pSling then customData.parts.Sling = getItemDataForPart(pSling) end
            local pStock = item:getWeaponPart("Stock")
            if pStock then customData.parts.Stock = getItemDataForPart(pStock) end
            local pCanon = item:getWeaponPart("Canon")
            if pCanon then customData.parts.Canon = getItemDataForPart(pCanon) end
            local pRecoilpad = item:getWeaponPart("RecoilPad")
            if pRecoilpad then customData.parts.Recoilpad = getItemDataForPart(pRecoilpad) end
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

    local itemModData = item:getModData()
    if itemModData then
        customData.modData = {}
        for k,v in pairs(itemModData) do
            if type(v) ~= "userdata" and type(v) ~= "function" then
                customData.modData[k] = v
            end
        end
    end

    return customData
end

function restoreVehicle(vehicleData, itemEquiped)
    local player = getPlayer()
    local x = player:getX()
    local y = player:getY()
    local z = player:getZ()
    local VehicleStatus = 0

    -- Crear un nuevo vehículo de forma compatible con Cliente/Servidor
    local vehicle = nil
    if isClient() then
        sendClientCommand(getPlayer(), "SKO_Capsule", "spawnVehicle", { name = vehicleData.name, dir = player:getDir(), status = VehicleStatus, x = x, y = y, z = z, data = vehicleData, itemId = itemEquiped:getID() })
        return -- la parte de restaurecion debe controlarse asincronamente si se hace por server
    else
        vehicle = addVehicleDebug(vehicleData.name, player:getDir(), VehicleStatus, getCell():getGridSquare(x, y, z))
        if vehicle then
            vehicle:setColorHSV(vehicleData.color.h, vehicleData.color.s, vehicleData.color.v)
        end
    end
    if vehicle and vehicleData.parts then
        for i = 1, vehicle:getPartCount() do
            local part = vehicle:getPartByIndex(i - 1)
            if part then
                local partData = vehicleData.parts[part:getId()]
                if partData then
                    local condition = partData.condition
                    if partData.hasItem and partData.item then
                        pcall(function() part:setInventoryItem(partData.item) end)
                    end
                    -- verificamos si vehicleData.inventory[part:getId()].capacity esta definido
                    if vehicleData.inventory[part:getId()] then
                        pcall(function() part:setContainerCapacity(vehicleData.inventory[part:getId()].capacity) end)
                    end

                    if condition then
                        if part:getId() == "GasTank" then
                            pcall(function() part:setContainerCapacity(vehicleData.fuelCapacity) end)
                            pcall(function() part:setContainerContentAmount(vehicleData.fuel) end)
                        end
                        if part:getId() == "Battery" then
                            local battery = part:getInventoryItem()
                            if battery then
                                pcall(function() battery:setUsedDelta(vehicleData.batteryCharge) end)
                            end
                        end
                        part:setCondition(condition)
                        if not partData.hasItem then
                            pcall(function() part:setInventoryItem(nil) end)
                        end
                    else
                        part:setCondition(0)
                        pcall(function() part:setInventoryItem(nil) end)
                    end
                end
            end
        end
    end
    
    -- Restaurar los inventarios de los contenedores del vehiculo
    if vehicle and vehicleData.inventory then
        for partId, partInventory in pairs(vehicleData.inventory) do
            local vPart = vehicle:getPartById(partId)
            if vPart and vPart:getItemContainer() then
                local container = vPart:getItemContainer()
                container:clear()
                restoreItemsToContainer(container, partInventory.items)
            end
        end
    end

    -- Restaurar estado de puertas
    if vehicle and vehicleData.doors then
        for partId, doorData in pairs(vehicleData.doors) do
            local part = vehicle:getPartById(partId)
            if part then
                local door = part:getDoor()
                if door then
                    door:setOpen(doorData.isOpen or false)
                    door:setLocked(doorData.isLocked or false)
                end
            end
        end
    end

    -- Restaurar estado de ventanas
    if vehicle and vehicleData.windows then
        for partId, windowData in pairs(vehicleData.windows) do
            local part = vehicle:getPartById(partId)
            if part then
                local window = part:getWindow()
                if window then
                    window:setOpen(windowData.isOpen or false)
                end
            end
        end
    end

    -- Restaurar la llave, puenteo y keyId
    if vehicle then
        if vehicleData.hotwired then
            vehicle:setHotwired(true)
        end
        if vehicleData.hasKey then
            vehicle:setKeysInIgnition(true)
        end
        -- Restaurar el keyId original para que las llaves del jugador sigan funcionando
        if vehicleData.keyId and vehicleData.keyId > 0 then
            vehicle:setKeyId(vehicleData.keyId)
        end
        if vehicleData.trunkLocked then
            vehicle:setTrunkLocked(true)
        end
    end

    -- Regresar el nombre del itemEquiped a "Contenedor de vehiculos"
    itemEquiped:setName("Contenedor de vehiculos")

    -- Eliminar el vehículo restaurado de storedVehicles
    local storedVehicles = getModData()
    storedVehicles[vehicleData.id] = nil
    setModData(storedVehicles) 
end

function restoreItemsToContainer(container, items)
    for _, itemData in ipairs(items) do
        local item = instanceItem(itemData.type)
        if item then
            setItemCustomData(item, itemData.customData)
            item:setCondition(itemData.condition)
            container:AddItem(item)

            if itemData.inventario and #itemData.inventario > 0 then
                local itemContainer = item:getInventory()
                if itemContainer then
                    print("Restaurando contenedor: " .. itemData.type)
                    restoreItemsToContainer(itemContainer, itemData.inventario)
                end
            end
        else
            print("No se pudo crear el item: " .. tostring(itemData.type))
        end
    end
end

local function restoreItemForPart(partData)
    if not partData then return nil end
    local newItem = instanceItem(partData.type)
    if not newItem then return nil end
    if partData.condition then newItem:setCondition(partData.condition) end
    setItemCustomData(newItem, partData.customData)
    return newItem
end

function setItemCustomData(item, customData)
    if not customData then return end

    if customData.uses and instanceof(item, "DrainableComboItem") then
        item:setUsedDelta(customData.uses)
    end
    if customData.ammo and instanceof(item, "HandWeapon") then
        item:setCurrentAmmoCount(customData.ammo)
        if customData.parts and type(item.attachWeaponPart) == "function" then
            if customData.parts.Scope then item:attachWeaponPart(restoreItemForPart(customData.parts.Scope)) end
            if customData.parts.Clip then item:attachWeaponPart(restoreItemForPart(customData.parts.Clip)) end
            if customData.parts.Sling then item:attachWeaponPart(restoreItemForPart(customData.parts.Sling)) end
            if customData.parts.Stock then item:attachWeaponPart(restoreItemForPart(customData.parts.Stock)) end
            if customData.parts.Canon then item:attachWeaponPart(restoreItemForPart(customData.parts.Canon)) end
            if customData.parts.Recoilpad then item:attachWeaponPart(restoreItemForPart(customData.parts.Recoilpad)) end
        end
    end

    if customData.food and instanceof(item, "Food") then
        if customData.food.hungerChange then item:setHungChange(customData.food.hungerChange) end
        if customData.food.thirst then item:setThirstChange(customData.food.thirst) end
        if customData.food.boredom then item:setBoredomChange(customData.food.boredom) end
        if customData.food.unhappy then item:setUnhappyChange(customData.food.unhappy) end
        if customData.food.carbs then item:setCarbohydrates(customData.food.carbs) end
        if customData.food.lipids then item:setLipids(customData.food.lipids) end
        if customData.food.proteins then item:setProteins(customData.food.proteins) end
        if customData.food.calories then item:setCalories(customData.food.calories) end
        if customData.food.cooked ~= nil then item:setCooked(customData.food.cooked) end
        if customData.food.burn ~= nil then item:setBurnt(customData.food.burn) end
        if customData.food.freshness then item:setAge(customData.food.freshness) end
        if customData.food.rotten ~= nil then item:setRotten(customData.food.rotten) end
    end

    if customData.modData then
        local mData = item:getModData()
        for k,v in pairs(customData.modData) do
            mData[k] = v
        end
    end
end


-- Crear un botón para restaurar el vehículo
function createRestoreButton(context, vehicleData, itemEquiped)
    context:addOption("Restaurar Vehiculo: " .. vehicleData.name, nil, function()
        restoreVehicle(vehicleData, itemEquiped)
    end)
end

function AgregarOpcionVehiculo(player, context, worldobjects)
    local jugador = getPlayer()
    local itemEquiped = jugador:getSecondaryHandItem() 
    if not itemEquiped then return end

    local itemName = itemEquiped:getDisplayName()
    -- verificar que itemName contenga "Contenedor vehiculo:" y se ejecuta un explode despues de los dos puntos
    if itemName:find("Contenedor vehiculo:") then
        local vehicleId = string.split(itemName, ":")[2]
        local storedVehicles = getModData()
        local vehicleData = storedVehicles[vehicleId]
        
        if vehicleData then
            createRestoreButton(context, vehicleData, itemEquiped)
        end
    end
end

-- Función para llenar el menú fuera del vehículo
local original_FillMenuOutsideVehicle = ISVehicleMenu.FillMenuOutsideVehicle
function ISVehicleMenu.FillMenuOutsideVehicle(player, context, vehicle, test)
    if original_FillMenuOutsideVehicle then
        original_FillMenuOutsideVehicle(player, context, vehicle, test)
    end
    
    local jugador = getSpecificPlayer(player)
    local itemEquiped = jugador:getSecondaryHandItem()
    if not itemEquiped then return end

    if itemEquiped:getDisplayName() == "Contenedor de vehiculos" then
        local optionText = "Encapsular Vehiculo: " .. vehicle:getScript():getName()
        context:addOption(optionText, player, function()
            storeVehicleInContainer(vehicle, itemEquiped)
        end)
    end  
end

function OnServerCommand(module, command, args)
    if module == "SKO_Capsule" and command == "doRestore" then
        local vehicle = getVehicleById(tonumber(args.vehicleIdStr))
        if vehicle then
            local p = getPlayer()
            local inv = p:getInventory()
            local itemEquiped = inv:getItemById(tonumber(args.itemId)) or p:getSecondaryHandItem()
            
            if itemEquiped then
                local vehicleData = args.data

                -- Restaurar las partes del vehículo
                if vehicleData.parts then
                    for i = 1, vehicle:getPartCount() do
                        local part = vehicle:getPartByIndex(i - 1)
                        if part then
                            local partData = vehicleData.parts[part:getId()]
                            if partData then
                                local condition = partData.condition
                                if partData.hasItem and partData.item then
                                    part:setInventoryItem(partData.item)
                                end
                                
                                if vehicleData.inventory[part:getId()] then
                                    part:setContainerCapacity(vehicleData.inventory[part:getId()].capacity)
                                end

                                if condition then
                                    if part:getId() == "GasTank" then
                                        part:setContainerCapacity(vehicleData.fuelCapacity)
                                        part:setContainerContentAmount(vehicleData.fuel)
                                    end
                                    if part:getId() == "Battery" then
                                        local battery = part:getInventoryItem()
                                        if battery then
                                            battery:setUsedDelta(vehicleData.batteryCharge)
                                        end
                                    end
                                    part:setCondition(condition)
                                    if not partData.hasItem then
                                        part:setInventoryItem(nil)
                                    end
                                else
                                    part:setCondition(0)
                                    part:setInventoryItem(nil)
                                end
                            end
                        end
                    end
                end
                
                -- Restaurar los inventarios de los contenedores
                if vehicleData.inventory then
                    for partId, partInventory in pairs(vehicleData.inventory) do
                        local vPart = vehicle:getPartById(partId)
                        if vPart and vPart:getItemContainer() then
                            local container = vPart:getItemContainer()
                            container:clear()
                            restoreItemsToContainer(container, partInventory.items)
                        end
                    end
                end

                -- Restaurar estado de puertas
                if vehicleData.doors then
                    for partId, doorData in pairs(vehicleData.doors) do
                        local part = vehicle:getPartById(partId)
                        if part then
                            local door = part:getDoor()
                            if door then
                                door:setOpen(doorData.isOpen or false)
                                door:setLocked(doorData.isLocked or false)
                            end
                        end
                    end
                end

                -- Restaurar estado de ventanas
                if vehicleData.windows then
                    for partId, windowData in pairs(vehicleData.windows) do
                        local part = vehicle:getPartById(partId)
                        if part then
                            local window = part:getWindow()
                            if window then
                                window:setOpen(windowData.isOpen or false)
                            end
                        end
                    end
                end

                -- Restaurar la llave, puenteo y keyId
                if vehicleData.hotwired then
                    vehicle:setHotwired(true)
                end
                if vehicleData.hasKey then
                    vehicle:setKeysInIgnition(true)
                end
                if vehicleData.keyId and vehicleData.keyId > 0 then
                    vehicle:setKeyId(vehicleData.keyId)
                end
                if vehicleData.trunkLocked then
                    vehicle:setTrunkLocked(true)
                end

                -- Regresar nombre del itemEquiped
                itemEquiped:setName("Contenedor de vehiculos")

                -- Eliminar datos
                local storedVehicles = getModData()
                storedVehicles[vehicleData.id] = nil
                setModData(storedVehicles) 
            end
        end
    end
end

-- Registrar eventos
Events.OnServerCommand.Add(OnServerCommand)
Events.OnFillWorldObjectContextMenu.Add(AgregarOpcionVehiculo)