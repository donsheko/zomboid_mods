# SKO Collection B42 — Guía de Contexto para Claude

## Instalación del Juego
`D:\SteamLibrary\steamapps\common\ProjectZomboid`
- Scripts (ítems/recetas): `media/scripts`
- Lua vanilla referencia: `media/lua` (`client/`, `server/`, `shared/`)

---

## Estructura del Proyecto

```
Contents/mods/
├── SKOLib/42/media/lua/
│   ├── shared/
│   │   └── SKOLib_ItemSerializer.lua   ← Serializer compartido (NÚCLEO)
│   └── client/
│       └── SKOLib_PanelUtils.lua
├── SKOCapsule/42/media/lua/
│   ├── client/SKO_CapsuleClient.lua    ← UI + storeVehicle + OnServerCommand
│   └── server/SKO_CapsuleServer.lua    ← OnClientCommand (spawn/remove vehicle)
└── SKOWaypoints/42/media/lua/
    └── client/UI/SKO_WaypointStoragePanel.lua  ← Panel nube (upload/download)
```

> `SKO_CapsuleClient.lua` (en `client/`) contiene la lógica del jugador: UI, serialización, `OnServerCommand`. `SKO_CapsuleServer.lua` (en `server/`) maneja los comandos del servidor: `OnClientCommand`, spawn de vehículos. El naming es convencional y correcto.

---

## Reglas Críticas de B42

### Lua
- **Motor**: KahluaVM (Lua 5.1). **No soporta `goto`**. Usar `if/else` para flujo de control.
- **`instanceItem(fullType)`**: Solo funciona para ítems con script estático. Los muebles recogibles de B42 (`Base.appliances_*`, `Base.furniture_*`) se crean dinámicamente y `instanceItem` retorna `nil` para ellos.
- **`pcall` obligatorio**: Envolver llamadas peligrosas (`getInventory()`, `AddItem()`, `IsInventoryContainer()`, `getCurrentUsesFloat()`) siempre que operen sobre tipos polimórficos.
- **`type(item.method) == "function"`**: Verificar antes de llamar métodos que pueden no existir en subtipos (ej: `getWeaponPart`, `getCurrentUsesFloat`).

### Arquitectura cliente/servidor
- **Propiedades de vehículos son autoritativas en el servidor**. Llamar `setKeyId()`, `setHotwired()`, `setTrunkLocked()` desde el cliente vía `doRestore` es intermitente — el servidor puede sobrescribirlos con los valores del spawn. **Siempre aplicar estas propiedades en el handler del servidor** (en `OnClientCommand`).
- `sendClientCommand(player, module, command, args)` → cliente a servidor.
- `sendServerCommand(player, module, command, args)` → servidor a cliente.
- `Events.OnClientCommand` se registra en el servidor.
- `Events.OnServerCommand` se registra en el cliente.

### API de muebles recogibles (ISMoveableSpriteProps)
Para spawnear un mueble recogible que `instanceItem` no puede recrear:
```lua
-- spriteName se deriva del fullType: "Base.appliances_refrigeration_01_1" → "appliances_refrigeration_01_1"
local spriteName = itData.worldSprite or (itData.fullType and itData.fullType:match("%.(.+)$"))
local dummyItem = instanceItem("Base.Plank")  -- dummy; no se usa para IsoThumpable sólidos
local props = ISMoveableSpriteProps.new(spriteName)
if props and props.isMoveable then
    props:placeMoveableInternal(square, dummyItem, spriteName)
end
```
- `ISMoveableSpriteProps.lua` está en `shared/Moveables/` — accesible desde cliente y servidor.
- Para `IsoStove` sí usa `_item:getCondition()`. Para `IsoThumpable` sólidos (neveras, refrigeradores) **no accede a `_item`**.
- El mueble spawneado queda **vacío** (el contenido previo no se restaura).

---

## Serializer (SKOLib_ItemSerializer.lua)

### Campos serializados
| Campo | Descripción |
|---|---|
| `fullType` | Tipo completo del ítem (`Base.Axe`) |
| `name` | Nombre traducido |
| `condition` | Durabilidad |
| `customData.customName` | **CRÍTICO** para SKOCapsule: guarda `item:getName()` (incluye `"Contenedor vehiculo:ID"`) |
| `customData.uses` | Usos restantes en DrainableComboItem |
| `customData.ammo` + `parts` | Munición y accesorios de HandWeapon |
| `customData.food` | Propiedades nutricionales de Food |
| `modData` | modData del ítem (sin userdata ni functions) |
| `inventory` | Items internos (recursivo, para InventoryContainer) |
| `worldSprite` | Sprite world del ítem si es mueble B42 (`item:getWorldSprite()`) |

### Reglas del serializer
- **NUNCA llamar `isTaintedWater()`** en Food genérico — lanza excepción Java en B42.
- Para armas usar `getWeaponPart("Scope")`, nunca `getScope()` (deprecated B42).
- El llenado del inventario interno está protegido con `pcall` individual por cada inner item — un fallo en un ítem interno no cancela la deserialización del contenedor completo.

---

## Bugs Conocidos y Resueltos

### SKOCapsule: Color y llave cambian al restaurar (intermitente)
- **Causa**: `setKeyId()`, `setHotwired()`, `setTrunkLocked()` se aplicaban solo en el cliente vía `doRestore`. El spawn del servidor asigna un `keyId` aleatorio nuevo y puede sobrescribir los valores del cliente.
- **Fix**: Aplicar `setKeyId`, `setHotwired`, `setTrunkLocked` en `SKO_CapsuleServer.lua` (servidor) inmediatamente después de `addVehicleDebug`, antes de enviar `doRestore`.

### SKOWaypoints: Contenedores (neveras, etc.) no descargan
- **Causa**: `instanceItem("Base.appliances_*")` retorna `nil` — muebles B42 no tienen script estático. El error lanzaba excepción silenciosa, el sonido se reproducía igual pero el ítem quedaba en la nube.
- **Fix A**: `pcall` alrededor de `deserializeItemData` y `AddItem` en `onDownloadItem`.
- **Fix B**: Fallback de spawn con `ISMoveableSpriteProps:placeMoveableInternal` cuando `instanceItem` falla.
- **Fix C**: `pcall` individual en cada inner item dentro del serializer para no cancelar deserialización del contenedor padre.

### SKOWaypoints: Duplicación de botones de encapsulado
- Usar `Events.OnFillWorldObjectContextMenu` con `break` al encontrar el primer vehículo. No sobreescribir `ISVehicleMenu`.

### ISComboBox no dispara onChange
- Necesita `comboCategory.onChange = self.onCategoryChange` y `comboCategory.target = self` post-inicialización.

### `getCurrentUsesFloat()` vs `getUsedDelta()`
- B42 usa `getCurrentUsesFloat()`. Siempre verificar con `type() == "function"` antes de llamar.

---

## Filosofía del Proyecto

1. **No modificar SKOLib si el fix puede ir en el mod específico** — SKOLib es compartido por todos los mods.
2. **Excepciones al punto anterior**: Cambios que solo agregan robustez (pcall, nil-checks) sin alterar comportamiento exitoso son aceptables en SKOLib.
3. **Compatibilidad con saves existentes**: El deserializador tiene un path legacy para datos viejos sin `fullType`.
4. **Server-authoritative para vehículos**: Toda modificación de estado de vehículo debe ejecutarse en el servidor.
