---
name: pz-serialization-base
topic: Project Zomboid Item Serialization
stack: lua, project-zomboid, b42
description: Patrón base para la serialización de InventoryItem en Build 42. Asegura la persistencia de atributos fundamentales como tipo, nombre personalizado y estado básico.
---

# PZ Serialization Base (Build 42)

Este skill define el contrato mínimo para convertir un `InventoryItem` de Java a una tabla Lua persistente.

## 📋 Atributos Base Requeridos

| Atributo | Método Java | Propósito |
| :--- | :--- | :--- |
| `fullType` | `item:getFullType()` | ID único del ítem (ej: `Base.Axe`). |
| `customName` | `item:getName()` | Nombre inyectado vía `setName()` (distinto del DisplayName). |
| `condition` | `item:getCondition()` | Durabilidad actual. |
| `favorite` | `item:isFavorite()` | Estado de favorito en el inventario. |
| `modData` | `item:getModData()` | Tabla de datos personalizados de otros mods. |

## 🛠️ Implementación Recomendada

### Serialización
```lua
function serializeBase(item)
    local data = {
        fullType = item:getFullType(),
        condition = item:getCondition(),
        favorite = item:isFavorite(),
        customName = item:getName() ~= item:getScriptItem():getDisplayName() and item:getName() or nil,
        modData = {}
    }
    
    -- Copiar ModData (solo tipos primitivos)
    local itModData = item:getModData()
    for k,v in pairs(itModData) do
        if type(v) ~= "userdata" and type(v) ~= "function" then
            data.modData[k] = v
        end
    end
    
    return data
end
```

### Deserialización
```lua
function deserializeBase(data)
    local item = instanceItem(data.fullType)
    if not item then return nil end
    
    item:setCondition(data.condition or item:getConditionMax())
    item:setFavorite(data.favorite or false)
    if data.customName then item:setName(data.customName) end
    
    if data.modData then
        local mData = item:getModData()
        for k,v in pairs(data.modData) do mData[k] = v end
    end
    
    return item
end
```

> [!IMPORTANT]
> En Build 42, siempre usa `pcall` al instanciar ítems (`instanceItem`) para evitar crashes si un mod ha sido removido.
