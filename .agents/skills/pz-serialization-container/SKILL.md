---
name: pz-serialization-container
topic: Project Zomboid Item Serialization
stack: lua, project-zomboid, b42
description: Patrón recursivo para serializar contenedores (Mochilas, Riñoneras, Neveras) y su contenido.
---

# PZ Serialization Container (Build 42)

Los contenedores requieren un procesamiento recursivo para capturar todos los ítems anidados.

## 📋 Lógica de Recursividad

1. Detectar si el ítem es un `InventoryContainer`.
2. Obtener su inventario físico (`getInventory()`).
3. Iterar por todos los ítems y llamar a la función de serialización principal.
4. Guardar los resultados en una tabla `inventory`.

## 🛠️ Implementación Recomendada

### Serialización
```lua
function serializeContainer(item, data)
    if item:IsInventoryContainer() then
        data.inventory = {}
        local inv = item:getInventory()
        local items = inv:getItems()
        for i = 0, items:size() - 1 do
            local innerItem = items:get(i)
            table.insert(data.inventory, SKOLib.Serializer.serializeItemData(innerItem))
        end
    end
end
```

### Deserialización
```lua
function deserializeContainer(item, data)
    if item:IsInventoryContainer() and data.inventory then
        local inv = item:getInventory()
        for _, itemData in ipairs(data.inventory) do
            local innerItem = SKOLib.Serializer.deserializeItemData(itemData)
            if innerItem then
                inv:AddItem(innerItem)
            end
        end
    end
end
```

> [!CAUTION]
> En Build 42, algunos contenedores (ej: neveras) pueden devolver `nil` en `getInventory()` si no están correctamente instanciados. Usa siempre `pcall` o verificaciones de `nil`.
