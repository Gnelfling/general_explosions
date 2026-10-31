-- Optional binding for the user-supplied VAC impact atlas/shader contract.
-- Separate material and instance list; never changes GEVolume or VAC globals.
if not CLIENT then return end
if not include("general_explosions/load_runtime.lua") then return end
GEVACImpact = GEVACImpact or {}
local V, R = GEVACImpact, GERuntime
V.list = {}
local enabled = CreateClientConVar("ge_railgun_vac_impact", "1", true, false, "Optional VAC impact layer", 0, 1)
local maximum = CreateClientConVar("ge_railgun_vac_max", "1", true, false, "Maximum optional impact volumes", 1, 2)
local distance = CreateClientConVar("ge_railgun_vac_distance", "8000", true, false, "Optional impact cutoff", 1000, 20000)
local dataPath = "general_explosions/data/vac_impact.lua"
V.files = { "shaders/fxc/vac_impactvol_ps30.vcs", "shaders/fxc/vac_nukevol_vs30.vcs",
    "materials/vac/fx/impactvol/fields.vtf", "materials/vac/fx/impactvol/coords.vtf",
    "materials/vac/fx/impactvol/light.vtf", "materials/vac/fx/nukevol/noise.vtf", "lua/" .. dataPath }
local function setup()
    for _, path in ipairs(V.files) do
        if not file.Exists(path, "GAME") then return false, "Missing optional asset: " .. path end
    end
    if not V.data then
        local ok, data = pcall(include, dataPath)
        if not ok or type(data) ~= "table" or data.COLS ~= 16 or data.ROWS ~= 8
            or type(data.F) ~= "table" or #data.F < 2 then return false, "Invalid VAC impact metadata" end
        local previous = -1
        for _, f in ipairs(data.F) do
            if type(f) ~= "table" then return false, "Invalid VAC frame" end
            for _, key in ipairs({"t", "wA", "rA", "rB", "Rb", "Zb"}) do
                if not R.Finite(f[key]) then return false, "Invalid VAC frame constant: " .. key end
            end
            if f.t <= previous or f.Rb <= 0 or f.Rb > 1023 or f.Zb <= 0 or f.Zb > 1000 then
                return false, "Invalid VAC frame bounds/timing"
            end
            previous = f.t
        end
        V.data = data
    end
    if not V.material then
        V.material = CreateMaterial("ge_optional_vac_impact_v1", "screenspace_general", {
            ["$pixshader"] = "vac_impactvol_ps30", ["$vertexshader"] = "vac_nukevol_vs30",
            ["$basetexture"] = "vac/fx/nukevol/noise", ["$texture1"] = "vac/fx/impactvol/fields",
            ["$texture2"] = "vac/fx/impactvol/coords", ["$texture3"] = "vac/fx/impactvol/light",
            ["$linearread_basetexture"] = "1", ["$linearread_texture1"] = "1",
            ["$linearread_texture2"] = "1", ["$linearread_texture3"] = "1",
            ["$cull"] = "0", ["$depthtest"] = "1", ["$alpha_blend"] = "1"
        })
    end
    if not V.material or V.material:IsError() then V.material = nil; return false, "VAC impact material error" end
    return true
end

function V.Frame(t)
    local frames = V.data.F
    local lo, hi = 1, #frames
    if t <= frames[1].t then return 0, 0, frames[1], frames[2] end
    if t >= frames[hi].t then return hi - 2, 1, frames[hi - 1], frames[hi] end
    while hi - lo > 1 do
        local mid = math.floor((lo + hi) / 2)
        if frames[mid].t <= t then lo = mid else hi = mid end
    end
    return lo - 1, (t - frames[lo].t) / (frames[hi].t - frames[lo].t), frames[lo], frames[hi]
end

function V.Spawn(pos, radius, start)
    if not enabled:GetBool() or not R.Position(pos) then return false end
    local ok, reason = setup()
    if not ok then return false, reason end
    start = R.Number(start, CurTime(), 0, CurTime() + 5)
    -- Match the original 200/24-second impact window; VAC's authored time
    -- still runs from 0 to 40 within that window. Never restarts on late arrival.
    if CurTime() - start >= 200 / 24 then return false, "expired" end
    V.list[#V.list + 1] = {pos = Vector(pos.x, pos.y, pos.z), start = start,
        scale = R.Number(radius, 320, 80, 900) / 20}
    while #V.list > maximum:GetInt() do table.remove(V.list, 1) end
    return true
