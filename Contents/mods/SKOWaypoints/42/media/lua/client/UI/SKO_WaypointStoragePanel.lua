require "ISUI/ISPanelJoypad"
require "ISUI/ISScrollingListBox"
require "ISUI/ISComboBox"

SKOWaypointStoragePanel = ISPanelJoypad:derive("SKOWaypointStoragePanel")
local autoupload_tick_counter = 0
local autoupload_handler = nil

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

    local comboWidth = 180
    self.lblSource = ISLabel:new(10, 58, 15, "Origen:", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.lblSource)

    self.comboSource = ISComboBox:new(55, 55, comboWidth, 20, self, self.onSourceChange)
    self.comboSource:initialise()
    self.comboSource:addOption("Inventario")
    self:addChild(self.comboSource)

    -- Tabla para mapear opciones del combo a contenedores reales
    self.sourceContainers = {}

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
    self.listInventory.itemheight = 25 -- Regreso al tamaño compacto original
    self.listInventory.font = UIFont.NewSmall
    self.listInventory.drawBorder = true
    self.listInventory.backgroundColor = {r=0, g=0, b=0, a=0.5}
    self.listInventory.doDrawItem = SKOWaypointStoragePanel.doDrawItem
    self.listInventory:setOnMouseDoubleClick(self, self.onUploadItem)
    self.listInventory.onRightMouseUp = function(list, x, y)
        local row = list:rowAt(x, y)
        if row > 0 then
            list.selected = row
            local item = list.items[row].item
            local context = ISContextMenu.get(0, getMouseX(), getMouseY())
            context:addOption("Subir uno", self, self.onUploadItem, item)
            context:addOption("Subir todos (mismo tipo)", self, self.onUploadItem, item, true)
        end
    end
    self:addChild(self.listInventory)

    -- Lista derecha: Nube / Transmisor
    self.listNetwork = ISScrollingListBox:new(self.width / 2 + 5, listY, listWidth, listHeight)
    self.listNetwork:initialise()
    self.listNetwork:instantiate()
    self.listNetwork.itemheight = 25 -- Regreso al tamaño compacto original
    self.listNetwork.font = UIFont.NewSmall
    self.listNetwork.drawBorder = true
    self.listNetwork.backgroundColor = {r=0, g=0, b=0, a=0.5}
    self.listNetwork.doDrawItem = SKOWaypointStoragePanel.doDrawItem
    self.listNetwork:setOnMouseDoubleClick(self, self.onDownloadItem)
    self.listNetwork.onRightMouseUp = function(list, x, y)
        local row = list:rowAt(x, y)
        if row > 0 then
            list.selected = row
            local item = list.items[row].item
            local context = ISContextMenu.get(0, getMouseX(), getMouseY())
            context:addOption("Bajar uno", self, self.onDownloadItem, item)
            context:addOption("Bajar todos (mismo tipo)", self, self.onDownloadItem, item, true)
            
            -- Opción Whitelist: Auto-subida
            local whitelist = getPlayer():getModData().skoAutoUploadWhitelist
            if whitelist[item.fullType] then
                context:addOption("Remove Autoupload", self, self.onToggleWhitelist, item)
            else
                context:addOption("Add Autoupload", self, self.onToggleWhitelist, item)
            end

            context:addOption("Quitar de la nube", self, self.onRemoveFromNetwork, item)
        end
    end
    self:addChild(self.listNetwork)

    -- Combobox para filtrar categorias de la Nube (Alineado con Origen de Datos)
    local comboWidth = 140
    self.comboCategory = ISComboBox:new(self.width - 10 - comboWidth, 55, comboWidth, 20, self, self.onCategoryChange)
    self.comboCategory.onChange = self.onCategoryChange
    self.comboCategory.target = self
    self.comboCategory:initialise()
    self.comboCategory:addOption("Todos")
    self:addChild(self.comboCategory)

    -- Boton destino de descarga (toggle Inventario / Suelo)
    local btnWid = 110
    local btnHgt = 25
    local btnSpacing = 15
    local totalBtnsWidth = btnWid * 3 + btnSpacing * 2
    local btnsStartX = (self.width - totalBtnsWidth) / 2

    self.downloadToGround = false
    self.destinoBtn = ISButton:new(btnsStartX, self.height - btnHgt - 10, btnWid, btnHgt, "Dest: Inventario", self, self.onToggleDestino)
    self.destinoBtn:initialise()
    self.destinoBtn.borderColor = {r=0.3, g=1, b=0.3, a=0.5}
    self:addChild(self.destinoBtn)

    -- Boton Auto-upload Maestro
    local masterAuto = getPlayer():getModData().skoAutoUploadEnabled or false
    local autoTitle = masterAuto and "Auto-up: ON" or "Auto-up: OFF"
    self.autoBtn = ISButton:new(btnsStartX + btnWid + btnSpacing, self.height - btnHgt - 10, btnWid, btnHgt, autoTitle, self, self.onToggleAutoMaster)
    self.autoBtn:initialise()
    self.autoBtn.borderColor = masterAuto and {r=0.2, g=0.8, b=0.8, a=0.7} or {r=1, g=1, b=1, a=0.2}
    self:addChild(self.autoBtn)

    -- Boton cerrar
    self.closeBtn = ISButton:new(btnsStartX + (btnWid + btnSpacing) * 2, self.height - btnHgt - 10, btnWid, btnHgt, "Cerrar", self, self.close)
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
    if modData.skoAutoUploadEnabled == nil then
        modData.skoAutoUploadEnabled = false
    end
    if not modData.skoAutoUploadWhitelist then
        modData.skoAutoUploadWhitelist = {}
    end
