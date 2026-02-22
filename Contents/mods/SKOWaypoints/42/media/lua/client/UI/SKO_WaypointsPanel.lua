require "ISUI/ISPanelJoypad"
require "ISUI/ISScrollingListBox"

-- Panel principal de Waypoints - Build 42
-- Las opciones de abrir este panel vienen desde el Control Remoto de Waypoints (SKO_WaypointRemote.lua)
SKOWaypointsPanel = ISPanelJoypad:derive("SKOWaypointsPanel")

function SKOWaypointsPanel:new(x, y, width, height)
    local o = ISPanelJoypad:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.x = x
    o.y = y
    o.width = width
    o.height = height
    o.anchorLeft = true
    o.anchorRight = false
    o.anchorTop = true
    o.anchorBottom = false
    o.backgroundColor = {r=0, g=0, b=0, a=0.8}
    o.borderColor = {r=1, g=1, b=1, a=0.2}
    o.title = "SKO Waypoints"
    o.moveWithMouse = true
    SKOWaypointsPanel.instance = o
    return o
end

function SKOWaypointsPanel:createChildren()
    initModTable()
    local ultimaPosicion = getPlayer():getModData().lastPosition

    -- Titulo centrado
    local titleHgt = getTextManager():getFontFromEnum(UIFont.Medium):getLineHeight()
    local titleY = 10
    local titleX = self.width / 2
    self.titleLabel = ISLabel:new(titleX, titleY, titleHgt, "SKO Waypoints", 1, 1, 1, 1, UIFont.Medium, true)
    self.titleLabel:initialise()
    self.titleLabel:instantiate()
    self.titleLabel:setAnchorLeft(true)
    self.titleLabel:setAnchorRight(true)
    self.titleLabel:setAnchorTop(true)
    self.titleLabel:setAnchorBottom(false)
    self.titleLabel.center = true
    self:addChild(self.titleLabel)

    -- Lista de waypoints (deja espacio arriba para el titulo y abajo para botones)
    self:createWaypointsList()

    -- Fila de botones inferior
    local buttonWid = 90
    local buttonHgt = 25
    local buttonY = self.height - buttonHgt - 10
    local margin = 8

    -- Boton Cerrar (derecha)
    local buttonX = self.width - buttonWid - margin
    self.closeButton = ISButton:new(buttonX, buttonY, buttonWid, buttonHgt, "Cerrar", self, self.onCloseButtonClick)
    self.closeButton.internal = "CLOSE"
    self.closeButton.anchorTop = false
    self.closeButton.anchorBottom = true
    self.closeButton.anchorRight = true
    self.closeButton:initialise()
    self.closeButton:instantiate()
    self.closeButton.borderColor = {r=1, g=1, b=1, a=0.1}
    self:addChild(self.closeButton)

    -- Boton Eliminar Waypoint (centro-derecha)
    buttonX = buttonX - buttonWid - margin
    self.deleteButton = ISButton:new(buttonX, buttonY, buttonWid, buttonHgt, "Eliminar", self, self.onDeleteButtonClick)
    self.deleteButton.internal = "DELETE"
    self.deleteButton.anchorTop = false
    self.deleteButton.anchorBottom = true
    self.deleteButton.anchorRight = true
    self.deleteButton:initialise()
    self.deleteButton:instantiate()
    self.deleteButton.borderColor = {r=1, g=0.3, b=0.3, a=0.3}
    self:addChild(self.deleteButton)

    -- Boton Renombrar Waypoint (centro)
    buttonX = buttonX - buttonWid - margin
    self.renameButton = ISButton:new(buttonX, buttonY, buttonWid, buttonHgt, "Renombrar", self, self.onRenameButtonClick)
    self.renameButton.internal = "RENAME"
    self.renameButton.anchorTop = false
    self.renameButton.anchorBottom = true
    self.renameButton.anchorRight = true
    self.renameButton:initialise()
    self.renameButton:instantiate()
    self.renameButton.borderColor = {r=1, g=1, b=1, a=0.1}
    self:addChild(self.renameButton)

    -- Boton Ultima Posicion (izquierda)
    if ultimaPosicion and ultimaPosicion.x and ultimaPosicion.y and ultimaPosicion.z then
        buttonX = buttonX - buttonWid - margin
        self.lastPositionButton = ISButton:new(buttonX, buttonY, buttonWid, buttonHgt, "< Volver", self, self.onLastPositionButtonClick)
        self.lastPositionButton.internal = "LastPositionTP"
        self.lastPositionButton.anchorTop = false
        self.lastPositionButton.anchorBottom = true
        self.lastPositionButton.anchorRight = true
        self.lastPositionButton:initialise()
        self.lastPositionButton:instantiate()
        self.lastPositionButton.borderColor = {r=0.3, g=0.8, b=0.3, a=0.2}
        self:addChild(self.lastPositionButton)
    end

    -- Pequeña pista de uso
    local hintHgt = getTextManager():getFontFromEnum(UIFont.NewSmall):getLineHeight()
    local hintY = self.height - buttonHgt - hintHgt - 14
    self.hintLabel = ISLabel:new(self.width / 2, hintY, hintHgt, "[ Doble click = Teleportarse ]", 0.6, 0.6, 0.6, 1, UIFont.NewSmall, true)
    self.hintLabel:initialise()
    self.hintLabel:instantiate()
    self.hintLabel.center = true
    self.hintLabel.anchorTop = false
    self.hintLabel.anchorBottom = true
    self:addChild(self.hintLabel)
end

