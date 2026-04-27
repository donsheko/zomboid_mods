---
name: pz-serialization-weapon
topic: Project Zomboid Item Serialization
stack: lua, project-zomboid, b42
description: Especialización para la serialización de armas de fuego (HandWeapon), incluyendo munición, recámara, accesorios y modos de disparo.
---

# PZ Serialization Weapon (Build 42)

Las armas de fuego requieren un seguimiento preciso de la munición y el estado mecánico para evitar duplicación o pérdida de balas.

## 📋 Atributos de Armas

| Atributo | Método Java | Propósito |
| :--- | :--- | :--- |
| `ammo` | `item:getCurrentAmmoCount()` | Balas en el cargador/arma. |
| `jammed` | `item:isJammed()` | Si el arma está encasquillada. |
| `chambered` | `item:isRoundChambered()` | Bala en la recámara. |
| `spentRound` | `item:isSpentRoundChambered()` | Vaina servida en la recámara. |
| `spentCount` | `item:getSpentRoundCount()` | Contador de vainas para revólveres. |
| `fireMode` | `item:getFireMode()` | Modo actual (Auto, Single, Safe). |
| `parts` | `item:getWeaponPart(slot)` | Accesorios instalados (Mira, Correa, etc.). |

## 🛠️ Implementación Recomendada

### Serialización
```lua
function serializeWeapon(item, data)
    if instanceof(item, "HandWeapon") then
        data.weapon = {
            ammo = item:getCurrentAmmoCount(),
            jammed = item:isJammed(),
            chambered = item:isRoundChambered(),
            spentRound = item:isSpentRoundChambered(),
            spentCount = item:getSpentRoundCount(),
            fireMode = item:getFireMode(),
            parts = {}
        }
        
        local partSlots = {"Scope", "Clip", "Sling", "Stock", "Canon", "RecoilPad"}
        for _, slot in ipairs(partSlots) do
            local part = item:getWeaponPart(slot)
            if part then
                data.weapon.parts[slot] = SKOLib.Serializer.serializeItemData(part)
            end
        end
    end
end
```

### Deserialización
```lua
function deserializeWeapon(item, data)
    if data.weapon and instanceof(item, "HandWeapon") then
        local w = data.weapon
        item:setCurrentAmmoCount(w.ammo or 0)
        item:setJammed(w.jammed or false)
        item:setRoundChambered(w.chambered or false)
        item:setSpentRoundChambered(w.spentRound or false)
        item:setSpentRoundCount(w.spentCount or 0)
        if w.fireMode then item:setFireMode(w.fireMode) end
        
        for slot, pData in pairs(w.parts or {}) do
            local part = SKOLib.Serializer.deserializeItemData(pData)
            if part then item:attachWeaponPart(part) end
        end
    end
end
```

> [!IMPORTANT]
> En MP, tras deserializar un arma y cambiar su estado de munición, es imperativo llamar a `syncHandWeaponFields(player, item)` si el arma está equipada.
