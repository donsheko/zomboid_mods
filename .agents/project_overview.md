# SKO Collection B42 - Resumen del Proyecto y Contexto

## Descripción General

La `SKO_Collection_B42` engloba una serie de modificaciones para Project Zomboid (Build 42) orientadas a mejorar y expandir mecánicas de almacenamiento, logística y progresión. Los módulos principales en los que estamos trabajando son:

### 1. SKOCapsule (Cápsulas de Vehículos)

Permite a los jugadores comprimir ("encapsular") vehículos completos del mundo real dentro de un ítem de inventario (`Contenedor de vehiculos`). El mod extrae y resguarda toda la información granular del coche (inventario en la guantera y maletero, carga de batería, nivel de gasolina, estado de las puertas/ventanas y cada daño estructural) usando un identificador único enlazado al nombre del ítem.

### 2. SKOWaypoints (Transmisores / Red de Almacenamiento Global)

Añade un sistema de almacenamiento "en la nube". Permite enviar objetos físicos a un inventario de red a través de un Transmisor y retirarlos desde cualquier otro terminal. Este sistema es profundamente complejo porque debe ser capaz de desintegrar un ítem, subir toda su metadata a una red Lua global (modData) y reconstituirlo a la perfección al descargarlo.

## Objetivos Recientes Alcanzados

- **Compatibilidad Extrema entre Nube y Cápsulas**: Logramos que una Cápsula que contiene un Camión blindado repleto de comida y armas pueda subirse a la nube de Waypoints, y que al ser descargada desde otro lugar, siga manteniendo la referencia exacta a la información del vehículo.
- **Adaptación Crítica al Motor B42**: Zomboid cambió drásticamente su manejo de armas y menús contextuales en el salto a la Build 42. Hemos blindado los scripts para prevenir excepciones de sintaxis anticuada de Java.

## Filosofía Técnica del Proyecto

1. **Evitar Pérdida de Datos a toda costa**: El serializador recursivo de inventario es el corazón de ambos mods. Todo `modData` externo, durabilidad de armas o aditamentos debe persistir.
2. **Estabilidad del Menú Contextual**: Evitar múltiples ejecuciones de UI ocasionadas por la forma en que B42 maneja las capas espaciales de los IsoObjects.
3. **Resiliencia ante Excepciones Kahlua**: Envolver variables peligrosas en chequeos de `type() == "function"` para prevenir el colapso del Thread principal del servidor/cliente durante eventos asíncronos o manejo de objetos polimórficos (`InventoryItem` -> `Food` / `HandWeapon`).
