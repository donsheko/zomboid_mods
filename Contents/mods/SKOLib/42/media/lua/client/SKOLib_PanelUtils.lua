-- ======================================================================
-- SKO Lib: Panel Utilities - Build 42
-- Descripción: Funciones compartidas para abrir paneles de SKO Mods.
--              Permite que cualquier mod dependiente de SKOLib pueda
--              llamar a los paneles de Waypoints sin acoplamientos directos.
-- ======================================================================

SKOLib = SKOLib or {}
SKOLib.PanelUtils = SKOLib.PanelUtils or {}

--- Abre el panel principal de SKO Waypoints (lista de waypoints y teleporte).
--- Requiere que el mod SKOWaypoints esté activo.
function SKOLib.PanelUtils.openWaypointsPanel()
    if not SKOWaypointsPanel then
        print("SKOLib: SKOWaypointsPanel no está disponible. ¿Está SKOWaypoints activo?")
        return
    end
    if SKOWaypointsPanel.instance then
        SKOWaypointsPanel.instance:removeFromUIManager()
        SKOWaypointsPanel.instance:close()
        SKOWaypointsPanel.instance = nil
        return
    end
    local ui = SKOWaypointsPanel:new(150, 150, 350, 420)
    ui:initialise()
    ui:addToUIManager()
end

--- Abre el panel de almacenamiento global (Transmisor / Nube) de SKO Waypoints.
--- Requiere que el mod SKOWaypoints esté activo.
function SKOLib.PanelUtils.openStoragePanel()
    if not openSKOWaypointStorage then
        print("SKOLib: openSKOWaypointStorage no está disponible. ¿Está SKOWaypoints activo?")
        return
    end
    openSKOWaypointStorage()
end
