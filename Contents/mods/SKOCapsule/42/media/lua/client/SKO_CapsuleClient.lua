if not SKO_CapsuleClient then SKO_CapsuleClient = {} end
SKO_CapsuleClient.DEBUG = false

SKO_CapsuleClient.CAPSULE_TYPE = "SKOCapsule.ContenedorVehiculos"
-- Guardas de idempotencia: evitan doble encapsulado / doble restauración
SKO_CapsuleClient.storeInProgress = false
SKO_CapsuleClient.restoreInProgress = false

local function debugLog(msg)
    if SKO_CapsuleClient.DEBUG then
        print("[SKOCapsule-Client] " .. tostring(msg))
    end
end

-- Consume exactamente 1 cápsula del inventario del jugador (SP / uso local).
-- Devuelve true solo si existía y fue eliminada correctamente.
function SKO_CapsuleClient.consumeCapsule(player)
    if not player then return false end
    local inv = player:getInventory()
    local capsule = inv:getFirstTypeRecurse(SKO_CapsuleClient.CAPSULE_TYPE)
    if not capsule then return false end
    local ok = pcall(function() inv:Remove(capsule) end)
    if not ok then
        print("[SKOCapsule-Client] Error al consumir capsula del inventario.")
        return false
    end
    debugLog("Capsula consumida del inventario.")
    return true
end

-- Crea y añade exactamente 1 cápsula al inventario del jugador (SP / uso local).
-- Devuelve el item creado o nil si falló.
function SKO_CapsuleClient.giveCapsule(player)
    if not player then return nil end
    local ok, item = pcall(function()
        return player:getInventory():AddItem(SKO_CapsuleClient.CAPSULE_TYPE)
    end)
    if not ok or not item then
        print("[SKOCapsule-Client] Error al crear capsula para el jugador.")
        return nil
    end
    debugLog("Capsula entregada al inventario.")
    return item
end

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

-- Serialización protegida del vehículo.
-- Devuelve la tabla completa de datos, o nil si falló la serialización.
function SKO_CapsuleClient.serializeVehicle(vehicle)
    if not vehicle then return nil end
    local ok, vehicleData = pcall(function()
        local id = vehicle:getScript():getName() .. vehicle:getID() .. "_" .. os.time()
        
        local capturedSkinIndex = 0
        if vehicle.getSkinIndex then
            capturedSkinIndex = vehicle:getSkinIndex()
        else
            local visual = SKO_getVehicleVisual(vehicle)
            if visual and visual.getSkinIndex then
                pcall(function() capturedSkinIndex = visual:getSkinIndex() end)
            end
        end
        debugLog("SkinIndex capturado: " .. tostring(capturedSkinIndex) .. " / " .. tostring(vehicle:getSkinCount()))

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
            colorIndex = (type(vehicle.getColorIndex) == "function") and vehicle:getColorIndex() or nil,
            skinIndex = capturedSkinIndex,
        }

        -- B42 Color Refuerzo: RGB + Visual Tint
        local visual = SKO_getVehicleVisual(vehicle)
        if visual then
            pcall(function()
                vehicleData.visualData = {
                    hue = visual:getHue(),
                    saturation = visual:getSaturation(),
                    value = visual:getValue()
                }
                if visual.getTint then
                    local t = visual:getTint()
                    vehicleData.visualData.tint = { r = t:getR(), g = t:getG(), b = t:getB() }
                end
            end)
        end

        -- B42 Color Refuerzo: RGB
        if vehicle.getColor and type(vehicle.getColor) == "function" then
            pcall(function()
                local c = vehicle:getColor()
                if c then
                    vehicleData.colorRGB = { r = c:getR(), g = c:getG(), b = c:getB() }
                end
            end)
        end

        -- Log ModData keys for debugging
        local mData = vehicle:getModData()
        if mData then
            local keys = ""
            pcall(function()
                for k, v in pairs(mData) do keys = keys .. tostring(k) .. ", " end
            end)
            debugLog("Vehicle ModData keys: " .. keys)
        end

        vehicleData.doors = {}
        vehicleData.windows = {}
        vehicleData.modData = SKO_copyTable(vehicle:getModData())
        
        debugLog("Color capturado: H=" .. tostring(vehicleData.color.h) .. " S=" .. tostring(vehicleData.color.s) .. " V=" .. tostring(vehicleData.color.v) .. " Index=" .. tostring(vehicleData.colorIndex))

        for i = 1, vehicle:getPartCount() do
            local part = vehicle:getPartByIndex(i - 1)
            if part then
                local partId = part:getId()
                local invItem = part:getInventoryItem()
                
                vehicleData.parts[partId] = {
                    condition = part:getCondition(),
                    hasItem = invItem ~= nil,
                    itemData = invItem and SKOLib.Serializer.serializeItemData(invItem) or nil,
                    modData = SKO_copyTable(part:getModData())
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

        return vehicleData
    end)

    if not ok or not vehicleData then
        print("[SKOCapsule-Client] ERROR de serialización del vehiculo: " .. tostring(vehicleData))
        return nil
    end
    return vehicleData
