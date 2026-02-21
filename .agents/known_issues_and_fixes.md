# Bugs Resolvidos y Mejoras Anotadas (SKO Collection)

A continuación, una lista de los errores crudos en Zomboid Build 42 encontrados y resueltos, junto con la forma en que se deben tratar a futuro:

## 1. Excepciones `isTaintedWater()` en Objetos Tipo 'Food' (Menú de Nube / Cápsula)

- **Problema:** Un error nativo Java cortaba la serialización silenciando todos los demás ítemes del jugador cada vez que el jugador guardaba una "Barra de Granola" (Base.GranolaBar).
- **Causa:** El antiguo iterador `serializeItem` le exigía el valor del estado contaminado `item:isTaintedWater()` a cualquier cosa de tipo `Food` genérico. El Build 42 de Project Zomboid es muy restrictivo y lanza excepciones (`fail`) al leer variables de métodos que no son de tipo líquido, crasheando el Thread Principal.
- **Solución:** Eliminamos los intentos genéricos de leer polimorfismos de TaintedWater del inventario. `serializeItemData()` asume alimentos secos y preserva todo (Calorías, Macronutrientes, Podredumbre o Quemadura), pero no contamina agua.

## 2. Invalidez de Funciones de Armas Deprecated (`getScope()`) en B42

- **Problema:** En Build 41 el código dependía de métodos explícitos en la clase base HandWeapon para recuperar accesorios (miras, clips, culatas).
- **Causa:** Build 42 borró `item:getScope()` centralizándolo todo en una matriz Hash leída mediante Textos Arbitrarios `item:getWeaponPart("Name")`. Adicionalmente, los Destornilladores, cuchillos y otras herramientas son consideradas `HandWeapons` nativamente pero no alojan métodos de accesorios de ametralladoras.
- **Solución:** Verificando `if type(item.getWeaponPart) == "function"` salvamos las aspas filosas de las herramientas. Invocamos las miras con strings `getWeaponPart("Scope")`, `getWeaponPart("Clip")`, etc.

## 3. Duplicación Masiva (x5 x7) de Botones de Cápsula en Vehículos

- **Problema:** El menú derecho se inundaba con la opción "Encapsular Vehículo" 7 veces seguidas en un clic.
- **Causa:** Sobrescribíamos la función `ISVehicleMenu.FillMenuOutsideVehicle`. El motor interno B42 escanea el exterior, el interior, los cristales y las salpicaderas en la línea visual del puntero, ejecutando los overrides UI por CADA pieza del vehículo encontrada en la misma baldosa (`getSquare`).
- **Solución:** Abandono total de las sobreescrituras en la interfaz base (`ISContextMenu.lua`). Todo se inyectó a través del despachador global `Events.OnFillWorldObjectContextMenu.Add()`. Se hizo un bucle `break` por cada tabla `worldobjects` obteniendo el iso-vehicle del entorno y anulando copias.

## 4. El Cliche de las Categorías No Desplegables de Transmisores (Combo Box)

- **Problema:** El combo-box de Transmisores podía desplegar Categorías en pantalla (`Todos`, `Food`, `Weapon`) pero al darle Click jamás disparaba eventos de filtro.
- **Causa:** La clase visual Zomboid `ISComboBox` olvida mapear y disparar los callbacks si no configuran explícitamente sus métodos post-inicialización en su constructor de tablas jerárquico.
- **Solución:** Enganche de gatillo manual `comboCategory.onChange = self.onCategoryChange` y estableciendo `comboCategory.target = self`. Además se encriptó un sub-fichero para organizar el output alfabéticamente (de la A a la Z) usando tablas numéricas transitorias `table.sort`.

## 5. El Bug del Período de Amnesia del Contenedor de Cápsula en los Waypoints

- **Problema:** Al descargar un vehículo del panel de la Nube se recibía de vuelta el contenedor original pero sin sus propiedades mágicas (decía el nombre base y no tenía la camioneta adentro). El maletero guardado seguía en la Base de Datos fantasma.
- **Causa:** La variable serializadora `itemData` no transmitía metadatos de "Nombres visuales del string del texto renderizado del jugador o el mod". Un Base.GranolaBar genérico reconstruido al bajar del Transmisor carecía de la etiqueta `Contenedor Vehiculo:StepVan2531` arrojando un objeto desnudo desconectado de la memoria RAM global modData.
- **Solución:** Modificación dual. En Upload se transcribió un inyector adicional: `customData.customName = item:getName()`. En Download interceptamos el constructor puro forzando a re-bautizar las cosas que tuvieran esta variable viva `if cData.customName then newItem:setName(cData.customName) end`.

## 6. Excepciones `getUsedDelta()` en Objetos Tipo 'DrainableComboItem'

- **Problema:** Un error nativo Java salta de `getItemCustomData()` al intentar guardar en la Cápsula ciertos objetos gastables (ej: Pañuelos o Papel Higiénico / `Base.Tissue`), deteniendo por completo al juego.
- **Causa:** En versiones previas como B41, todos los ítems consumibles manejaban su remanente a través de la función genérica `getUsedDelta()`. En B42 esto cambió fundamentalmente: algunos de estos objetos suprimieron de raíz el método ocasionando colapsos de llamada ("attempt to call a nil value").
- **Solución:** Se implementó como método predilecto B42 `getCurrentUsesFloat()`. Si falla, cae al antiguo `getUsedDelta()`, y siempre están resguardados por verificación del tipo de método `type() == "function"`.
