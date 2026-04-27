---
name: pz-serialization-food
topic: Project Zomboid Item Serialization
stack: lua, project-zomboid, b42
description: Especialización para ítems consumibles (Food), gestionando nutrición, frescura, cocción y estados de congelación.
---

# PZ Serialization Food (Build 42)

El sistema de comida en B42 es más dinámico con la introducción de nuevos estados de putrefacción y procesamiento.

## 📋 Atributos de Comida

| Atributo | Método Java | Propósito |
| :--- | :--- | :--- |
| `age` | `item:getAge()` | Tiempo transcurrido (afecta frescura). |
| `cooked` | `item:isCooked()` | Si ha sido cocinado. |
| `burnt` | `item:isBurnt()` | Si se ha quemado. |
| `frozenTime` | `item:getFrozenTime()` | Progreso de congelación/descongelación. |
| `poison` | `item:getPoisonPower()` | Nivel de toxicidad (si aplica). |
| `nutrients` | `item:getCalories()`, etc. | Calorías, Carbohidratos, Lípidos, Proteínas. |

## 🛠️ Implementación Recomendada

### Serialización
```lua
function serializeFood(item, data)
    if instanceof(item, "Food") then
        data.food = {
            age = item:getAge(),
            cooked = item:isCooked(),
            burnt = item:isBurnt(),
            frozenTime = item:getFrozenTime(),
            poison = item:getPoisonPower(),
            hung = item:getHungChange(),
            calories = item:getCalories(),
            carbs = item:getCarbohydrates(),
            lipids = item:getLipids(),
            proteins = item:getProteins()
        }
    end
end
```

### Deserialización
```lua
function deserializeFood(item, data)
    if data.food and instanceof(item, "Food") then
        local f = data.food
        item:setAge(f.age or 0)
        item:setCooked(f.cooked or false)
        item:setBurnt(f.burnt or false)
        item:setFrozenTime(f.frozenTime or 0)
        item:setPoisonPower(f.poison or 0)
        item:setHungChange(f.hung or item:getHungChange())
        item:setCalories(f.calories or 0)
        item:setCarbohydrates(f.carbs or 0)
        item:setLipids(f.lipids or 0)
        item:setProteins(f.proteins or 0)
    end
end
```

> [!IMPORTANT]
> En Build 42, algunos alimentos procesados pueden tener `modData` que indica ingredientes específicos (ej: ensaladas, guisos). La serialización de `modData` (base) es crítica para no perder estas recetas personalizadas.
