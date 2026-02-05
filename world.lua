local Gear = require("gear")

local World = {}
World.__index = World

function World.new(grid_size)
    local self = setmetatable({}, World)
    self.gears = {}
    self.grid_size = grid_size or 40
    self.power_on = false
    return self
end

function World:snapToGrid(wx, wy)
    local gx = math.floor(wx / self.grid_size + 0.5) * self.grid_size
    local gy = math.floor(wy / self.grid_size + 0.5) * self.grid_size
    return gx, gy
end

function World:addGear(x, y, radius)
    local new_gear = Gear.new(x, y, radius)
    table.insert(self.gears, new_gear)
    self:updateConnections()
end

function World:removeGearAt(wx, wy)
    for i = #self.gears, 1, -1 do
        if self.gears[i]:containsPoint(wx, wy) then
            table.remove(self.gears, i)
            self:updateConnections()
            return true
        end
    end
    return false
end

function World:updateConnections()
    for _, g in ipairs(self.gears) do
        g.is_motor = false
        g.is_powered = false
        g.parent = nil
        g.ratio = 0
        g.phase_offset = 0
        g.visited = false
        g.target_speed = 0
    end

    if #self.gears == 0 then return end

    local function process_island(root_index, start_powered)
        local root = self.gears[root_index]
        root.visited = true
        root.is_powered = start_powered
        if root_index == 1 then root.is_motor = true end
        
        local queue = {root}
        local head = 1
        while head <= #queue do
            local g1 = queue[head]
            head = head + 1

            for _, g2 in ipairs(self.gears) do
                if not g2.visited then
                    local is_tangent, term = g1:checkTangency(g2)
                    if is_tangent then
                        g2.visited = true
                        g2.is_powered = start_powered
                        g2.parent = g1
                        
                        -- [Core fix]: use tooth count ratio (N1/N2) instead of radius ratio (R1/R2)
                        -- This ensures gear ratio is always a discrete rational number, eliminating periodic misalignment
                        g2.ratio = (term > 0 and -1 or 1) * (g1.N / g2.N)
                        
                        local psi = math.atan2(g2.y - g1.y, g2.x - g1.x)
                        -- Alignment formula also uses tooth count ratio
                        if term > 0 then
                            -- External meshing
                            g2.phase_offset = (psi + math.pi) + (g1.N / g2.N) * (psi - g1.angle) - (math.pi / g2.N) - (g2.ratio * g1.angle)
                        else
                            -- Internal meshing
                            g2.phase_offset = psi - (g1.N / g2.N) * (psi - g1.angle) - (g2.ratio * g1.angle)
                        end
                        table.insert(queue, g2)
                    end
                end
            end
        end
    end

    process_island(1, true)
    for i = 2, #self.gears do
        if not self.gears[i].visited then
            process_island(i, false)
        end
    end
end

function World:update(dt)
    if #self.gears == 0 then return end

    local motor = self.gears[1]
    motor.target_speed = self.power_on and 2.0 or 0.0
    local lerp_speed = 0.3
    motor.current_speed = motor.current_speed + (motor.target_speed - motor.current_speed) * dt * lerp_speed

    for _, g in ipairs(self.gears) do
        if g.is_motor then
            g.angle = g.angle + g.current_speed * dt
        elseif g.parent then
            g.current_speed = g.parent.current_speed * g.ratio
            g.angle = g.parent.angle * g.ratio + g.phase_offset
        else
            g.current_speed = g.current_speed * math.max(0, 1 - 0.5 * dt)
            g.angle = g.angle + g.current_speed * dt
        end
    end
end

function World:isValidPlacement(x, y, radius)
    -- Note: can still use raw radius for collision since physics only cares about distance
    for _, g in ipairs(self.gears) do
        local dx, dy = x - g.x, y - g.y
        local d2 = dx*dx + dy*dy
        local dist = math.sqrt(d2)
        local sum_r = radius + g.radius
        
        if dist < sum_r - 1.0 then 
            local diff_r = math.abs(radius - g.radius)
            if math.abs(dist - diff_r) < 1.0 then
            else
                return false 
            end
        end
    end
    return true
end

function World:draw(camera, is_occlusion, debug_mode)
    if not is_occlusion then
        local w1, h1 = camera:screenToWorld(0, 0)
        local w2, h2 = camera:screenToWorld(love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(0.1, 0.25, 0.5)
        for x = math.floor(w1/self.grid_size)*self.grid_size, w2, self.grid_size do
            love.graphics.line(x, h1, x, h2)
        end
        for y = math.floor(h1/self.grid_size)*self.grid_size, h2, self.grid_size do
            love.graphics.line(w1, y, w2, y)
        end
    end
    for _, gear in ipairs(self.gears) do
        gear:draw(camera, is_occlusion, self.power_on)
        if debug_mode and not is_occlusion then
            love.graphics.setColor(1, 1, 0, 0.5)
            love.graphics.circle("line", gear.x, gear.y, gear.radius)
        end
    end
end

return World