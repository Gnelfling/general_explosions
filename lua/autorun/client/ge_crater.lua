-- General Explosions: original, client-side visual crater renderer.
-- This does not modify BSP geometry or physics. The apparent hole is created
-- with stencil masking, a depth clear, and an independently drawn bowl mesh.
if not CLIENT then return end

GECraters = GECraters or {}
local CR = GECraters
if CR.Clear then CR.Clear() end
hook.Remove("PostDrawOpaqueRenderables", "GE.Crater.Render")
hook.Remove("PostCleanupMap", "GE.Crater.Cleanup")

CR.list = {}
local enabled = CreateClientConVar("ge_crater_enabled", "1", true, false, "Render visual craters", 0, 1)
local detail = CreateClientConVar("ge_crater_detail", "1", true, false, "Crater geometry detail 0-2", 0, 2)
local maximum = CreateClientConVar("ge_crater_max", "12", true, false, "Maximum retained visual craters", 1, 32)
local distance = CreateClientConVar("ge_crater_distance", "12000", true, false, "Crater draw distance (Source units)", 1000, 50000)
local showRim = CreateClientConVar("ge_crater_rim", "1", true, false, "Draw raised crater rim", 0, 1)
local showBlanket = CreateClientConVar("ge_crater_blanket", "1", true, false, "Draw scorched surroundings", 0, 1)
local UP = Vector(0, 0, 1)
local maskMaterial = CreateMaterial("ge_crater_stencil_v1", "UnlitGeneric", {
    ["$basetexture"] = "models/debug/debugwhite", ["$nocull"] = "1"
})
local soilMaterial = CreateMaterial("ge_crater_soil_v1", "UnlitGeneric", {
    ["$basetexture"] = "models/debug/debugwhite", ["$vertexcolor"] = "1",
    ["$nocull"] = "1"
})
local fadeMaterial = CreateMaterial("ge_crater_fade_v1", "UnlitGeneric", {
    ["$basetexture"] = "models/debug/debugwhite", ["$vertexcolor"] = "1",
    ["$vertexalpha"] = "1", ["$translucent"] = "1", ["$nocull"] = "1"
})

local function clamp(v, low, high) return math.max(low, math.min(high, v)) end
local function smooth(t) t = clamp(t, 0, 1) return t * t * (3 - 2 * t) end
local function noise(x) return (math.sin(x * 91.873 + 17.312) * 43758.5453) % 1 end

local function radiusWave(theta, seed)
    local n = seed * 0.001
    return clamp(1 + 0.060 * math.sin(theta * 3 + n)
                   + 0.033 * math.sin(theta * 7 - n * 1.7)
                   + 0.022 * math.cos(theta * 11 + n * 2.3), 0.86, 1.14)
end

local function profile(x, D, H)
    local hollow = x < 1 and -D * math.max(0, 1 - x * x) ^ 0.8 or 0
    local lip = H * math.exp(-((x - 1) / 0.22) ^ 2)
    local outside = x > 1 and (1 - smooth((x - 1.0) / 0.88)) or 1
    return hollow + lip * outside
end

local function openingRadius(D, H)
    if D < 1 then return 0 end
    local a, b = 0, 1
    for _ = 1, 24 do
        local m = (a + b) / 2
        if profile(m, D, H) < 0 then a = m else b = m end
    end
    return (a + b) / 2
end

local function sampleGround(x, y, baseZ)
    local tr = util.TraceLine({
        start = Vector(x, y, baseZ + 500), endpos = Vector(x, y, baseZ - 500),
        mask = MASK_SOLID_BRUSHONLY
    })
    if tr.Hit and not tr.HitSky and not tr.StartSolid then return tr.HitPos.z end
    return baseZ
end

local function vertex(q, mode, fade)
    mesh.Position(mode == "mask" and q.mask or q.pos)
    mesh.TexCoord(0, q.u, q.v)
    if mode == "mask" then
        mesh.Color(255, 255, 255, 255)
    else
        mesh.Color(q.r, q.g, q.b, fade and q.a or 255)
    end
    mesh.AdvanceVertex()
end

local function surfaceMesh(rows, sides, jStart, jEnd, mode, fade)
    local m = Mesh()
    mesh.Begin(m, MATERIAL_TRIANGLES, sides * (jEnd - jStart) * 2)
    for i = 1, sides do
        local nextI = i % sides + 1
        for j = jStart, jEnd - 1 do
            local a, b = rows[i][j], rows[nextI][j]
            local c, d = rows[i][j + 1], rows[nextI][j + 1]
            -- Both-sided material avoids disappearing faces at glancing angles.
            vertex(a, mode, fade) vertex(d, mode, fade) vertex(c, mode, fade)
            vertex(a, mode, fade) vertex(b, mode, fade) vertex(d, mode, fade)
        end
    end
    mesh.End()
    return m
