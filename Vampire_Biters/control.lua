require "util"
require "tests"
require "vampireLibs/logic"

local vampires
local regions
local surface

---------------------------------------------
-- Only called once on start of new world or when adding to a save without the mod
function on_initialize()
    game.create_force('vampire')
    -- create table in global persistance store
    global.vampires = {}
    
    -- pass reference of global store to module local for faster reference
    vampires = global.vampires
end

-- called only on load of save game, game object is not available
function on_load() 
    vampires = global.vampires
end

function on_running(event)
    if (event.tick % 360 == 0) then
        vampires = onLightLevel(vampires, surface)
    end
end

function on_remove(event)
    vampires = raiseVampire(event, vampires, surface)
end

-- called on chunk generation, chunks will generate past explored area by a couple chunks
function on_chunk(event)
    -- local txy = event.area.left_top
    -- local x = (txy.x * 0.03125) 
    -- local y = (txy.y * 0.03125)
    -- will be used for building basic AI
end

-- initalize local references that need game object
function on_first_tick(event)
    -- create a module local variable of the surface for faster reference
    surface = game.surfaces[1]
    
    -- run first tick
    on_running({tick = 0})
    -- switch on_tick to real function
    script.on_event(defines.events.on_tick, on_running)
end

---------------------------------------------
script.on_init(on_initialize)
script.on_load(on_load)

script.on_event(defines.events.on_chunk_generated, on_chunk)
script.on_event(defines.events.on_entity_died, on_remove)
script.on_event(defines.events.on_tick, on_first_tick)


