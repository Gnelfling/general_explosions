include("shared.lua")
if not include("general_explosions/load_runtime.lua") then return end

-- Original procedural geometry over stock Source materials. No new shaders.
local enabled = CreateClientConVar("ge_railgun_visuals", "1", true, false, "Show orbital presentation", 0, 1)
local colorCV = CreateClientConVar("ge_railgun_color", "blue", true, false, "Beam tint: blue, purple, red")
local heightCV = CreateClientConVar("ge_railgun_beam_height", "6000", true, false, "Orbital column height", 1000, 10000)
local widthCV = CreateClientConVar("ge_railgun_beam_width", "1.75", true, false, "Beam width multiplier", 0.5, 3)
local glowCV = CreateClientConVar("ge_railgun_glow", "1", true, false, "Occlusion-aware impact glare", 0, 1)
local lightCV = CreateClientConVar("ge_railgun_light", "1", true, false, "Local environmental light", 0, 1)
local qualityCV = CreateClientConVar("ge_railgun_quality", "1", true, false, "Beam detail: 0, 1, 2", 0, 2)
local distanceCV = CreateClientConVar("ge_railgun_distance", "18000", true, false, "Orbital visual cutoff", 2000, 50000)
local lightsCV = CreateClientConVar("ge_railgun_light_budget", "2", true, false, "Nearest orbital lights allowed", 0, 4)
local beamMat = Material("sprites/physbeam")
local arcMat = Material("cable/blue_elec")
local glowMat = Material("sprites/light_glow02_add")
local UP, TAU = Vector(0, 0, 1), math.pi * 2
local R = GERuntime
local palettes = {
    blue = { outer = { 32, 141, 255 }, core = { 231, 249, 255 } },
    purple = { outer = { 166, 78, 255 }, core = { 248, 222, 255 } },
    red = { outer = { 255, 65, 94 }, core = { 255, 235, 226 } }
}
local function palette() return palettes[string.lower(colorCV:GetString())] or palettes.blue end
local function tint(rgb, alpha) return Color(rgb[1], rgb[2], rgb[3], math.Clamp(alpha, 0, 255)) end
local circles = {}
local function circle(segments)
    if circles[segments] then return circles[segments] end
    local points = {}
    for i = 0, segments do
        local angle = i / segments * TAU
        points[i] = { math.cos(angle), math.sin(angle) }
    end
    circles[segments] = points
    return points
end

local function basis(normal)
    if normal:LengthSqr() < 0.5 then normal = UP end
    local right = Vector(0, 1, 0):Cross(normal):GetNormalized()
    return normal, right, normal:Cross(right):GetNormalized()
end

local function ring(pos, right, forward, radius, segments, width, col, rotation, first, count)
    if radius < 1 or width <= 0 or col.a <= 0 then return end
    first, count = first or 0, count or segments
    local points = circle(segments)
    local cs, sn = math.cos(rotation or 0), math.sin(rotation or 0)
    render.SetMaterial(beamMat)
    render.StartBeam(count + 1)
    for j = first, first + count do
        local p = points[j % segments]
        local x, y = p[1] * cs - p[2] * sn, p[1] * sn + p[2] * cs
        render.AddBeam(pos + (right * x + forward * y) * radius, width, j / segments * 4, col)
    end
    render.EndBeam()
end

local function retireLight(self)
    if not self._geLightActive then return end
    local light = DynamicLight(self:EntIndex())
    if light then light.size = 0; light.brightness = 0; light.dietime = CurTime() + 0.01 end
    self._geLightActive = false
end