end

function storeVehicleInContainer(vehicle, itemEquiped)
    debugLog("Iniciando encapsulado de vehiculo: " .. tostring(vehicle:getScript():getName()))
    
    -- Guarda anti doble-click / doble encapsulado
    if SKO_CapsuleClient.storeInProgress then
        debugLog("Encapsulado ya en curso. Ignorando llamada duplicada.")
        return
    end
    SKO_CapsuleClient.storeInProgress = true

    -- 1) Serialización protegida: si falla, NO consumimos cápsula ni eliminamos el vehículo.
    local vehicleData = SKO_CapsuleClient.serializeVehicle(vehicle)
    if not vehicleData then
        getPlayer():Say("No se pudo encapsular el vehiculo (error de datos).")
        SKO_CapsuleClient.storeInProgress = false
        return
    end

    -- 2) Guardar en la nube local (client-side; en MP la entrada vive en el cliente).
    local storedVehicles = SKO_getCapsuleData()
    storedVehicles[vehicleData.id] = vehicleData
    SKO_setCapsuleData(storedVehicles)
    debugLog("Vehiculo guardado en la nube local: " .. tostring(vehicleData.id))

    -- 3) Eliminación del vehículo + consumo de cápsula (solo tras serialización OK).
    if isClient() then
        -- MP: el servidor valida la cápsula, elimina el vehículo y consume de forma
        -- autoritativa. Confirma al cliente con "vehicleRemoved" para finalizar.
        sendClientCommand(getPlayer(), "SKO_Capsule", "removeVehicle", {
            vehicleId = vehicle:getId(),
            dataId = vehicleData.id
        })
        debugLog("Comando removeVehicle enviado al servidor (MP).")
    else
        -- SP: eliminación local y consumo local.
        local removedOk = pcall(function() vehicle:permanentlyRemove() end)
        if removedOk then
            local consumed = SKO_CapsuleClient.consumeCapsule(getPlayer())
            if not consumed then
                print("[SKOCapsule-Client] SP: el vehiculo se elimino pero no se encontro capsula para consumir.")
            end
        else
            -- Fallo al eliminar: revertimos la entrada para no perder el vehículo.
            print("[SKOCapsule-Client] SP: fallo al eliminar el vehiculo. Revirtiendo entrada de nube.")
            storedVehicles[vehicleData.id] = nil
            SKO_setCapsuleData(storedVehicles)
            getPlayer():Say("No se pudo encapsular el vehiculo.")
        end
        SKO_CapsuleClient.storeInProgress = false
    end
end

