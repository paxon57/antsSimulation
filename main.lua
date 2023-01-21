-- CONFIG MAIN
local nTotal = 1000 -- Amount of ants 
local releaseTime = 10 -- Amount of time (seconds) ants should be release in
local w, h = 1280, 720 -- Resolution and world size
local nestX, nestY, nestR = 640, 360, 40 -- Nest position and size
local antSpeed = 2 -- Speed of the ants
local pheromoneAdjust = true -- Adjust pheromone visibility for highest concentrations
-- CONFIG
local explorationDesirability = 0.2 -- Exploration preference
local pheromoneDesirability = 0.2  -- Pheromone following preference
local foodDesirability = 1 -- Food following preference
local pheromoneRelease = 4 -- Amount of pheromones released by single ant every tick
local evaporationRate = 0.01 -- Evaporation per tick
local diffusionRate = 0.4 -- Diffusion per tick
local maxPheromoneIntensity = 100 -- Max pheromone concentration
local foodBatches = 3 -- Amount of food clusters
local foodBatchSize = 200 -- Amount of food in clsters (and size of the cluster)
local foodDetectionDistance = 25 -- How far away can an ant see the food from
local antFov = math.pi / 4 -- Field of view of the ants
local antViewDist = 10 -- Distance of ant vision

local ants = {}
local foodCollected = 0
local n = 0
local foodBatch = {}

local pheromones = {}
local currentMaxPheromone = 0

-- Half the res for performance
w = w/2
h = h/2
nestX = nestX/2
nestY = nestY/2
nestR = nestR/2

local pheromoneMap = love.image.newImageData(w, h)
local pheromoneImg = love.graphics.newImage(pheromoneMap)


local function round(val) return math.floor(val + 0.5) end
local function clamp(val, min, max) return (math.min(max, math.max(val, min))) end
local function dot(vec1, vec2) return vec1.x*vec2.x + vec1.y*vec2.y end

local function spawnAnts(dt)
    local toSpawnPerSec = nTotal / releaseTime
    local toSpawn = dt * toSpawnPerSec
    if toSpawn > nTotal - n then toSpawn = nTotal - n end

    for i = 1, toSpawn do
        local randRot = math.random() * math.pi * 2
        local ant = {}
        ant.x = nestX + round(math.sin(randRot) * nestR)
        ant.y = nestY - round(math.cos(randRot) * nestR)
        ant.vel = {
            x = math.sin(randRot),
            y = -math.cos(randRot)
        }
        ant.holdingFood = false
        table.insert(ants, ant)
        n = n + 1
    end
end

local function angVec(vec1, vec2)
    local vec1len = math.sqrt(vec1.x^2 + vec1.y^2)
    local vec2len = math.sqrt(vec2.x^2 + vec2.y^2)
    return math.acos(dot(vec1, vec2)/(math.abs(vec1len)*math.abs(vec2len)))
end

local function normalize(vec)
    local len = math.sqrt(vec.x ^ 2 + vec.y ^ 2)
    if len == 0 then return {x = 0, y = 0} end
    return {x = vec.x/len, y = vec.y/len}
end