end

function SKOWaypointStoragePanel:refreshLists()
    self:initModData()
    
    -- Guardar scrolls
    local invScroll = self.listInventory:getYScroll()
    local netScroll = self.listNetwork:getYScroll()

    self.listInventory:clear()
    self.listNetwork:clear()

    -- Llenar Inventario, contenedores o Suelo según selección
    local player = getPlayer()
    local displayInv = {}

    -- Funcion auxiliar para formatear el texto de un item
    local function formatItemText(itemToEval)
        local text = tostring(itemToEval:getDisplayName())

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

        return text
    end

    -- Funcion auxiliar para verificar si un item se puede subir (no equipado, no keyring, no ropa puesta)
    local function canUploadItem(itemToEval)
        if itemToEval:isEquipped() then return false end
        if itemToEval:getType() == "KeyRing" then return false end
        if itemToEval:IsClothing() then
            local okC, res = pcall(function() return player:isEquippedClothing(itemToEval) end)
            if okC and res then return false end
        end
        return true
    end

    -- Funcion para agregar items de un contenedor a displayInv
    local function addItemsFromContainer(container, suffixStr)
        local items = container:getItems()
        if not items then return end
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if item and canUploadItem(item) then
                local data = {
                    realItem = item,
                    sourceContainer = container,
                    fullType = tostring(item:getFullType()),
                    name = item:getDisplayName(),
                    condition = item:getCondition(),
                    icon = item:getTex()
                }
                local text = formatItemText(item)
                if suffixStr and suffixStr ~= "" then
                    text = text .. " " .. suffixStr
                end
                table.insert(displayInv, { text = text, data = data })
            end
        end
    end

    -- Reconstruir el combo de origenes dinamicamente
    local prevSelection = self.comboSource:getSelectedText()
    self.comboSource:clear()
    self.sourceContainers = {}

    -- Opcion 1: Suelo cercano
    self.comboSource:addOption("Suelo (Cercano)")
    self.sourceContainers["Suelo (Cercano)"] = { type = "ground" }

    -- Opcion 2: Inventario base del jugador (items sueltos, no dentro de mochilas)
    self.comboSource:addOption("Inventario")
    self.sourceContainers["Inventario"] = { type = "inventory" }

    -- Detectar contenedores (mochilas, riñoneras, etc.) en el inventario del jugador
    local inv = player:getInventory()
    local topItems = inv:getItems()
    if topItems then
        for i = 0, topItems:size() - 1 do
            local item = topItems:get(i)
            if item and instanceof(item, "InventoryContainer") then
                local containerName = tostring(item:getDisplayName())
                -- Evitar nombres duplicados agregando un sufijo si es necesario
                local optionName = containerName
                local counter = 1
                while self.sourceContainers[optionName] do
                    counter = counter + 1
                    optionName = containerName .. " (" .. counter .. ")"
                end
                self.comboSource:addOption(optionName)
                self.sourceContainers[optionName] = { type = "container", container = item:getInventory(), containerItem = item }
            end
        end
    end

    -- Restaurar seleccion previa si aun existe
    if prevSelection then
        self.comboSource:select(prevSelection)
    end

    local selectedSource = self.comboSource:getSelectedText()
    local sourceInfo = self.sourceContainers[selectedSource]

    if not sourceInfo or sourceInfo.type == "inventory" then
        -- Inventario base: solo items sueltos del jugador (no contenido de mochilas)
        addItemsFromContainer(inv, "")

    elseif sourceInfo.type == "container" then
        -- Contenedor especifico (mochila, riñonera, etc.)
        addItemsFromContainer(sourceInfo.container, "")

    elseif sourceInfo.type == "ground" then
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
                                condition = item:getCondition(),
                                icon = item:getTex()
                            }
                            local text = formatItemText(item) .. " [Suelo]"
                            table.insert(displayInv, { text = text, data = data })
                        end
                    end
                end
            end
        end
    end

    -- Agrupar items idénticos en el panel de inventario / suelo
    local groupedInv = {}
    for _, itemEntry in ipairs(displayInv) do
        local text = itemEntry.text
        if not groupedInv[text] then
            groupedInv[text] = { itemsData = {}, count = 0, text = text }
        end
        table.insert(groupedInv[text].itemsData, itemEntry.data)
        groupedInv[text].count = groupedInv[text].count + 1
    end

    local finalDisplayInv = {}
    for _, group in pairs(groupedInv) do
        local displayText = group.text .. " (x" .. group.count .. ")"
        -- Tomamos el primer item como representante para la UI
        local rowData = group.itemsData[1]
        rowData.groupedItemsData = group.itemsData
        table.insert(finalDisplayInv, { text = displayText, data = rowData, sortText = group.text })
    end

    table.sort(finalDisplayInv, function(a, b) return a.sortText < b.sortText end)
    for _, rowInfo in ipairs(finalDisplayInv) do
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

    local groupedNet = {}
    local whitelist = player:getModData().skoAutoUploadWhitelist
    
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
            
            -- Añadir indicador de Whitelist si está activo para este tipo
            if whitelist[itemData.fullType] then
                text = "[A] " .. text
            end

            if itemData.condition and (itemData.isWeapon or itemData.isClothing) then
                text = text .. " (Cond: " .. itemData.condition .. ")"
            end
            if itemData.usedDelta then
                text = text .. " (Restante: " .. math.floor(itemData.usedDelta * 100) .. "%)"
            end
            if itemData.hungChange then
                text = text .. " (Hambre: " .. math.floor(itemData.hungChange * 100) .. ")"
            end
            
            if not groupedNet[text] then
                groupedNet[text] = { itemData = itemData, indices = {}, count = 0, text = text, icon = getItemTex(itemData.fullType) }
            end
            table.insert(groupedNet[text].indices, index)
            groupedNet[text].count = groupedNet[text].count + 1
        end
    end

    local displayNet = {}
    for _, group in pairs(groupedNet) do
        local displayText = group.text .. " (x" .. group.count .. ")"
        -- Clonar itemData para evitar efectos secundarios en modData y agregar los indices
        local rowData = {}
        for k,v in pairs(group.itemData) do rowData[k] = v end
        rowData.networkIndices = group.indices
        rowData.icon = group.icon
        
        table.insert(displayNet, { text = displayText, data = rowData, sortText = group.text })
    end
    table.sort(displayNet, function(a, b) return a.sortText < b.sortText end)

    for _, rowInfo in ipairs(displayNet) do
        self.listNetwork:addItem(rowInfo.text, rowInfo.data)
    end

    -- Restaurar scrolls
    self.listInventory:setYScroll(invScroll)
    self.listNetwork:setYScroll(netScroll)
