-- General Explosions: client-side visual effects controller.
-- Network events contain only world positions and cosmetic parameters.
if not CLIENT then return end

GEVisuals = GEVisuals or {}
local FX = GEVisuals

local function spawnAt(pos, radius, depth, seed, glass)
    if not isvector(pos) then return end
    radius = math.Clamp(tonumber(radius) or 260, 30, 2000)
    depth = math.Clamp(tonumber(depth) or radius * 0.24, 0, radius * 0.7)

    if GECraters and GECraters.Add then
        local ok, err = GECraters.Add(pos, radius, depth, { seed = seed, glass = glass })
        if not ok then print("[GE] Crater: " .. tostring(err)) end
    end
    if GEImpactFX and GEImpactFX.Burst then
        GEImpactFX.Burst(pos + Vector(0, 0, 4), radius / 260, seed)
    end
    if GEVolume and GEVolume.Spawn then
        local ok, reason = GEVolume.Spawn(pos + Vector(0, 0, 4), radius / 260)
        if not ok then print("[GE] Volume: " .. tostring(reason)) end
    end
end

FX.SpawnAt = spawnAt

net.Receive("ge_fx_visual_impact_v1", function()
    local pos = net.ReadVector()
    local radius = net.ReadFloat()
    local depth = net.ReadFloat()
    local seed = net.ReadUInt(24)
    local glass = net.ReadBool()
    spawnAt(pos, radius, depth, seed, glass)
end)

net.Receive("ge_fx_crater_snapshot_v1", function()
    local count = net.ReadUInt(6)
    if not GECraters then return end
    GECraters.Clear()
    for i = 1, count do
        local pos = net.ReadVector()
        local radius, depth = net.ReadFloat(), net.ReadFloat()
        local seed = net.ReadUInt(24)
        local glass = net.ReadBool()
        local ok, err = GECraters.Add(pos, radius, depth, { seed = seed, glass = glass })
        if not ok then print("[GE] Snapshot crater " .. i .. ": " .. tostring(err)) end
    end
end)

net.Receive("ge_fx_clear_v1", function()
    if GECraters then GECraters.Clear() end
    if GEVolume then GEVolume.ClearInstances() end
end)

concommand.Add("ge_fx_local_test", function(_, _, args)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local tr = ply:GetEyeTrace()
    if not tr.Hit or tr.HitSky or not tr.HitWorld or tr.HitNormal.z < 0.65 then
        print("[GE] Look at fairly level map ground for an impact preview.")
        return
    end
    local radius = math.Clamp(tonumber(args[1]) or 260, 30, 2000)
    local depth = math.Clamp(tonumber(args[2]) or radius * 0.24, 0, radius * 0.7)
    spawnAt(tr.HitPos, radius, depth, math.random(1, 999999), false)
    print("[GE] Local visual impact preview at crosshair (no damage).")
end, nil, "Preview smoke, ground crater and dust together: ge_fx_local_test [radius] [depth]")

concommand.Add("ge_fx_local_clear", function()
    if GECraters then GECraters.Clear() end
    if GEVolume then GEVolume.ClearInstances() end
    print("[GE] Cleared local visual impacts.")
end)
