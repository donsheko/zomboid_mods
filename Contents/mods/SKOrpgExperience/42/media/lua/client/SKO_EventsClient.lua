local function onGainXp(character, perk, amount)
    local localPlayer = getPlayer();
    
    if not character or not perk or not amount or amount <= 0 then
        return;
    end
    
    if character ~= localPlayer then
        return;
    end

    local xpToSend = math.floor(amount);
    if xpToSend > 0 then
        if isClient() then
            -- Multiplayer: enviar al server para procesar
            sendClientCommand(localPlayer, "SKO_Events", "SKOAddXP", { amount = xpToSend });
        else
            -- Singleplayer: procesar directamente y actualizar UI
            SKO_PlayerObject:addXP(localPlayer, xpToSend);
            if SKOExperiencePanel and SKOExperiencePanel.instance then
                SKOExperiencePanel.instance:onXpUpdate();
            end
        end
    end
end


local function onZombieDead(zombie)
    local xpKill = 10;
    local localPlayer = getPlayer();
    if isClient() then
        -- Multiplayer: enviar al server
        sendClientCommand(localPlayer, "SKO_Events", "SKOAddXP", { amount = xpKill });
    else
        -- Singleplayer: procesar directamente
        SKO_PlayerObject:addXP(localPlayer, xpKill);
        if SKOExperiencePanel and SKOExperiencePanel.instance then
            SKOExperiencePanel.instance:onXpUpdate();
        end
    end
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