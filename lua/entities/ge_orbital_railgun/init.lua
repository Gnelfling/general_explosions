AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")
if not include("general_explosions/load_runtime.lua") then return end

-- A sandbox presentation effect, not a functioning weapon.
local radiusCV = CreateConVar(
    "ge_railgun_radius", "320", FCVAR_ARCHIVE,
    "Visual crater radius in Source units (80-900).", 80, 900
)
local shakeCV = CreateConVar(
    "ge_railgun_shake", "1", FCVAR_ARCHIVE,
    "Play a short cosmetic screen shake on nearby players.", 0, 1
)
local maxActiveCV = CreateConVar(
    "ge_railgun_max_active", "2", FCVAR_ARCHIVE,
    "Maximum simultaneously charging/firing railgun visual entities.", 1, 6
)

local SOUND_DIR = "general_explosions/railgun/"
local warnedSound = {}
for _, name in ipairs({ "railgun_charge.wav", "railgun_fire.wav", "railgun_explosion.wav" }) do
    local path = "sound/" .. SOUND_DIR .. name
    if file.Exists(path, "GAME") then resource.AddFile(path) end
end

local function cue(pos, name)
    local path = SOUND_DIR .. name
    if not file.Exists("sound/" .. path, "GAME") then
        if not warnedSound[path] then
            print("[GE] Optional railgun sound not installed: sound/" .. path)
            warnedSound[path] = true
        end
        return
    end
    sound.Play(path, pos, 115, 100, 1)
end

local function allowed(ply)
    return IsValid(ply) and (game.SinglePlayer() or ply:IsAdmin())
end

local function validGround(tr)
    return tr and tr.Hit and tr.HitWorld and not tr.HitSky
        and GERuntime.Position(tr.HitPos) and GERuntime.Position(tr.HitNormal) and tr.HitNormal.z >= 0.65
end

local function activeCount()
    return #ents.FindByClass("ge_orbital_railgun")
end

local function spawnVisual(ply, tr, className, manualUndo)
    if not allowed(ply) then return nil end
    if not validGround(tr) then
        ply:ChatPrint("[GE] Aim at level map ground (not a prop) to place the railgun effect.")
        return nil
    end
    if activeCount() >= maxActiveCV:GetInt() then
        ply:ChatPrint("[GE] Active railgun visual limit reached.")
        return nil
    end

    local ent = ents.Create(className or "ge_orbital_railgun")
    if not IsValid(ent) then
        ply:ChatPrint("[GE] Could not create railgun entity.")
        return nil
    end
    ent:SetPos(tr.HitPos + Vector(0, 0, 3))
    ent:SetAngles(Angle(0, 0, 0))
    ent:SetGroundNormal(tr.HitNormal)
    ent:Spawn()
    if not IsValid(ent) then return nil end
    ent:Activate()
    ent:SetCreator(ply)
    -- Sandbox already registers SpawnFunction results. Only the direct
    -- console path needs its own undo/cleanup entry.
    if manualUndo then
        undo.Create("Orbital Railgun (Visual)")
        undo.AddEntity(ent)
        undo.SetPlayer(ply)
        undo.Finish()
        ply:AddCleanup("sents", ent)
    end
    return ent
end

function ENT:SpawnFunction(ply, tr, className)
    return spawnVisual(ply, tr, className)
end

function ENT:Initialize()
    if activeCount() > maxActiveCV:GetInt() then self:Remove() return end
    -- Model is used only as an engine entity anchor; no model is drawn.
    self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_NONE)
    self:DrawShadow(false)
    self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
    self:SetStartTime(CurTime() + 0.45)
    self:SetImpactRadius(radiusCV:GetFloat())
    self:SetVisualSeed(math.random(1, 16777214))
    if self:GetGroundNormal():LengthSqr() < 0.5 then self:SetGroundNormal(Vector(0, 0, 1)) end
    self._gePlayedCharge = false
    self._gePlayedFire = false
    self._geDidImpact = false
end

-- The visual beam can remain visible on distant maps even when its small
-- anchor would normally be outside the player's PVS.
function ENT:UpdateTransmitState()
    return TRANSMIT_ALWAYS
end

function ENT:Think()
    local t = CurTime() - self:GetStartTime()
    if t >= self.GELifetime then self:Remove() return end
    if t < 0 then
        self:NextThink(CurTime())
        return true
    end

    if not self._gePlayedCharge and t >= self.GEChargeAt then
        self._gePlayedCharge = true
        cue(self:GetPos(), "railgun_charge.wav")
    end

    if not self._gePlayedFire and t >= self.GEFireAt then
        self._gePlayedFire = true
        cue(self:GetPos(), "railgun_fire.wav")
    end

    if not self._geDidImpact and t >= self.GEImpactAt then
        self._geDidImpact = true
        local origin = self:GetPos() - Vector(0, 0, 3)
        local radius = self:GetImpactRadius()
        if GEFXServer and GEFXServer.Impact then
            GEFXServer.Impact(origin, radius, radius * 0.24, {
                time = self:GetStartTime() + self.GEImpactAt,
                seed = self:GetVisualSeed(), normal = self:GetGroundNormal()
            })
        else
            ErrorNoHalt("[GE] Railgun: ge_fx_server.lua is missing; volumetric impact not spawned.\n")
        end
        if shakeCV:GetBool() then
            util.ScreenShake(origin, 4, 6, 1.2, math.min(radius * 7, 3000))
        end
        cue(origin, "railgun_explosion.wav")
    end

    self:NextThink(CurTime())
    return true
end

concommand.Add("ge_railgun_fire", function(ply)
    if not allowed(ply) then return end
    local visual = spawnVisual(ply, ply:GetEyeTrace(), "ge_orbital_railgun", true)
    if IsValid(visual) then
        ply:ChatPrint("[GE] Orbital railgun sequence started (visual only).")
    end
end, nil, "Start a cosmetic orbital beam at the map ground under your crosshair.")

concommand.Add("ge_railgun_status", function(ply)
    if not allowed(ply) then return end
    ply:ChatPrint("[GE] Active orbital visuals: " .. activeCount() ..
        " | radius: " .. radiusCV:GetInt() .. " | optional audio: 3 WAV files.")
end)

concommand.Add("ge_railgun_clear", function(ply)
    if IsValid(ply) and not allowed(ply) then return end
    for _, ent in ipairs(ents.FindByClass("ge_orbital_railgun")) do ent:Remove() end
    if GEFXServer then GEFXServer.Clear() end
end, nil, "Cancel active railgun visuals and clear synchronized cosmetic impacts.")
