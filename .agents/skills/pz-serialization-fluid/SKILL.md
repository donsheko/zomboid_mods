---
name: pz-serialization-fluid
topic: Project Zomboid Item Serialization
stack: lua, project-zomboid, b42
description: Especialización para la serialización del nuevo sistema de FluidContainer introducido en Build 42.
---

# PZ Serialization Fluid (Build 42)

En Build 42, los ítems que contienen líquidos (botellas, bidones, etc.) ya no dependen únicamente de `DrainableComboItem`. Ahora utilizan el componente `FluidContainer`.

## 📋 Atributos de Fluidos

| Atributo | Método Java | Propósito |
| :--- | :--- | :--- |
| `amount` | `fluidCont:getAmount()` | Cantidad de líquido en mililitros. |
| `type` | `fluidCont:getContainerType()` | ID del tipo de líquido (ej: `Water`, `Petrol`). |
| `tainted` | `fluidCont:isTainted()` | Si el agua está contaminada. |

## 🛠️ Implementación Recomendada

### Serialización
```lua
function serializeFluid(item, data)
    if item:getFluidContainer() then
        local fc = item:getFluidContainer()
        data.fluid = {
            amount = fc:getAmount(),
            type = fc:getContainerType(),
            tainted = fc:isTainted()
        }
    end
end
```

### Deserialización
```lua
function deserializeFluid(item, data)
    if data.fluid and item:getFluidContainer() then
        local fc = item:getFluidContainer()
        -- En B42, para setear fluidos se recomienda usar addFluid
        -- Primero vaciamos por seguridad
        fc:empty()
        if data.fluid.amount > 0 then
            fc:addFluid(data.fluid.type, data.fluid.amount)
            if data.fluid.tainted then
                fc:setTainted(true)
            end
        end
    end
end
```

> [!TIP]
> Si el ítem es un `DrainableComboItem` pero NO tiene `FluidContainer`, usa el sistema de `uses` (skill `pz-serialization-base`).
