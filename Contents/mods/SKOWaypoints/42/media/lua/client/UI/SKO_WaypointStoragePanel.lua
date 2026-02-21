require "ISUI/ISPanelJoypad"
require "ISUI/ISScrollingListBox"

SKOWaypointStoragePanel = ISPanelJoypad:derive("SKOWaypointStoragePanel")

function SKOWaypointStoragePanel:new(x, y, width, height)
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
    o.backgroundColor = {r=0, g=0, b=0, a=0.9}
    o.borderColor = {r=1, g=1, b=1, a=0.2}
    o.moveWithMouse = true
    SKOWaypointStoragePanel.instance = o
    return o
end

function SKOWaypointStoragePanel:createChildren()
    local titleHgt = getTextManager():getFontFromEnum(UIFont.Medium):getLineHeight()
    self.titleLabel = ISLabel:new(self.width / 2, 10, titleHgt, "Red Global de Waypoints (Transmisor)", 1, 1, 1, 1, UIFont.Medium, true)
    self.titleLabel:initialise()
    self.titleLabel:instantiate()
    self.titleLabel.center = true
    self:addChild(self.titleLabel)

    local listY = 40
    local listWidth = (self.width / 2) - 15
    local listHeight = self.height - 90

    -- Labels de las listas
    self.lblInventory = ISLabel:new(10, listY - 20, 15, "Tu Inventario (Doble click para subir)", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.lblInventory)

    self.lblNetwork = ISLabel:new(self.width / 2 + 5, listY - 20, 15, "Red Waypoint (Doble click para bajar)", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.lblNetwork)

    -- Lista izquierda: Inventario del jugador
    self.listInventory = ISScrollingListBox:new(10, listY, listWidth, listHeight)
    self.listInventory:initialise()
    self.listInventory:instantiate()
    self.listInventory.itemheight = 25
    self.listInventory.font = UIFont.NewSmall
    self.listInventory.drawBorder = true
    self.listInventory.backgroundColor = {r=0, g=0, b=0, a=0.5}
    self.listInventory:setOnMouseDoubleClick(self, self.onUploadItem)
    self:addChild(self.listInventory)

    -- Lista derecha: Nube / Transmisor
    self.listNetwork = ISScrollingListBox:new(self.width / 2 + 5, listY, listWidth, listHeight)
    self.listNetwork:initialise()
    self.listNetwork:instantiate()
    self.listNetwork.itemheight = 25
    self.listNetwork.font = UIFont.NewSmall
    self.listNetwork.drawBorder = true
    self.listNetwork.backgroundColor = {r=0, g=0, b=0, a=0.5}
    self.listNetwork:setOnMouseDoubleClick(self, self.onDownloadItem)
    self:addChild(self.listNetwork)

    -- Boton cerrar
    local btnWid = 100
    local btnHgt = 25
    self.closeBtn = ISButton:new((self.width - btnWid) / 2, self.height - btnHgt - 10, btnWid, btnHgt, "Cerrar", self, self.close)
    self.closeBtn:initialise()
    self.closeBtn.borderColor = {r=1, g=1, b=1, a=0.3}
    self:addChild(self.closeBtn)

    self:refreshLists()
end

function SKOWaypointStoragePanel:initModData()
    local modData = getPlayer():getModData()
    if not modData.skoGlobalItems then
        modData.skoGlobalItems = {}
    end
end

