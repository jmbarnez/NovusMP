local Utils = {}

function Utils.generate_starfield()
    local starfield = {}
    local screen_w, screen_h = love.graphics.getDimensions()
    
    -- Layer 1: Deep Space
    for i=1, 400 do 
        table.insert(starfield, {
            x = math.random(0, screen_w), 
            y = math.random(0, screen_h), 
            size = 1, speed = 0.001, alpha = 0.3
        }) 
    end

    -- Layer 2: Mid-Distance
    for i=1, 50 do 
        table.insert(starfield, {
            x = math.random(0, screen_w), 
            y = math.random(0, screen_h), 
            size = 1, speed = 0.003, alpha = 0.5
        }) 
    end

    -- Layer 3: "Foreground" (still distant)
    for i=1, 10 do 
        table.insert(starfield, {
            x = math.random(0, screen_w), 
            y = math.random(0, screen_h), 
            size = 2, speed = 0.005, alpha = 0.7
        }) 
    end
    
    return starfield
end

return Utils