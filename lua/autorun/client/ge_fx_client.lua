-- Cosmetic event coordination; all animation ages use server CurTime.
if not CLIENT then return end
if not include("general_explosions/load_runtime.lua") then return end
GEVisuals = GEVisuals or {}
local FX = GEVisuals
local queue, pending, seen, order = {}, {}, {}, {}
local function report(kind, reason)
    FX.warnings = FX.warnings or {}
    local key = kind .. tostring(reason)
    if FX.warnings[key] then return end
    FX.warnings[key] = true
    print("[GE] " .. kind .. ": " .. tostring(reason))
end

local function crater(c)
    queue[#queue + 1] = c
    while #queue > 32 do table.remove(queue, 1) end
end

local function transient(c)
    local age = CurTime() - c.time
    if age < 0 then
        pending[#pending + 1] = c
        while #pending > 32 do table.remove(pending, 1) end
        return
    end
    if age < 0.35 and age >= 0 and GEImpactFX then
        GEImpactFX.Burst(c.pos + c.normal * 4, c.radius / 260, c.seed, c.normal)
    end
    if GEVolume then
        local ok, reason = GEVolume.Spawn(c.pos + Vector(0, 0, 4), c.radius / 260, c.time)
        if not ok and reason ~= "animation expired" then report("Volume", reason) end
    end
end

local function receive(c, snapshot)
    if not GERuntime.Position(c.pos) or not GERuntime.Finite(c.time)
        or c.time < 0 or c.time > CurTime() + 5 then return end
    c.radius = GERuntime.Number(c.radius, 260, 30, 2000)
    c.depth = GERuntime.Number(c.depth, c.radius * 0.24, 0, c.radius * 0.7)
    if snapshot or not seen[c.id] then crater(c) end
    if seen[c.id] then return end
    seen[c.id] = true
    order[#order + 1] = c.id
    while #order > 64 do seen[table.remove(order, 1)] = nil end
    transient(c)
end

local function readRecord()
    return {
        id = net.ReadUInt(32), time = net.ReadFloat(), pos = net.ReadVector(), normal = net.ReadNormal(),
        radius = net.ReadFloat(), depth = net.ReadFloat(), seed = net.ReadUInt(24), glass = net.ReadBool()
    }
end

function FX.SpawnAt(pos, radius, depth, seed, glass)
    if not GERuntime.Position(pos) then return end
    local c = { pos = pos, radius = GERuntime.Number(radius, 260, 30, 2000),
        seed = seed, glass = glass, time = CurTime(), normal = Vector(0, 0, 1) }
    c.depth = GERuntime.Number(depth, c.radius * 0.24, 0, c.radius * 0.7)
    crater(c)
    transient(c)
end

hook.Add("Think", "GE.FX.BuildCraters", function()
    for i = #pending, 1, -1 do
        if pending[i].time <= CurTime() then transient(table.remove(pending, i)) end
    end
    -- At most one mesh build per frame; joins cannot trigger 32 builds at once.
    if #queue == 0 or not GECraters then return end
    if queue[1].time > CurTime() then return end
    local c = table.remove(queue, 1)
    local ok, err = GECraters.Add(c.pos, c.radius, c.depth, { seed = c.seed, glass = c.glass, time = c.time })
    if not ok then report("Crater", err) end
end)

net.Receive("ge_fx_visual_impact_v2", function() receive(readRecord(), false) end)
net.Receive("ge_fx_crater_snapshot_v2", function()
    local count = net.ReadUInt(6)
    queue = {}
    if GECraters then GECraters.Clear() end
    for _ = 1, count do receive(readRecord(), true) end
end)

function FX.Clear()
    if GEVACImpact then GEVACImpact.Clear() end
    queue, pending, seen, order = {}, {}, {}, {}
    if GECraters then GECraters.Clear() end
    if GEVolume then GEVolume.ClearInstances() end
    if GEImpactFX and GEImpactFX.Clear then GEImpactFX.Clear() end
end
net.Receive("ge_fx_clear_v2", FX.Clear)
hook.Add("PostCleanupMap", "GE.FX.Cleanup", FX.Clear)
local function ready()
    net.Start("ge_fx_ready_v2")
    net.SendToServer()
end
hook.Add("InitPostEntity", "GE.FX.Ready", ready)
concommand.Add("ge_fx_resync", ready)

concommand.Add("ge_fx_local_test", function(_, _, args)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local tr = ply:GetEyeTrace()
    if not tr.Hit or tr.HitSky or not tr.HitWorld or tr.HitNormal.z < 0.65 then
        print("[GE] Look at fairly level map ground for an impact preview.")
        return
    end
    FX.SpawnAt(tr.HitPos, args[1], args[2], math.random(1, 999999), false)
end, nil, "Preview smoke, ground crater and dust: ge_fx_local_test [radius] [depth]")
concommand.Add("ge_fx_local_clear", FX.Clear)
