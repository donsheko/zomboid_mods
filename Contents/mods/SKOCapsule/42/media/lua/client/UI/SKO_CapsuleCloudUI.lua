require "ISUI/ISPanelJoypad"
require "ISUI/ISScrollingListBox"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISModalDialog"

SKO_CapsuleCloudUI = ISPanelJoypad:derive("SKO_CapsuleCloudUI")

function SKO_CapsuleCloudUI:new(x, y, width, height)
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
    o.selectedVehicle = nil
    SKO_CapsuleCloudUI.instance = o
    return o
end

function SKO_CapsuleCloudUI:createChildren()
    local titleHgt = getTextManager():getFontFromEnum(UIFont.Medium):getLineHeight()
    self.titleLabel = ISLabel:new(self.width / 2, 10, titleHgt, "Nube de Vehiculos (SKO)", 1, 1, 1, 1, UIFont.Medium, true)
    self.titleLabel:initialise()
    self.titleLabel:instantiate()
    self.titleLabel.center = true
    self:addChild(self.titleLabel)

    local listY = 85
    local listWidth = (self.width / 2) - 15
    local listHeight = self.height - 135

    -- Etiquetas
    self.lblVehicles = ISLabel:new(10, 58, 15, "Flota Almacenada", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.lblVehicles)

    self.lblDetails = ISLabel:new(self.width / 2 + 5, 58, 15, "Contenido del Vehiculo", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.lblDetails)

    -- Lista izquierda: Vehiculos
    self.listVehicles = ISScrollingListBox:new(10, listY, listWidth, listHeight)
    self.listVehicles:initialise()
    self.listVehicles:instantiate()
    self.listVehicles.itemheight = 40
    self.listVehicles.font = UIFont.NewSmall
    self.listVehicles.drawBorder = true
    self.listVehicles.backgroundColor = {r=0, g=0, b=0, a=0.5}
    self.listVehicles.doDrawItem = SKO_CapsuleCloudUI.doDrawVehicleItem
    
    -- Usamos el patron exacto de SKOWaypoints para evitar errores de contexto
    self.listVehicles.onMouseDown = function(list, x, y)
        local row = list:rowAt(x, y)
        if row and row > 0 then
            list.selected = row
            local vData = list.items[row].item
            SKO_CapsuleCloudUI.instance:onSelectVehicle(vData)
        end
    end

    self.listVehicles.onRightMouseUp = function(list, x, y)
        local row = list:rowAt(x, y)
        if row and row > 0 then
            list.selected = row
            local vData = list.items[row].item
            local context = ISContextMenu.get(0, getMouseX(), getMouseY())
            context:addOption("Eliminar de la Nube", SKO_CapsuleCloudUI.instance, SKO_CapsuleCloudUI.onConfirmDelete, vData)
        end
    end
    self:addChild(self.listVehicles)

    -- Lista derecha: Inventario
    self.listItems = ISScrollingListBox:new(self.width / 2 + 5, listY, listWidth, listHeight)
    self.listItems:initialise()
    self.listItems:instantiate()
    self.listItems.itemheight = 25
    self.listItems.font = UIFont.NewSmall
    self.listItems.drawBorder = true
    self.listItems.backgroundColor = {r=0, g=0, b=0, a=0.5}
    self.listItems.doDrawItem = SKO_CapsuleCloudUI.doDrawInventoryItem
    self:addChild(self.listItems)

    -- Botones
    local btnWid = 110
    local btnHgt = 25
    local btnsStartX = (self.width - (btnWid * 2 + 20)) / 2

    self.closeBtn = ISButton:new(btnsStartX, self.height - btnHgt - 10, btnWid, btnHgt, "Cerrar", self, self.close)
    self.closeBtn:initialise()
    self.closeBtn.borderColor = {r=1, g=1, b=1, a=0.3}
    self:addChild(self.closeBtn)

    self.spawnBtn = ISButton:new(btnsStartX + btnWid + 20, self.height - btnHgt - 10, btnWid, btnHgt, "Desplegar", self, self.onSpawn)
    self.spawnBtn:initialise()
    self.spawnBtn.borderColor = {r=0.3, g=1, b=0.3, a=0.5}
    self.spawnBtn.enable = false
    self:addChild(self.spawnBtn)

    self:refreshList()
end

function SKO_CapsuleCloudUI:refreshList()
    self.listVehicles:clear()
    local vehicles = SKO_getCapsuleData()
    for id, vData in pairs(vehicles) do
        self.listVehicles:addItem(vData.name, vData)
    end
end

