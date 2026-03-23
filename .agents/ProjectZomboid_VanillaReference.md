# Project Zomboid Vanilla Reference

Este archivo sirve como guía para localizar los recursos originales del juego y asegurar que las nuevas funciones, recetas e ítems sigan las convenciones de nombres de la Build 42.

## Ruta del Juego
La instalación de Project Zomboid se encuentra en:
`D:\SteamLibrary\steamapps\common\ProjectZomboid` (en el equipo del USER)

## Directorios Clave para Referencia

### Scripts (Ítems y Recetas)
`D:\SteamLibrary\steamapps\common\ProjectZomboid\media\scripts`
- Aquí se encuentran todas las definiciones de ítems, recetas de crafteo y construcciones de la Build 42.

### Lógica (Lua Vanilla)
`D:\SteamLibrary\steamapps\common\ProjectZomboid\media\lua`
- `client/`: Referencia para componentes de UI, comportamientos de inventario y acciones del jugador.
- `server/`: Referencia para lógica de mundo, spawn y persistencia.
- `shared/`: Referencia para definiciones comunes.

### Uso en Tareas
Cuando sea necesario crear nuevos ítems o recetas que interactúen con contenido oficial, se debe consultar esta ruta para obtener los nombres técnicos exactos utilizados en el juego base.
