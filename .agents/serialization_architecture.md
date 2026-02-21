# Arquitectura de Serialización (Inventory y Vehículos)

## Cómo Funciona `serializeItemData()` y `deserializeItemData()`

Dado que la Nube (Waypoints) mueve ítems enteros como texto codificado dentro de una tabla remota de metadatos, cualquier propiedad del ítem debe transcribirse manualmente a Lua usando la API de Project Zomboid antes de borrar el ítem físico.

**Las piezas fundamentales que se registran son:**

1. **Identificadores Base**:
   - `fullType` (`Base.Axe`)
   - `name` (Nombre traducido estandarizado)
   - `customName` (Nombre modificado por el jugador o modificado por `SKOCapsule` para alojar referencias al coche: Ej. `Contenedor vehiculo:StepVan1024`). Es CRÍTICO guardarlo en `cData.customName = item:getName()` para no romper la conexión.
   - `condition` y posibles deltas de baterías o durabilidad.

2. **Categorías Sensibles ("Food")**:
   - La comida guarda sus valores biológicos: `hungerChange`, `thirst`, `boredom`, `carbs`, `lipids`, `proteins`, `calories`.
   - Modificadores de estado físico: `cooked`, `burn`, `freshness`, `rotten`.
   - **Regla Intocable**: NUNCA invocar `isTaintedWater()` en comida sólida. Project Zomboid (B42) lanza Excepciones nativas (Java Kahlua Engine) que crashean los scripts porque el objeto `GranolaBar` o similares no comparten la herencia de líquidos.

3. **Armas ("HandWeapon" en Build 42)**:
   - Guardar la munición en recámara mediante `getCurrentAmmoCount()`.
   - Extraer todos los accesorios montados en el arma (miras telescópicas, láseres, silenciadores, etc.).
   - **Regla B42**: Se debe usar exclusivamente `item:getWeaponPart("Scope")`, `item:getWeaponPart("Clip")`, etc.
   - Las antiguas funciones explícitas como `item:getScope()` ya no existen y detendrán la ejecución. Previamente agregar un chequeo `if type(item.getWeaponPart) == "function"` para descartar Destornilladores o armas cortas que heredan parcialmente HandWeapon pero sin soporte para partes de armamento.

4. **Iteración Recursiva en Mochilas (`IsInventoryContainer`)**:
   - Si el objeto actual tiene ítems dentro, la función `serialize` itera `getInventory():getItems()`, llama a sí misma recursivamente para cada objeto hijo, y los inyecta en la tabla `inventory`.
   - Durante `deserialize`, el script recorre todos los `innerItem` creados y los añade uno por uno dentro del `container:AddItem()` de la mochila re-fabricada.

5. **Alineación con modData Extraña**:
   - Escaneamos todo el `item:getModData()` del ítem y anexamos en la sub-tabla `customData.modData` todos los pares Key-Value siempre y cuando no sean de tipo "userdata" o "function" (no viajan bien por la red serializada de Lua).
