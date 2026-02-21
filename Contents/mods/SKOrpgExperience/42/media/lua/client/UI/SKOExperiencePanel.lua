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
    SKOExperiencePanel.instance = o
    return o
end

function SKOExperiencePanel:createChildren()
    --Agregamos El titulo Centrado
    local titleHgt = getTextManager():getFontFromEnum(UIFont.Medium):getLineHeight()
    local titleY = 10
    local titleX = self.width / 2
    self.title = ISLabel:new(titleX, titleY, titleHgt, "Experience RPG Panel", 1, 1, 1, 1, UIFont.Medium, true)
    self.title:initialise()
    self.title:instantiate()
    self.title:setAnchorLeft(true)
    self.title:setAnchorRight(false)
    self.title:setAnchorTop(true)
    self.title:setAnchorBottom(false)
    self.title.center = true
    self:addChild(self.title)
    

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

    self:displayData()
    self:menuHabilidades()
end

function SKOExperiencePanel:displayData()
    local titleHgt = getTextManager():getFontFromEnum(UIFont.Medium):getLineHeight()
    local personaje = getPlayer()
    local playerData = SKO_PlayerObject:getPlayerData(personaje)
    if playerData then 
        local playerText = (personaje:getUsername() or "N/A")
        local prestigeText = "Prestigio: " .. (playerData.prestige or 0)
        local totalXpText = "XP Total: " .. (playerData.totalXp or 0)
        local levelText = "Nivel Actual: " .. (playerData.currentLevel or 1)
        local xpText = "Experiencia Actual: " .. (playerData.currentXP or 0)
        local xpGap = (playerData.xpToNextLevel or 100) - (playerData.currentXP or 0)
        local availablePointsText = "Puntos Disponibles: " .. (playerData.availablePoints or 0)
        local xpToNextLevelText = "XP Siguiente Nivel: " .. xpGap

        -- *** Información del Jugador (Formato de "Tabla" mejorado) ***
        local infoStartY = titleHgt + 20 -- Posición Y inicial para la información del jugador
        local labelX = 15 -- Posición X para las etiquetas (izquierda)
        local valueRightX = self.width - 15 -- Extremo derecho donde queremos que termine el valor (15px de margen derecho)
        local valueWidth = self.width / 2 - 20 -- Ancho para las etiquetas de valor
        local currentY = infoStartY
        local rowHeight = getTextManager():getFontFromEnum(UIFont.Medium):getLineHeight() -- Altura de cada fila basada en la fuente
        local font = UIFont.Medium -- Fuente para las etiquetas de información

        -- Función auxiliar para crear y añadir una fila de etiqueta-valor
        local function addInfoRow(labelText, valueRef)
            -- Etiqueta de la izquierda (el "nombre" del campo)
            local label = ISLabel:new(labelX, currentY, rowHeight, labelText, 1, 1, 1, 1, font, true)
            label:initialise()
            label:instantiate()
            self:addChild(label)

            -- Etiqueta de la derecha (el "valor" del campo)
            -- La posición X se calcula para que su borde derecho esté en valueRightX
            -- y su ancho es valueWidth
            local value = ISLabel:new(valueRightX - valueWidth, currentY, rowHeight, valueRef, 1, 1, 1, 1, font, true)
            value:initialise()
            value:instantiate()
            value.rightAlign = true -- Esto sí funciona: alinea el texto *dentro de la caja de la etiqueta* a la derecha
            self:addChild(value)
            currentY = currentY + rowHeight
        end
        
        addInfoRow("Personaje:", playerText)
        addInfoRow(prestigeText, totalXpText)
        addInfoRow(levelText, xpText)
        addInfoRow(availablePointsText, xpToNextLevelText)
    end
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

function SKOExperiencePanel:onXpUpdate()
    if SKOExperiencePanel and not SKOExperiencePanel.instance then return end

    if SKOExperiencePanel.instance and SKOExperiencePanel.instance:getIsVisible() then
        SKOExperiencePanel.instance:removeFromUIManager();
    end
    
    openSKOExperiencePanel();
end

function SKOExperiencePanel:onAbilityDoubleClick(habilidad)
    local personaje = getPlayer()
    SKO_PlayerObject:comprarHabilidad(personaje, habilidad)
    self:removeFromUIManager()
    self:close()
    openSKOExperiencePanel()
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
