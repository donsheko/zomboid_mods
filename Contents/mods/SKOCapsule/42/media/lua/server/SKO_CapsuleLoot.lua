-- ==========================================================
-- SKO Capsule - Loot Distribution (Build 42.15 Compatible)
-- ==========================================================

require 'Items/ProceduralDistributions'

local function SKO_Capsule_LootInjection()
    local item = "SKOCapsule.ContenedorVehiculos"
    local dist = ProceduralDistributions.list

    -- Definición de lugares y probabilidades
    -- Nota: En PZ, 1.0 es "común", 0.1 es "raro", 0.01 es "extremadamente raro"
    local lootTable = {
        -- [Categoría de Loot] = Probabilidad
        ["MechanicTools"]      = 0.1,   -- Talleres (Estantes de herramientas)
        ["AutoRepair"]         = 0.05,  -- Talleres (Contenedores de repuestos)
        ["ElectronicStoreMisc"]= 0.05,  -- Tiendas de electrónica
        ["MilitaryMisc"]       = 0.2,   -- Bases militares (General)
        ["ArmySupplyCrate"]    = 0.1,   -- Cajas de suministros militares
        ["SurvivorCache"]      = 0.1,   -- Alijos de supervivientes (Casas tapiadas)
        ["GarageTools"]        = 0.02,  -- Garajes residenciales (Muy raro)
        ["Toolbox"]            = 0.05,  -- Cajas de herramientas portátiles
        ["VehicleMaintenance"] = 0.08,  -- (Nueva en B42) Áreas de mantenimiento
    }

    for distribution, chance in pairs(lootTable) do
        if dist[distribution] then
            table.insert(dist[distribution].items, item)
            table.insert(dist[distribution].items, chance)
        end
    end
end

-- OnPostDistributionMerge es el evento correcto para B42.15
Events.OnPostDistributionMerge.Add(SKO_Capsule_LootInjection)
