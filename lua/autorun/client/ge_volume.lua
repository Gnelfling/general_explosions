-- General Explosions: client-only smoke/fire volume visualization scaffold.
-- Requires separately compiled ge_volume_vs30.vcs and ge_volume_ps30.vcs
-- plus VTFs and a generated Lua manifest from tools/vdb_to_vtf.py.
-- No gameplay mechanics, damage, or network messages are implemented.

if not CLIENT then return end

GEVolume = GEVolume or {}
local GE = GEVolume
hook.Remove("PostDrawTranslucentRenderables", "GE.Volume.Render")

local enabled = CreateClientConVar("ge_volume_enabled", "1", true, false, "Draw the GroundExplosionVDB volume", 0, 1)
local opacity = CreateClientConVar("ge_volume_opacity", "11", true, false, "Volume extinction", 0, 40)
local steps = CreateClientConVar("ge_volume_steps", "64", true, false, "GPU ray-march steps", 8, 96)
local scale = CreateClientConVar("ge_volume_unit_scale", "4", true, false, "GMod units per OpenVDB voxel", 0.1, 50)
local ambient = CreateClientConVar("ge_volume_ambient", "0.32", true, false, "Ambient brightness", 0, 1)
local fireGain = CreateClientConVar("ge_volume_fire", "1.6", true, false, "Fire emission strength", 0, 8)

local dataPath = "general_explosions/data/ground_explosion.lua"
local VERTEX_SHADER = "shaders/fxc/ge_volume_vs30.vcs"
local PIXEL_SHADER = "shaders/fxc/ge_volume_ps30.vcs"

GE.manifest = GE.manifest or nil
GE.material = GE.material or nil
GE.preview = GE.preview or nil
GE.lastTexture = nil

local function setup()
    if not file.Exists(VERTEX_SHADER, "GAME") or not file.Exists(PIXEL_SHADER, "GAME") then
        return false, "Missing compiled .vcs shader(s) in garrysmod/shaders/fxc"
    end
    if not file.Exists("lua/" .. dataPath, "GAME") then
        return false, "Missing generated Lua manifest: " .. dataPath
    end
    if not GE.manifest then
        local ok, result = pcall(include, dataPath)
        if not ok or not result or not result.frames or #result.frames == 0 then
            return false, "Could not load non-empty volume manifest"
        end
        GE.manifest = result
    end
    if not GE.material then
        local initial = GE.manifest.frames[1].texture
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
        local toEye = Vector(cameraUVW.x - 0.5, cameraUVW.y - 0.5, cameraUVW.z - 0.5)
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

local function selectFrame(elapsed)
    local frames = GE.manifest.frames
    if #frames == 1 then return frames[1] end
    local fps = GE.manifest.fps or 24
    local desired = frames[1].frame + math.floor(elapsed * fps)
    if desired > frames[#frames].frame then
        desired = frames[1].frame + ((desired - frames[1].frame) % (frames[#frames].frame - frames[1].frame + 1))
    end
    local current = frames[1]
    for i = 2, #frames do
        if frames[i].frame > desired then break end
        current = frames[i]
    end
    return current
end

local function draw()
    if not enabled:GetBool() or not GE.preview then return end
    local ok = setup()
    if not ok then return end

    local frame = selectFrame(CurTime() - GE.preview.start)
    if not frame or not setFrame(frame) then return end

    local unitScale = scale:GetFloat() * GE.preview.multiplier
    local mn, mx = frame.min, frame.max
    local center = {(mn[1] + mx[1]) * 0.5, (mn[2] + mx[2]) * 0.5, (mn[3] + mx[3]) * 0.5}
    local eye = EyePos()
    local loc = (eye - GE.preview.origin) / unitScale
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
    m:SetFloat("$c3_x", 0.40)
    m:SetFloat("$c3_y", 0.42)
    m:SetFloat("$c3_z", 0.44)
    m:SetFloat("$c3_w", 1.0)

    render.SetMaterial(m)
    drawBox(frame, center, GE.preview.origin, unitScale, camera, inside)
end

hook.Add("PostDrawTranslucentRenderables", "GE.Volume.Render", function(depth, sky)
    if sky or depth then return end
    draw()
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
        start = CurTime(), multiplier = multiplier
    }
    print("[GE] Previewing GroundExplosionVDB (visual only).")
end, nil, "Preview animated VDB smoke in front of your camera")

concommand.Add("ge_volume_stop", function()
    GE.preview = nil
    print("[GE] Preview stopped.")
end)

concommand.Add("ge_volume_status", function()
    local ok, reason = setup()
    print("[GE] " .. (ok and "Shader + manifest files found" or tostring(reason)))
    if ok then print("[GE] Loaded frame records: " .. #GE.manifest.frames) end
end)