function SKO_applyVehicleData(vehicle, vData)
    if not vehicle or not vData then return end
    debugLog("Aplicando datos locales (Cliente): " .. tostring(vData.name))
    
    -- Limpieza total de partes generadas aleatoriamente para evitar duplicados visuales
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
                        -- Forzamos la reinstalación del ítem para asegurar integridad visual y de estado (B42)
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

    -- APLICACIÓN FINAL DE COLOR Y SKIN (Posterior a las piezas para evitar sobrescrituras)
    pcall(function()
        local visual = SKO_getVehicleVisual(vehicle)
        
        if vData.color then
            debugLog("Restaurando Color HSV (Vehicle): " .. tostring(vData.color.h) .. "," .. tostring(vData.color.s) .. "," .. tostring(vData.color.v))
            vehicle:setColorHSV(vData.color.h, vData.color.s, vData.color.v)
            -- Forzamos comando nativo de PZ para sincronización total
            local args = { vehicle = vehicle:getId(), h = vData.color.h, s = vData.color.s, v = vData.color.v }
            sendClientCommand(getPlayer(), 'vehicle', 'setHSV', args)
        end

        if vData.colorRGB and vehicle.setColor then
            debugLog("Restaurando Color RGB (Vehicle): " .. tostring(vData.colorRGB.r) .. "," .. tostring(vData.colorRGB.g) .. "," .. tostring(vData.colorRGB.b))
            vehicle:setColor(ImmutableColor.new(vData.colorRGB.r, vData.colorRGB.g, vData.colorRGB.b, 1))
        end

        if vData.colorIndex and vehicle.setColorIndex then
            debugLog("Restaurando Color Index: " .. tostring(vData.colorIndex))
            vehicle:setColorIndex(vData.colorIndex)
        end

        -- SkinIndex es autoritativo en el vehículo
        if vData.skinIndex then 
            debugLog("Restaurando SkinIndex: " .. tostring(vData.skinIndex))
            if vehicle.setSkinIndex then 
                vehicle:setSkinIndex(vData.skinIndex) 
            end
            if visual and visual.setSkinIndex then 
                visual:setSkinIndex(vData.skinIndex) 
            end
            if vehicle.updateSkin then vehicle:updateSkin() end
            -- Forzamos comando nativo para Skin
            local args = { vehicle = vehicle:getId(), index = vData.skinIndex }
            sendClientCommand(getPlayer(), 'vehicle', 'setSkinIndex', args)
        end

        -- VisualData (Propiedades internas del objeto visual)
        if visual and vData.visualData then
            debugLog("Restaurando VisualData: H=" .. tostring(vData.visualData.hue) .. " S=" .. tostring(vData.visualData.saturation) .. " V=" .. tostring(vData.visualData.value))
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

function restoreVehicle(vehicleData, itemEquiped)
    if not vehicleData then return end
    local player = getPlayer()
    local x, y, z = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    local sq = getCell():getGridSquare(x, y, z)
    if z > 0 or not sq or sq:getRoom() or not sq:isOutside() then player:Say("Espacio bloqueado.") return end

    -- Guarda anti doble-click / doble restauración
    if SKO_CapsuleClient.restoreInProgress then
        debugLog("Restauración ya en curso. Ignorando llamada duplicada.")
        return
    end
    SKO_CapsuleClient.restoreInProgress = true

    if isClient() then
        -- MP: el servidor spawnea, aplica los datos y devuelve la cápsula al confirmar.
        -- La entrada de la nube se retira al recibir "doRestore" (confirmación de éxito).
        sendClientCommand(getPlayer(), "SKO_Capsule", "spawnVehicle", { 
            name = vehicleData.name, dir = player:getDir(), status = 0, 
            x = x, y = y, z = z, data = vehicleData
        })
        return
    end

    -- SP: spawn local + restauración diferida (60 ticks)
    local vehicle = addVehicleDebug(vehicleData.name, player:getDir(), 0, sq)
    if vehicle then
        debugLog("Vehiculo spawneado (SP). Iniciando restauración diferida (60 ticks)...")
        local ticks = 0
        local function onRestoreTick()
            ticks = ticks + 1
            if ticks >= 60 then
                Events.OnTick.Remove(onRestoreTick)
                SKO_CapsuleClient.restoreInProgress = false
                
                local stored = SKO_getCapsuleData()
                if vehicle and stored[vehicleData.id] then
                    local appliedOk = pcall(function() SKO_applyVehicleData(vehicle, vehicleData) end)
                    if appliedOk then
                        -- Aplicación confirmada: retiramos la entrada y devolvemos la cápsula
                        stored[vehicleData.id] = nil
                        SKO_setCapsuleData(stored)
                        local given = SKO_CapsuleClient.giveCapsule(player)
                        debugLog("Restauración diferida (SP) completada. Cápsula devuelta: " .. tostring(given ~= nil))
                    else
                        -- Fallo de aplicación: conservar la entrada en la nube, no devolver
                        -- cápsula y eliminar el vehículo a medio restaurar (evita duplicados)
                        pcall(function() vehicle:permanentlyRemove() end)
                        player:Say("No se pudo restaurar el vehiculo (aplicación de datos).")
                        print("[SKOCapsule-Client] SP: error aplicando datos del vehiculo.")
                    end
                else
                    player:Say("No se pudo restaurar el vehiculo (spawn perdido).")
                    print("[SKOCapsule-Client] SP: vehiculo no disponible o entrada ya retirada.")
                end
                debugLog("Restauración diferida (SP) finalizada.")
            end
        end
        Events.OnTick.Add(onRestoreTick)
    else
        SKO_CapsuleClient.restoreInProgress = false
        player:Say("No se pudo restaurar el vehiculo (spawn fallido).")
    end
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
                            print("[SKOCapsule] Mueble spawneado (fallback): " .. tostring(itemData.fullType))
                        end
                    end)
                end
            end
        end
    end
