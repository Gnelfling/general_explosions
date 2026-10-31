-- General Explosions: client-only smoke/fire volume visualization scaffold.
-- Requires separately compiled ge_volume_vs30.vcs and ge_volume_ps30.vcs
-- plus VTFs and a generated Lua manifest from tools/vdb_to_vtf.py.
-- No gameplay mechanics, damage, or network messages are implemented.

if not CLIENT then return end
if not include("general_explosions/load_runtime.lua") then return end

GEVolume = GEVolume or {}
local GE = GEVolume
hook.Remove("PostDrawTranslucentRenderables", "GE.Volume.Render")

local enabled = CreateClientConVar("ge_volume_enabled", "1", true, false, "Draw the GroundExplosionVDB volume", 0, 1)
local opacity = CreateClientConVar("ge_volume_opacity", "100", true, false, "Volume extinction", 0, 200)
local steps = CreateClientConVar("ge_volume_steps", "40", true, false, "GPU ray-march steps", 8, 96)
local scale = CreateClientConVar("ge_volume_unit_scale", "8", true, false, "GMod units per OpenVDB voxel", 0.1, 50)
local ambient = CreateClientConVar("ge_volume_ambient", "0.18", true, false, "Ambient brightness", 0, 1)
local fireGain = CreateClientConVar("ge_volume_fire", "0.15", true, false, "Fire emission strength", 0, 8)

local playbackSpeed = CreateClientConVar("ge_volume_speed", "1", true, false, "Animation playback multiplier", 0.1, 3)
local smokeR = CreateClientConVar("ge_volume_smoke_r", "0.40", true, false, "Smoke red tint", 0, 2)
local smokeG = CreateClientConVar("ge_volume_smoke_g", "0.42", true, false, "Smoke green tint", 0, 2)
local smokeB = CreateClientConVar("ge_volume_smoke_b", "0.44", true, false, "Smoke blue tint", 0, 2)
local maxInstances = CreateClientConVar("ge_volume_max_instances", "3", true, false, "Maximum simultaneous one-shot volumes", 1, 8)
local drawDistance = CreateClientConVar("ge_volume_draw_distance", "16000", true, false, "Volume draw distance in Source units", 1000, 60000)

local dataPath = "general_explosions/data/ground_explosion.lua"
local VERTEX_SHADER = "shaders/fxc/ge_volume_vs30.vcs"
local PIXEL_SHADER = "shaders/fxc/ge_volume_ps30.vcs"

GE.manifest = GE.manifest or nil
GE.material = GE.material or nil
GE.preview = GE.preview or nil
GE.instances = GE.instances or {}
GE.lastTexture = nil

