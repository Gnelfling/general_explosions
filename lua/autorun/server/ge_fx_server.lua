-- General Explosions: server-side synchronization for cosmetic world effects.
-- Visuals only: no weapon, projectile, real-world targeting or damage logic.
if CLIENT then return end

util.AddNetworkString("ge_fx_visual_impact_v1")
util.AddNetworkString("ge_fx_crater_snapshot_v1")
util.AddNetworkString("ge_fx_clear_v1")

GEFXServer = GEFXServer or {}
local FX = GEFXServer
FX.craters = FX.craters or {}
local maxCraterHistory = CreateConVar("ge_fx_crater_history", "12", FCVAR_ARCHIVE, "How many visual crater records to sync", 1, 32)

local function sendRecord(c)
    net.WriteVector(c.pos)
    net.WriteFloat(c.radius)
    net.WriteFloat(c.depth)
    net.WriteUInt(c.seed, 24)
    net.WriteBool(c.glass)
end

function FX.SendSnapshot(ply)
    if not IsValid(ply) then return end
    net.Start("ge_fx_crater_snapshot_v1")
    net.WriteUInt(#FX.craters, 6)
    for _, c in ipairs(FX.craters) do sendRecord(c) end
    net.Send(ply)
end

function FX.Impact(pos, radius, depth, opts)
    opts = opts or {}
    if not isvector(pos) then return false end
    radius = math.Clamp(tonumber(radius) or 260, 30, 2000)
    depth = math.Clamp(tonumber(depth) or radius * 0.24, 0, radius * 0.70)
    local c = {
        pos = Vector(pos.x, pos.y, pos.z), radius = radius, depth = depth,
        seed = math.random(1, 16777214), glass = opts.glass == true
    }
    table.insert(FX.craters, c)
    while #FX.craters > maxCraterHistory:GetInt() do table.remove(FX.craters, 1) end

    net.Start("ge_fx_visual_impact_v1")
    sendRecord(c)
    net.Broadcast()
    return true
end

function FX.Clear()
    FX.craters = {}
    net.Start("ge_fx_clear_v1")
    net.Broadcast()
end

local function canUse(ply)
    return not IsValid(ply) or game.SinglePlayer() or ply:IsAdmin()
end

local function groundAim(ply)
    if not IsValid(ply) then return nil end
    local tr = ply:GetEyeTrace()
    if tr.Hit and tr.HitWorld and not tr.HitSky and tr.HitNormal.z > 0.65 then
        return tr.HitPos
    end
    return nil
end

concommand.Add("ge_fx_impact", function(ply, _, args)
    if not canUse(ply) then return end
    local pos = groundAim(ply)
    if not pos then
        if IsValid(ply) then ply:ChatPrint("[GE] Aim at fairly level map ground.") end
        return
    end
    local radius = math.Clamp(tonumber(args[1]) or 260, 30, 2000)
    local depth = math.Clamp(tonumber(args[2]) or radius * 0.24, 0, radius * 0.7)
    FX.Impact(pos, radius, depth, { glass = false })
end, nil, "Cosmetic impact at the ground under your crosshair (no damage)")

-- Three staggered cosmetic effects, suitable for testing frame pacing and
-- visibility with multiple independent volume instances.
concommand.Add("ge_fx_showcase", function(ply, _, args)
    if not canUse(ply) or not IsValid(ply) then return end
    local center = groundAim(ply)
    if not center then
        ply:ChatPrint("[GE] Aim at fairly level map ground.")
        return
    end
    local radius = math.Clamp(tonumber(args[1]) or 200, 30, 600)
    local offsets = { Vector(0, 0, 0), Vector(210, 85, 0), Vector(-200, -75, 0) }
    for i, offset in ipairs(offsets) do
        timer.Simple((i - 1) * 1.3, function()
            if not IsValid(ply) then return end
            local sample = center + offset
            local trace = util.TraceLine({
                start = sample + Vector(0, 0, 400),
                endpos = sample - Vector(0, 0, 1000),
                mask = MASK_SOLID_BRUSHONLY
            })
            if trace.Hit and trace.HitWorld and trace.HitNormal.z > 0.65 then
                FX.Impact(trace.HitPos, radius, radius * 0.24)
            end
        end)
    end
end, nil, "Cosmetic multi-impact showcase, not a weapon: ge_fx_showcase [radius]")

concommand.Add("ge_fx_clear", function(ply)
    if canUse(ply) then FX.Clear() end
end)

hook.Add("PlayerInitialSpawn", "GE.FX.SyncCraters", function(ply)
    timer.Simple(3, function() if IsValid(ply) then FX.SendSnapshot(ply) end end)
end)

hook.Add("PostCleanupMap", "GE.FX.ClearCraters", function()
    FX.craters = {}
    net.Start("ge_fx_clear_v1")
    net.Broadcast()
end)
