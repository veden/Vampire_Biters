function killVampires(unitArray)
    for i=1, #unitArray do
        local vamp = unitArray[i]
        if (vamp.valid) then
            vamp.die()
        end
        unitArray[i] = nil
    end
end

function findValidUnit(unitArray)
    local unit = nil
    local i = 1
    while (i < #unitArray) and (unit == nil) do
        local vamp = unitArray[i]
        if (vamp ~= nil) then
            if (vamp.valid) then
                unit = vamp
            else
                unitArray[i] = nil
            end
        end
        i = i + 1
    end
    return unit
end

function euclideanDistance(p1, p2)
    local xs = p1.x - p2.x
    local ys = p1.y - p2.y
    return ((xs * xs) + (ys * ys)) ^ 0.5
end

function boundingBox(p, radius)
    return {{p.x - radius, p.y - radius},
            {p.x + radius, p.y + radius}}
end

function initializeVampireCoven()
    return {
             freeMinions = {},
             minions = {},
             clans = {},
             den = {},
             lordAge = 0,
             lord = nil
           }
end