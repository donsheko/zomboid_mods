Events.OnClientCommand.Add(function(module, command, player, args)
    if module == "SKO_Events" and command == "SKOAddXP" then
        if player and args and args.amount and args.amount > 0 then
            SKO_PlayerObject:addXP(player, args.amount);
            player:transmitModData();
            sendServerCommand(player, "SKO_Events", "UpdateUI", {});
        end
    end
end);