end
function V.Clear() V.list = {} end

local faces = {
    {Vector(-1,0,0),{{0,0,0},{0,0,1},{0,1,1},{0,1,0}}},
    {Vector(1,0,0),{{1,0,0},{1,1,0},{1,1,1},{1,0,1}}},
    {Vector(0,-1,0),{{0,0,0},{1,0,0},{1,0,1},{0,0,1}}},
    {Vector(0,1,0),{{0,1,0},{0,1,1},{1,1,1},{1,1,0}}},
    {Vector(0,0,-1),{{0,0,0},{0,1,0},{1,1,0},{1,0,0}}},
    {Vector(0,0,1),{{0,0,1},{1,0,1},{1,1,1},{0,1,1}}}
}
local function draw(b, age)
    local t = age / (200 / 24) * 40
    local idx, blend, a, c = V.Frame(t)
    local rb, zb = math.ceil(math.max(a.Rb, c.Rb)), math.ceil(math.max(a.Zb, c.Zb))
    local sun = Vector(0.35, 0.25, 0.9):GetNormalized()
    local constants = {
        {idx, blend, a.wA + (c.wA - a.wA) * blend, t},
        {a.rA, a.rB, 1 - R.Smooth((t - 14) / 26), 1},
        {sun.x, sun.y, sun.z, b.scale},
        {b.pos.x, b.pos.y, b.pos.z, rb * 1024 + zb}
    }
    for i = 1, 4 do
        for j, axis in ipairs({"x","y","z","w"}) do V.material:SetFloat("$c" .. (i - 1) .. "_" .. axis, constants[i][j]) end
    end
    local mn = b.pos + Vector(-rb,-rb,-1.5) * b.scale
    local size = Vector(rb * 2, rb * 2, zb + 1.5) * b.scale
    local e = EyePos() - mn
    local eye = Vector(e.x / size.x, e.y / size.y, e.z / size.z)
    local inside = eye.x >= 0 and eye.x <= 1 and eye.y >= 0 and eye.y <= 1 and eye.z >= 0 and eye.z <= 1
    render.SetMaterial(V.material)
    if inside then
        local forward = EyeAngles():Forward()
        render.DrawQuadEasy(EyePos() + forward * 10, forward * -1, 400, 400, Color(255,255,255,255), 0)
        return
    end
    for _, face in ipairs(faces) do
        local corners = face[2]
        local center = Vector()
        for _, p in ipairs(corners) do center = center + Vector(p[1],p[2],p[3]) * 0.25 end
        local dot = face[1]:Dot(eye - center)
        if (not inside and dot > 0) or (inside and dot < 0) then
            mesh.Begin(MATERIAL_TRIANGLES, 2)
            V.building = true
            for _, n in ipairs({1,2,3,1,3,4}) do
                local p = corners[n]
                mesh.Position(mn + Vector(p[1]*size.x,p[2]*size.y,p[3]*size.z))
                mesh.Color(255,255,255,255)
                mesh.AdvanceVertex()
            end
            mesh.End(); V.building = false
        end
    end
end
hook.Add("PostDrawTranslucentRenderables", "GE.VACImpact.Render", function(depth, sky)
    if depth or sky then return end
    local now = CurTime()
    while #V.list > maximum:GetInt() do table.remove(V.list, 1) end
    for i = #V.list, 1, -1 do if now - V.list[i].start >= 200 / 24 then table.remove(V.list, i) end end
    local master = GetConVar and GetConVar("ge_railgun_visuals")
    if not enabled:GetBool() or (master and not master:GetBool()) then return end
    for _, b in ipairs(V.list) do
        if now >= b.start and EyePos():DistToSqr(b.pos) <= distance:GetFloat() ^ 2 then
            render.OverrideDepthEnable(true, false)
            local ok, err = xpcall(function() draw(b, now - b.start) end, debug.traceback)
            if V.building then pcall(mesh.End); V.building = false end
            render.OverrideDepthEnable(false, false)
            if not ok then
                ErrorNoHalt("[GE] Optional VAC layer disabled after draw error: " .. tostring(err) .. "\n")
                V.Clear(); return
            end
        end
    end
end)
hook.Add("PostCleanupMap", "GE.VACImpact.Cleanup", V.Clear)
concommand.Add("ge_railgun_vac_status", function()
    local ok, reason = setup()
    print("[GE] Optional VAC impact: " .. (ok and "assets and metadata found (GPU output unverified)" or tostring(reason)))
end)