end

-- UTILS
SKO_CapsuleClient.getCapsuleFromInventory = function(player)
    local inv = player:getInventory()
    return inv:getFirstTypeRecurse(SKO_CapsuleClient.CAPSULE_TYPE)
end

SKO_CapsuleClient.openCloudUI = function()
    local player = getPlayer()
    
    -- Toggle logic: Si ya existe una instancia, la cerramos
    if SKO_CapsuleCloudUI.instance then
        SKO_CapsuleCloudUI.instance:close()
        return
    end

    -- Restaurar NO exige tener una cápsula previa: la nube se puede abrir siempre.
    -- (La SUBIDA sí exige cápsula; se valida en el menú contextual y en el servidor.)
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
        local ok, gui = pcall(getCore().getGameGui, getCore())
        if ok and gui and (gui:isTypeing() or gui:isSearching()) then return end
        
        SKO_CapsuleClient.openCloudUI()
    end
end

function SKO_CapsuleClient.OnServerCommand(module, command, args)
    if module ~= "SKO_Capsule" then return end

    if command == "doRestore" then
        -- El servidor solo envía doRestore tras spawn + aplicación EXITOSOS.
        -- La cápsula ya fue devuelta server-side; aquí retiramos la entrada de la nube.
        SKO_CapsuleClient.restoreInProgress = false
        if args and args.data and args.data.id then
            local vehicle = getVehicleById(tonumber(tostring(args.vehicleIdStr)))
            if vehicle then
                SKO_applyVehicleData(vehicle, args.data)
            else
                debugLog("doRestore: vehículo no encontrado localmente (posible desync); se retira la entrada igualmente.")
            end
            local stored = SKO_getCapsuleData()
            stored[args.data.id] = nil
            SKO_setCapsuleData(stored)
            debugLog("doRestore: entrada de nube retirada: " .. tostring(args.data.id))
        end
    elseif command == "vehicleRemoved" then
        -- Confirmación del servidor sobre la subida (MP).
        SKO_CapsuleClient.storeInProgress = false
        if args and args.ok == false and args.dataId then
            -- Fallo al eliminar/consumir: revertimos la entrada para no perder el vehículo.
            local stored = SKO_getCapsuleData()
            if stored[args.dataId] then
                stored[args.dataId] = nil
                SKO_setCapsuleData(stored)
            end
            getPlayer():Say("No se pudo subir el vehiculo a la nube.")
            debugLog("vehicleRemoved ok=false: entrada revertida: " .. tostring(args.dataId))
        elseif args and args.ok == true then
            debugLog("vehicleRemoved ok=true: vehículo eliminado y cápsula consumida por el servidor.")
        end
    elseif command == "restoreFailed" then
        -- Fallo de spawn o aplicación en el servidor: no se devolvió cápsula y la
        -- entrada de la nube se conserva para reintentar.
        SKO_CapsuleClient.restoreInProgress = false
        getPlayer():Say("No se pudo restaurar el vehiculo desde la nube.")
        debugLog("restoreFailed recibido: la entrada de nube se conserva.")
    end
end

Events.OnFillWorldObjectContextMenu.Add(SKO_CapsuleClient.OnFillWorldObjectContextMenu)
Events.OnKeyPressed.Add(SKO_CapsuleClient.OnKeyPressed)
Events.OnServerCommand.Add(SKO_CapsuleClient.OnServerCommand)
