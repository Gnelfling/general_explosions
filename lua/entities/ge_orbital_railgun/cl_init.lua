include("shared.lua")

-- Clientside cinematic only. Uses standard Source additive beam materials,
-- avoiding a new compiled shader or any new downloadable texture assets.
local enabledCV = CreateClientConVar("ge_railgun_visuals", "1", true, false, "Show cosmetic orbital beam", 0, 1)
local colorCV = CreateClientConVar("ge_railgun_color", "blue", true, false, "Beam tint: blue, purple, red")
local heightCV = CreateClientConVar("ge_railgun_beam_height", "6000", true, false, "Visual beam length in Source units", 1000, 10000)
local glowCV = CreateClientConVar("ge_railgun_glow", "1", true, false, "Enable glow sprites", 0, 1)
local lightCV = CreateClientConVar("ge_railgun_light", "1", true, false, "Enable brief dynamic lighting", 0, 1)

local beamMat = Material("sprites/physbeam")
local arcMat = Material("cable/blue_elec")
local glowMat = Material("sprites/light_glow02_add")
local UP = Vector(0, 0, 1)

local palettes = {
    blue = { outer = { 32, 141, 255 }, core = { 231, 249, 255 } },
    purple = { outer = { 166, 78, 255 }, core = { 248, 222, 255 } },
    red = { outer = { 255, 65, 94 }, core = { 255, 235, 226 } }
}

local function tint(rgb, alpha)
    return Color(rgb[1], rgb[2], rgb[3], math.Clamp(alpha, 0, 255))
end

local function palette()
    return palettes[string.lower(colorCV:GetString())] or palettes.blue
end

local function drawRing(pos, radius, segments, width, col, angle)
    if radius < 1 or width <= 0 or col.a <= 0 then return end
    render.SetMaterial(beamMat)
    render.StartBeam(segments + 1)
    for i = 0, segments do
        local theta = i / segments * math.pi * 2 + (angle or 0)
        local point = pos + Vector(math.cos(theta) * radius, math.sin(theta) * radius, 5)
        render.AddBeam(point, width, i / segments * 2, col)
    end
    render.EndBeam()
end

function ENT:Initialize()
    -- A model is present as an engine anchor; render only custom beams.
    -- Generous bounds prevent the tall sky column from being view-culled.
    self:SetRenderBounds(
        Vector(-2400, -2400, -256),
        Vector(2400, 2400, 10400)
    )
end

local function drawCharge(self, t, color)
    local pos = self:GetPos()
    local fraction = math.Clamp(t / self.GEFireAt, 0, 1)
    local spin = t * 0.85
    local radius = 105 + 48 * math.sin(t * 3) + fraction * 60
    local alpha = 65 + fraction * 115

    drawRing(pos, radius, 48, 6 + fraction * 5, tint(color.outer, alpha), spin)
    drawRing(pos, radius * 1.38, 48, 3 + fraction * 3, tint(color.outer, alpha * 0.65), -spin * 0.75)

    -- Radial charge arcs converge toward the impact point.
    render.SetMaterial(beamMat)
    for i = 1, 8 do
        local a = t * 0.65 + i * (math.pi * 2 / 8)
        local spread = 220 + 65 * math.sin(t * 1.5 + i)
        local edge = pos + Vector(math.cos(a) * spread, math.sin(a) * spread, 8)
        local inner = pos + Vector(math.cos(a) * 32, math.sin(a) * 32, 12)
        render.DrawBeam(edge, inner, 3 + fraction * 3, t * 0.5, t * 0.5 + 1, tint(color.outer, 45 + fraction * 75))
    end

    if glowCV:GetBool() then
        local sz = 46 + 70 * fraction + 20 * math.sin(t * 11)
        render.SetMaterial(glowMat)
        render.DrawSprite(pos + UP * 15, sz, sz, tint(color.outer, 115 + fraction * 80))
    end
end

