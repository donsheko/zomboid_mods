require "ISUI/ISPanelJoypad"
require "ISUI/ISScrollingListBox"

-- Panel principal de Waypoints - Build 42
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

    -- Lista de waypoints
    self:createWaypointsList()

    -- Boton cerrar
    local buttonWid = 100
    local buttonHgt = 25
    local buttonX = self.width - buttonWid - 10
    local buttonY = self.height - buttonHgt - 10
    self.closeButton = ISButton:new(buttonX, buttonY, buttonWid, buttonHgt, "Cerrar", self, self.onCloseButtonClick)
    self.closeButton.internal = "CLOSE"
    self.closeButton.anchorTop = false
    self.closeButton.anchorBottom = true
    self.closeButton.anchorRight = true
    self.closeButton:initialise()
    self.closeButton:instantiate()
    self.closeButton.borderColor = {r=1, g=1, b=1, a=0.1}
    self:addChild(self.closeButton)

    -- Boton ultima posicion
    if ultimaPosicion and ultimaPosicion.x and ultimaPosicion.y and ultimaPosicion.z then
        buttonX = buttonX - buttonWid - 10
        self.lastPositionButton = ISButton:new(buttonX, buttonY, buttonWid, buttonHgt, "Ultima Ubicacion", self, self.onLastPositionButtonClick)
        self.lastPositionButton.internal = "LastPositionTP"
        self.lastPositionButton.anchorTop = false
        self.lastPositionButton.anchorBottom = true
        self.lastPositionButton.anchorRight = true
        self.lastPositionButton:initialise()
        self.lastPositionButton:instantiate()
        self.lastPositionButton.borderColor = {r=1, g=1, b=1, a=0.1}
        self:addChild(self.lastPositionButton)
    end
end

function SKOWaypointsPanel:createWaypointsList()
    initModTable()
    local waypointsTable = getPlayer():getModData().skoWaypoints

    self.PanelWaypoints = ISScrollingListBox:new(10, 40, self.width - 20, self.height - 120)
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

function SKOWaypointsPanel:onCloseButtonClick()
    self:removeFromUIManager()
    self:close()
    SKOWaypointsPanel.instance = nil
end

local function openSKOWaypointsPanel()
    if SKOWaypointsPanel.instance then
        SKOWaypointsPanel.instance:removeFromUIManager()
        SKOWaypointsPanel.instance:close()
        SKOWaypointsPanel.instance = nil
    end
    local ui = SKOWaypointsPanel:new(150, 150, 350, 420)
    ui:initialise()
    ui:addToUIManager()
end

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

function agregarOpcionMenuWaypoints(player, context, worldObjects)
    context:addOption("SKO Waypoints", worldObjects, openSKOWaypointsPanel)
end

Events.OnFillWorldObjectContextMenu.Add(agregarOpcionMenuWaypoints)
