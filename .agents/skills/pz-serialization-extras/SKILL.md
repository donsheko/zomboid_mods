---
name: pz-serialization-extras
topic: Project Zomboid Item Serialization
stack: lua, project-zomboid, b42
description: Casos especiales de serialización: Llaves, Baterías, Radios y componentes de vehículos.
---

# PZ Serialization Extras (Build 42)

Atributos específicos para ítems con funciones especiales.

## 📋 Atributos Especiales

| Tipo de Ítem | Atributo | Método Java | Propósito |
| :--- | :--- | :--- | :--- |
| **Llave (Key)** | `keyId` | `item:getKeyId()` | ID de la cerradura/vehículo. |
| **Batería/Mechero** | `usedDelta` | `item:getUsedDelta()` | Carga actual (Drainable). |
| **Radio/Walkie** | `channel` | `item:getDeviceData():getChannel()` | Frecuencia sintonizada. |

## 🛠️ Implementación Recomendada

### Serialización
```lua
function serializeExtras(item, data)
    -- Llaves
    if instanceof(item, "Key") then
        data.keyId = item:getKeyId()
    end
    
    -- Dispositivos Electrónicos
    if item:getDeviceData() then
        local dd = item:getDeviceData()
        data.device = {
            channel = dd:getChannel(),
            turnedOn = dd:getIsTurnedOn(),
            battery = dd:getBattery()
        }
    end
end
```

### Deserialización
```lua
function deserializeExtras(item, data)
    -- Llaves
    if data.keyId and instanceof(item, "Key") then
        item:setKeyId(data.keyId)
    end
    
    -- Dispositivos
    if data.device and item:getDeviceData() then
        local dd = item:getDeviceData()
        dd:setChannel(data.device.channel)
        dd:setIsTurnedOn(data.device.turnedOn)
        dd:setBattery(data.device.battery)
    end
end
```

> [!TIP]
> Para ítems de vehículos (Tire, Battery), la `condition` (base) suele ser suficiente, pero las baterías también son `Drainable`, así que el `pz-serialization-base` cubrirá su carga vía `uses`.
