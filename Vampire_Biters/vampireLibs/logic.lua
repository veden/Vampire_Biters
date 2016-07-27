
require "vampireUtils"

function onLightLevel(vampires, surface)
    -- if light outside vampires die or lord saves surrounding minions by building nest
    if (vampires ~= nil) then
        if surface.darkness < 0.5 then
            if (vampires.lord ~= nil) and vampires.lord.valid then
                local lordPosition = vampires.lord.position
                local den = surface.create_entity({name = "vampire-den",
                                                   position = lordPosition,
                                                   force = "vampire"})
                local guards = surface.find_entities_filtered({area = boundingBox(lordPosition, 15), -- TODO increase capture size based on lordage and evolution
                                                               type = "unit",
                                                               force = "vampire"})
                for i=1, #guards do
                    local guard = guards[i]
                    if (guard.valid) then
                        guard.destroy()
                    end
                end
                vampires.lord = nil
                vampires.den.coffin = den
                vampires.den.guards = #guards - 1
                -- as lord gets older it gets stronger
                vampires.lordAge = vampires.lordAge + 1
            end
            killVampires(vampires.minions)
            killVampires(vampires.freeMinions)
            for i=1, #vampires.clans do
                if (vampires.clans[i] ~= nil) and (vampires.clans[i].valid) then
                    vampires.clans[i].destroy()
                end
            end
        elseif (vampires.den ~= nil) and (vampires.den.coffin ~= nil) and vampires.den.coffin.valid then -- if it is dark and nest exists, free them
            local denPosition = vampires.den.coffin.position
            vampires.lord = surface.create_entity({name = "medium-vampire", -- TODO replace with scaled lord age and evolution factor
                                                   position = denPosition,
                                                   force = "vampire"})
            local freeMinions = vampires.freeMinions
            local newGuardRow = denPosition.x + 5
            denPosition.x = denPosition.x - 10
            denPosition.y = denPosition.y - 5
            for i=1, vampires.den.guards do
                local vamp = surface.create_entity({name = "small-vampire", -- TODO replace with scaled evolution factor
                                                    position = denPosition,
                                                    force = "vampire"})
                freeMinions[#freeMinions+1] = vamp
                if (denPosition.x < newGuardRow) then
                    denPosition.x = denPosition.x + 1
                else
                    denPosition.x = denPosition.x - 10
                    denPosition.y = denPosition.y + 1
                end
            end
            if (#freeMinions >= 10) then
                formClans(vampires, surface)
            end
            vampires.den.guards = 0
            vampires.den.coffin.destroy()
            vampires.den.coffin = nil
        end
    end
    return vampires
end

function raiseVampire(event, vampires, surface)
    -- if the vampire lord or coffin dies reset stats
    if (event.entity == vampires.lord) or (event.entity == vampires.den.coffin) then
        vampires.lordAge = 0
        vampires.lord = nil
        vampires.den.guard = 0
    end
    if (event.force ~= nil) and (event.force.name == "vampire") and (event.entity.force.name == "enemy") then
        local freeMinions = vampires.freeMinions
        local risenPosition = event.entity.position
        local entityType = event.entity.type
        local entityName = event.entity.name
        event.entity.destroy()
        if (vampires.lord ~= nil) and (vampires.lord.valid) and (euclideanDistance(risenPosition, vampires.lord.position) < 20) then
            vampires.lord.health = vampires.lord.prototype.max_health
        end
        if (entityType == "unit")  then
            -- raise just the killed enemy as vampire
            local risenName = string.gsub(string.gsub(entityName, "biter", "vampire"), "spitter", "vampire")
            local risen = surface.create_entity({name = risenName,
                                                 position = risenPosition,
                                                 force = "vampire"})
            freeMinions[#freeMinions+1] = risen
        else
            -- if a spawner is killed then spawn a group of vampires
            risenPosition.x = risenPosition.x - 5
            for i=1, 10 do
                local risen = surface.create_entity({name = "small-vampire", -- TODO replace with scaled evolution factor
                                                     position = risenPosition,
                                                     force = "vampire"})
                risenPosition.x = risenPosition.x + 1
                freeMinions[#freeMinions+1] = risen
            end
        end
        -- large enough groups to start forming unit groups
        if (#freeMinions > 10) then
            vampires = formClans(vampires, surface)
        end
    end
    return vampires
end

function formClans(vampires, surface)
    local freeMinions = vampires.freeMinions
    local clanLeader = findValidUnit(freeMinions)
    -- pick the first unassigned valid unit
    if (clanLeader ~= nil) then
        local newClan = surface.create_unit_group({position = clanLeader.position,
                                                   force = "vampire"})
        local minions = vampires.minions
        for i=1, #freeMinions do
            local vamp = freeMinions[i]
            if (vamp ~= nil) then
                if (vamp.valid) then
                    newClan.add_member(vamp)
                    minions[#minions+1] = vamp
                    freeMinions[i] = nil
                else
                    freeMinions[i] = nil
                end
            end
        end
        vampires.clans[#vampires.clans+1] = newClan
        -- merge clans if they are close enough together
        mergeClans(vampires, surface)
        -- give clans orders
        moveClans(vampires, surface)
    end
    return vampires
end

function moveClans(vampires, surface)
    local clans = vampires.clans
    local clanIndex = 1
    repeat
        local clan = clans[clanIndex]
        if (clan ~= nil) and (clan.valid) then
            -- check pollution is touching unit group, set_autonomous
            if (surface.get_pollution(clan.position) ~= 0) then
                clan.set_autonomous()
            end
            
            local players = game.players
            local playerIndex = 1
            local closestDistance = -1
            local closestPlayer = nil
            repeat
                local distance = euclideanDistance(players[playerIndex].position, clan.position)
                if (closestDistance == -1) or (distance < closestDistance) then
                    closestPlayer = players[playerIndex]
                    closestDistance = distance
                end
                playerIndex = playerIndex + 1
            until (playerIndex >= #players)
            clan.set_command({type = defines.command.attack,
                              target = closestPlayer.character})
            
            -- TODO improve the logic
        end
        clanIndex = clanIndex + 1
    until (clanIndex >= #clans)
end

function mergeClans(vampires, surface) 
    local clans = vampires.clans
    if (#clans >= 2) then
        
        for clanIndex=1, #clans do
            -- pick a clan and merge with any other nearby clans
            local clan = clans[clanIndex]
            if (clan ~= nil) and clan.valid then
                
                for mergedIndex=clanIndex+1, #clans do
                    local mergeClan = clans[mergedIndex]
                    if (mergeClan ~= nil) and (mergeClan.valid) then
                        if (euclideanDistance(clan.position, mergeClan.position) < 100) then
                            local mergeMembers = mergeClan.members
                            for i=1, #mergeMembers do
                                clan.add_member(mergeMembers[i])
                            end
                            mergeClan.destroy()
                            clans[mergedIndex] = nil
                        end
                    end
                end
            
            end
        end
    
    end
    return vampires
end