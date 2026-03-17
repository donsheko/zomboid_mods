-- ======================================================================
-- SKO Waypoints: Atajos de Teclado - Build 42
-- Descripción: Registra y gestiona los atajos de teclado para acceder
--              a los paneles de Waypoints y Nube, siempre que se tenga
--              el Control Remoto.
-- ======================================================================

local function playerHasRemote(player)
    local inv = player:getInventory()
    if not inv then return false end
    
    local topItems = inv:getItems()
    if not topItems then return false end

    for i = 0, topItems:size() - 1 do
        local item = topItems:get(i)
        if not item then break end

        -- 1. Buscar en el inventario principal (bolsillos)
        if item:getFullType() == "SKO_Waypoint.RemoteWP" then return true end
        
        -- 2. Buscar dentro de mochilas que estén EQUIPADAS
        if item:isEquipped() and instanceof(item, "InventoryContainer") then
            local containerInv = item:getInventory()
            if containerInv then
                local subItems = containerInv:getItems()
                if subItems then
                    for j = 0, subItems:size() - 1 do
                        local subItem = subItems:get(j)
                        if subItem and subItem:getFullType() == "SKO_Waypoint.RemoteWP" then
                            return true
                        end
                    end
                end
            end
        end
    end
    
    return false
end

-- Función auxiliar para abrir el panel de Waypoints (similar a la de la Nube)
local function openSKOWaypointsPanel()
    if SKOWaypointsPanel.instance then
        SKOWaypointsPanel.instance:onCloseButtonClick()
    end
    local ui = SKOWaypointsPanel:new(150, 150, 450, 400)
    ui:initialise()
    ui:addToUIManager()
end

-- Listener de teclas
local function OnKeyPressed_SKOWaypoints(key)
    -- Evitar que se dispare si se está escribiendo en un chat o buscador
    -- Usamos pcall porque getGameGui() puede no estar disponible o ser nil en ciertos estados
    local ok, gui = pcall(getCore().getGameGui, getCore())
    if ok and gui and (gui:isTypeing() or gui:isSearching()) then return end
    
    local player = getPlayer()
    if not player or player:isDead() then return end

    -- Obtener las teclas configuradas dinámicamente desde las opciones del juego
    local keyOpenWaypoints = getCore():getKey("SKO_OpenWaypoints")
    local keyOpenStorage = getCore():getKey("SKO_OpenStorage")

    if key == keyOpenWaypoints then
        -- TOGGLE: Si el panel ya está abierto, lo cerramos
        if SKOWaypointsPanel and SKOWaypointsPanel.instance then
            SKOWaypointsPanel.instance:onCloseButtonClick()
            return
        end

        -- Comprobar si tiene el RemoteWP antes de abrir
        if not playerHasRemote(player) then
            player:setHaloNote("Necesitas el Control Remoto de Waypoints", 255, 255, 255, 300)
            return
        end

        -- Abrir panel
        if SKOLib and SKOLib.PanelUtils and SKOLib.PanelUtils.openWaypointsPanel then
            SKOLib.PanelUtils.openWaypointsPanel()
        else
            openSKOWaypointsPanel()
        end

    elseif key == keyOpenStorage then
        -- TOGGLE: Si el panel ya está abierto, lo cerramos
        if SKOWaypointStoragePanel and SKOWaypointStoragePanel.instance then
            -- Intentamos llamar a close() o onCloseButtonClick() según lo que tenga el objeto
            if SKOWaypointStoragePanel.instance.close then
                SKOWaypointStoragePanel.instance:close()
            elseif SKOWaypointStoragePanel.instance.onCloseButtonClick then
                SKOWaypointStoragePanel.instance:onCloseButtonClick()
            end
            return
        end

        -- Comprobar si tiene el RemoteWP antes de abrir
        if not playerHasRemote(player) then
            player:setHaloNote("Necesitas el Control Remoto de Waypoints", 255, 255, 255, 300)
            return
        end

        -- Abrir panel
        if SKOLib and SKOLib.PanelUtils and SKOLib.PanelUtils.openStoragePanel then
            SKOLib.PanelUtils.openStoragePanel()
        elseif openSKOWaypointStorage then
            openSKOWaypointStorage()
        end
    end
end

Events.OnKeyPressed.Add(OnKeyPressed_SKOWaypoints)