function SKO_CapsuleCloudUI:onSelectVehicle(vData)
    self.selectedVehicle = vData
    self.spawnBtn.enable = true
    self.listItems:clear()
    if vData and vData.inventory then
        for partId, inv in pairs(vData.inventory) do
            if inv.items then
                for _, itData in ipairs(inv.items) do
                    itData.partId = partId
                    self.listItems:addItem(itData.name or itData.fullType, itData)
                end
            end
        end
    end
    self.lblDetails:setName("Contenido: " .. vData.name:gsub("Base%.", ""))
end

function SKO_CapsuleCloudUI:onConfirmDelete(vData)
    local modal = ISModalDialog:new(0, 0, 350, 150, "¿Seguro que quieres eliminar este " .. vData.name:gsub("Base%.", "") .. "? Se perdera para siempre.", true, self, self.onDoDelete, nil, vData)
    modal:initialise()
    modal:addToUIManager()
end

function SKO_CapsuleCloudUI:onDoDelete(button, vData)
    if button.internal == "YES" then
        local stored = SKO_getCapsuleData()
        stored[vData.id] = nil
        SKO_setCapsuleData(stored)
        
        self:refreshList()
        self.listItems:clear()
        self.selectedVehicle = nil
        self.spawnBtn.enable = false
        self.lblDetails:setName("Contenido del Vehiculo")
    end
end

function SKO_CapsuleCloudUI:doDrawVehicleItem(y, item, alt)
    if not item.height then item.height = self.itemheight end
    if self.selected == item.index then
        self:drawRect(0, y, self:getWidth(), item.height, 0.2, 0.4, 0.8, 0.3)
    end
    self:drawRectBorder(0, y, self:getWidth(), item.height, 0.1, 1, 1, 1, 0.1)
    
    local vData = item.item
    local title = vData.name:gsub("Base%.", "")
    self:drawText(title, 10, y + 5, 1, 1, 1, 0.9, UIFont.Small)
    
    local fuelCap = vData.fuelCapacity or 1
    if fuelCap <= 0 then fuelCap = 1 end
    local fuelPct = (vData.fuel or 0) / fuelCap
    
    local batVal = vData.batteryCharge or 0
    if batVal > 1 then batVal = batVal / 100 end
    if batVal > 1 then batVal = 1 end
    
    local fColor = {r=0, g=1, b=0}
    if fuelPct < 0.2 then fColor = {r=1, g=0.2, b=0.2} end
    
    self:drawText("Fuel: " .. math.floor(fuelPct * 100) .. "%", 10, y + 22, fColor.r, fColor.g, fColor.b, 0.7, UIFont.NewSmall)
    self:drawText("Bat: " .. math.floor(batVal * 100) .. "%", 120, y + 22, 0.4, 0.8, 1, 0.7, UIFont.NewSmall)
    
    return y + item.height
end

function SKO_CapsuleCloudUI:doDrawInventoryItem(y, item, alt)
    if not item.height then item.height = self.itemheight end
    self:drawRectBorder(0, y, self:getWidth(), item.height, 0.1, 1, 1, 1, 0.05)
    
    local itData = item.item
    local icon = nil
    if itData.fullType then pcall(function() icon = getItemTex(itData.fullType) end) end
    if icon then self:drawTextureScaled(icon, 5, y + (item.height - 18) / 2, 18, 18, 1, 1, 1, 1) end
    
    self:drawText(itData.name or itData.fullType, 30, y + (item.height - 15) / 2, 0.9, 0.9, 0.9, 0.9, UIFont.NewSmall)
    
    if itData.partId then
        local pText = "[" .. itData.partId .. "]"
        local pW = getTextManager():MeasureStringX(UIFont.NewSmall, pText)
        self:drawText(pText, self:getWidth() - pW - 10, y + (item.height - 15) / 2, 0.5, 0.5, 0.5, 0.7, UIFont.NewSmall)
    end
    return y + item.height
end

function SKO_CapsuleCloudUI:onSpawn()
    if not self.selectedVehicle then return end
    local player = getPlayer()
    local capsule = SKO_CapsuleClient.getCapsuleFromInventory(player)
    if not capsule then
        player:Say("Necesito una capsula.")
        return
    end
    restoreVehicle(self.selectedVehicle, capsule)
    self:close()
end

function SKO_CapsuleCloudUI:close()
    self:removeFromUIManager()
    if SKO_CapsuleCloudUI.instance == self then SKO_CapsuleCloudUI.instance = nil end
end

function SKO_CapsuleCloudUI:onKeyStartPressed(key)
    if key == Keyboard.KEY_ESCAPE then self:close() end
end
