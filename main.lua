Ants = {}

local antSprite = love.graphics.newImage('sprites/ant.png')
local map = love.image.newImageData('sprites/map.png')
local mapImg =  love.graphics.newImage(map)
local food = love.image.newImageData('sprites/food.png')
local foodImg = love.graphics.newImage(food)
local pheromoneMap = love.image.newImageData(128, 72)
local pheromoneImg =  love.graphics.newImage(pheromoneMap)

-- Config
local n = 1000
local nestX, nestY, nestRadius = 200, 400, 50
local w, h = 1280, 720
local antSpeed = 120
local explorationDesirability = 1
local pheromoneDesirability = 5
local evaporationRate = 0.15
local pheromoneRelease = 0.1

local foodCollected = 0

local function clamp(val, min, max)
    return math.max(min, math.min(max, val))
end

local function moveAnts(dt)
    for k, ant in pairs(Ants) do
        -- Check for collisions
        local r, g, b, a = map:getPixel(ant.x, ant.y)
        if r == 52/255 and g == 73/255 and b == 94/255 then
            ant.rot = ant.rot + math.pi
            ant.x = ant.x + antSpeed * math.sin(ant.rot) * dt
            ant.y = ant.y - antSpeed * math.cos(ant.rot) * dt
        end

        local pheromoneRot = 0

        -- Check for pheromones
        local x = ant.x/10 + math.sin(ant.rot) * 1.2
        r, g, b, a = pheromoneMap:getPixel(ant.x/10 + math.sin(ant.rot - math.pi/4) * 1.2, ant.y/10 - math.cos(ant.rot - math.pi/4) * 1.2)
        local r2, g2, b2, a2 = pheromoneMap:getPixel(ant.x/10 + math.sin(ant.rot + math.pi/4) * 1.2, ant.y/10 - math.cos(ant.rot + math.pi/4) * 1.2)
        if a > 0 or a2 > 0 then
            if ant.holdingFood then
                pheromoneRot = math.pi * clamp(b2 - b, -1.0, 1.0)
            else 
                if g > 0 then pheromoneRot = math.pi * clamp(b2 - b, -1.0, 1.0) end
            end
        end

        -- Explore
        local explorationRot = (math.random()*2-1) * 2 * math.pi

        -- Final rotation
        if pheromoneRot ~= 0 then
            ant.rot = ant.rot + pheromoneRot * pheromoneDesirability * dt + explorationRot * explorationDesirability * dt
        else
            ant.rot = ant.rot + pheromoneRot * pheromoneDesirability * dt + explorationRot * explorationDesirability * dt
        end
        

        -- Move forward
        ant.x = ant.x + antSpeed * math.sin(ant.rot) * dt
        ant.y = ant.y - antSpeed * math.cos(ant.rot) * dt

        -- Map bounds check
        if ant.x < 10 or ant.x > w-10 or ant.y < 10 or ant.y > h-10 then
            ant.x = nestX + math.sin(ant.rot) * nestRadius
            ant.y = nestY - math.cos(ant.rot) * nestRadius
        end
    end
end

local function releasePheromones(dt)
    for k, ant in pairs(Ants) do
        local r, g, b, a = pheromoneMap:getPixel(ant.x/10, ant.y/10)
        if ant.holdingFood then
            pheromoneMap:setPixel(ant.x/10, ant.y/10, 0, g + pheromoneRelease, b, 1.0)
        else
            pheromoneMap:setPixel(ant.x/10, ant.y/10, 0, g, b + pheromoneRelease, 1.0)
        end
    end
end

local function evaporate(dt)
    for x = 0, 127 do
        for y = 0, 71 do
            local r, g, b, a = pheromoneMap:getPixel(x, y)
            if a ~= 0 then
                g = clamp(g - evaporationRate * dt, 0.0, 999.0)
                b = clamp(b - evaporationRate * dt, 0.0, 999.0)
                if g > b then a = g else a = b end
                pheromoneMap:setPixel(x, y, r, g, b, a)
            end
        end
    end
end

local function checkForFood()
    for k, ant in pairs(Ants) do
        if ant.holdingFood == false then
            local r, g, b, a = food:getPixel(ant.x, ant.y)
            if a == 1 then
                ant.holdingFood = true
                ant.rot = ant.rot + math.pi
                food:setPixel(ant.x, ant.y, r, g, b, 0.0)
            end
        end
    end
end

local function checkForNest()
    for k, ant in pairs(Ants) do
        if ant.holdingFood then
            if (ant.x - nestX)^2 + (ant.y - nestY)^2 < nestRadius^2 then
                ant.holdingFood = false
                ant.rot = ant.rot + math.pi
                foodCollected = foodCollected + 1
            end
        end
    end
end

function love.load()
    -- Setup
    love.window.setMode(w, h)
    love.window.setTitle('Ants Simulation - ' .. n .. ' ants')
    love.graphics.setDefaultFilter("nearest", "nearest")
    math.randomseed(os.clock())

    -- Spawn ants
    for i = 1, n do
        local ant = {}
        ant.rot = math.random() * 2 * math.pi
        ant.x = nestX + math.sin(ant.rot) * nestRadius
        ant.y = nestY - math.cos(ant.rot) * nestRadius
        ant.holdingFood = false
        table.insert(Ants, ant)
    end
end

function love.update(dt)
    checkForFood()
    moveAnts(dt)
    checkForNest()
    evaporate(dt)
    releasePheromones(dt)
end

function love.draw()
    --love.graphics.reset()

    -- World
    love.graphics.draw(mapImg)
    foodImg:replacePixels(food)
    love.graphics.draw(foodImg)
    pheromoneImg:replacePixels(pheromoneMap)
    love.graphics.draw(pheromoneImg, nil, nil, nil, 10)
    
    -- Draw ants
    for k, ant in pairs(Ants) do
        love.graphics.draw(antSprite, ant.x, ant.y, ant.rot, 0.01, nil, antSprite:getWidth()/2, antSprite:getHeight()/2)
    end
    
    -- Draw nest
    love.graphics.setColor(231/255, 76/255, 60/255, 1.0)
    love.graphics.circle("fill", nestX, nestY, nestRadius)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(''..foodCollected, nestX - 50, nestY - 10, 100, "center")
end