local function drawColumn(self, t, color)
    local pos = self:GetPos()
    local height = heightCV:GetFloat()
    local source = pos + UP * height
    local target = pos + UP * 15
    local start = t - self.GEFireAt
    local fadeIn = math.Clamp(start / 0.07, 0, 1)
    local fadeOut = math.Clamp((self.GEBeamEnd - t) / 0.40, 0, 1)
    local fade = fadeIn * fadeOut
    if fade <= 0 then return end

    local flicker = 1 + math.sin(t * 56) * 0.11 + math.sin(t * 91) * 0.05
    local width = (82 + 28 * math.sin(t * 17)) * flicker
    local flow = t * 5

    -- Outer aura, saturated core, and flickering bright center.
    render.SetMaterial(beamMat)
    render.DrawBeam(source, target, width * 4.0, flow, flow + 10, tint(color.outer, 42 * fade))
    render.DrawBeam(source, target, width * 2.2, flow * 1.2, flow * 1.2 + 10, tint(color.outer, 145 * fade))
    render.DrawBeam(source, target, width * 0.80, flow * 1.6, flow * 1.6 + 10, tint(color.core, 240 * fade))

    -- A few unstable electrical strands make the column feel energetic.
    render.SetMaterial(arcMat)
    for i = 1, 5 do
        local a = t * (7 + i) + i * 2.39996
        local offset = Vector(math.cos(a) * width * 0.55, math.sin(a) * width * 0.55, 0)
        render.DrawBeam(source + offset, target + offset * 0.25,
            math.max(6, width * 0.10), flow + i * 0.2, flow + 8 + i * 0.2,
            tint(color.outer, 110 * fade))
    end

    if glowCV:GetBool() then
        render.SetMaterial(glowMat)
        render.DrawSprite(target, 430 * fade, 430 * fade, tint(color.core, 200 * fade))
        render.DrawSprite(target, 750 * fade, 750 * fade, tint(color.outer, 68 * fade))
    end
end

local function drawImpact(self, t, color)
    local elapsed = t - self.GEImpactAt
    if elapsed < 0 or elapsed > 1.5 then return end
    local pos = self:GetPos()
    local wave = math.Clamp(elapsed / 1.25, 0, 1)
    drawRing(pos, 35 + 1000 * wave, 64, 52 * (1 - wave) + 2,
        tint(color.core, 200 * (1 - wave) ^ 2), 0)
    drawRing(pos, 30 + 700 * math.Clamp(elapsed / 0.85, 0, 1),
        48, math.max(1, 18 * (1 - wave)), tint(color.outer, 155 * (1 - wave)), 0)

    if glowCV:GetBool() and elapsed < 0.62 then
        local flash = (1 - elapsed / 0.62) ^ 1.7
        render.SetMaterial(glowMat)
        render.DrawSprite(pos + UP * 35, 800 * flash, 800 * flash, tint(color.core, 230 * flash))
        render.DrawSprite(pos + UP * 35, 1150 * flash, 1150 * flash, tint(color.outer, 110 * flash))
    end
end

function ENT:DrawTranslucent()
    if not enabledCV:GetBool() then return end
    local begin = self:GetStartTime()
    if begin <= 0 then return end
    local t = CurTime() - begin
    if t < 0 or t > self.GELifetime then return end
    local col = palette()

    if t < self.GEFireAt then drawCharge(self, t, col) end
    if t >= self.GEFireAt and t <= self.GEBeamEnd then drawColumn(self, t, col) end
    if t >= self.GEImpactAt then drawImpact(self, t, col) end
end

function ENT:Think()
    if not lightCV:GetBool() then return end
    local begin = self:GetStartTime()
    if begin <= 0 then return end
    local t = CurTime() - begin
    if t < self.GEFireAt or t > self.GEBeamEnd + 0.25 then return end
    local col = palette()
    local impactFlash = t >= self.GEImpactAt and (1 - math.Clamp((t - self.GEImpactAt) / 0.7, 0, 1)) or 0
    local strength = math.Clamp(0.9 + 1.8 * impactFlash, 0, 3)
    local dynamic = DynamicLight(self:EntIndex())
    if not dynamic then return end
    dynamic.pos = self:GetPos() + UP * 110
    dynamic.r = col.outer[1]
    dynamic.g = col.outer[2]
    dynamic.b = col.outer[3]
    dynamic.brightness = strength
    dynamic.Decay = 1200
    dynamic.Size = math.Clamp(430 + self:GetImpactRadius() * 2.2, 450, 1700)
    dynamic.DieTime = CurTime() + 0.12
end
