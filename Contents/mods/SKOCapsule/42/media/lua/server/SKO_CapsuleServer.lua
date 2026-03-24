local function OnClientCommand(module, command, player, args)
    if module == "SKO_Capsule" then
        if command == "removeVehicle" then
            local vehicle = getVehicleById(args.vehicleId)
            if vehicle then
                vehicle:permanentlyRemove()
            end
        elseif command == "spawnVehicle" then
            local sq = getCell():getGridSquare(args.x, args.y, args.z)
            
            -- Validación extra en servidor
            if not sq or args.z > 0 or sq:getRoom() or not sq:isOutside() then
                sendServerCommand(player, "SKO_Capsule", "spawnFailed", {})
                return 
            end
            
            local vehicle = addVehicleDebug(args.name, args.dir, args.status, sq)
            if vehicle then
                -- Color del vehiculo via script
                vehicle:setColorHSV(args.data.color.h, args.data.color.s, args.data.color.v)

                -- Restaurar keyId, hotwired y trunkLocked aqui en el servidor (autoritativo en B42).
                -- Hacerlo solo via doRestore en el cliente es intermitente: el spawn asigna un
                -- keyId aleatorio nuevo y el cliente puede recibirlo despues de que el servidor
                -- ya lo sobreescribio. Aplicarlo aqui garantiza consistencia antes del doRestore.
                local vData = args.data
                if vData.keyId and vData.keyId > 0 then
                    vehicle:setKeyId(vData.keyId)
                end
                if vData.hotwired then
                    vehicle:setHotwired(true)
                end
                if vData.trunkLocked then
                    vehicle:setTrunkLocked(true)
                end

                sendServerCommand(player, "SKO_Capsule", "doRestore", {
                    vehicleIdStr = tostring(vehicle:getId()),
                    data = args.data,
                    itemId = args.itemId
                })
            else
                sendServerCommand(player, "SKO_Capsule", "spawnFailed", {})
            end
        end
    end
end

Events.OnClientCommand.Add(OnClientCommand)
