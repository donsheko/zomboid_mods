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
        batteryCharge = 0,
        color = {
            h = vehicle:getColorHue(),
            s = vehicle:getColorSaturation(),
            v = vehicle:getColorValue()
        }
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
                    vehicleData.batteryCharge = battery:getUsedDelta()
                end
            end

            -- Almacenar la condición de la parte del vehículo
            vehicleData.parts[part:getId()] = {
                condition = part:getCondition(),
                hasItem = part:getInventoryItem() ~= nil,
                item = part:getInventoryItem()
            }
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

function getItemCustomData(item)
    local customData = {
        uses = nil,
        ammo = nil,
        food = nil,
    }
    if item:IsDrainable() then
        customData.uses = item:getUsedDelta()
    end
    if item:IsWeapon() then
        customData.ammo = item:getCurrentAmmoCount()
    end
    if item:IsFood() then
        customData.food = {
            hungerChange = item:getHungChange(),
            thirst = item:getThirstChange(),
            boredom = item:getBoredomChange(),
            unhappy = item:getUnhappyChange(),
            carbs = item:getCarbohydrates(),
            lipids = item:getLipids(),
            proteins = item:getProteins(),
            calories = item:getCalories(),
            tained = item:isTaintedWater(),

            cooked = item:isCooked(),
            burn = item:isBurnt(),
            freshness = item:getAge(),
            rotten = item:isRotten(),
        }
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
    if vehicleData.parts then
        for i = 1, vehicle:getPartCount() do
            local part = vehicle:getPartByIndex(i - 1)
            if part then
                local partData = vehicleData.parts[part:getId()]
                local condition = partData.condition
                if partData.hasItem and partData.item then
                    part:setInventoryItem(partData.item)
                end
                -- verificamos si vehicleData.inventory[part:getId()].capacity esta definido
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
                    part:setCondition(0)  -- Establecer la condición en 0 si no hay datos almacenados
                    part:setInventoryItem(nil)
                end
            end
        end
    end
    
    -- Restaurar los inventarios de los contenedores del vehiculo
    if vehicleData.inventory then
        for partId, partInventory in pairs(vehicleData.inventory) do
            local container = vehicle:getPartById(partId):getItemContainer()
            container:clear()
            restoreItemsToContainer(container, partInventory.items)
        end
    end

    -- Restaurar la llave y el estado de puente
    if vehicleData.hasKey or vehicleData.hotwired then
        vehicle:setHotwired(true)
    else
        vehicle:setHotwired(false)
        vehicle:setKeysInIgnition(false)
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
        local item = InventoryItemFactory.CreateItem(itemData.type)
        if item then
            setItemCustomData(item, itemData.customData)
            item:setCondition(itemData.condition)
            container:AddItem(item)

            if #itemData.inventario > 0 then
                local itemContainer = item:getInventory()
                print("Restaurando contenedor: " .. itemData.type)
                restoreItemsToContainer(itemContainer, itemData.inventario)
            end
        else
            print("No se pudo crear el item: " .. itemData.type)
        end
    end
end

function setItemCustomData(item, customData)
    if customData then
        if customData.uses then
            item:setUsedDelta(customData.uses)
        end
        if customData.ammo then
            item:setCurrentAmmoCount(customData.ammo)
        end

        if customData.food and item:IsFood() then
            item:setHungChange(customData.food.hungerChange)
            item:setThirstChange(customData.food.thirst)
            item:setBoredomChange(customData.food.boredom)
            item:setUnhappyChange(customData.food.unhappy)
            item:setCarbohydrates(customData.food.carbs)
            item:setLipids(customData.food.lipids)
            item:setProteins(customData.food.proteins)
            item:setCalories(customData.food.calories)
            item:setTaintedWater(customData.food.tained)

            item:setCooked(customData.food.cooked)
            item:setBurnt(customData.food.burn)
            item:setAge(customData.food.freshness)
            item:setRotten(customData.food.rotten)
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

                -- Restaurar la llave y el estado de puente
                if vehicleData.hasKey or vehicleData.hotwired then
                    vehicle:setHotwired(true)
                else
                    vehicle:setHotwired(false)
                    vehicle:setKeysInIgnition(false)
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