local function moveAnts()
    for k, ant in pairs(ants) do

        -- Exploration
        local dx = math.random() * 2 - 1
        local dy = math.random() * 2 - 1

        -- Food detection
        local fx, fy = 0, 0
        local closest = 9999999999
        if not ant.holdingFood then
            for i, batch in ipairs(foodBatch) do
                if ((ant.x - batch.x)^2 + (ant.y - batch.y)^2) < (foodBatchSize/3)^2 then
                    for key, f in ipairs(batch.food) do
                        local dist = (f.x - ant.x)^2 + (f.y - ant.y)^2
                        if dist < foodDetectionDistance^2 then
                            if dist < closest then
                                closest = dist
                                fx = f.x - ant.x
                                fy = f.y - ant.y
                                if dist < 3 then -- Grab
                                    ant.vel.x = ant.vel.x * -1
                                    ant.vel.y = ant.vel.y * -1
                                    ant.holdingFood = true
                                    table.remove(foodBatch[i].food, key)
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end

        -- Pheromone detection
        local px, py = 0, 0
        local frontX, frontY = round(ant.x + ant.vel.x * antViewDist), round(ant.y + ant.vel.y * antViewDist)
        local ang = math.atan2(ant.vel.y, ant.vel.x) - math.pi / 2
        local leftX, leftY = round(ant.x + math.sin(ang - antFov + math.pi) * antViewDist), round(ant.y - math.cos(ang - antFov + math.pi) * antViewDist)
        local rightX, rightY = round(ant.x + math.sin(ang + antFov + math.pi) * antViewDist), round(ant.y - math.cos(ang + antFov + math.pi) * antViewDist)

        local frontHome, frontFood, leftHome, leftFood, rightHome, rightFood = 0, 0, 0, 0, 0, 0
        -- Check front
        for x = -3, 3, 1 do
            for y = -3, 3, 1 do
                if frontX + x > 0 and frontX + x < w and frontY + y > 0 and frontY + y < h then
                    frontHome = frontHome + pheromones[frontX + x][frontY + y].home
                    frontFood = frontFood + pheromones[frontX + x][frontY + y].food
                end
            end
        end
        -- Check left
        for x = -3, 3, 1 do
            for y = -3, 3, 1 do
                if leftX + x > 0 and leftX + x < w and leftY + y > 0 and leftY + y < h then
                    leftHome = leftHome + pheromones[leftX + x][leftY + y].home
                    leftFood = leftFood + pheromones[leftX + x][leftY + y].food
                end
            end
        end
        -- Check right
        for x = -3, 3, 1 do
            for y = -3, 3, 1 do
                if rightX + x > 0 and rightX + x < w and rightY + y > 0 and rightY + y < h then
                    rightHome = rightHome + pheromones[rightX + x][rightY + y].home
                    rightFood = rightFood + pheromones[rightX + x][rightY + y].food
                end
            end
        end
        -- Turn towards biggest concentration
        if ant.holdingFood then
            if frontHome > leftHome and frontHome > rightHome then px = frontX - ant.x py = frontY - ant.y
            elseif leftHome > frontHome and leftHome > rightHome then px = leftX - ant.x py = leftY - ant.y
            elseif rightHome > frontHome and rightHome > leftHome then px = rightX - ant.x py = rightY - ant.y end
        else
            if frontFood > leftFood and frontFood > rightFood then px = frontX - ant.x py = frontY - ant.y
            elseif leftFood > frontFood and leftFood > rightFood then px = leftX - ant.x py = leftY - ant.y
            elseif rightFood > frontFood and rightFood > leftFood then px = rightX - ant.x py = rightY - ant.y end
        end
        -- Normalize
        local pVel = normalize({x = px, y = py})
        px = pVel.x
        py = pVel.y

        -- Check for nest proximity
        local nx, ny = 0, 0
        if ant.holdingFood then
            if (ant.x - nestX)^2 + (ant.y - nestY)^2 < (nestR*1.5)^2 then
                nx = nestX - ant.x
                ny = nestY - ant.y
            end
        end
        -- Sum up velocities
        local vel = {
            x = ant.vel.x + dx * explorationDesirability + fx * foodDesirability + px * pheromoneDesirability + nx,
            y = ant.vel.y + dy * explorationDesirability + fy * foodDesirability + py * pheromoneDesirability + ny
        }
        ant.vel = normalize(vel)

        ant.x = round(ant.x + ant.vel.x * antSpeed)
        ant.y = round(ant.y + ant.vel.y * antSpeed)

        -- Check for the nest collision
        if ant.holdingFood then
            if (ant.x - nestX) ^ 2 + (ant.y - nestY)^2 < nestR ^ 2 then
                ant.holdingFood = false
                foodCollected = foodCollected + 1
                ant.vel.x = -ant.vel.x
                ant.vel.y = -ant.vel.y
            end
        end

        -- Check for map bounds
        if ant.x < 0 then ant.x = 1 ant.vel.x = -ant.vel.x end
        if ant.x >= w then ant.x = w - 1 ant.vel.x = -ant.vel.x end
        if ant.y < 0 then ant.y = 1 ant.vel.y = -ant.vel.y end
        if ant.y >= h then ant.y = h - 1 ant.vel.y = -ant.vel.y end
    end
end

local function releasePheromones()
    for k, ant in pairs(ants) do
        if ant.holdingFood then 
            pheromones[ant.x + 1][ant.y + 1].food = pheromones[ant.x + 1][ant.y + 1].food + pheromoneRelease
        else
            pheromones[ant.x + 1][ant.y + 1].home = pheromones[ant.x + 1][ant.y + 1].home + pheromoneRelease
        end
    end
end

local function evaporate()
    for x = 1, w do
        for y = 1, h do
            pheromones[x][y].food = clamp(pheromones[x][y].food - evaporationRate, 0, maxPheromoneIntensity)
            pheromones[x][y].home = clamp(pheromones[x][y].home - evaporationRate, 0, maxPheromoneIntensity)
        end
    end
