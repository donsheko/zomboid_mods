---
name: pz-serialization-literature
topic: Project Zomboid Item Serialization
stack: lua, project-zomboid, b42
description: Especialización para libros, revistas y medios grabados (cintas, vinilos) en Build 42.
---

# PZ Serialization Literature & Media (Build 42)

Asegura que el progreso de lectura y los datos de medios grabados persistan.

## 📋 Atributos de Literatura

| Atributo | Método Java | Propósito |
| :--- | :--- | :--- |
| `pagesRead` | `item:getAlreadyReadPages()` | Páginas leídas actualmente. |
| `mediaID` | `item:getMediaData():getId()` | ID del contenido (para cintas/vinilos). |

## 🛠️ Implementación Recomendada

### Serialización
```lua
function serializeLiterature(item, data)
    if item:getNumberOfPages() > 0 then
        data.literature = {
            pages = item:getAlreadyReadPages()
        }
    end
    
    -- Soporte para Medios Grabados (B42)
    if item.getMediaData and item:getMediaData() then
        data.mediaID = item:getMediaData():getId()
    end
end
```

### Deserialización
```lua
function deserializeLiterature(item, data)
    if data.literature and item:getNumberOfPages() > 0 then
        item:setAlreadyReadPages(data.literature.pages or 0)
    end
    
    -- Restaurar Medio Grabado
    if data.mediaID and item.setMediaData then
        local mediaData = getZomboidRadio():getRecordedMedia():getMediaDataFromID(data.mediaID)
        if mediaData then
            item:setMediaData(mediaData)
        end
    end
end
```

> [!NOTE]
> En Build 42, los periódicos y fotos ahora pueden tener metadatos de mapas. Asegúrate de que `modData` se serialice correctamente (skill `pz-serialization-base`) ya que PZ guarda ahí los datos de "Mapa Revelado".
