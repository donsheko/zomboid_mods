-- SKO Waypoints Handler - Build 42

function initModTable()
    local modData = getPlayer():getModData()
    if not modData.skoWaypoints then
        modData.skoWaypoints = {}
    end
    if not modData.lastPosition then
        modData.lastPosition = {}
    end
end

function addWaypoint(worldobject)
    initModTable()
    local modData = getPlayer():getModData()
    local waypointsTable = modData.skoWaypoints
    if checkObjectisWaypoint(worldobject) then
        local cordx = worldobject:getX()
        local cordy = worldobject:getY()
        local cordz = worldobject:getZ()
    
        if #waypointsTable > 0 then
            for i, waypoint in ipairs(waypointsTable) do
                if waypoint.x == cordx and waypoint.y == cordy and waypoint.z == cordz then
                    return
                end
            end
        end
    
        local os = tostring(worldobject)
        local nameID = string.sub(os, (string.find(os, "@") or 0) + 1)
        local newName = "Waypoint " .. nameID
        local waypoint = {
            name = newName,
            x = cordx,
            y = cordy,
            z = cordz
        }
    
        table.insert(waypointsTable, waypoint)
        modData.skoWaypoints = waypointsTable
        print("SKOWaypoints: Waypoint agregado en " .. cordx .. ", " .. cordy .. ", " .. cordz)
    end
end

function checkWaypointExist(worldobject)
    initModTable()
    local modData = getPlayer():getModData()
    local waypointsTable = modData.skoWaypoints
    local waypointIndex = -1
    if not worldobject then
        return waypointIndex
    end

    local cordx = worldobject:getX()
    local cordy = worldobject:getY()
    local cordz = worldobject:getZ()
    if #waypointsTable > 0 then
        for i, waypoint in ipairs(waypointsTable) do
            if (waypoint.x == cordx and waypoint.y == cordy and waypoint.z == cordz) then
                waypointIndex = i
            end
        end
    end
    return waypointIndex
end

function checkObjectisWaypoint(worldobject)
    if not worldobject then return false end

    -- Verificar por nombre del objeto
    local ok, name = pcall(function() return worldobject:getName() end)
    if ok and name == "Waypoint" then
        return true
    end

    -- Verificar si es un WorldInventoryItem con un Waypoint
    local ok2, objName = pcall(function() return worldobject:getObjectName() end)
    if ok2 and objName == "WorldInventoryItem" then
        local ok3, itemName = pcall(function() return worldobject:getItem():getName() end)
        if ok3 and itemName == "Waypoint" then
            return true
        end
    end

    return false
end

function eliminarWaypoint(worldObject, waypointIndex) 
    initModTable()
    local modData = getPlayer():getModData()
    local waypointsTable = modData.skoWaypoints
    table.remove(waypointsTable, waypointIndex)
    modData.skoWaypoints = waypointsTable
    print("SKOWaypoints: Waypoint eliminado")
end

function OnFillWorldObjectContextMenu_Waypoints(playerIndex, context, worldobjects, test)
    local squares = {}
    local checkedSquares = {}
    local wObjects = {}

    for _,v in ipairs(worldobjects) do
        local sq = nil
        pcall(function() sq = v:getSquare() end)
        if sq and not checkedSquares[sq] then
            table.insert(squares, sq)
            checkedSquares[sq] = true
        end
    end

    if #squares == 0 then
        return
    end

    for _,v in ipairs(squares) do
        for i = 0, v:getObjects():size() - 1 do
            table.insert(wObjects, v:getObjects():get(i))
        end
    end

    if #wObjects == 0 then
        return
    end

    for i, worldobject in ipairs(wObjects) do
        if checkObjectisWaypoint(worldobject) then           
            local waypointIndex = checkWaypointExist(worldobject)
            if not waypointIndex or waypointIndex < 0 then
                context:addOption("Agregar Waypoint", worldobject, addWaypoint, worldobject)
            else
                context:addOption("Eliminar Waypoint", worldobject, eliminarWaypoint, waypointIndex)
                context:addOption("Nube Waypoint (Transmisor)", worldobject, openSKOWaypointStorage)
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(OnFillWorldObjectContextMenu_Waypoints)
