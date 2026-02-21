
SKO_PlayerObject = {}

-- Estructura de datos por defecto para un jugador
local defaultPlayerData = {
    currentLevel = 1,
    currentXP = 0,
    availablePoints = 0,
    xpToNextLevel = 1000,
    perkList = {}, -- Lista de habilidades del jugador
    prestige = 0, -- Nivel de prestigio del jugador
    totalXp = 0, -- Experiencia total acumulada
};

-- Función auxiliar para obtener o inicializar datos de un jugador desde ModData
function SKO_PlayerObject:getPlayerData(player)
    if not player then return nil end
    
    local modData = player:getModData();
    if not modData.SKORPGExperience then
        -- Crear una copia profunda de defaultPlayerData
        local newPlayerData = {};
        for key, value in pairs(defaultPlayerData) do
            newPlayerData[key] = value;
        end
        modData.SKORPGExperience = newPlayerData;
    end
    return modData.SKORPGExperience;
end

-- Función para obtener la XP necesaria para subir al siguiente nivel
function SKO_PlayerObject:getRequiredXPForNextLevel(player)
    local playerData = self:getPlayerData(player);
    if not playerData then return 0 end
    
    if playerData.currentLevel >= 105 then
        return 0; -- No hay más niveles si ya está al máximo
    end
    return SKO_XpConfig.levelUpRequirements[playerData.currentLevel + 1];
end

-- Función para añadir experiencia al personaje
function SKO_PlayerObject:addXP(player, amount)
    if not player or not amount or amount <= 0 then return end
    
    local playerData = self:getPlayerData(player);
    if not playerData then return end

    if playerData.totalXp == nil then playerData.totalXp = 0 end
    if playerData.prestige == nil then playerData.prestige = 0 end
    
    playerData.totalXp = playerData.totalXp + amount;
    playerData.currentXP = playerData.currentXP + amount;

    while true do
        local requiredXP = self:getRequiredXPForNextLevel(player); 
        local scalamiento = 1 + (playerData.prestige * 0.1);
        requiredXP = math.floor(requiredXP * scalamiento);

        if playerData.currentLevel >= 105 and playerData.currentXP < requiredXP then
            break;
        end

        if playerData.currentXP >= requiredXP then
            if playerData.currentLevel < 105 then
                playerData.currentXP = playerData.currentXP - requiredXP;
                playerData.currentLevel = playerData.currentLevel + 1;
                self:addAvailablePointsForLevel(player, playerData.currentLevel);

                print(string.format("SKORPGExperience: ¡Has subido al Nivel %d (Prestigio %d)!", playerData.currentLevel, playerData.prestige));
                print(string.format("SKORPGExperience: Puntos disponibles: %d", playerData.availablePoints));
                player:Say("He subido al Nivel " .. playerData.currentLevel .. "! Puntos disponibles: " .. playerData.availablePoints);

            elseif playerData.currentLevel == 105 then
                playerData.prestige = playerData.prestige + 1;
                playerData.currentLevel = 1;
                playerData.currentXP = playerData.currentXP - requiredXP;

                print(string.format("SKORPGExperience: ¡HAS PRESTIGIADO! Nivel de Prestigio %d. Nivel actual %d.", playerData.prestige, playerData.currentLevel));
                player:Say("Nuevo nivel de Prestigio " .. playerData.prestige .. "! Nivel actual " .. playerData.currentLevel);
            end
        else
            break;
        end
    end

    if playerData.currentXP < 0 then playerData.currentXP = 0 end
    local finalBaseRequiredXP = self:getRequiredXPForNextLevel(player);
    local finalScalamiento = 1 + (playerData.prestige * 0.1);
    finalBaseRequiredXP = math.floor(finalBaseRequiredXP * finalScalamiento);
    playerData.xpToNextLevel = math.floor(finalBaseRequiredXP);
end

-- Función para añadir puntos de habilidad basados en el nivel alcanzado
function SKO_PlayerObject:addAvailablePointsForLevel(player, level)
    local playerData = self:getPlayerData(player);
    if not playerData then return end
    
    for _, tier in ipairs(SKO_XpConfig.pointsPerLevelTier) do
        if level >= tier.levelRange[1] and level <= tier.levelRange[2] then
            playerData.availablePoints = playerData.availablePoints + tier.points;
            return;
        end
    end
end

-- Función para resetear datos de un jugador específico
function SKO_PlayerObject:resetPlayerData(player)
    if not player then return false end
    
    local modData = player:getModData();
    local newPlayerData = {};
    for key, value in pairs(defaultPlayerData) do
        newPlayerData[key] = value;
    end
    modData.SKORPGExperience = newPlayerData;
    
    local playerID = tostring(player:getUsername());
    print(string.format("SKORPGExperience [%s]: Datos del jugador reseteados", playerID));
    return true;
end

function SKO_PlayerObject:obtenerHabilidades(personaje)
    if not personaje then return nil end
    
    local playerData = self:getPlayerData(personaje);

    if playerData then
        local perkList = {};
        for i = 0, PerkFactory.PerkList:size() - 1 do
            local perk = PerkFactory.PerkList:get(i);
            if perk:getParent() ~= Perks.None then
                local level = personaje:getPerkLevel(perk);
                local xpFaltante = perk:getTotalXpForLevel(level + 1) - personaje:getXp():getXP(perk)
                local skillPointCost = SKO_PlayerObject.getSkillPointCost(level + 1);
                if level < 10 then
                    table.insert(perkList, {
                        name = perk:getName(),
                        level = level,
                        skillPointCost = skillPointCost,
                        xpFaltante = xpFaltante,
                        perk = perk,
                    });
                end
            end
        end
        table.sort(perkList, function(a, b)
            return a.name < b.name;
        end);
        playerData.perkList = perkList;

        return perkList;
    end
end

function SKO_PlayerObject:comprarHabilidad(personaje, habilidad)
    if not personaje or not habilidad then
        print("SKORPGExperience: ERROR - Datos de personaje o habilidad inválidos para compararHabilidad.");
        return false;
    end

    if habilidad.level >= 10 then
        print("Esta habilidad ya se encuentra al nivel maximo.")
        return false;
    end

    local playerData = self:getPlayerData(personaje);
    if playerData then
        local currentPoints = playerData.availablePoints;
        local skillPointCost = habilidad.skillPointCost;
        local newLevel = habilidad.level + 1;
        local perk = habilidad.perk;
        if currentPoints < skillPointCost then
            print(string.format("SKORPGExperience: No tienes suficientes puntos de habilidad. Necesitas %s puntos, pero tienes %s.", skillPointCost, currentPoints));
            personaje:Say("No tienes suficientes puntos de habilidad para comprar esta habilidad.");
            return false;
        end
        
        personaje:getXp():setXPToLevel(perk, newLevel);
        personaje:LevelPerk(perk);
        personaje:Say("Has comprado el nivel " .. newLevel .. ". de la habilidad " .. habilidad.name);
        playerData.availablePoints = currentPoints - skillPointCost;
        self:obtenerHabilidades(personaje); -- Actualizar la lista de habilidades
        personaje:transmitModData();
    end
end

function SKO_PlayerObject.getSkillPointCost(targetSkillLevel)
    return SKO_XpConfig.skillPointCosts[targetSkillLevel] or 0;
end

