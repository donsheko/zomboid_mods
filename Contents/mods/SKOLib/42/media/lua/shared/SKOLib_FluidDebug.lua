
local function emptyFluidTarget(target, label)
    if not target then return end
    print("[SKO-DEBUG-LAB] Intentando vaciar " .. label .. "...")
    local fc = nil
    if target.getFluidContainer then fc = target:getFluidContainer() end
    if fc then
        pcall(function() fc:Empty() end)
        pcall(function() fc:adjustAmount(0.0) end)
        print("[SKO-DEBUG-LAB] " .. label .. " - Cantidad tras vaciado: " .. tostring(fc:getAmount()))
        return true
    end
    return false
end

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
        player:Say("Debug: No hay PetrolCan en el suelo.")
        return
    end
    
    -- SERIALIZAR (Con la lógica de WorldObject que descubrimos)
    local fcSource = targetItem:getFluidContainer() or (targetWorldObj.getFluidContainer and targetWorldObj:getFluidContainer())
    if not fcSource then
        print("[SKO-DEBUG-LAB] ERROR: No se detecta fluido ni en item ni en worldobj.")
        return
    end

    local originalAmount = fcSource:getAmount()
    local originalType = ""
    if type(fcSource.getContainerType) == "function" then
        originalType = fcSource:getContainerType()
    elseif not fcSource:isEmpty() and fcSource:getPrimaryFluid() then
        originalType = fcSource:getPrimaryFluid():getFluidTypeString()
    end

    print("[SKO-DEBUG-LAB] --- FASE 1: CAPTURA ---")
    print("[SKO-DEBUG-LAB] Capturado de " .. (targetItem:getFluidContainer() and "ITEM" or "WORLDOBJ") .. ": " .. tostring(originalAmount) .. "L")

    -- SIMULAR TABLA
    local data = { 
        fullType = "Base.PetrolCan", 
        fluid = { amount = originalAmount, type = originalType, capacity = fcSource:getCapacity() } 
    }

    -- 2. ELIMINAR ORIGINAL
    sq:transmitRemoveItemFromSquare(targetWorldObj)
    sq:removeWorldObject(targetWorldObj)
    
    -- 3. RECREAR Y AÑADIR (AQUÍ EMPIEZA EL TEST DE TIMING)
    print("[SKO-DEBUG-LAB] --- FASE 2: RECREACIÓN ---")
    local newItem = instanceItem("Base.PetrolCan")
    local newWorldObj = sq:AddWorldInventoryItem(newItem, 0.5, 0.5, 0)
    print("[SKO-DEBUG-LAB] Item puesto en el suelo. Empieza secuencia de vaciado agresivo...")

    -- TEST 1: Vaciado Instantáneo
    emptyFluidTarget(newItem, "Item (Instant)")
    emptyFluidTarget(newWorldObj, "WorldObj (Instant)")
    newItem:syncItemFields()

    -- TEST 2: Vaciado diferido (DENTRO DE 1 SEGUNDO REAL)
    -- Usamos un OnTick temporal para simular el delay que necesita la B42
    local ticks = 0
    local function onTestTick()
        ticks = ticks + 1
        if ticks == 60 then -- Aproximadamente 1 segundo después
            print("[SKO-DEBUG-LAB] --- FASE 3: VACIADO DIFERIDO (DELAY 1s) ---")
            
            -- Re-capturar el WorldObject del suelo (por si cambió)
            local currentWorldObj = nil
            local worldObjectsNow = sq:getWorldObjects()
            for i=0, worldObjectsNow:size()-1 do
                local wo = worldObjectsNow:get(i)
                if wo and wo:getItem() == newItem then currentWorldObj = wo break end
            end

            emptyFluidTarget(newItem, "Item (Delayed)")
            emptyFluidTarget(currentWorldObj, "WorldObj (Delayed)")
            
            -- Llenado Parcial (Simulando restauración)
            if data.fluid.amount > 0 then
                local fcFinal = (currentWorldObj and currentWorldObj:getFluidContainer()) or newItem:getFluidContainer()
                if fcFinal then
                    -- Resolvemos tipo y añadimos
                    local ft = (FluidType and FluidType.FromNameLower and FluidType.FromNameLower(data.fluid.type)) or Fluid[data.fluid.type]
                    if ft then
                        fcFinal:addFluid(ft, data.fluid.amount)
                        print("[SKO-DEBUG-LAB] Restaurado final: " .. tostring(fcFinal:getAmount()))
                    end
                end
            end
            
            newItem:syncItemFields()
            player:Say("DEBUG LAB: Ciclo diferido completado. Verifica tooltip.")
            Events.OnTick.Remove(onTestTick)
        end
    end
    Events.OnTick.Add(onTestTick)
end
