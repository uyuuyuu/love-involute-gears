local Camera = require("camera")
local World = require("world")

local cam
local world
local light_shader
local occlusion_canvas
local selected_point = nil
local debug_mode = false
local show_ui = true

function love.load()
    love.window.setTitle("Gear Game - Physical Inertia")
    love.window.setFullscreen(true)
    
    local w, h = love.graphics.getDimensions()
    cam = Camera.new()
    world = World.new(40)
    
    light_shader = love.graphics.newShader("light_shader.glsl")
    occlusion_canvas = love.graphics.newCanvas(w, h)
end

function love.update(dt)
    -- Sync canvas size
    local w, h = love.graphics.getDimensions()
    if occlusion_canvas:getWidth() ~= w or occlusion_canvas:getHeight() ~= h then
        occlusion_canvas = love.graphics.newCanvas(w, h)
    end

    -- Update camera smoothing
    cam:update(dt)

    -- Always update physics world for inertia handling
    world:update(dt)
    
    cam:updateDrag(love.mouse.getPosition())
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "space" then
        -- Toggle power source
        world.power_on = not world.power_on
    elseif key == "d" then
        debug_mode = not debug_mode
    elseif key == "h" then
        show_ui = not show_ui
    end
end

function love.mousepressed(x, y, button)
    local wx, wy = cam:screenToWorld(x, y)
    if button == 1 then
        local sx, sy = world:snapToGrid(wx, wy)
        if not selected_point then
            selected_point = {x = sx, y = sy}
        else
            local dx, dy = sx - selected_point.x, sy - selected_point.y
            local radius = math.sqrt(dx*dx + dy*dy)
            if radius > 0 and world:isValidPlacement(selected_point.x, selected_point.y, radius) then
                world:addGear(selected_point.x, selected_point.y, radius)
                selected_point = nil
            elseif radius > 0 then
                -- If invalid, keep selected_point, allow player to adjust radius
            else
                selected_point = nil
            end
        end
    elseif button == 2 then
        if selected_point then selected_point = nil else world:removeGearAt(wx, wy) end
    elseif button == 3 then
        cam:startDrag(x, y)
    end
end

function love.mousereleased(x, y, button)
    if button == 3 then cam:stopDrag() end
end

function love.wheelmoved(x, y)
    cam:zoomAt(love.mouse.getX(), love.mouse.getY(), y)
end

function love.draw()
    local w, h = love.graphics.getDimensions()

    -- 1. Occlusion render
    love.graphics.setCanvas(occlusion_canvas)
    love.graphics.clear(0, 0, 0, 1) 
    world:draw(cam, true)
    love.graphics.setCanvas()

    -- 2. Background
    love.graphics.clear(0.05, 0.1, 0.25)
    
    -- 3. Volumetric light
    love.graphics.setBlendMode("add")
    love.graphics.setShader(light_shader)
    light_shader:send("light_pos", {love.mouse.getX(), love.mouse.getY()})
    light_shader:send("occlusion", occlusion_canvas)
    light_shader:send("screen_res", {w, h})
    light_shader:send("light_color", {0.4, 0.7, 1.0}) 
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setShader()
    love.graphics.setBlendMode("alpha")

    -- 4. World render
    cam:apply()
    world:draw(cam, false, debug_mode)

    -- Draw preview (inside camera transform)
    if selected_point then
        local wx, wy = cam:screenToWorld(love.mouse.getPosition())
        local sx, sy = world:snapToGrid(wx, wy)
        local dx, dy = sx - selected_point.x, sy - selected_point.y
        local radius = math.sqrt(dx*dx + dy*dy)
        
        -- Dynamic color
        if radius > 0 then
            if world:isValidPlacement(selected_point.x, selected_point.y, radius) then
                love.graphics.setColor(0, 1, 0, 0.5) -- Green
            else
                love.graphics.setColor(1, 0, 0, 0.5) -- Red
            end
            love.graphics.circle("line", selected_point.x, selected_point.y, radius)
        else
            love.graphics.setColor(0, 1, 0, 0.5)
        end
        love.graphics.circle("fill", selected_point.x, selected_point.y, 5/cam.zoom)
    end
    cam:detach()

    -- UI
    if show_ui then
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Space: Power | D: Debug Circle | H: Hide UI", 10, 10)
        love.graphics.print("Left Click: Place | Right Click: Delete", 10, 30)
        love.graphics.print(string.format("Motor: %s | Debug: %s | Gears: %d | Zoom: %.2f", 
            world.power_on and "ON" or "OFF", debug_mode and "ON" or "OFF", #world.gears, cam.zoom), 10, 50)
    end
end