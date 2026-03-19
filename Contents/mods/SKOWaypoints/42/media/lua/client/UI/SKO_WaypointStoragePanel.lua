require "ISUI/ISPanelJoypad"
require "ISUI/ISScrollingListBox"
require "ISUI/ISComboBox"

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

    local comboWidth = 140
    self.lblSource = ISLabel:new(10, 58, 15, "Origen de Datos:", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.lblSource)

    self.comboSource = ISComboBox:new(105, 55, comboWidth, 20, self, self.onSourceChange)
    self.comboSource:initialise()
    self.comboSource:addOption("Personaje")
    self.comboSource:addOption("Suelo (Cercano)")
    self:addChild(self.comboSource)

    local listY = 85
    local listWidth = (self.width / 2) - 15
    local listHeight = self.height - 135

    -- Etiquetas de las listas (Red Waypoint alineada con Origen de Datos)
    self.lblNetwork = ISLabel:new(self.width / 2 + 5, 58, 15, "Red Waypoint", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.lblNetwork)

    -- Lista izquierda: Inventario del jugador / Suelo
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

    -- Combobox para filtrar categorias de la Nube (Alineado con Origen de Datos)
    local comboWidth = 140
    self.comboCategory = ISComboBox:new(self.width - 10 - comboWidth, 55, comboWidth, 20, self, self.onCategoryChange)
    self.comboCategory.onChange = self.onCategoryChange
    self.comboCategory.target = self
    self.comboCategory:initialise()
    self.comboCategory:addOption("Todos")
    self:addChild(self.comboCategory)

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

    -- Llenar Inventario o Suelo según selección
    local player = getPlayer()
    local displayInv = {}

    local selectedSource = self.comboSource:getSelectedText()
    
    if selectedSource == "Personaje" then
        local inv = player:getInventory()

        local function checkAdd(itemToEval, sourceContainer, suffixStr)
            if itemToEval:isEquipped() then return end
            if itemToEval:getType() == "KeyRing" then return end

            local isClothing = false
            if itemToEval:IsClothing() then
                local okC, res = pcall(function() return player:isEquippedClothing(itemToEval) end)
                if okC and res then isClothing = true end
            end
            if isClothing then return end

            local data = {
                realItem = itemToEval,
                sourceContainer = sourceContainer,
                fullType = tostring(itemToEval:getFullType()),
                name = itemToEval:getDisplayName(),
                condition = itemToEval:getCondition()
            }
            
            local text = tostring(data.name)
            
            local okW, isW = pcall(function() return itemToEval:IsWeapon() end)
            local okC, isC = pcall(function() return itemToEval:IsClothing() end)
            if (okW and isW) or (okC and isC) then
                pcall(function() text = text .. " (Cond: " .. tostring(itemToEval:getCondition()) .. "/" .. tostring(itemToEval:getConditionMax()) .. ")" end)
            end
            
            local okD, isD = pcall(function() return itemToEval:IsDrainable() end)
            if okD and isD then
                pcall(function()
                    if type(itemToEval.getCurrentUsesFloat) == "function" then
                        text = text .. " (Restante: " .. math.floor(itemToEval:getCurrentUsesFloat() * 100) .. "%)"
                    elseif type(itemToEval.getUsedDelta) == "function" then
                        text = text .. " (Restante: " .. math.floor(itemToEval:getUsedDelta() * 100) .. "%)"
                    end
                end)
            end
            
            local okH, isH = pcall(function() return itemToEval:IsFood() end)
            if okH and isH then
                pcall(function() text = text .. " (Hambre: " .. math.floor(itemToEval:getHungChange() * 100) .. ")" end)
            end
            
            if suffixStr and suffixStr ~= "" then
                text = text .. " " .. suffixStr
            end
            
            table.insert(displayInv, { text = text, data = data })
        end

        local topItems = inv:getItems()
        if topItems then
            for i = 0, topItems:size() - 1 do
                local item = topItems:get(i)
                if item then
                    checkAdd(item, inv, "")
                    if instanceof(item, "InventoryContainer") then
                        local subInv = item:getInventory()
                        if subInv then
                            local suffix = "- [" .. tostring(item:getDisplayName()) .. "]"
                            local subItems = subInv:getItems()
                            if subItems then
                                for j = 0, subItems:size() - 1 do
                                    local subItem = subItems:get(j)
                                    if subItem then
                                        checkAdd(subItem, subInv, suffix)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    else
        -- Llenar desde el suelo
        local px = player:getX()
        local py = player:getY()
        local pz = player:getZ()
        local range = 2

        for x = px - range, px + range do
            for y = py - range, py + range do
                local square = getCell():getGridSquare(x, y, pz)
                if square then
                    local worldItems = square:getWorldObjects()
                    for i = 0, worldItems:size() - 1 do
                        local worldObj = worldItems:get(i)
                        if worldObj and worldObj:getItem() then
                            local item = worldObj:getItem()
                            local data = {
                                realItem = item,
                                worldItem = worldObj,
                                square = square,
                                fullType = tostring(item:getFullType()),
                                name = item:getDisplayName(),
                                condition = item:getCondition()
                            }
                            
                            local text = tostring(data.name) .. " [Suelo]"
                            
                            local okW, isW = pcall(function() return item:IsWeapon() end)
                            local okC, isC = pcall(function() return item:IsClothing() end)
                            if (okW and isW) or (okC and isC) then
                                pcall(function() text = text .. " (Cond: " .. tostring(item:getCondition()) .. "/" .. tostring(item:getConditionMax()) .. ")" end)
                            end
                            
                            table.insert(displayInv, { text = text, data = data })
                        end
                    end
                end
            end
        end
    end

    table.sort(displayInv, function(a, b) return a.text < b.text end)
    for _, rowInfo in ipairs(displayInv) do
        self.listInventory:addItem(rowInfo.text, rowInfo.data)
    end

    -- Extraer categorias unicas dinamicamente
    local globalItems = player:getModData().skoGlobalItems
    local uniqueCategories = {}
    for _, itemData in ipairs(globalItems) do
        -- Si es un item viejo sin categoria, tratar de adivinar o poner Sin Clasificar
        local cat = itemData.category
        if not cat then
            if itemData.isWeapon then cat = getText("IGUI_ItemCat_Weapon") or "Weapon"
            elseif itemData.isClothing then cat = getText("IGUI_ItemCat_Clothing") or "Clothing"
            elseif itemData.isFood then cat = getText("IGUI_ItemCat_Food") or "Food"
            elseif itemData.isMedical then cat = getText("IGUI_ItemCat_Medical") or "Medical"
            else cat = "Sin Clasificar" end
        end
        uniqueCategories[cat] = true
    end

    -- Reconstruir combobox manteniendo la seleccion
    local currentSelection = "Todos"
    if self.comboCategory then
        local st = self.comboCategory:getSelectedText()
        if st then currentSelection = st end
        
        self.comboCategory:clear()
        self.comboCategory:addOption("Todos")
        
        local sortedCategories = {}
        for cat, _ in pairs(uniqueCategories) do
            table.insert(sortedCategories, cat)
        end
        table.sort(sortedCategories)

        for _, cat in ipairs(sortedCategories) do
            self.comboCategory:addOption(cat)
        end
        
        self.comboCategory.selected = 1
        self.comboCategory:select(currentSelection)
    end

    local selectedCategory = nil
    if self.comboCategory then
        selectedCategory = self.comboCategory:getSelectedText()
    end

    local displayNet = {}
    for index, itemData in ipairs(globalItems) do
        local cat = itemData.category
        if not cat then
            if itemData.isWeapon then cat = getText("IGUI_ItemCat_Weapon") or "Weapon"
            elseif itemData.isClothing then cat = getText("IGUI_ItemCat_Clothing") or "Clothing"
            elseif itemData.isFood then cat = getText("IGUI_ItemCat_Food") or "Food"
            elseif itemData.isMedical then cat = getText("IGUI_ItemCat_Medical") or "Medical"
            else cat = "Sin Clasificar" end
        end

        local showItem = true
        if selectedCategory and selectedCategory ~= "Todos" then
            if selectedCategory ~= cat then showItem = false end
        end

        if showItem then
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
            table.insert(displayNet, { text = text, data = itemData })
        end
    end
    table.sort(displayNet, function(a, b) return a.text < b.text end)
    for _, rowInfo in ipairs(displayNet) do
        self.listNetwork:addItem(rowInfo.text, rowInfo.data)
    end

    -- Restaurar scrolls
    self.listInventory:setYScroll(invScroll)
    self.listNetwork:setYScroll(netScroll)
