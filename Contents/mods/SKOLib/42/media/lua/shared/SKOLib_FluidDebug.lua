
function SKO_Debug_SimulateCycleFromGround()
    local player = getPlayer()
    local sq = player:getCurrentSquare()
    if not sq then return end
    
    local worldObjects = sq:getWorldObjects()
    local targetWorldObj = nil
    local targetItem = nil
    
    -- 1. Buscar PetrolCan en el suelo
    for i=0, worldObjects:size()-1 do
        local wo = worldObjects:get(i)
        if wo and wo:getItem() and wo:getItem():getFullType() == "Base.PetrolCan" then
            targetWorldObj = wo
            targetItem = wo:getItem()
            break
        end
    end
    
    if not targetItem then
        player:Say("Debug: No hay PetrolCan en el suelo (mismo cuadro que jugador).")
        return
    end
    
    print("[SKO-DEBUG-CYCLE] --- FASE 1: SERIALIZACIÓN ---")
    print("[SKO-DEBUG-CYCLE] Item Original: " .. targetItem:getFullType())
    
    local fc = nil
    if targetItem.getFluidContainer then
        fc = targetItem:getFluidContainer()
    end
    
    if not fc then
        print("[SKO-DEBUG-CYCLE] Buscando en Visual y ModData...")
        -- Intento 1: Visual (B42 separa lógica y visual)
        if targetItem.getVisual then
            local vis = targetItem:getVisual()
            if vis and vis.getFluidContainer then
                fc = vis:getFluidContainer()
                if fc then print("[SKO-DEBUG-CYCLE] ¡Encontrado vía getVisual()!") end
            end
        end
        
        -- Intento 2: Ver si el dato está en ModData (raro pero posible)
        local md = targetItem:getModData()
        if md then
            print("[SKO-DEBUG-CYCLE] Contenido del ModData del item del suelo:")
            for k,v in pairs(md) do
                print("  - " .. tostring(k) .. ": " .. tostring(v))
            end
        end
    end
    
    if not fc then
        -- ÚLTIMA ESPERANZA: El WorldObject mismo podría tener el componente
        print("[SKO-DEBUG-CYCLE] ¿El WorldObject tiene el contenedor?")
        if targetWorldObj.getFluidContainer then
            fc = targetWorldObj:getFluidContainer()
            if fc then print("[SKO-DEBUG-CYCLE] ¡Encontrado en el WorldObject!") end
        end
    end

    if not fc then
        print("[SKO-DEBUG-CYCLE] ERROR FATAL: No se encuentra FluidContainer por ningún método conocido.")
        return
    end
    
    local originalAmount = fc:getAmount()
    local originalType = ""
    if type(fc.getContainerType) == "function" then
        originalType = fc:getContainerType()
    elseif not fc:isEmpty() and fc:getPrimaryFluid() then
        originalType = fc:getPrimaryFluid():getFluidTypeString()
    end
    
    print("[SKO-DEBUG-CYCLE] Amount Original: " .. tostring(originalAmount))
    print("[SKO-DEBUG-CYCLE] Type Original: " .. tostring(originalType))
    print("[SKO-DEBUG-CYCLE] Capacity Original: " .. tostring(fc:getCapacity()))
    
    -- Serializar usando la lógica de SKOLib
    local data = SKOLib.Serializer.serializeItemData(targetItem)
    print("[SKO-DEBUG-CYCLE] DATOS EN TABLA (data.fluid):")
    if data.fluid then
        for k,v in pairs(data.fluid) do
            print("  - " .. tostring(k) .. ": " .. tostring(v))
        end
    else
        print("  - ERROR: No se generó data.fluid")
    end
    
    -- 2. Eliminar el item original
    print("[SKO-DEBUG-CYCLE] --- FASE 2: ELIMINACIÓN ---")
    sq:transmitRemoveItemFromSquare(targetWorldObj)
    sq:removeWorldObject(targetWorldObj)
    
    -- 3. Simular descarga (Deserialización)
    print("[SKO-DEBUG-CYCLE] --- FASE 3: DESERIALIZACIÓN (RECREACIÓN) ---")
    local newItem = SKOLib.Serializer.deserializeItemData(data)
    if not newItem then
        print("[SKO-DEBUG-CYCLE] ERROR: No se pudo recrear el item.")
        return
    end
    
    print("[SKO-DEBUG-CYCLE] Item Recreado (Pre-restoration Amount): " .. tostring(newItem:getFluidContainer():getAmount()))
    
    -- 4. Simular Add al suelo
    local newWorldObj = sq:AddWorldInventoryItem(newItem, 0.5, 0.5, 0)
    print("[SKO-DEBUG-CYCLE] Item añadido al suelo.")
    
    -- 5. Aplicar Restauración Diferida
    print("[SKO-DEBUG-CYCLE] --- FASE 4: RESTAURACIÓN DIFERIDA ---")
    SKOLib.Serializer.applyDeferredRestoration(newItem)
    
    -- Si es un WorldObject, el item dentro podría ser diferente
    if newWorldObj and newWorldObj:getItem() then
        print("[SKO-DEBUG-CYCLE] Aplicando restauración al item del WorldObject...")
        SKOLib.Serializer.applyDeferredRestoration(newWorldObj:getItem())
    end
    
    local finalAmount = newItem:getFluidContainer():getAmount()
    print("[SKO-DEBUG-CYCLE] --- RESULTADO FINAL ---")
    print("[SKO-DEBUG-CYCLE] Cantidad Final: " .. tostring(finalAmount))
    
    if math.abs(finalAmount - originalAmount) < 0.1 then
        player:Say("DEBUG: CICLO EXITOSO. Cantidad preservada.")
    else
        player:Say("DEBUG: CICLO FALLIDO. Cantidad: " .. tostring(finalAmount))
    end
end