end

function SKOWaypointStoragePanel:doDrawItem(y, item, alt)
    if not item.height then item.height = self.itemheight end
    
    -- Bordes sutiles entre filas
    self:drawRectBorder(0, y, self:getWidth(), item.height, 0.1, 1, 1, 1, 0.05)
    
    local iconSize = 18 -- Tamaño compacto (vanilla style) para máxima nitidez
    local iconX = 4
    local iconY = y + (item.height - iconSize) / 2
    local textX = iconX + iconSize + 6
    
    -- Dibujar Icono
    if item.item and item.item.icon then
        self:drawTextureScaled(item.item.icon, iconX, iconY, iconSize, iconSize, 1, 1, 1, 1)
    end
    
    -- Dibujar Texto
    local fontHgt = getTextManager():getFontFromEnum(self.font):getLineHeight()
    local textY = y + (item.height - fontHgt) / 2
    
    local r,g,b = 0.9, 0.9, 0.9
    if self.selected == item.index then
        r,g,b = 0.4, 1.0, 0.4 -- Verde original vibrante
    end
    
    self:drawText(item.text, textX, textY, r, g, b, 0.9, self.font)
    
    return y + item.height
end

function SKOWaypointStoragePanel:onCategoryChange(combo, arg1, arg2)
    -- Disparar refresco manualmente
    self:refreshLists()
