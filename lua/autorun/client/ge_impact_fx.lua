-- General Explosions: optional, purely visual impact accents.
-- The OpenVDB renderer remains the main explosion. These particles add
-- ground-level dust without projectile physics or damage.
if not CLIENT then return end

GEImpactFX = GEImpactFX or {}
local FX = GEImpactFX
local enabled = CreateClientConVar("ge_fx_dust", "1", true, false, "Enable impact dust accents", 0, 1)
local amount = CreateClientConVar("ge_fx_particle_amount", "0.65", true, false, "Impact dust amount", 0, 2)
local distance = CreateClientConVar("ge_fx_particle_distance", "9000", true, false, "Impact dust render cutoff", 1000, 50000)
local MATERIAL = "particle/particle_smokegrenade"

function FX.Burst(pos, scale, seed)
    if not enabled:GetBool() or not isvector(pos) then return end
    local cutoff = distance:GetFloat()
    if EyePos():DistToSqr(pos) > cutoff * cutoff then return end
    scale = math.Clamp(tonumber(scale) or 1, 0.15, 5)
    local count = math.floor(math.Clamp(22 * amount:GetFloat() * math.sqrt(scale), 0, 80))
    if count < 1 then return end
    local emitter = ParticleEmitter(pos)
    if not emitter then return end
    local phase = (tonumber(seed) or 1) % 100 / 100 * math.pi * 2
    for i = 1, count do
        local angle = phase + i * 2.3999632297
        local outward = Vector(math.cos(angle), math.sin(angle), 0)
        local p = emitter:Add(MATERIAL, pos + outward * (10 + math.Rand(2, 26)) * scale)
        if p then
            local velocity = outward * math.Rand(80, 190) * scale + Vector(0, 0, math.Rand(45, 145) * scale)
            local alpha = math.random(65, 140)
            local sz = math.Rand(30, 74) * scale
            p:SetVelocity(velocity)
            p:SetDieTime(math.Rand(1.6, 3.2))
            p:SetStartAlpha(alpha)
            p:SetEndAlpha(0)
            p:SetStartSize(sz * 0.45)
            p:SetEndSize(sz * math.Rand(1.8, 2.7))
            p:SetRoll(math.Rand(0, 360))
            p:SetRollDelta(math.Rand(-1.4, 1.4))
            p:SetAirResistance(110)
            p:SetGravity(Vector(0, 0, -45))
            p:SetColor(93, 84, 77)
            p:SetLighting(true)
        end
    end
    emitter:Finish()
end
