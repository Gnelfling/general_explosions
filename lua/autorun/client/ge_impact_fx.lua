-- Bounded secondary accents; the original OpenVDB volume remains the explosion.
if not CLIENT then return end
GEImpactFX = GEImpactFX or {}
local FX = GEImpactFX
if FX.Clear then FX.Clear() end
local enabled = CreateClientConVar("ge_fx_dust", "1", true, false, "Impact particle accents", 0, 1)
local amount = CreateClientConVar("ge_fx_particle_amount", "0.65", true, false, "Impact particle density", 0, 2)
local distance = CreateClientConVar("ge_fx_particle_distance", "9000", true, false, "Particle cutoff", 1000, 50000)
local budget = CreateClientConVar("ge_fx_particle_budget", "192", true, false, "Maximum addon impact particles", 32, 512)
local active = {}
local UP = Vector(0, 0, 1)

local function finish(record, hide)
    if hide then record.emitter:SetNoDraw(true) end
    record.emitter:Finish()
end
function FX.Clear()
    for _, record in ipairs(active) do finish(record, true) end
    active = {}
end
hook.Add("PostCleanupMap", "GE.Particles.Cleanup", FX.Clear)
hook.Add("ShutDown", "GE.Particles.Shutdown", FX.Clear)
hook.Add("Think", "GE.Particles.Retire", function()
    for i = #active, 1, -1 do
        local record = active[i]
        if CurTime() >= record.expires then finish(record, false); table.remove(active, i) end
    end
end)

function FX.Burst(pos, scale, seed, normal)
    if not enabled:GetBool() or not GERuntime.Position(pos) then return 0 end
    local d, cutoff = EyePos():DistToSqr(pos), distance:GetFloat()
    if d > cutoff * cutoff then return 0 end
    if #active >= 8 then return 0 end
    local used = 0
    for _, record in ipairs(active) do used = used + record.count end
    local available = math.max(0, budget:GetInt() - used)
    scale = GERuntime.Number(scale, 1, 0.15, 5)
    local density = amount:GetFloat() * math.sqrt(scale) * (1 - 0.7 * GERuntime.Smooth(d / (cutoff * cutoff)))
    local count = math.min(available, math.floor(math.min(128, 56 * density)))
    if count < 1 then return 0 end
    if not GERuntime.Position(normal) or normal:LengthSqr() < 0.5 then normal = UP end
    normal = normal:GetNormalized()
    local right = Vector(0, 1, 0):Cross(normal):GetNormalized()
    local forward = normal:Cross(right):GetNormalized()
    local random = GERuntime.Random(seed)
    local emitter = ParticleEmitter(pos)
    if not emitter then return 0 end
    local record = { emitter = emitter, count = 0, expires = CurTime() + 4 }
    active[#active + 1] = record
    local ok, err = xpcall(function()
        for i = 1, count do
            local angle = i * 2.3999632297 + random(-0.12, 0.12)
            local dir = right * math.cos(angle) + forward * math.sin(angle)
            local dust = i % 3 == 0
            local chip = i % 3 == 1
            local material = dust and "particle/particle_smokegrenade" or (chip and "effects/fleck_cement1" or "effects/spark")
            local p = emitter:Add(material, pos + dir * random(8, 40) * scale)
            if p then
                record.count = record.count + 1
                local speed = dust and random(130, 250) or random(240, 620)
                local lift = dust and random(25, 90) or random(180, 470)
                p:SetVelocity((dir * speed + normal * lift) * scale)
                p:SetDieTime(dust and random(2.1, 3.8) or random(0.55, 1.8))
                p:SetStartAlpha(dust and random(65, 115) or 240)
                p:SetEndAlpha(0)
                local size = (dust and random(18, 36) or (chip and random(2, 5) or random(1, 2.5))) * scale
                p:SetStartSize(size)
                p:SetEndSize(dust and size * random(2.4, 3.5) or 0)
                p:SetRoll(random(0, math.pi * 2))
                p:SetRollDelta(random(-2, 2))
                p:SetAirResistance(dust and 140 or 30)
                p:SetGravity(UP * (dust and -25 or -420))
                p:SetCollide(false) -- Avoid per-particle collision traces.
                p:SetLighting(dust or chip)
                if dust then p:SetColor(106, 96, 85)
                elseif chip then p:SetColor(69, 61, 54)
                else p:SetColor(255, 191, 110); p:SetStartLength(size * 10); p:SetEndLength(0) end
            end
        end
    end, debug.traceback)
    if not ok then
        finish(record, true)
        table.remove(active)
        ErrorNoHalt("[GE] Particle burst failed: " .. tostring(err) .. "\n")
    end
    return record.count
end