end

function SKOWaypointStoragePanel:onSourceChange(combo)
    self:refreshLists()
end

function SKOWaypointStoragePanel:onToggleDestino()
    self.downloadToGround = not self.downloadToGround
    if self.downloadToGround then
        self.destinoBtn:setTitle("Dest: Suelo")
        self.destinoBtn.borderColor = {r=1, g=0.6, b=0.2, a=0.5}
    else
        self.destinoBtn:setTitle("Dest: Inventario")
        self.destinoBtn.borderColor = {r=0.3, g=1, b=0.3, a=0.5}
    end
end

function SKOWaypointStoragePanel:onRemoveFromNetwork(itemData)
    local player = getPlayer()
    local globalItems = player:getModData().skoGlobalItems
    local indices = {}
    if itemData.networkIndices then
        for _, idx in ipairs(itemData.networkIndices) do table.insert(indices, idx) end
    elseif itemData.networkIndex then
        table.insert(indices, itemData.networkIndex)
    end
    table.sort(indices, function(a,b) return a > b end)
    for _, idx in ipairs(indices) do
        table.remove(globalItems, idx)
    end
    self:refreshLists()
end

function SKOWaypointStoragePanel:onUploadItem(itemData, transferAll)
    local player = getPlayer()
    local itemsToProcess = {}

    if (transferAll or isShiftKeyDown()) and itemData.groupedItemsData and #itemData.groupedItemsData > 0 then
        itemsToProcess = itemData.groupedItemsData
        itemData.groupedItemsData = {}
    elseif itemData.groupedItemsData and #itemData.groupedItemsData > 0 then
        table.insert(itemsToProcess, table.remove(itemData.groupedItemsData))
    else
        table.insert(itemsToProcess, itemData)
    end

    if #itemsToProcess == 0 then return end

    for _, data in ipairs(itemsToProcess) do
        local realItem = data.realItem
        if realItem then
            do
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
                if data.worldItem and data.square then
                    -- Caso: Item del suelo
                    print("SKOWaypoints: Removiendo item del suelo: " .. tostring(data.name))
                    data.square:transmitRemoveItemFromSquare(data.worldItem)
                    data.square:removeWorldObject(data.worldItem)
                else
                    -- Caso: Item del inventario
                    local srcCont = data.sourceContainer
                    if not srcCont then srcCont = player:getInventory() end
                    srcCont:Remove(realItem)
                end

                table.insert(player:getModData().skoGlobalItems, serialized)
            end
        end
    end

    player:playSound("PutItemInBag")
    self:refreshLists()