function SKOWaypointStoragePanel:refreshLists()
    self:initModData()
    
    -- Guardar scrolls
    local invScroll = self.listInventory:getYScroll()
    local netScroll = self.listNetwork:getYScroll()

    self.listInventory:clear()
    self.listNetwork:clear()

    -- Llenar Inventario (solo items top-level que no son equipados ni llaves esenciales)
    local player = getPlayer()
    local inv = player:getInventory()
    for i = 0, inv:getItems():size() - 1 do
        local item = inv:getItems():get(i)
        if not item:isEquipped() and item:getType() ~= "KeyRing" then
            local data = {
                realItem = item,
                fullType = item:getFullType(),
                name = item:getDisplayName(),
                condition = item:getCondition()
            }
            local text = data.name
            if item:IsWeapon() or item:IsClothing() then
                text = text .. " (Cond: " .. item:getCondition() .. "/" .. item:getConditionMax() .. ")"
            end
            if item:IsDrainable() then
                text = text .. " (Restante: " .. math.floor(item:getUsedDelta() * 100) .. "%)"
            end
            if item:IsFood() then
                text = text .. " (Hambre: " .. math.floor(item:getHungChange() * 100) .. ")"
            end
            
            self.listInventory:addItem(text, data)
        end
    end

    -- Llenar Nube
    local globalItems = player:getModData().skoGlobalItems
    for index, itemData in ipairs(globalItems) do
        local text = itemData.name
        if itemData.condition and (itemData.isWeapon or itemData.isClothing) then
            text = text .. " (Cond: " .. itemData.condition .. ")"
        end
        if itemData.usedDelta then
            text = text .. " (Restante: " .. math.floor(itemData.usedDelta * 100) .. "%)"
        end
        if itemData.hungChange then
            text = text .. " (Hambre: " .. math.floor(itemData.hungChange * 100) .. ")"
        end
        itemData.networkIndex = index -- Guardamos su indice para poder borrarlo
        self.listNetwork:addItem(text, itemData)
    end

    -- Restaurar scrolls
    self.listInventory:setYScroll(invScroll)
    self.listNetwork:setYScroll(netScroll)
end

function SKOWaypointStoragePanel:onUploadItem(itemData)
    local player = getPlayer()
    local realItem = itemData.realItem
    if not realItem then return end

    -- Preparar serializacion basica para salvar al modData
    local serialized = {
        fullType = realItem:getFullType(),
        name = realItem:getDisplayName(),
        condition = realItem:getCondition(),
        isWeapon = realItem:IsWeapon(),
        isClothing = realItem:IsClothing(),
        isFood = realItem:IsFood(),
        isDrainable = realItem:IsDrainable()
    }

    if serialized.isDrainable then
        serialized.usedDelta = realItem:getUsedDelta()
    end
    if serialized.isFood then
        serialized.hungChange = realItem:getHungChange()
        serialized.baseHunger = realItem:getBaseHunger()
        serialized.thirstChange = realItem:getThirstChange()
        serialized.calories = realItem:getCalories()
    end

    -- Remueve item del jugador y sube a modData
    player:getInventory():Remove(realItem)
    table.insert(player:getModData().skoGlobalItems, serialized)
    
    player:playSound("PutItemInBag")
    self:refreshLists()
end

function SKOWaypointStoragePanel:onDownloadItem(itemData)
    local player = getPlayer()
    local globalItems = player:getModData().skoGlobalItems
    local removeIndex = itemData.networkIndex

    if not removeIndex or not globalItems[removeIndex] then return end

    -- Re-crear el item
    local newItem = instanceItem(itemData.fullType)
    if not newItem then
        print("SKOWaypoints: No se pudo recrear el item " .. tostring(itemData.fullType))
        return
    end

    -- Restaurar propiedades basicas
    if (itemData.isWeapon or itemData.isClothing) and itemData.condition then
        newItem:setCondition(itemData.condition)
    end
    if itemData.isDrainable and itemData.usedDelta then
        newItem:setUsedDelta(itemData.usedDelta)
    end
    if itemData.isFood then
        if itemData.hungChange then newItem:setHungChange(itemData.hungChange) end
        if itemData.baseHunger then newItem:setBaseHunger(itemData.baseHunger) end
        if itemData.thirstChange then newItem:setThirstChange(itemData.thirstChange) end
        if itemData.calories then newItem:setCalories(itemData.calories) end
    end

    -- Entregar al jugador y borrar de la red
    player:getInventory():AddItem(newItem)
    table.remove(globalItems, removeIndex)

    player:playSound("OpenBag")
    self:refreshLists()
end

function SKOWaypointStoragePanel:close()
    self:removeFromUIManager()
    SKOWaypointStoragePanel.instance = nil
end

function openSKOWaypointStorage()
    if SKOWaypointStoragePanel.instance then
        SKOWaypointStoragePanel.instance:close()
    end
    local ui = SKOWaypointStoragePanel:new(100, 100, 600, 450)
    ui:initialise()
    ui:addToUIManager()
end