end 

local function diffuse()
    local newPheromones = {}
    for x = 1, w do
        newPheromones[x] = {}
        for y = 1, h do
            newPheromones[x][y] = {
                food = 0,
                home = 0
            }
        end
    end

    for x = 1, w do
        for y = 1, h do
            local home = pheromones[x][y].home
            local food = pheromones[x][y].food
            local dHome = (home * diffusionRate) / 8
            local dFood = (diffusionRate * food) / 8

            newPheromones[x][y].food = newPheromones[x][y].food + math.max(pheromones[x][y].food - dFood*8, 0)
            newPheromones[x][y].home = newPheromones[x][y].home + math.max(pheromones[x][y].home - dHome*8, 0)

             for dx = -1, 1 do
                if x + dx > 0 and x + dx < w then
                    for dy = -1, 1 do
                        if y + dy > 0 and y + dy < h and not(dx == 0 and dy == 0) then
                            newPheromones[x + dx][y + dy].food = newPheromones[x + dx][y + dy].food + dFood
                            newPheromones[x + dx][y + dy].home = newPheromones[x + dx][y + dy].home + dHome
                        end
                    end
                end
            end
        end
    end

    currentMaxPheromone = 0

    for x = 1, w do
        for y = 1, h do
            pheromones[x][y].food = newPheromones[x][y].food
            pheromones[x][y].home = newPheromones[x][y].home
            if currentMaxPheromone < newPheromones[x][y].food then currentMaxPheromone = newPheromones[x][y].food end
            if currentMaxPheromone < newPheromones[x][y].home then currentMaxPheromone = newPheromones[x][y].home end
        end
    end

    if not pheromoneAdjust then currentMaxPheromone = 1 end
end 

local function generatePheromoneImg()
    for x = 1, w do
        for y = 1, h do
            local a = 0
            if pheromones[x][y].food > pheromones[x][y].home then a = pheromones[x][y].food / currentMaxPheromone else a = pheromones[x][y].home / currentMaxPheromone end
            pheromoneMap:setPixel(x - 1, y - 1, pheromones[x][y].food / currentMaxPheromone, 0, pheromones[x][y].home / currentMaxPheromone, a)
        end
    end
    pheromoneImg:replacePixels(pheromoneMap)
end

function love.load()
    love.window.setMode(w*2, h*2)
    love.window.setTitle('Ant colony simulation with '..nTotal..' ants')

    -- Init array
    for x = 1, w do
        pheromones[x] = {}
        for y = 1, h do
            pheromones[x][y] = {
                home = 0,
                food = 0
            }
        end
    end

    -- Init random
    math.randomseed(os.clock())

    

    -- Spawn food
    for i = 1, foodBatches do
        local x = math.random() * w
        local y = math.random() * h

        table.insert(foodBatch, {
            x = x,
            y = y,
            food = {}
        })

        for j = 1, foodBatchSize do
            local fx = x + math.sin(math.random() * math.pi * 2) * math.random() * foodBatchSize/5
            local fy = y + math.cos(math.random() * math.pi * 2) * math.random() * foodBatchSize/5

            if fx < 0 then fx = fx * -1 end
            if fx > w then fx = fx - (fx - w) end
            if fy < 0 then fy = fy * -1 end
            if fy > h then fy = fy - (fy - h) end
            
            table.insert(foodBatch[#foodBatch].food, {
                x = fx,
                y = fy
            })
        end
    end
end

function love.update(dt)
    if n < nTotal then spawnAnts(dt) end
    moveAnts()
    releasePheromones()
    evaporate()
    diffuse()
    generatePheromoneImg()
end

function love.draw()
    love.graphics.scale(2)
    love.graphics.draw(pheromoneImg)

    -- Draw pheromones
    love.graphics.draw(pheromoneImg)

    -- Draw food
    love.graphics.setColor(0, 1, 0)
    for i, batch in pairs(foodBatch) do
        for k, f in pairs(batch.food) do
            love.graphics.circle("fill", f.x, f.y, 2.5)
        end
    end

    -- Draw ants
    for k, ant in pairs(ants) do
        love.graphics.setColor(1, 0, 0)
        love.graphics.rectangle("fill", ant.x - 1.5, ant.y - 1.5, 3, 3)
    end

    -- Draw nest
    love.graphics.setColor(1, 0.5, 0)
    love.graphics.circle("fill", nestX, nestY, nestR)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(''..foodCollected, nestX - nestR, nestY - 8, nestR * 2, "center")
end

function love.conf(t)
    t.console = true
end