end

function SKOWaypointStoragePanel:onDownloadItem(itemData, transferAll)
    local player = getPlayer()
    local globalItems = player:getModData().skoGlobalItems

    local indices = {}
    if (transferAll or isShiftKeyDown()) and itemData.networkIndices and #itemData.networkIndices > 0 then
        for _, idx in ipairs(itemData.networkIndices) do table.insert(indices, idx) end
        table.sort(indices, function(a,b) return a > b end)
        itemData.networkIndices = {}
    elseif itemData.networkIndices and #itemData.networkIndices > 0 then
        table.sort(itemData.networkIndices)
        table.insert(indices, table.remove(itemData.networkIndices))
    elseif itemData.networkIndex then
        table.insert(indices, itemData.networkIndex)
    end

    if #indices == 0 then return end

    local downloaded = 0
    local failedNames = {}

    for _, removeIndex in ipairs(indices) do
        local itData = globalItems[removeIndex]
        if itData then
            -- Re-crear el item. Se usa pcall porque contenedores con inventario interno
            -- (neveras, cajas, etc.) pueden lanzar error en B42 al llenar su contenido
            -- si el container interno no esta inicializado en el momento de creacion.
            local ok, newItem = pcall(SKOLib.Serializer.deserializeItemData, itData)
            if not ok then
                print("[SKOWaypoints] Error al deserializar: " .. tostring(itData.fullType) .. " | " .. tostring(newItem))
                newItem = nil
            end

            if newItem then
                -- Entregar al jugador (inventario o suelo) y borrar de la red
                local placeOk, placeErr = pcall(function()
                    if self.downloadToGround then
                        local square = player:getCurrentSquare()
                        if square then
                            square:AddWorldInventoryItem(newItem, 0.5, 0.5, 0)
                        else
                            player:getInventory():AddItem(newItem)
                        end
                    else
                        player:getInventory():AddItem(newItem)
                    end
                end)
                if placeOk then
                    table.remove(globalItems, removeIndex)
                    downloaded = downloaded + 1
                else
                    print("[SKOWaypoints] Error al colocar item: " .. tostring(itData.fullType) .. " | " .. tostring(placeErr))
                    table.insert(failedNames, tostring(itData.name or itData.fullType))
                end
            else
                -- instanceItem fallo: posiblemente es un mueble recogible de B42.
                -- Intentar spawnearlo como objeto del mundo usando ISMoveableSpriteProps.
                -- Preferir worldSprite guardado; fallback: derivar del fullType.
                local spriteName = itData.worldSprite or (itData.fullType and itData.fullType:match("%.(.+)$"))
                local spawnedAsFurniture = false
                if spriteName then
                    local square = player:getCurrentSquare()
                    if square then
                        local spawnOk, spawnErr = pcall(function()
                            -- Base.Plank como item dummy: el placeMoveableInternal solo usa _item
                            -- en casos especiales (stoves, mannequins, radios). Para IsoThumpable
                            -- solidos como neveras no se accede al item.
                            local dummyItem = instanceItem("Base.Plank")
                            local props = ISMoveableSpriteProps.new(spriteName)
                            if not props or not props.isMoveable then
                                error("sprite no reconocido como movible: " .. spriteName)
                            end
                            props:placeMoveableInternal(square, dummyItem, spriteName)
                        end)
                        if spawnOk then
                            table.remove(globalItems, removeIndex)
                            downloaded = downloaded + 1
                            spawnedAsFurniture = true
                            print("[SKOWaypoints] Mueble spawneado en el mundo: " .. tostring(itData.fullType))
                        else
                            print("[SKOWaypoints] Fallo spawn como mueble: " .. tostring(spawnErr))
                        end
                    end
                end
                if not spawnedAsFurniture then
                    table.insert(failedNames, tostring(itData.name or itData.fullType))
                    print("[SKOWaypoints] No se pudo recrear ni spawnear: " .. tostring(itData.fullType))
                end
            end
        end
    end

    if downloaded > 0 then
        if self.downloadToGround then
            player:playSound("PutItemOnGround")
        else
            player:playSound("OpenBag")
        end
    end

    if #failedNames > 0 then
        player:Say("No se pudo descargar: " .. table.concat(failedNames, ", ") .. " (ver consola)")
    end

    self:refreshLists()
