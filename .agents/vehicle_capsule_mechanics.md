# Mecánicas Internas de Contenedor de Vehículo (SKOCapsule)

## ¿Cómo Funciona el Proceso de Encapsulado?

1. Detecta si el jugador tiene equipado en la mano secundaria un `Contenedor de vehiculos` y chequea alrededor del mundo (usando `Events.OnFillWorldObjectContextMenu`) si hay coches accesibles en la misma casilla que el clic derecho del usuario (evitando repetición de menú nativo interactivo `ISVehicleMenu` de Build 42 que se dispara en bucle).
2. Genera un ID híbrido: `id = vehicle:getScript():getName() .. vehicle:getID()`.
3. Renombra al ítem contenedor y le impregna el String del ID usando `item:setName("Contenedor vehiculo:" .. id)`, de esta manera la metadata se ancla a este string y podrá recuperarse si este ítem viaja por el servidor, cofres, o Waypoints.
4. Explora las Partes del vehículo (`vehicle:getPartCount()`).
   - Recrea el inventario de todas las guanteras, cajuelas o asientos. Extrae y serializa los ítems alojados.
   - Lee "GasTank" (Capacidad máxima y cantidad restante).
   - Lee "Battery" (Chequea la Delta de batería cargada actualmente).
   - Copia color `.getColorValue()`.
   - Modifica y guarda el coche entero dentro de una tabla remota de metadatos general bajo `getPlayer():getModData().storedVehicles[ID]`.
5. Ejecuta un borrado absoluto del coche en el mundo o usa un comando remoto al Servidor (según singleplayer/multiplayer).

## ¿Cómo Funciona la Restauración (Spawn)?

1. El script examina si el objeto en mano empieza con `Contenedor vehiculo:` (`string.split(itemName, ":")`). Si esto concuerda, habilita el botón contextual "Restaurar Vehículo" mostrando inclusive el nombre del modelo.
2. A través de `sendClientCommand`, manda las coordenadas (`x`, `y`, `z`) y la data extraída de la llave alojada en `getPlayer():getModData().storedVehicles[ID]`.
3. El Servidor genera la silueta del coche 3D de nuevo (`addVehicleDebug` o `spawnVehicle`).
4. Reimplanta la pintura, abre el capó/puertas o ventanillas tal como estaban antes.
5. Inyecta los items deserializados en el inventario correspondiente.
6. Limpia el `Contenedor de vehículos` devolviéndole su nombre neutral.
7. Elimina toda la estructura de Lua con `storedVehicles[vehicleData.id] = nil` para vaciar memoria.

## Resumen de la Compatibilidad Cruzada con la Nube (Waypoints)

- Al almacenar la Cápsula usando el Panel Waypoints en red, esta se desintegrará a código binario y transitará limpia. Por consiguiente, Waypoints debe clonar el `DisplayName` inyectado, resguardarlo e reimprimirlo cuando el usuario de otro pueblo/base decida bajar la Cápsula nuevamente de la red, para que Zomboid mantenga viva la relación con la base de datos de los coches.