function SKOWaypointsPanel:createWaypointsList()
    initModTable()
    local waypointsTable = getPlayer():getModData().skoWaypoints

    -- La lista ocupa el espacio central dejando margen para hint + botones abajo (60px)
    self.PanelWaypoints = ISScrollingListBox:new(10, 40, self.width - 20, self.height - 125)
    self.PanelWaypoints:initialise()
    self.PanelWaypoints:instantiate()
    self.PanelWaypoints.itemheight = 25
    self.PanelWaypoints.selected = 0
    self.PanelWaypoints.joypadParent = self
    self.PanelWaypoints.font = UIFont.NewSmall
    self.PanelWaypoints.doDrawItem = SKOWaypointsPanel.doDrawItem
    self.PanelWaypoints.drawBorder = true
    self.PanelWaypoints:setOnMouseDoubleClick(self, self.onDoubleClick)
    self:addChild(self.PanelWaypoints)

    if waypointsTable and #waypointsTable > 0 then
        for k, waypoint in pairs(waypointsTable) do
            local item = {}
            item.name = waypoint.name or ("Waypoint " .. k)
            item.x = waypoint.x
            item.y = waypoint.y
            item.z = waypoint.z
            item.index = k
            item.text = item.name .. " (" .. math.floor(item.x) .. ", " .. math.floor(item.y) .. ", " .. math.floor(item.z) .. ")"
            self.PanelWaypoints:addItem(item.text, item)
        end
    end
end

-- Refrescar la lista sin destruir el panel
function SKOWaypointsPanel:refreshWaypointsList()
    if not self.PanelWaypoints then return end

    local selectedIndex = self.PanelWaypoints.selected
    local scrollY = self.PanelWaypoints:getYScroll()

    self.PanelWaypoints:clear()

    initModTable()
    local waypointsTable = getPlayer():getModData().skoWaypoints

    if waypointsTable and #waypointsTable > 0 then
        for k, waypoint in pairs(waypointsTable) do
            local item = {}
            item.name = waypoint.name or ("Waypoint " .. k)
            item.x = waypoint.x
            item.y = waypoint.y
            item.z = waypoint.z
            item.index = k
            item.text = item.name .. " (" .. math.floor(item.x) .. ", " .. math.floor(item.y) .. ", " .. math.floor(item.z) .. ")"
            self.PanelWaypoints:addItem(item.text, item)
        end
    end

    local itemCount = #self.PanelWaypoints.items
    if selectedIndex and selectedIndex > 0 and selectedIndex <= itemCount then
        self.PanelWaypoints.selected = selectedIndex
    elseif itemCount > 0 then
        self.PanelWaypoints.selected = math.min(selectedIndex or 1, itemCount)
    end
    self.PanelWaypoints:setYScroll(scrollY)
end

-- Obtiene el item actualmente seleccionado en la lista (o nil si no hay seleccion valida)
function SKOWaypointsPanel:getSelectedItem()
    if not self.PanelWaypoints then return nil end
    local sel = self.PanelWaypoints.selected
    if sel and sel > 0 and self.PanelWaypoints.items[sel] then
        return self.PanelWaypoints.items[sel].item
    end
    return nil
end

-- ===========================
-- Callbacks de botones
-- ===========================

function SKOWaypointsPanel:onDoubleClick(item)
    local player = getPlayer()
    teleportPlayerTo(item.x, item.y, item.z)
    player:Say("Teletransportando a " .. item.name)
end

function SKOWaypointsPanel:onLastPositionButtonClick()
    initModTable()
    local ultimaPosicion = getPlayer():getModData().lastPosition
    if ultimaPosicion and ultimaPosicion.x and ultimaPosicion.y and ultimaPosicion.z then
        teleportPlayerTo(ultimaPosicion.x, ultimaPosicion.y, ultimaPosicion.z)
    end
end

--- Boton Renombrar: abre un cuadro de texto para renombrar el waypoint seleccionado
function SKOWaypointsPanel:onRenameButtonClick()
    local selectedItem = self:getSelectedItem()
    if not selectedItem then
        -- No hay waypoint seleccionado, no hacemos nada
        return
    end
    local waypointIndex = selectedItem.index
    if not waypointIndex then return end

    local waypointsTable = getPlayer():getModData().skoWaypoints
    if waypointsTable and waypointsTable[waypointIndex] then
        local currentName = waypointsTable[waypointIndex].name
        local modal = ISTextBox:new(0, 0, 280, 180, "Nuevo nombre para el Waypoint:", currentName, nil, onRenombrarWaypointPrompt, getPlayer():getPlayerNum(), getPlayer(), waypointIndex)
        modal:initialise()
        modal:addToUIManager()
    end
end

--- Boton Eliminar: elimina el waypoint seleccionado con confirmacion
function SKOWaypointsPanel:onDeleteButtonClick()
    local selectedItem = self:getSelectedItem()
    if not selectedItem then return end

    local waypointIndex = selectedItem.index
    if not waypointIndex then return end

    -- Llamamos a la funcion de SKO_Waypoints_handle.lua
    eliminarWaypoint(nil, waypointIndex)
    self:refreshWaypointsList()
end

function SKOWaypointsPanel:onCloseButtonClick()
    self:removeFromUIManager()
    self:close()
    SKOWaypointsPanel.instance = nil
end

-- ===========================
-- Teleporte
-- ===========================

function teleportPlayerTo(x, y, z)
    local player = getPlayer()
    if not player then
        return false
    end

    -- Guardar la posicion anterior
    local modData = player:getModData()
    modData.lastPosition = {x = player:getX(), y = player:getY(), z = player:getZ()}
    print("SKOWaypoints: Teletransportando a " .. x .. ", " .. y .. ", " .. z)
    
    if isClient() then
        SendCommandToServer("/teleportto " .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(z))
    else
        player:teleportTo(tonumber(x), tonumber(y), tonumber(z))
    end
end