end

function SKOWaypointStoragePanel:close()
    self:removeFromUIManager()
    if SKOWaypointStoragePanel.instance == self then
        SKOWaypointStoragePanel.instance = nil
    end
end

function SKOWaypointStoragePanel:onToggleAutoMaster()
    local modData = getPlayer():getModData()
    modData.skoAutoUploadEnabled = not modData.skoAutoUploadEnabled
    
    local isEnabled = modData.skoAutoUploadEnabled
    self.autoBtn:setTitle(isEnabled and "Auto-up: ON" or "Auto-up: OFF")
    self.autoBtn.borderColor = isEnabled and {r=0.2, g=0.8, b=0.8, a=0.7} or {r=1, g=1, b=1, a=0.2}
    
    manageAutoUploadListener()
end

function SKOWaypointStoragePanel:onToggleWhitelist(itemData)
    local modData = getPlayer():getModData()
    local whitelist = modData.skoAutoUploadWhitelist
    local fType = itemData.fullType
    
    if whitelist[fType] then
        whitelist[fType] = nil
        getPlayer():Say("Auto-subida desactivada para: " .. tostring(itemData.name))
    else
        whitelist[fType] = true
        getPlayer():Say("Auto-subida activada para: " .. tostring(itemData.name))
        -- Si activamos whitelist, aseguramos que el switch maestro esté encendido si no lo estaba
        if not modData.skoAutoUploadEnabled then
            modData.skoAutoUploadEnabled = true
            if SKOWaypointStoragePanel.instance then
                SKOWaypointStoragePanel.instance.autoBtn:setTitle("Auto-up: ON")
                SKOWaypointStoragePanel.instance.autoBtn.borderColor = {r=0.2, g=0.8, b=0.8, a=0.7}
            end
            manageAutoUploadListener()
        end
    end
    self:refreshLists()
end

