-- local Camera = require("camera") -- This is to allow reloading if needed, but we define the class below
local Camera = {}
Camera.__index = Camera

function Camera.new()
    local self = setmetatable({}, Camera)
    -- Current visual state
    self.x = love.graphics.getWidth() / 2
    self.y = love.graphics.getHeight() / 2
    self.zoom = 1
    
    -- Target state
    self.target_x = self.x
    self.target_y = self.y
    self.target_zoom = 1
    
    self.is_dragging = false
    self.last_mx = 0
    self.last_my = 0
    
    -- Spring/Damper constants for "heavy" feel
    self.lerp_speed = 12
    return self
end

function Camera:screenToWorld(sx, sy)
    local wx = (sx - love.graphics.getWidth()/2) / self.zoom + self.x
    local wy = (sy - love.graphics.getHeight()/2) / self.zoom + self.y
    return wx, wy
end

function Camera:worldToScreen(wx, wy)
    local sx = (wx - self.x) * self.zoom + love.graphics.getWidth()/2
    local sy = (wy - self.y) * self.zoom + love.graphics.getHeight()/2
    return sx, sy
end

function Camera:apply()
    love.graphics.push()
    love.graphics.translate(love.graphics.getWidth()/2, love.graphics.getHeight()/2)
    love.graphics.scale(self.zoom)
    love.graphics.translate(-self.x, -self.y)
end

function Camera:detach()
    love.graphics.pop()
end

function Camera:update(dt)
    -- Use a single lerp factor for everything to stay in sync
    local f = 1 - math.exp(-self.lerp_speed * dt)
    
    -- Save world point under mouse before zoom change
    local mx, my = love.mouse.getPosition()
    local wx, wy = self:screenToWorld(mx, my)
    
    -- Smoothly transition zoom
    self.zoom = self.zoom + (self.target_zoom - self.zoom) * f
    
    -- Smoothly transition position
    -- We transition target_x/y as well if they are being dragged
    self.x = self.x + (self.target_x - self.x) * f
    self.y = self.y + (self.target_y - self.y) * f

    -- If we are NOT dragging, we can optionally lock the zoom to the mouse more strictly
    -- but for a "heavy" feel, letting the lerp handle target_x/y is usually enough.
end

function Camera:startDrag(x, y)
    self.is_dragging = true
    self.last_mx, self.last_my = x, y
end

function Camera:stopDrag()
    self.is_dragging = false
end

function Camera:updateDrag(x, y)
    if self.is_dragging then
        local dx = x - self.last_mx
        local dy = y - self.last_my
        -- Move the TARGET, not the current position
        self.target_x = self.target_x - dx / self.target_zoom
        self.target_y = self.target_y - dy / self.target_zoom
        self.last_mx, self.last_my = x, y
    end
end

function Camera:zoomAt(mx, my, y_scroll)
    -- Calculate where the world point is currently (at the target zoom/pos)
    local wx = (mx - love.graphics.getWidth()/2) / self.target_zoom + self.target_x
    local wy = (my - love.graphics.getHeight()/2) / self.target_zoom + self.target_y
    
    -- Update target zoom
    local zoom_factor = y_scroll > 0 and 1.3 or (1/1.3)
    self.target_zoom = math.max(0.05, math.min(10, self.target_zoom * zoom_factor))
    
    -- Recalculate where target_x/y needs to be so that 'wx/wy' stays under 'mx/my'
    -- at the NEW target zoom level.
    self.target_x = wx - (mx - love.graphics.getWidth()/2) / self.target_zoom
    self.target_y = wy - (my - love.graphics.getHeight()/2) / self.target_zoom
end

return Camera
