---
name: pz-serialization-clothing
topic: Project Zomboid Item Serialization
stack: lua, project-zomboid, b42
description: Especialización para la serialización de ropa (Clothing), incluyendo suciedad, sangre, parches y personalización visual.
---

# PZ Serialization Clothing (Build 42)

La ropa en Project Zomboid es compleja debido a que el estado se rastrea por partes del cuerpo (BodyPart).

## 📋 Atributos de Ropa

| Atributo | Método Java | Propósito |
| :--- | :--- | :--- |
| `dirtyness` | `item:getDirtyness()` | Nivel de suciedad global. |
| `bloodLevel` | `item:getBloodlevel()` | Nivel de sangre global. |
| `wetness` | `item:getWetness()` | Qué tan mojada está la prenda. |
| `holes` | `item:getVisual():getHoles()` | Tabla de agujeros por parte. |
| `patches` | `item:getPatchType(part)` | Parches de sastrería aplicados. |
| `color` | `item:getVisual():getTint()` | Color personalizado (RGB). |

## 🛠️ Implementación Recomendada

### Serialización
```lua
function serializeClothing(item, data)
    if instanceof(item, "Clothing") then
        local visual = item:getVisual()
        local coveredParts = item:getCoveredParts()
        
        data.clothing = {
            wetness = item:getWetness(),
            dirtyness = item:getDirtyness(),
            blood = item:getBloodlevel(),
            parts = {},
            tint = { r = visual:getTint():getR(), g = visual:getTint():getG(), b = visual:getTint():getB() }
        }
        
        for i=0, coveredParts:size()-1 do
            local part = coveredParts:get(i)
            local partID = part:toString()
            data.clothing.parts[partID] = {
                hole = visual:getHole(part) > 0,
                blood = item:getBloodlevelForPart(part),
                patch = item:getPatchType(part) and item:getPatchType(part):getType() or nil
            }
        end
    end
end
```

### Deserialización
```lua
function deserializeClothing(item, data)
    if data.clothing and instanceof(item, "Clothing") then
        local c = data.clothing
        item:setWetness(c.wetness or 0)
        item:setDirtyness(c.dirtyness or 0)
        item:setBloodLevel(c.blood or 0)
        
        if c.tint then
            local color = ImmutableColor.new(c.tint.r, c.tint.g, c.tint.b, 1)
            item:getVisual():setTint(color)
        end
        
        for partID, pData in pairs(c.parts or {}) do
            local part = BloodBodyPartType.FromString(partID)
            if part then
                if pData.hole then item:getVisual():setHole(part) end
                item:setBlood(part, pData.blood or 0)
                -- Los parches requieren lógica de sastrería más profunda (FabricType)
            end
        end
    end
end
```

> [!WARNING]
> Restaurar parches (`patches`) requiere instanciar el objeto de tela adecuado. Es preferible guardar el `fullType` del material del parche.
