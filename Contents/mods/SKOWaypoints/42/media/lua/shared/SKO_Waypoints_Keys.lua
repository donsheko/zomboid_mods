-- ======================================================================
-- SKO Waypoints: Registro de Teclas - Build 42
-- ======================================================================

if keyBinding then
    -- Registramos los IDs de las teclas y sus valores por defecto (K y L)
    table.insert(keyBinding, { value = "[SKOWaypoints]", key = nil }) -- Separador/Cabecera en el menú
    table.insert(keyBinding, { value = "SKO_OpenWaypoints", key = Keyboard.KEY_K })
    table.insert(keyBinding, { value = "SKO_OpenStorage", key = Keyboard.KEY_L })
end
