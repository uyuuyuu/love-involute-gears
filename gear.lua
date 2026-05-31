local Gear = {}
Gear.__index = Gear

-- Preload shader
local shader = love.graphics.newShader("gear_shader.glsl")

function Gear.new(x, y, radius)
    local self = setmetatable({}, Gear)
    self.x = x
    self.y = y
    self.radius = radius -- Keep raw radius (e.g. sqrt(2))
    self.angle = 0
    self.current_speed = 0
    self.target_speed = 0
    self.visited = false
    self.is_motor = false

    self.color = {
        0.4 + math.random() * 0.6,
        0.4 + math.random() * 0.6,
        0.4 + math.random() * 0.6
    }

    -- Mechanical parameter auto-adaptation
    local target_module = 10 -- Desired ideal tooth size
    self.phi = math.rad(20)

    -- Calculate nearest integer tooth count: N = round(D / m)
    self.N = math.floor((2 * self.radius) / target_module + 0.5)
    if self.N < 6 then self.N = 6 end

    -- Calculate this gear's actual module: m = D / N
    self.module = (2 * self.radius) / self.N

    self.rb = self.radius * math.cos(self.phi)
    self.ra = self.radius + self.module
    self.rf = self.radius - self.module
    self.inv_alpha_p = math.tan(self.phi) - self.phi
    self.half_thick_p = math.pi / (2 * self.N)

    return self
end

function Gear:update(dt)
    -- Note: controlled gear updates are now handled by World:update
end

function Gear:draw(camera, is_occlusion, power_on)
    if is_occlusion then
        love.graphics.setColor(1, 1, 1, 1)
    elseif self.is_motor then
        if power_on then
            love.graphics.setColor(1, 0.6, 0.2) -- On: bright orange
        else
            love.graphics.setColor(0.5, 0.3, 0.1) -- Off: dim dark orange
        end
    elseif self.is_powered then
        -- Connected to power source
        love.graphics.setColor(unpack(self.color))
    else
        -- Isolated gear group, gray even if meshing
        love.graphics.setColor(self.color[1]*0.3, self.color[2]*0.3, self.color[3]*0.3)
    end

    local screen_x, screen_y = camera:worldToScreen(self.x, self.y)
    local zoom = camera.zoom

    love.graphics.setShader(shader)
    shader:send("N", float(self.N))
    shader:send("rb", self.rb * zoom)
    shader:send("ra", self.ra * zoom)
    shader:send("rf", self.rf * zoom)
    -- shader:send("m", self.module * zoom)
    shader:send("rotation", self.angle)
    shader:send("center", {screen_x, screen_y})
    shader:send("inv_alpha_p", self.inv_alpha_p)
    shader:send("half_thick_p", self.half_thick_p)
    -- Send light position for specular calculation
    shader:send("light_pos", {love.mouse.getX(), love.mouse.getY()})

    local size = self.ra * 2.2 * zoom
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.rectangle("fill", screen_x - size/2, screen_y - size/2, size, size)
    love.graphics.pop()

    love.graphics.setShader()
end

-- Helper: ensure float values sent to shader
function float(n) return n end

function Gear:checkTangency(other)
    local dx, dy = self.x - other.x, self.y - other.y
    local d2 = dx*dx + dy*dy
    local r1_2, r2_2 = self.radius^2, other.radius^2
    local term = d2 - r1_2 - r2_2
    local result = term*term - 4*r1_2*r2_2

    if math.abs(result) < 1.0 then
        return true, term -- return if tangent and the term for direction
    end
    return false
end

function Gear:containsPoint(px, py)
    local dx, dy = px - self.x, py - self.y
    return (dx*dx + dy*dy) < (self.radius * self.radius)
end

return Gear