function onAutoUploadUpdate(player)
    if player ~= getPlayer() then return end
    
    autoupload_tick_counter = autoupload_tick_counter + 1
    if autoupload_tick_counter < 300 then return end
    autoupload_tick_counter = 0

    local modData = player:getModData()
    if not modData.skoAutoUploadEnabled then 
        manageAutoUploadListener() 
        return 
    end

    local whitelist = modData.skoAutoUploadWhitelist
    local px = player:getX()
    local py = player:getY()
    local pz = player:getZ()
    local range = 3
    local itemsFound = 0
    
    local itemsToRemove = {}

    -- 1. SCAN: SUELO
    for x = px - range, px + range do
        for y = py - range, py + range do
            local square = getCell():getGridSquare(x, y, pz)
            if square then
                local worldItems = square:getWorldObjects()
                for i = 0, worldItems:size() - 1 do
                    local worldObj = worldItems:get(i)
                    if worldObj and worldObj:getItem() then
                        local item = worldObj:getItem()
                        local fType = item:getFullType()
                        if whitelist[fType] then
                            table.insert(itemsToRemove, { type = "ground", square = square, worldObj = worldObj, item = item })
                        end
                    end
                end
            end
        end
    end

    -- 2. SCAN: INVENTARIO PRINCIPAL (Solo bolsillos, no mochilas)
    local inv = player:getInventory()
    local invItems = inv:getItems()
    if invItems then
        for i = 0, invItems:size() - 1 do
            local item = invItems:get(i)
            if item then
                local fType = item:getFullType()
                -- Filtro: Whitelist + No Favorito + No Equipado + No Ropa puesta + No KeyRing
                if whitelist[fType] and not item:isFavorite() and not item:isEquipped() and item:getType() ~= "KeyRing" then
                    local isWearing = false
                    if item:IsClothing() then
                        local okC, res = pcall(function() return player:isEquippedClothing(item) end)
                        if okC and res then isWearing = true end
                    end
                    
                    if not isWearing then
                        table.insert(itemsToRemove, { type = "inventory", container = inv, item = item })
                    end
                end
            end
        end
    end

    if #itemsToRemove == 0 then return end

    -- PROCESS
    for _, data in ipairs(itemsToRemove) do
        local item = data.item
        local ok, serialized = pcall(SKOLib.Serializer.serializeItemData, item)
        
        if ok and serialized then
            local catStr = item:getDisplayCategory()
            if catStr then catStr = getText("IGUI_ItemCat_" .. catStr) or catStr
            else catStr = item:getCategory() or "Sin Clasificar" end
            
            serialized.category = catStr
            serialized.isWeapon = item:IsWeapon()
            serialized.isClothing = item:IsClothing()
            serialized.isFood = item:IsFood()
            serialized.isDrainable = item:IsDrainable()

            if serialized.isDrainable then
                if type(item.getCurrentUsesFloat) == "function" then
                    serialized.usedDelta = item:getCurrentUsesFloat()
                elseif type(item.getUsedDelta) == "function" then
                    serialized.usedDelta = item:getUsedDelta()
                end
            end
            if serialized.isFood then
                serialized.hungChange = item:getHungChange()
            end

            -- REMOVE
            if data.type == "ground" then
                data.square:transmitRemoveItemFromSquare(data.worldObj)
                data.square:removeWorldObject(data.worldObj)
            else
                data.container:Remove(item)
            end

            -- UPLOAD
            table.insert(modData.skoGlobalItems, serialized)
            itemsFound = itemsFound + 1
        end
    end

    if itemsFound > 0 then
        player:playSound("PutItemInBag")
        if not isClient() then
            player:Say("Auto-subida SKO: " .. itemsFound .. " objetos capturados.")
        end
        if SKOWaypointStoragePanel.instance then
            SKOWaypointStoragePanel.instance:refreshLists()
        end
    end
end

function manageAutoUploadListener()
    local player = getPlayer()
    if not player then return end
    local isEnabled = player:getModData().skoAutoUploadEnabled
    if isEnabled and not autoupload_handler then
        autoupload_handler = onAutoUploadUpdate
        Events.OnPlayerUpdate.Add(autoupload_handler)
    elseif not isEnabled and autoupload_handler then
        Events.OnPlayerUpdate.Remove(autoupload_handler)
        autoupload_handler = nil
    end
end

-- Asegurar que el listener sobreviva o se reinicie post-carga
local function onGameStart()
    manageAutoUploadListener()
end
Events.OnGameStart.Add(onGameStart)
Events.OnCreatePlayer.Add(onGameStart) -- Soporte para reconexión en Multiplayer

function openSKOWaypointStorage()
    if SKOWaypointStoragePanel.instance then
        SKOWaypointStoragePanel.instance:close()
        return
    end
    local ui = SKOWaypointStoragePanel:new(100, 100, 750, 450)
    ui:initialise()
    ui:addToUIManager()
end