local function setup()
    if not file.Exists(VERTEX_SHADER, "GAME") or not file.Exists(PIXEL_SHADER, "GAME") then
        return false, "Missing compiled .vcs shader(s) in shaders/fxc"
    end
    if not file.Exists("lua/" .. dataPath, "GAME") then
        return false, "Missing generated Lua manifest: " .. dataPath
    end
    if not GE.manifest then
        local ok, result = pcall(include, dataPath)
        if not ok or type(result) ~= "table" or type(result.frames) ~= "table" or #result.frames == 0 then
            return false, "Could not load non-empty volume manifest"
        end
        if not GERuntime.Finite(result.fps or 24) or (result.fps or 24) <= 0 then
            return false, "Invalid manifest FPS"
        end
        result.fps = result.fps or 24
        if result.anchor ~= nil then
            if type(result.anchor) ~= "table" then return false, "Invalid volume anchor" end
            for axis = 1, 3 do
                if not GERuntime.Finite(result.anchor[axis]) then return false, "Invalid volume anchor" end
            end
        end
        local previous = -1
        for _, frame in ipairs(result.frames) do
            if type(frame) ~= "table" or not GERuntime.Finite(frame.frame) or frame.frame <= previous
                or frame.frame < 0 or frame.frame % 1 ~= 0 then
                return false, "Manifest frames must be strictly ordered"
            end
            previous = frame.frame
            if not frame.empty then
                if type(frame.texture) ~= "string" or type(frame.min) ~= "table" or type(frame.max) ~= "table"
                    or not GERuntime.Finite(frame.density_scale) or not GERuntime.Finite(frame.flames_scale)
                    or frame.density_scale < 0 or frame.flames_scale < 0 then
                    return false, "Invalid volume frame data"
                end
                for axis = 1, 3 do
                    if not GERuntime.Finite(frame.min[axis]) or not GERuntime.Finite(frame.max[axis])
                        or frame.max[axis] <= frame.min[axis] then return false, "Invalid volume bounds" end
                end
            end
        end
        local first = result.first_frame or result.frames[1].frame
        local last = result.last_frame or previous
        if not GERuntime.Finite(first) or not GERuntime.Finite(last) or first % 1 ~= 0 or last % 1 ~= 0
            or first < 0 or first > result.frames[1].frame or last < previous then
            return false, "Invalid manifest timeline"
        end
        GE.manifest = result
        if last < 199 then
            print("[GE] Volume manifest ends at frame " .. last .. "; shorter exports are supported. Preserve your full local 200-frame manifest/VTF/VMT set if available; Git cannot recover missing frames.")
        end
    end
    if not GE.material then
        local initial
        for _, frame in ipairs(GE.manifest.frames) do
            if not frame.empty then initial = frame.texture break end
        end
        if not initial then return false, "Manifest contains only empty frames" end
        GE.material = CreateMaterial("ge_volume_raymarch_v1", "screenspace_general", {
            ["$pixshader"] = "ge_volume_ps30",
            ["$vertexshader"] = "ge_volume_vs30",
            ["$basetexture"] = initial,
            ["$tcsize0"] = "3",
            ["$vertextransform"] = "1",
            ["$linearread_basetexture"] = "1",
            ["$linearwrite"] = "1",
            ["$depthtest"] = "1",
            ["$alphablend"] = "1",
            ["$cull"] = "0",
            ["$c0_x"] = "0", ["$c0_y"] = "0", ["$c0_z"] = "0", ["$c0_w"] = "1",
            ["$c1_x"] = "0", ["$c1_y"] = "0", ["$c1_z"] = "1", ["$c1_w"] = "64",
            ["$c2_x"] = "1", ["$c2_y"] = "1", ["$c2_z"] = "1", ["$c2_w"] = "0.3",
            ["$c3_x"] = "0.5", ["$c3_y"] = "0.5", ["$c3_z"] = "0.5", ["$c3_w"] = "1"
        })
        if not GE.material or GE.material:IsError() then
            GE.material = nil
            return false, "screenspace_general material is in error state"
        end
    end
    return true
end

local cubeFaces = {
    {normal = Vector(-1, 0, 0), corners = {{0,0,0},{0,0,1},{0,1,1},{0,1,0}}},
    {normal = Vector( 1, 0, 0), corners = {{1,0,0},{1,1,0},{1,1,1},{1,0,1}}},
    {normal = Vector(0,-1, 0), corners = {{0,0,0},{1,0,0},{1,0,1},{0,0,1}}},
    {normal = Vector(0, 1, 0), corners = {{0,1,0},{0,1,1},{1,1,1},{1,1,0}}},
    {normal = Vector(0, 0,-1), corners = {{0,0,0},{0,1,0},{1,1,0},{1,0,0}}},
    {normal = Vector(0, 0, 1), corners = {{0,0,1},{1,0,1},{1,1,1},{0,1,1}}}
}

local function vertex(localUvw, frame, center, origin, unitScale)
    local mn, mx = frame.min, frame.max
    local p = Vector(
        mn[1] + localUvw[1] * (mx[1] - mn[1]) - center[1],
        mn[2] + localUvw[2] * (mx[2] - mn[2]) - center[2],
        mn[3] + localUvw[3] * (mx[3] - mn[3]) - center[3]
    ) * unitScale + origin
    mesh.Position(p)
    mesh.TexCoord(0, localUvw[1], localUvw[2], localUvw[3])
    mesh.AdvanceVertex()
