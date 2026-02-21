require "ISUI/ISPanelJoypad"
require "ISUI/ISScrollingListBox"

SKOExperiencePanel  = ISPanelJoypad:derive("SKOExperiencePanel")

function SKOExperiencePanel:new(x, y, width, height)
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
    o.title = "Experience RPG Panel"
    o.moveWithMouse = true
    -- Guardar labels de datos para actualización en vivo
    o.dataLabels = {}
    SKOExperiencePanel.instance = o
    return o
end

function SKOExperiencePanel:createChildren()
    --Agregamos El titulo Centrado
    local titleHgt = getTextManager():getFontFromEnum(UIFont.Medium):getLineHeight()
    local titleY = 10
    local titleX = self.width / 2
    self.titleLabel = ISLabel:new(titleX, titleY, titleHgt, "Experience RPG Panel", 1, 1, 1, 1, UIFont.Medium, true)
    self.titleLabel:initialise()
    self.titleLabel:instantiate()
    self.titleLabel:setAnchorLeft(true)
    self.titleLabel:setAnchorRight(false)
    self.titleLabel:setAnchorTop(true)
    self.titleLabel:setAnchorBottom(false)
    self.titleLabel.center = true
    self:addChild(self.titleLabel)
    

    --agregamos el boton de Cerrar en la parte inferior derecha
    local buttonWid = 100
    local buttonHgt = 25
    self.closeButton = ISButton:new(self.width - buttonWid - 10, self.height - buttonHgt - 10, buttonWid, buttonHgt, "Cerrar", self, self.onCloseButtonClick)
    self.closeButton.internal = "CLOSE"
    self.closeButton.anchorTop = false
    self.closeButton.anchorBottom = true
    self.closeButton:initialise()
    self.closeButton:instantiate()
    self.closeButton.borderColor = {r=1, g=1, b=1, a=0.1}
    self:addChild(self.closeButton)

    self:createDataLabels()
    self:refreshData()
    self:menuHabilidades()
end

-- Crear las labels una sola vez (sin llenar datos)
function SKOExperiencePanel:createDataLabels()
    local titleHgt = getTextManager():getFontFromEnum(UIFont.Medium):getLineHeight()
    local infoStartY = titleHgt + 20
    local labelX = 15
    local valueRightX = self.width - 15
    local valueWidth = self.width / 2 - 20
    local currentY = infoStartY
    local rowHeight = getTextManager():getFontFromEnum(UIFont.Medium):getLineHeight()
    local font = UIFont.Medium

    local function addLabelPair(key)
        local label = ISLabel:new(labelX, currentY, rowHeight, "", 1, 1, 1, 1, font, true)
        label:initialise()
        label:instantiate()
        self:addChild(label)

        local value = ISLabel:new(valueRightX - valueWidth, currentY, rowHeight, "", 1, 1, 1, 1, font, true)
        value:initialise()
        value:instantiate()
        value.rightAlign = true
        self:addChild(value)

        self.dataLabels[key] = { label = label, value = value }
        currentY = currentY + rowHeight
    end

    addLabelPair("row1")
    addLabelPair("row2")
    addLabelPair("row3")
    addLabelPair("row4")
end

-- Actualizar los textos de las labels sin recrearlas
function SKOExperiencePanel:refreshData()
    local personaje = getPlayer()
    local playerData = SKO_PlayerObject:getPlayerData(personaje)
    if not playerData then return end

    local playerText = (personaje:getUsername() or "N/A")
    local prestigeText = "Prestigio: " .. (playerData.prestige or 0)
    local totalXpText = "XP Total: " .. (playerData.totalXp or 0)
    local levelText = "Nivel Actual: " .. (playerData.currentLevel or 1)
    local xpText = "Experiencia Actual: " .. (playerData.currentXP or 0)
    local xpGap = (playerData.xpToNextLevel or 100) - (playerData.currentXP or 0)
    local availablePointsText = "Puntos Disponibles: " .. (playerData.availablePoints or 0)
    local xpToNextLevelText = "XP Siguiente Nivel: " .. xpGap

    local function setRow(key, leftText, rightText)
        if self.dataLabels[key] then
            self.dataLabels[key].label:setName(leftText)
            self.dataLabels[key].value:setName(rightText)
        end
    end

    setRow("row1", "Personaje:", playerText)
    setRow("row2", prestigeText, totalXpText)
    setRow("row3", levelText, xpText)
    setRow("row4", availablePointsText, xpToNextLevelText)
