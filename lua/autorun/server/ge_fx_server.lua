-- General Explosions: server-side synchronization for cosmetic world effects.
-- Visuals only: no weapon, projectile, real-world targeting or damage logic.
if CLIENT then return end

util.AddNetworkString("ge_fx_visual_impact_v2")
util.AddNetworkString("ge_fx_crater_snapshot_v2")
util.AddNetworkString("ge_fx_clear_v2")
util.AddNetworkString("ge_fx_ready_v2")

GEFXServer = GEFXServer or {}
local FX = GEFXServer
FX.craters = FX.craters or {}
if FX.craters[1] and not FX.craters[1].id then FX.craters = {} end -- v1 hot reload
FX.serial = FX.serial or 0
FX.generation = FX.generation or 0
local maxCraterHistory = CreateConVar("ge_fx_crater_history", "12", FCVAR_ARCHIVE, "How many visual crater records to sync", 1, 32)

local function sendRecord(c)
    net.WriteUInt(c.id, 32)
    net.WriteFloat(c.time)
    net.WriteVector(c.pos)
    net.WriteNormal(c.normal)
    net.WriteFloat(c.radius)
    net.WriteFloat(c.depth)
    net.WriteUInt(c.seed, 24)
    net.WriteBool(c.glass)
end

function FX.SendSnapshot(ply)
    if not IsValid(ply) then return end
    net.Start("ge_fx_crater_snapshot_v2")
    net.WriteUInt(#FX.craters, 6)
    for _, c in ipairs(FX.craters) do sendRecord(c) end
    net.Send(ply)
end

function FX.Impact(pos, radius, depth, opts)
    opts = opts or {}
    if not GERuntime.Position(pos) then return false end
    radius = GERuntime.Number(radius, 260, 30, 2000)
    depth = GERuntime.Number(depth, radius * 0.24, 0, radius * 0.70)
    FX.serial = FX.serial % 4294967295 + 1
    local normal = opts.normal
    if not GERuntime.Position(normal) or normal:LengthSqr() < 0.5 then normal = Vector(0, 0, 1) end
    local c = {
        id = FX.serial, time = GERuntime.Number(opts.time, CurTime(), CurTime() - 30, CurTime()),
        normal = normal:GetNormalized(),
        pos = Vector(pos.x, pos.y, pos.z), radius = radius, depth = depth,
        seed = math.floor(GERuntime.Number(opts.seed, math.random(1, 16777214), 1, 16777214)), glass = opts.glass == true
    }
    table.insert(FX.craters, c)
    while #FX.craters > maxCraterHistory:GetInt() do table.remove(FX.craters, 1) end

    net.Start("ge_fx_visual_impact_v2")
    sendRecord(c)
    net.Broadcast()
    return true
end

function FX.Clear()
    FX.generation = FX.generation + 1
    FX.craters = {}
    net.Start("ge_fx_clear_v2")
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
    local generation = FX.generation
    for i, offset in ipairs(offsets) do
        timer.Simple((i - 1) * 1.3, function()
            if not IsValid(ply) or generation ~= FX.generation then return end
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

-- A client requests history once its networking/render modules are ready.
-- No client-supplied effect parameters are accepted.
net.Receive("ge_fx_ready_v2", function(_, ply)
    if not IsValid(ply) or (ply._geNextSnapshot or 0) > CurTime() then return end
    ply._geNextSnapshot = CurTime() + 10
    FX.SendSnapshot(ply)
end)

hook.Add("PostCleanupMap", "GE.FX.ClearCraters", function()
    FX.Clear()
end)