end

local function build(c)
    local level = detail:GetInt()
    local sides = level == 0 and 28 or (level == 1 and 48 or 72)
    local inner = level == 0 and 6 or (level == 1 and 10 or 14)
    local outer = level == 0 and 7 or (level == 1 and 10 or 16)
    local opening = openingRadius(c.depth, c.rim)
    local flat = opening == 0
    local stations = {}
    if not flat then
        for j = 0, inner do
            local t = j / inner
            stations[#stations + 1] = opening * (1 - (1 - t) ^ 1.5)
        end
    else
        inner = 0
        stations[1] = 0
    end
    for j = 1, outer do
        local t = j / outer
        stations[#stations + 1] = opening + (c.blanket / c.radius - opening) * t ^ 1.25
    end

    local rows = {}
    for i = 1, sides do
        local angle = (i - 1) / sides * math.pi * 2
        local dirX, dirY = math.cos(angle), math.sin(angle)
        local radial = radiusWave(angle, c.seed)
        local row = {}
        for j, x in ipairs(stations) do
            local r = c.radius * radial * x
            local wx, wy = c.pos.x + dirX * r, c.pos.y + dirY * r
            local gz = sampleGround(wx, wy, c.pos.z)
            local irregular = (noise(c.seed + i * 31 + j * 179) - 0.5) * c.depth * 0.07
                * smooth(x / 0.55) * (1 - smooth((x - 1.35) / 0.6))
            local height = profile(x, c.depth, c.rim) + irregular
            if j == inner + 1 then height = 0 end
            local z = gz + height
            if j > inner + 1 then z = math.max(gz + 1.5, z) end
            local scorch = 1 - smooth((x - 0.35) / 1.85)
            local speckle = 0.82 + noise(c.seed + i * 47 + j * 59) * 0.33
            local shade = (0.50 + 0.50 * smooth(x / 1.95)) * speckle
            local char = (0.38 + 0.62 * (1 - scorch))
            local base = c.glass and {45, 63, 52} or {114, 91, 71}
            local bright = (j == inner + 1 and 1.12 or 1)
            local a = x > 1.45 and 255 * (1 - smooth((x - 1.45) / math.max(c.blanket / c.radius - 1.45, 0.01))) or 255
            row[j] = {
                pos = Vector(wx, wy, z), mask = Vector(wx, wy, gz + 3),
                u = wx / 52, v = wy / 52,
                r = clamp(math.floor(base[1] * shade * char * bright), 0, 255),
                g = clamp(math.floor(base[2] * shade * char * bright), 0, 255),
                b = clamp(math.floor(base[3] * shade * char * bright), 0, 255),
                a = clamp(math.floor(a), 0, 255)
            }
        end
        rows[i] = row
    end

    c.meshes = {}
    local function add(key, startJ, endJ, mode, fade)
        if endJ <= startJ then return end
        local m = surfaceMesh(rows, sides, startJ, endJ, mode, fade)
        c.meshes[#c.meshes + 1] = m
        c[key] = m
    end
    if not flat then
        add("opening", 1, inner + 1, "mask", false)
        add("bowl", 1, inner + 1, "soil", false)
    end
    local split = inner + 1
    while split < #stations and stations[split] < 1.65 do split = split + 1 end
    add("rimMesh", inner + 1, split, "soil", false)
    add("blanketMesh", split, #stations, "soil", true)
    if flat then
        -- A scorch-only mark should not clear the underlying world's depth.
        add("flatMesh", 1, #stations, "soil", true)
    end
    return c
end

function CR.Free(c)
    if not c then return end
    for _, m in ipairs(c.meshes or {}) do if m and m.Destroy then m:Destroy() end end
    c.meshes = nil
end

function CR.Clear()
    for _, c in ipairs(CR.list or {}) do CR.Free(c) end
    CR.list = {}
end

function CR.Add(pos, radius, depth, opts)
    opts = opts or {}
    if not isvector(pos) then return false, "invalid position" end
    radius = clamp(tonumber(radius) or 240, 30, 2000)
    depth = clamp(tonumber(depth) or radius * 0.24, 0, radius * 0.70)
    local c = {
        pos = Vector(pos.x, pos.y, pos.z), radius = radius,
        depth = depth, rim = clamp(tonumber(opts.rim) or radius * 0.11, 0, radius * 0.30),
        blanket = clamp(tonumber(opts.blanket) or radius * 2.7, radius * 1.9, radius * 4),
        glass = opts.glass == true, seed = math.floor(tonumber(opts.seed) or math.random(1, 999999))
    }
    local ok, err = pcall(build, c)
    if not ok then
        CR.Free(c)
        return false, tostring(err)
    end
    table.insert(CR.list, c)
    while #CR.list > maximum:GetInt() do CR.Free(table.remove(CR.list, 1)) end
    return true, c
end

local function drawOne(c)
    if c.flatMesh then
        render.SetMaterial(fadeMaterial)
        c.flatMesh:Draw()
        return
    end
    if not c.opening or not c.bowl then return end

    -- Explicit cleanup is essential: a failed draw must not leave stencil
    -- or depth overrides enabled for other addons.
    render.SetStencilEnable(true)
    render.ClearStencil()
    render.SetStencilWriteMask(255)
    render.SetStencilTestMask(255)
    render.SetStencilReferenceValue(1)
    render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_ALWAYS)
    render.SetStencilPassOperation(STENCILOPERATION_REPLACE)
    render.SetStencilFailOperation(STENCILOPERATION_KEEP)
    render.SetStencilZFailOperation(STENCILOPERATION_KEEP)
    render.OverrideColorWriteEnable(true, false)
    render.OverrideDepthEnable(true, false)
    render.SetMaterial(maskMaterial)
    c.opening:Draw()
    render.OverrideDepthEnable(false, false)
    render.OverrideColorWriteEnable(false, false)
    render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)
    render.SetStencilPassOperation(STENCILOPERATION_KEEP)
    render.ClearBuffersObeyStencil(24, 19, 16, 255, true)
    render.SetMaterial(soilMaterial)
    c.bowl:Draw()
    render.SetStencilEnable(false)

    if showRim:GetBool() and c.rimMesh then
        render.SetMaterial(soilMaterial)
        c.rimMesh:Draw()
    end
    if showBlanket:GetBool() and c.blanketMesh then
        render.SetMaterial(fadeMaterial)
        c.blanketMesh:Draw()
    end
end

hook.Add("PostDrawOpaqueRenderables", "GE.Crater.Render", function(depthPass, sky)
    if depthPass or sky or not enabled:GetBool() then return end
    local eye, limit = EyePos(), distance:GetFloat()
    for _, c in ipairs(CR.list) do
        local bound = limit + c.blanket
        if eye:DistToSqr(c.pos) < bound * bound then
            local ok, err = xpcall(function() drawOne(c) end, debug.traceback)
            -- Restore engine state even when another addon or a mesh fails.
            render.OverrideDepthEnable(false, false)
            render.OverrideColorWriteEnable(false, false)
            render.SetStencilEnable(false)
            if not ok then
                ErrorNoHalt("[GE] Crater render failed: " .. tostring(err) .. "\n")
                break
            end
        end
    end
end)

hook.Add("PostCleanupMap", "GE.Crater.Cleanup", CR.Clear)

concommand.Add("ge_crater_test", function(_, _, args)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local tr = ply:GetEyeTrace()
    if not tr.Hit or tr.HitSky or tr.HitNormal.z < 0.65 or not tr.HitWorld then
        print("[GE] Aim at reasonably level map ground to place a crater.")
        return
    end
    local radius = clamp(tonumber(args[1]) or 260, 30, 2000)
    local depth = clamp(tonumber(args[2]) or radius * 0.24, 0, radius * 0.70)
    local ok, err = CR.Add(tr.HitPos, radius, depth)
    print(ok and ("[GE] Crater created (" .. radius .. "u radius, " .. depth .. "u depth).")
        or ("[GE] Crater failed: " .. tostring(err)))
end, nil, "Look at map ground; ge_crater_test [radius_units] [depth_units]")

concommand.Add("ge_crater_scorch", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local tr = ply:GetEyeTrace()
    if tr.Hit and tr.HitWorld and tr.HitNormal.z > 0.65 then
        local ok, err = CR.Add(tr.HitPos, 260, 0)
        print(ok and "[GE] Scorched ground created." or ("[GE] " .. tostring(err)))
    end
end)

concommand.Add("ge_crater_clear", function() CR.Clear() print("[GE] Craters cleared.") end)
concommand.Add("ge_crater_status", function() print("[GE] Active visual craters: " .. #CR.list) end)