end

-- Actualizar solo la lista de habilidades, conservando la selección y el scroll
function SKOExperiencePanel:refreshHabilidades()
    if not self.PanelHabilidades then return end

    -- Guardar posición actual
    local selectedIndex = self.PanelHabilidades.selected
    local scrollY = self.PanelHabilidades:getYScroll()

    -- Limpiar y repoblar
    self.PanelHabilidades:clear()

    local personaje = getPlayer()
    local habilidades = SKO_PlayerObject:obtenerHabilidades(personaje)
    if habilidades then
        for _, habilidad in ipairs(habilidades) do
            local habilidadText = habilidad.name .. " (Nivel: " .. habilidad.level .. ") - Costo: " .. habilidad.skillPointCost .. " puntos"
            if habilidad.level < 10 then
                self.PanelHabilidades:addItem(habilidadText, habilidad)
            end
        end
    end

    -- Restaurar posición
    local itemCount = #self.PanelHabilidades.items
    if selectedIndex and selectedIndex > 0 and selectedIndex <= itemCount then
        self.PanelHabilidades.selected = selectedIndex
    elseif itemCount > 0 then
        self.PanelHabilidades.selected = math.min(selectedIndex or 1, itemCount)
    end
    self.PanelHabilidades:setYScroll(scrollY)
end

function SKOExperiencePanel:menuHabilidades()
    self.PanelHabilidades = ISScrollingListBox:new(10, 150, self.width - 20, self.height - 200)
    self.PanelHabilidades:initialise()
    self.PanelHabilidades:instantiate()
    self.PanelHabilidades.itemheight = 25
    self.PanelHabilidades.selected = 0
    self.PanelHabilidades.joypadParent = self
    self.PanelHabilidades.font = UIFont.NewSmall
    self.PanelHabilidades.doDrawItem = self.doDrawItem
    self.PanelHabilidades.drawBorder = true
    self.PanelHabilidades.backgroundColor = {r=0, g=0, b=0, a=0.8}
    self.PanelHabilidades:setOnMouseDoubleClick(self, self.onAbilityDoubleClick)
    self:addChild(self.PanelHabilidades)

    local personaje = getPlayer()
    local habilidades = SKO_PlayerObject:obtenerHabilidades(personaje)
    if habilidades then
        for _, habilidad in ipairs(habilidades) do
            local habilidadText = habilidad.name .. " (Nivel: " .. habilidad.level .. ") - Costo: " .. habilidad.skillPointCost .. " puntos"
            if habilidad.level < 10 then
                self.PanelHabilidades:addItem(habilidadText, habilidad)
            end
        end
    end
end

function SKOExperiencePanel:onCloseButtonClick()
    self:removeFromUIManager()
    self:close()
    SKOExperiencePanel.instance = nil
end

-- Actualización en vivo: solo refrescar datos, NO destruir/recrear el panel
function SKOExperiencePanel:onXpUpdate()
    if not SKOExperiencePanel.instance then return end
    if not SKOExperiencePanel.instance:getIsVisible() then return end

    SKOExperiencePanel.instance:refreshData()
    SKOExperiencePanel.instance:refreshHabilidades()
end

-- Al comprar habilidad: actualizar in-place sin cerrar el panel
function SKOExperiencePanel:onAbilityDoubleClick(habilidad)
    local personaje = getPlayer()
    SKO_PlayerObject:comprarHabilidad(personaje, habilidad)
    -- Refrescar in-place en lugar de destruir/recrear
    self:refreshData()
    self:refreshHabilidades()
end


function openSKOExperiencePanel()
    if SKOExperiencePanel.instance then
        SKOExperiencePanel.instance:removeFromUIManager()
        SKOExperiencePanel.instance:close()
        SKOExperiencePanel.instance = nil
    end
    local ui = SKOExperiencePanel:new(150, 100,500, 620)
    ui:initialise()
    ui:addToUIManager()
end

function agregarSkoExperienceMenu(player, context, worldObjects)
    context:addOption("Abrir Panel Experiencia", worldObjects, openSKOExperiencePanel)
end


Events.OnFillWorldObjectContextMenu.Add(agregarSkoExperienceMenu)