end

function SKOWaypointStoragePanel:onCategoryChange(combo, arg1, arg2)
    -- Disparar refresco manualmente
    self:refreshLists()
end

function SKOWaypointStoragePanel:onSourceChange(combo)
    self:refreshLists()
end

function SKOWaypointStoragePanel:onUploadItem(itemData)
    local player = getPlayer()
    local realItem = itemData.realItem
    if not realItem then return end

    -- Obtiene la categoria nativa traducida que el juego le asigna (Ej: "Arma Larga", "Material", "Comida")
    local catStr = realItem:getDisplayCategory()
    if catStr then 
        catStr = getText("IGUI_ItemCat_" .. catStr) or catStr 
    else 
        catStr = realItem:getCategory() or "Sin Clasificar" 
    end

    -- Realizar serializacion profunda requerida por SKO Core
    local serialized = SKOLib.Serializer.serializeItemData(realItem)
    
    -- Agregar variables necesarias para que las listas de la UI funcionen bien (visual)
    serialized.category = catStr
    serialized.isWeapon = realItem:IsWeapon()
    serialized.isClothing = realItem:IsClothing()
    serialized.isFood = realItem:IsFood()
    serialized.isDrainable = realItem:IsDrainable()

    if serialized.isDrainable then
        if type(realItem.getCurrentUsesFloat) == "function" then
            serialized.usedDelta = realItem:getCurrentUsesFloat()
        elseif type(realItem.getUsedDelta) == "function" then
            serialized.usedDelta = realItem:getUsedDelta()
        end
    end
    if serialized.isFood then
        serialized.hungChange = realItem:getHungChange()
    end

    -- Remueve item del jugador (de su mochila o inventario) o del suelo y sube a modData
    if itemData.worldItem and itemData.square then
        -- Caso: Item del suelo
        print("SKOWaypoints: Removiendo item del suelo: " .. tostring(itemData.name))
        itemData.square:transmitRemoveItemFromSquare(itemData.worldItem)
        itemData.square:removeWorldObject(itemData.worldItem)
    else
        -- Caso: Item del inventario
        local srcCont = itemData.sourceContainer
        if not srcCont then srcCont = player:getInventory() end
        srcCont:Remove(realItem)
    end
    
    table.insert(player:getModData().skoGlobalItems, serialized)
    
    player:playSound("PutItemInBag")
    self:refreshLists()
end

function SKOWaypointStoragePanel:onDownloadItem(itemData)
    local player = getPlayer()
    local globalItems = player:getModData().skoGlobalItems
    local removeIndex = itemData.networkIndex

    if not removeIndex or not globalItems[removeIndex] then return end

    -- Re-crear el item recursivamente con todos sus contenidos y customDatas (SKO Core)
    local newItem = SKOLib.Serializer.deserializeItemData(itemData)
    if not newItem then
        print("SKOWaypoints: No se pudo recrear el item " .. tostring(itemData.fullType))
        return
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
