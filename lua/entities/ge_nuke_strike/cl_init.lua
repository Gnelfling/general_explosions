include("shared.lua")
if not include("general_explosions/load_runtime.lua") then return end

local flash = CreateClientConVar("ge_nuke_flash", "1", true, false, "Draw nuclear strike flashes", 0, 1)
local glow = Material("sprites/light_glow02_add")
local beam = Material("sprites/physbeam")
local up = Vector(0, 0, 1)
local ring = {}
for i = 0, 64 do
    local angle = i * math.pi * 2 / 64
    ring[i] = Vector(math.cos(angle), math.sin(angle), 0)
end

function ENT:Initialize()
    self:SetRenderBounds(Vector(-4100, -4100, -64), Vector(4100, 4100, 8000))
end

function ENT:Think()
    local start = self:GetStrikeStart()
    local age = CurTime() - start - self.DescentTime
    if start <= 0 or age < 0 or age > 0.85 or not flash:GetBool()
        or EyePos():DistToSqr(self:GetPos()) > 8500 ^ 2 then return end
    local light = DynamicLight(self:EntIndex())
    if not light then return end
    light.pos = self:GetPos() + up * 160
    light.r, light.g, light.b = 255, 196, 130
    light.brightness = 6 * math.exp(-age * 4)
    light.size, light.decay, light.dietime = 3800, 4000, CurTime() + 0.1
end

local function flarePosition(origin, height, t)
    return origin + up * height * (1 - math.Clamp(t, 0, 1) ^ 5)
end

function ENT:DrawTranslucent()
    local start = self:GetStrikeStart()
    if start <= 0 then return end
    local age = CurTime() - start
    if age < 0 then return end
    local pos = self:GetPos()
    if EyePos():DistToSqr(pos) > 20000 ^ 2 then return end
    if age < self.DescentTime then
        local t = age / self.DescentTime
        local head = flarePosition(pos, self:GetDropHeight(), t)
        local tail = flarePosition(pos, self:GetDropHeight(), t - 0.065) + up * 48
        render.SetMaterial(beam)
        render.DrawBeam(head, tail, 18 + 42 * t ^ 4, 0, 1, Color(255, 180, 100, 180))
        if flash:GetBool() then
            local pulse = (0.5 + 0.5 * math.cos(age * math.pi * 4)) ^ 6
            render.SetMaterial(glow)
            render.DrawSprite(head, 190, 190, Color(255, 245, 205, 255))
            render.DrawSprite(head, 820 + 640 * pulse, 820 + 640 * pulse, Color(255, 188, 110, 100 + 125 * pulse))
        end
        return
    end

    local elapsed = age - self.DescentTime
    if elapsed < 0.85 and flash:GetBool() then
        local fade = math.exp(-elapsed * 5)
        local center = pos + up * (150 + elapsed * 230)
        render.SetMaterial(glow)
        render.DrawSprite(center, 1100, 850, Color(255, 249, 218, 245 * fade))
        render.DrawSprite(center, 3200, 1900, Color(255, 160, 72, 130 * fade))
    end
    if elapsed < 2.4 then
        local progress = elapsed / 2.4
        local radius = 90 + 3500 * progress ^ 0.72
        local width = 65 * (1 - progress) + 12
        local color = Color(213, 191, 161, 120 * (1 - progress)^2)
        render.SetMaterial(beam)
        render.StartBeam(65)
        for i = 0, 64 do
            render.AddBeam(pos + up * 16 + ring[i] * radius, width, i / 8, color)
        end
        render.EndBeam()
    end
end
