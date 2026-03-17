-- ======================================================================
-- SKO Waypoints: Control Remoto de Waypoints - Build 42
-- Descripción: Registra el menú contextual de inventario para el item
--              SKO_Waypoint.RemoteWP, dando acceso a los dos paneles
--              principales de SKOWaypoints desde cualquier sitio.
-- ======================================================================

--- Agrega las opciones al hacer click derecho sobre el Control Remoto de Waypoints
--- en el inventario del jugador.
local function OnFillInventoryContextMenu_RemoteWP(playerIndex, context, items)
    -- Buscar si alguno de los items seleccionados es nuestro control remoto
    local hasRemote = false
    for _, item in ipairs(items) do
        local realItem = item
        -- En B42, la lista puede contener wrappers con campo 'items'
        if type(item) == "table" and item.items then
            for _, subItem in ipairs(item.items) do
                if subItem:getFullType() == "SKO_Waypoint.RemoteWP" then
                    hasRemote = true
                    break
                end
            end
        elseif type(item) == "userdata" then
            if item:getFullType() == "SKO_Waypoint.RemoteWP" then
                hasRemote = true
            end
        end
        if hasRemote then break end
    end

    if not hasRemote then return end

    -- Opción 1: Abrir el panel de Waypoints
    context:addOption("Ver Waypoints", nil, SKOLib.PanelUtils.openWaypointsPanel)

    -- Opción 2: Abrir el Transmisor / Nube
    context:addOption("Nube Waypoint (Transmisor)", nil, SKOLib.PanelUtils.openStoragePanel)
end

Events.OnFillInventoryObjectContextMenu.Add(OnFillInventoryContextMenu_RemoteWP)
