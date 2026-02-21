local function onGainXp(character, perk, amount)
    local commandName = "SKOAddXP";
    local localPlayer = getPlayer();
    
    if not character or not perk or not amount or amount <= 0 then
        return;
    end
    
    if character ~= localPlayer then
        print("SKORPGExperience [CLIENT]: El personaje no es el jugador local, no se enviará el comando.");
        return;
    end

    if amount > 0 then
        local xpToSend = math.floor(amount);
        local args = { amount = xpToSend };
        if xpToSend > 0 then
            sendClientCommand(localPlayer, "SKO_Events", commandName, args);
        end
    end
end


local function onZombieDead(zombie)
    local xpKill = 10; -- Xp por zombie asesinado
    local localPlayer = getPlayer();
    sendClientCommand(localPlayer, "SKO_Events", "SKOAddXP", { amount = xpKill });
    print("SKORPGExperience [CLIENT]: Zombie asesinado, se ha añadido " .. xpKill .. " XP al jugador.");
end

local function onServerCommand(module, command, args)
    if module == "SKO_Events" and command == "UpdateUI" then
        if SKOExperiencePanel and SKOExperiencePanel.instance then
            SKOExperiencePanel.instance:onXpUpdate();
        end
    end
end

Events.OnServerCommand.Add(onServerCommand);
Events.AddXP.Add(onGainXp);
Events.OnZombieDead.Add(onZombieDead);