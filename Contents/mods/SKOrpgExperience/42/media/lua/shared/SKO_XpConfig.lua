SKO_XpConfig = {};

-- =============================================================================
-- [1] Requisitos de XP por Nivel de Personaje (hasta Nivel 105)
-- =============================================================================
SKO_XpConfig.levelUpRequirements = {};

function SKO_XpConfig.preCalculateLevelRequirements()
    local xpRequiredForNextLevel = 1000;
    local xpScalingFactor = 1.0225;

    SKO_XpConfig.levelUpRequirements[1] = 0;
    for level = 2, 105 do
        SKO_XpConfig.levelUpRequirements[level] = math.floor(xpRequiredForNextLevel);
        xpRequiredForNextLevel = xpRequiredForNextLevel * xpScalingFactor;
    end
end
SKO_XpConfig.preCalculateLevelRequirements();

-- =============================================================================
-- [2] Puntos de Habilidad Ganados por Nivel de Personaje
-- =============================================================================
SKO_XpConfig.pointsPerLevelTier = {
    {levelRange = {1, 5}, points = 1},
    {levelRange = {6, 10}, points = 2},
    {levelRange = {11, 15}, points = 3},
    {levelRange = {16, 20}, points = 5},
    {levelRange = {21, 30}, points = 10},
    {levelRange = {31, 40}, points = 20},
    {levelRange = {41, 50}, points = 30},
    {levelRange = {51, 60}, points = 40},
    {levelRange = {61, 70}, points = 50},
    {levelRange = {71, 80}, points = 60},
    {levelRange = {81, 90}, points = 70},
    {levelRange = {91, 100}, points = 85},
    {levelRange = {101, 105}, points = 100}
};

-- =============================================================================
-- [3] Costo de Puntos de Habilidad por Nivel de Habilidad
-- =============================================================================
SKO_XpConfig.skillPointCosts = {
    [1] = 2, 
    [2] = 4, 
    [3] = 8, 
    [4] = 10, 
    [5] = 20,
    [6] = 35, 
    [7] = 55, 
    [8] = 70, 
    [9] = 85, 
    [10] = 100
};