-- Small entity registry, not a world search on every light update.
GERailgunVisuals = GERailgunVisuals or { active = {} }
local registry = GERailgunVisuals
local lightFrame, selected = -1, {}
local function lightSelected(self)
    if lightFrame ~= FrameNumber() then
        lightFrame, selected = FrameNumber(), {}
        local candidates, eye = {}, EyePos()
        for ent in pairs(registry.active) do
            if IsValid(ent) and not ent._geCancelled then
                local t = CurTime() - ent:GetStartTime()
                local d = eye:DistToSqr(ent:GetPos())
                if t >= 0 and t < ent.GELifetime and d < 5000 ^ 2 then
                    candidates[#candidates + 1] = { ent = ent, distance = d }
                end
            end
        end
        table.sort(candidates, function(a, b) return a.distance < b.distance end)
        for i = 1, math.min(lightsCV:GetInt(), #candidates) do selected[candidates[i].ent] = true end
    end
    return selected[self]
end

function ENT:Initialize()
    self:SetRenderBounds(Vector(-5200, -5200, -5200), Vector(5200, 5200, 10400))
    self._geVisibility = util.GetPixelVisibleHandle()
    registry.active[self] = true
end

local function visibility(self, pos)
    -- A handle must not be queried twice in one engine tick (mirrors/RTs).
    local tick = engine.TickCount()
    if self._geVisTick ~= tick then
        self._geVisTick = tick
        self._geVisible = util.PixelVisible(pos, 24, self._geVisibility) or 0
    end
    return self._geVisible or 0
end

local function charge(self, t, col, alpha, detail, normal, right, forward, radius)
    local pos = self:GetPos() + normal * 5
    local f = R.Smooth(t / self.GEFireAt)
    local segments = detail == 0 and 24 or (detail == 1 and 48 or 72)
    local spin = t * (0.45 + f * 0.9) + self:GetVisualSeed() % 17
    local aperture = radius * (0.85 - f * 0.55)
    ring(pos, right, forward, aperture, segments, 3 + f * 5, tint(col.core, (35 + f * 150) * alpha), spin)
    -- Six separated arc sectors read as an assembling magnetic aperture.
    for i = 0, 5 do
        ring(pos + normal * (8 + f * 18), right, forward, radius * (1.1 - f * 0.25),
            segments, 3 + f * 3, tint(col.outer, (55 + f * 110) * alpha), -spin,
            i * segments / 6, math.floor(segments / 9))
    end
    ring(pos, right, forward, radius * (1.35 - f * 0.2), segments, 2,
        tint(col.outer, 45 * alpha), spin * 0.4)
    render.SetMaterial(beamMat)
    local spokes = detail == 0 and 6 or 10
    for i = 1, spokes do
        local a = i / spokes * TAU + spin
        local dir = right * math.cos(a) + forward * math.sin(a)
        local edge = pos + dir * radius * (1.0 - f * 0.15)
        local core = pos + dir * aperture * 0.8 + normal * (10 + f * 75)
        render.DrawBeam(edge, core, 1.5 + 2 * f, t, t + 1, tint(col.outer, (25 + f * 75) * alpha))
    end
    if not glowCV:GetBool() then return end
    render.SetMaterial(glowMat)
    -- Analytic motes: independent of framerate, no particle emitter per frame.
    local motes = detail == 0 and 8 or (detail == 1 and 16 or 24)
    for i = 1, motes do
        local u = (t * (0.48 + f * 0.3) + i / motes) % 1
        local a = i * 2.399963 + t * 1.8 + u * 3
        local p = pos + (right * math.cos(a) + forward * math.sin(a)) * radius * (1 - u) ^ 1.4
            + normal * (12 + u * u * (100 + f * 100))
        local size = (3 + 7 * u) * (0.6 + f)
        render.DrawSprite(p, size, size, tint(col.core, math.sin(u * math.pi) * 180 * alpha))
    end
    local size = 35 + f * 130 + math.sin(t * 21) * 8 * f
    render.DrawSprite(pos + normal * (15 + f * 65), size, size, tint(col.outer, 180 * alpha))
end

local function column(self, t, col, alpha, detail, radius)
    local pos = self:GetPos() + UP * 15
    local height = heightCV:GetFloat()
    local source = pos + UP * height
    local travel = R.Smooth((t - self.GEFireAt) / (self.GEImpactAt - self.GEFireAt))
    local target = source + (pos - source) * travel
    local fade = R.Smooth((t - self.GEFireAt) / 0.035) * R.Smooth((self.GEBeamEnd - t) / 0.4) * alpha
    if fade <= 0 then return end
    local width = radius * 0.30 * widthCV:GetFloat() * (1 + math.sin(t * 53) * 0.055 + math.sin(t * 87) * 0.025)
    local flow = t * 5
    render.SetMaterial(beamMat)
    render.DrawBeam(source, target, width * 4.6, flow, flow + 12, tint(col.outer, 25 * fade))
    render.DrawBeam(source, target, width * 2.0, flow * 1.2, flow * 1.2 + 12, tint(col.outer, 145 * fade))
    render.DrawBeam(source, target, width * 0.60, flow * 1.6, flow * 1.6 + 12, tint(col.core, 250 * fade))
    -- Curved, deterministic filaments instead of five parallel straight lines.
    local strands, steps = detail + 2, detail == 0 and 6 or (detail == 1 and 12 or 18)
    render.SetMaterial(arcMat)
    for strand = 1, strands do
        render.StartBeam(steps + 1)
        for j = 0, steps do
            local u = j / steps
            local a = u * TAU * 2.2 + t * (4 + strand) + strand * 2.399963 + self:GetVisualSeed() % 31
            local radial = math.sin(u * math.pi) * width * (0.9 + 0.2 * math.sin(u * 31 + t * 13))
            local p = target + (source - target) * u + Vector(math.cos(a), math.sin(a), 0) * radial
            render.AddBeam(p, math.max(2, width * 0.07), flow + u * 9, tint(col.outer, 160 * fade))
        end
        render.EndBeam()
    end
    -- Moving collars show energy flow down the column at medium/high detail.
    if detail > 0 then
        for i = 1, detail + 1 do
            local u = (t * 1.8 + i / (detail + 1)) % 1
            if u <= travel then
                ring(source - UP * height * u, Vector(1,0,0), Vector(0,1,0), width * (1.0 + 0.3 * u),
                    24, 3, tint(col.core, 90 * fade * math.sin(u * math.pi)), t)
            end
        end
    end
    if glowCV:GetBool() then
        render.SetMaterial(glowMat)
        local vis = visibility(self, target)
        render.DrawSprite(target, width * 4, width * 4, tint(col.core, 200 * fade * vis))
        render.DrawSprite(target, width * 8, width * 8, tint(col.outer, 60 * fade * vis))
    end
end

local function impact(self, t, col, alpha, detail, normal, right, forward, radius)
    local elapsed = t - self.GEImpactAt
    if elapsed < 0 then return end
    local pos = self:GetPos() + normal * 9
    local segments = detail == 0 and 32 or (detail == 1 and 64 or 96)
    local wave = math.Clamp(elapsed / 1.35, 0, 1)
    local expansion = 1 - (1 - wave) ^ 2
    ring(pos + normal * (18 * wave), right, forward, radius * (0.15 + expansion * 4.2),
        segments, radius * 0.13 * (1 - wave) + 1, tint(col.core, 200 * (1 - wave) ^ 2 * alpha), 0)
    local trailing = math.Clamp((elapsed - 0.08) / 1.5, 0, 1)
    ring(pos, right, forward, radius * (0.2 + (1 - (1 - trailing) ^ 2) * 3.6),
        segments, 8 + radius * 0.04 * (1 - trailing), tint(col.outer, 110 * (1 - trailing) ^ 3 * alpha), 0)
    if not glowCV:GetBool() or elapsed > 0.7 then return end
    local flash = math.exp(-elapsed * 10) + 0.22 * math.exp(-elapsed * 3.5)
    local vis = visibility(self, pos + normal * 45)
    render.SetMaterial(glowMat)
    local size = radius * (2.8 + elapsed * 2)
    render.DrawSprite(pos + normal * 45, size, size, tint(col.core, 235 * flash * alpha * vis))
    render.DrawSprite(pos + normal * 45, size * 1.9, size * 1.9, tint(col.outer, 70 * flash * alpha * vis))
    render.SetMaterial(beamMat)
    local screenRight = EyeAngles():Right()
    render.DrawBeam(pos - screenRight * radius * 2.4, pos + screenRight * radius * 2.4,
        radius * 0.08, 0, 1, tint(col.core, 110 * flash * alpha * vis))
end

-- Supplemental choreography. These layers never replace the charge, beam,
-- shock rings, particles, crater or VDB; all phases use the server clock.
local function containment(self, t, col, alpha, detail, normal, right, forward, radius)
    local f = R.Smooth(t / self.GEFireAt)
    local assemble = R.Smooth(t / 0.8)
    local lock = R.Smooth((t - 2.35) / 0.65)
    local pos = self:GetPos()
    local segments = detail == 0 and 24 or 48
    local seed = self:GetVisualSeed() % 19
    -- Floating, canted containment hoops rise out of the surface and collapse
    -- into a narrow throat immediately before firing.
    for i = 1, detail + 2 do
        local angle = t * (0.6 + i * 0.12) * (i % 2 == 0 and -1 or 1) + seed + i * 2.1
        local axis = right * math.cos(angle) + forward * math.sin(angle)
        local tangent = normal:Cross(axis)
        local tilt = 0.28 + 0.20 * math.sin(t * 0.7 + i)
        local tilted = axis * math.cos(tilt) + normal * math.sin(tilt)
        local center = pos + normal * radius * assemble * (0.22 + i * 0.20) * (1 - lock * 0.35)
        local r = radius * (0.75 + i * 0.12) * assemble * (1 - lock * 0.8)
        ring(center, tilted, tangent, r, segments, 2 + f * 2,
            tint(col.outer, (30 + f * 65) * assemble * alpha), angle,
            0, math.floor(segments * 0.75))
    end
    -- Six axial latches snap toward the core as a final, readable anticipation.
    if lock > 0 then
        render.SetMaterial(beamMat)
        for i = 1, 6 do
            local angle = i / 6 * TAU + seed
            local dir = right * math.cos(angle) + forward * math.sin(angle)
            local p = pos + dir * radius * (1.2 - lock * 0.85) + normal * 12
            render.DrawBeam(p, p + normal * radius * (0.12 + lock * 0.32),
                3 + lock * 3, 0, 1, tint(col.core, lock * 160 * alpha))
        end
    end
    -- Orbital emitter iris appears overhead while the ground aperture locks.
    local sky = R.Smooth((t - 1.75) / 1.0)
    if sky > 0 then
        local top = pos + UP * heightCV:GetFloat()
        ring(top, Vector(1,0,0), Vector(0,1,0), radius * (2.5 - lock * 0.8),
            segments, 8, tint(col.outer, sky * 100 * alpha), -t)
        ring(top - UP * 45, Vector(1,0,0), Vector(0,1,0), radius * (1.5 - lock * 0.8),
            segments, 4, tint(col.core, sky * 130 * alpha), t)
    end
end

local function discharge(self, t, col, alpha, detail, radius)
    local e = t - self.GEFireAt
    local fade = R.Smooth(e / 0.035) * R.Smooth((self.GEBeamEnd - t) / 0.4) * alpha
    local pos = self:GetPos() + UP * 15
    local height = heightCV:GetFloat()
    local top = pos + UP * height
    local travel = R.Smooth(e / (self.GEImpactAt - self.GEFireAt))
    -- A compressed luminous torus rides the leading edge of the discharge.
    ring(top - UP * height * travel, Vector(1,0,0), Vector(0,1,0),
        radius * (0.35 + (1 - travel) * 0.9) * widthCV:GetFloat(), 24, radius * 0.035,
        tint(col.core, fade * (1 - R.Smooth((e - 0.2) / 0.15)) * 220), t)
    -- The sky iris stays energized during firing, tying the column to a source.
    ring(top, Vector(1,0,0), Vector(0,1,0), radius * 1.7, detail == 0 and 24 or 48,
        7, tint(col.outer, fade * 100), -t)
end

local function pressureCrown(self, t, col, alpha, detail, normal, right, forward, radius)
    local e = t - self.GEImpactAt
    local pos = self:GetPos() + normal * 12
    if e < 0 then return end
    -- Three sparse meridian arcs give the ground shockwave a hemispherical
    -- pressure front. No refraction, screen capture or depth overrides.
    if detail > 0 and e < 0.85 then
        local u = e / 0.85
        local spread = radius * (0.2 + (1 - (1 - u) ^ 2) * 2.8)
        for i = 1, detail + 1 do
            local angle = i / (detail + 1) * math.pi + self:GetVisualSeed() % 7
            local axis = right * math.cos(angle) + forward * math.sin(angle)
            ring(pos, axis, normal, spread, 32, 5 * (1 - u) + 1,
                tint(col.outer, 65 * (1 - u) ^ 2 * alpha), 0, 0, 16)
        end
    end
    -- Inert ion trails fan upward after the flash. Each is an analytic short
    -- polyline, so joining late or changing FPS cannot multiply emissions.
    local count, steps = detail == 0 and 4 or (detail == 1 and 6 or 8), 5
    render.SetMaterial(arcMat)
    for i = 1, count do
        local age = e - (i % 3) * 0.055
        if age > 0 and age < 1.65 then
            local u = age / 1.65
            local a = i * 2.399963 + self:GetVisualSeed() % 23
            local dir = right * math.cos(a) + forward * math.sin(a)
            render.StartBeam(steps + 1)
            for j = 0, steps do
                local v = math.max(0, u - (1 - j / steps) * 0.16)
                local wobble = math.sin(v * 18 + i) * radius * 0.04 * v
                local p = pos + dir * radius * (0.15 + v * 1.8)
                    + normal * radius * (2.4 * v - 1.6 * v * v)
                    + normal:Cross(dir) * wobble
                render.AddBeam(p, (2 + radius * 0.009) * (1 - u), v * 3,
                    tint(col.outer, 125 * (1 - u) ^ 2 * (j / steps) * alpha))
            end
            render.EndBeam()
        end
    end
end

function ENT:DrawTranslucent()
    if not enabled:GetBool() or self._geCancelled then return end
    local begin = self:GetStartTime()
    if begin <= 0 then return end
    local t = CurTime() - begin
    if t < 0 or t > self.GELifetime then return end
    local d, limit = EyePos():DistToSqr(self:GetPos()), distanceCV:GetFloat()
    if d > limit * limit then return end
    local alpha = 1 - R.Smooth((math.sqrt(d) / limit - 0.8) / 0.2)
    local detail = qualityCV:GetInt()
    if d > 6500 ^ 2 then detail = 0 elseif d > 3500 ^ 2 then detail = math.min(detail, 1) end
    local normal, right, forward = basis(self:GetGroundNormal())
    local radius = R.Number(self:GetImpactRadius(), 320, 80, 900)
    local col = palette()
    if t < self.GEFireAt then
        charge(self, t, col, alpha, detail, normal, right, forward, radius)
        containment(self, t, col, alpha, detail, normal, right, forward, radius)
    end
    if t >= self.GEFireAt and t <= self.GEBeamEnd then
        column(self, t, col, alpha, detail, radius)
        discharge(self, t, col, alpha, detail, radius)
    end
    if t >= self.GEImpactAt then
        impact(self, t, col, alpha, detail, normal, right, forward, radius)
        pressureCrown(self, t, col, alpha, detail, normal, right, forward, radius)
    end
    -- No blend/depth/stencil/lighting overrides are used by this renderer.
end

function ENT:Think()
    if not self._geVACStarted and not self._geCancelled and enabled:GetBool()
        and self:GetStartTime() > 0 and CurTime() >= self:GetStartTime() + self.GEImpactAt then
        self._geVACStarted = true
        if GEVACImpact then
            GEVACImpact.Spawn(self:GetPos() - UP * 3, self:GetImpactRadius(), self:GetStartTime() + self.GEImpactAt)
        end
    end
    if not enabled:GetBool() or not lightCV:GetBool() or self._geCancelled then retireLight(self) return end
    local begin = self:GetStartTime()
    local t = CurTime() - begin
    if begin <= 0 or t < 0 or t > self.GEBeamEnd + 0.7 or not lightSelected(self) then retireLight(self) return end
    if (self._geNextLight or 0) > CurTime() then return end
    self._geNextLight = CurTime() + 0.05
    local col, f = palette(), R.Smooth(t / self.GEFireAt)
    local elapsed = t - self.GEImpactAt
    local flash = elapsed >= 0 and math.exp(-elapsed * 5.5) or 0
    local beam = t >= self.GEFireAt and R.Smooth((self.GEBeamEnd + 0.7 - t) / 0.9) or 0
    local light = DynamicLight(self:EntIndex())
    if not light then return end
    local normal = self:GetGroundNormal()
    light.pos = self:GetPos() + normal * 100
    light.r = col.outer[1] + (col.core[1] - col.outer[1]) * flash
    light.g = col.outer[2] + (col.core[2] - col.outer[2]) * flash
    light.b = col.outer[3] + (col.core[3] - col.outer[3]) * flash
    light.brightness = (t < self.GEFireAt and f * f * 0.9 or beam * 1.8) + flash * 2.5
    light.size = math.Clamp(self:GetImpactRadius() * (1.3 + f + flash * 1.3), 200, 1800)
    light.decay, light.dietime = 2000, CurTime() + 0.15
    self._geLightActive = true
end

function ENT:OnRemove()
    registry.active[self] = nil
    retireLight(self)
end
hook.Add("PostCleanupMap", "GE.Railgun.Cleanup", function()
    for ent in pairs(registry.active) do
        if IsValid(ent) then ent._geCancelled = true; retireLight(ent) end
    end
end)
