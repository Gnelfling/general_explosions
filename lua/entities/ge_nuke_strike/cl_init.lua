include("shared.lua")
if not include("general_explosions/load_runtime.lua") then return end

local flash = CreateClientConVar("ge_nuke_flash", "1", true, false, "Draw nuclear strike flashes", 0, 1)
local glow = Material("sprites/light_glow02_add")
local beam = Material("sprites/physbeam")
local up = Vector(0, 0, 1)
local exposureStart, exposureStrength = 0, 0
local ring = {}
for i = 0, 64 do
    local angle = i * math.pi * 2 / 64
    ring[i] = Vector(math.cos(angle), math.sin(angle), 0)
end

function ENT:Initialize()
    self:SetRenderBounds(Vector(-4800, -4800, -64), Vector(4800, 4800, self.MaxDropHeight + 1800))
end

function ENT:Think()
    local start = self:GetStrikeStart()
    local age = CurTime() - start - self.DescentTime
    if start <= 0 or age < 0 or age > 0.85 or not flash:GetBool()
        or EyePos():DistToSqr(self:GetPos()) > 8500 ^ 2 then return end
    if not self.ExposureTriggered then
        self.ExposureTriggered = true
        local origin = self:GetPos() + up * 160
        local eye = EyePos()
        local sight = util.TraceLine({start = eye, endpos = origin, mask = MASK_SOLID_BRUSHONLY})
        if not sight.Hit and age < 0.32 then
            exposureStart = start + self.DescentTime
            exposureStrength = 0.78 * (1 - GERuntime.Smooth(math.sqrt(eye:DistToSqr(origin)) / 8500))
        end
    end
    local light = DynamicLight(self:EntIndex())
    if not light then return end
    light.pos = self:GetPos() + up * 160
    light.r, light.g, light.b = 255, 196, 130
    light.brightness = 9 * math.exp(-age * 5) + 2 * math.exp(-age * 2)
    light.size, light.decay, light.dietime = 5200, 5500, CurTime() + 0.1
end

hook.Add("HUDPaint", "GE.NuclearStrike.Exposure", function()
    local age = CurTime() - exposureStart
    if exposureStrength <= 0 or age < 0 or age > 0.4 or not flash:GetBool() then return end
    surface.SetDrawColor(255, 239, 205, math.floor(255 * exposureStrength * math.exp(-age * 11)))
    surface.DrawRect(0, 0, ScrW(), ScrH())
end)

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
            local core = 340 + 180 * t
            local halo = 1400 + 1350 * pulse + 550 * t
            render.DrawSprite(head, core, core, Color(255, 252, 225, 255))
            render.DrawSprite(head, halo, halo, Color(255, 202, 137, 150 + 105 * pulse))
            render.DrawSprite(head, halo * 1.7, core * 0.4, Color(255, 241, 208, 80 + 110 * pulse))
        end
        return
    end

    local elapsed = age - self.DescentTime
    if elapsed < 0.85 and flash:GetBool() then
        local flashFade = math.exp(-elapsed * 12)
        local heatFade = math.exp(-elapsed * 3.8)
        local center = pos + up * (150 + elapsed * 230)
        render.SetMaterial(glow)
        render.DrawSprite(center, 2100, 1700, Color(255, 252, 231, 255 * flashFade))
        render.DrawSprite(center, 7500, 540, Color(255, 242, 201, 220 * flashFade))
        render.DrawSprite(center, 5100 + elapsed * 1600, 2900 + elapsed * 900,
            Color(255, 164, 75, 190 * heatFade))
    end
    if elapsed < 2.4 then
        local progress = elapsed / 2.4
        local radius = 90 + 3500 * progress ^ 0.72
        local width = 95 * (1 - progress) + 12
        local color = Color(213, 191, 161, 120 * (1 - progress)^2)
        render.SetMaterial(beam)
        render.StartBeam(65)
        for i = 0, 64 do
            render.AddBeam(pos + up * 16 + ring[i] * radius, width, i / 8, color)
        end
        render.EndBeam()
        render.StartBeam(65)
        local dust = Color(170, 145, 113, 90 * (1 - progress)^2)
        for i = 0, 64 do
            local lift = 30 + 18 * math.cos(i * math.pi / 4 + elapsed * 3)
            render.AddBeam(pos + up * lift + ring[i] * (radius * 0.92), width * 2.8, i / 8, dust)
        end
        render.EndBeam()
    end
end