end

local function drawBox(frame, center, origin, unitScale, cameraUVW, inside)
    local visible = {}
    for _, face in ipairs(cubeFaces) do
        -- Determine which side of the box faces the viewer. When inside the
        -- box, render exit faces instead of entry faces.
        local c = face.corners
        local faceCenter = Vector(
            (c[1][1] + c[2][1] + c[3][1] + c[4][1]) * 0.25,
            (c[1][2] + c[2][2] + c[3][2] + c[4][2]) * 0.25,
            (c[1][3] + c[2][3] + c[3][3] + c[4][3]) * 0.25
        )
        local toEye = cameraUVW - faceCenter
        local facing = face.normal:Dot(toEye)
        if (inside and facing < 0) or (not inside and facing > 0) then
            visible[#visible + 1] = face
        end
    end
    if #visible == 0 then return end

    mesh.Begin(MATERIAL_TRIANGLES, #visible * 2)
    for _, face in ipairs(visible) do
        local c = face.corners
        vertex(c[1], frame, center, origin, unitScale)
        vertex(c[2], frame, center, origin, unitScale)
        vertex(c[3], frame, center, origin, unitScale)
        vertex(c[1], frame, center, origin, unitScale)
        vertex(c[3], frame, center, origin, unitScale)
        vertex(c[4], frame, center, origin, unitScale)
    end
    mesh.End()
end

local function setFrame(frame)
    if GE.lastTexture == frame.texture then return true end
    local shell = Material(frame.texture)
    if not shell or shell:IsError() then return false end
    local tex = shell:GetTexture("$basetexture")
    if not tex or tex:IsError() then return false end
    GE.material:SetTexture("$basetexture", tex)
    GE.lastTexture = frame.texture
    return true
end

local function draw(instance)
    if not instance then return false end
    local ok = setup()
    if not ok then return false end

    local frame, alive = GERuntime.Frame(GE.manifest, CurTime() - instance.start,
        playbackSpeed:GetFloat(), instance.loop == true)
    if not alive then return false end
    if not enabled:GetBool() or not frame then return true end
    -- Cull before touching frame materials; distant sequences still age.
    if EyePos():DistToSqr(instance.origin) > drawDistance:GetFloat() ^ 2 then return true end
    if not setFrame(frame) then return true end

    local unitScale = scale:GetFloat() * instance.multiplier
    local mn, mx = frame.min, frame.max
    -- The animation uses one fixed VDB-space anchor, so the smoke doesn't
    -- snap back to its own bounding-box centre when it expands or rises.
    local center = GE.manifest.anchor or {0, 0, 0}
    local eye = EyePos()
    local loc = (eye - instance.origin) / unitScale
    local camera = Vector(
        (loc.x + center[1] - mn[1]) / math.max(mx[1] - mn[1], 1),
        (loc.y + center[2] - mn[2]) / math.max(mx[2] - mn[2], 1),
        (loc.z + center[3] - mn[3]) / math.max(mx[3] - mn[3], 1)
    )
    local inside = camera.x >= 0 and camera.x <= 1
        and camera.y >= 0 and camera.y <= 1
        and camera.z >= 0 and camera.z <= 1

    local m = GE.material
    m:SetFloat("$c0_x", camera.x)
    m:SetFloat("$c0_y", camera.y)
    m:SetFloat("$c0_z", camera.z)
    m:SetFloat("$c0_w", opacity:GetFloat())
    m:SetFloat("$c1_x", 0.25)
    m:SetFloat("$c1_y", 0.35)
    m:SetFloat("$c1_z", 0.9)
    m:SetFloat("$c1_w", steps:GetInt())
    m:SetFloat("$c2_x", frame.density_scale)
    m:SetFloat("$c2_y", frame.flames_scale)
    m:SetFloat("$c2_z", fireGain:GetFloat())
    m:SetFloat("$c2_w", ambient:GetFloat())
    m:SetFloat("$c3_x", smokeR:GetFloat())
    m:SetFloat("$c3_y", smokeG:GetFloat())
    m:SetFloat("$c3_z", smokeB:GetFloat())
    m:SetFloat("$c3_w", 1.0)

    if EyePos():DistToSqr(instance.origin) <= drawDistance:GetFloat() ^ 2 then
        render.SetMaterial(m)
        drawBox(frame, center, instance.origin, unitScale, camera, inside)
    end
    return true
end

function GE.Spawn(origin, multiplier, startTime)
    if not GERuntime.Position(origin) then return false, "invalid world position" end
    local ok, reason = setup()
    if not ok then return false, reason end
    startTime = GERuntime.Number(startTime, CurTime(), 0, CurTime() + 5)
    local _, alive = GERuntime.Frame(GE.manifest, CurTime() - startTime, playbackSpeed:GetFloat(), false)
    if not alive then return false, "animation expired" end
    table.insert(GE.instances, {
        origin = Vector(origin.x, origin.y, origin.z),
        start = startTime, multiplier = GERuntime.Number(multiplier, 1, 0.1, 20),
        loop = false
    })
    while #GE.instances > maxInstances:GetInt() do table.remove(GE.instances, 1) end
    return true
end

function GE.ClearInstances()
    GE.instances = {}
end

hook.Add("PostCleanupMap", "GE.Volume.Cleanup", function()
    GE.ClearInstances()
    GE.preview = nil
end)

hook.Add("PostDrawTranslucentRenderables", "GE.Volume.Render", function(depth, sky)
    if sky or depth then return end
    draw(GE.preview)
    local eye = EyePos()
    local ordered = {}
    for _, instance in ipairs(GE.instances) do ordered[#ordered + 1] = instance end
    table.sort(ordered, function(a, b)
        return eye:DistToSqr(a.origin) > eye:DistToSqr(b.origin)
    end)
    for _, instance in ipairs(ordered) do instance.alive = draw(instance) end
    for i = #GE.instances, 1, -1 do
        if not GE.instances[i].alive then table.remove(GE.instances, i) end
    end
end)

concommand.Add("ge_volume_preview", function(_, _, args)
    local ok, reason = setup()
    if not ok then
        print("[GE] " .. tostring(reason))
        return
    end
    local distance = math.Clamp(tonumber(args[1]) or 1400, 100, 20000)
    local multiplier = math.Clamp(tonumber(args[2]) or 1, 0.1, 20)
    GE.preview = {
        origin = EyePos() + EyeAngles():Forward() * distance,
        start = CurTime(), multiplier = multiplier, loop = true
    }
    print("[GE] Previewing GroundExplosionVDB (visual only).")
end, nil, "Preview animated VDB smoke in front of your camera")

concommand.Add("ge_volume_spawn", function(_, _, args)
    local d = math.Clamp(tonumber(args[1]) or 1400, 100, 20000)
    local mult = math.Clamp(tonumber(args[2]) or 1, 0.1, 20)
    local ok, reason = GE.Spawn(EyePos() + EyeAngles():Forward() * d, mult)
    print(ok and "[GE] One-shot volume spawned." or "[GE] " .. tostring(reason))
end)

concommand.Add("ge_volume_clear", function()
    GE.ClearInstances()
    print("[GE] One-shot volumes cleared.")
end)

concommand.Add("ge_volume_stop", function()
    GE.preview = nil
    print("[GE] Preview stopped.")
end)

concommand.Add("ge_volume_status", function()
    local ok, reason = setup()
    print("[GE] " .. (ok and "Shader + manifest files found" or tostring(reason)))
    if ok then print("[GE] Loaded frame records: " .. #GE.manifest.frames) end
    print("[GE] Active one-shot volumes: " .. #GE.instances)
end)
