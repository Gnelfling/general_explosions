AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")
if not include("general_explosions/load_runtime.lua") then return end

local impactWav = "general_explosions/nuke/atomic_strike.wav"
if file.Exists("sound/" .. impactWav, "GAME") then resource.AddFile("sound/" .. impactWav) end

function ENT:SpawnFunction(ply, trace)
    if not IsValid(ply) or not (game.SinglePlayer() or ply:IsAdmin()) then return end
    if not trace.HitWorld or trace.HitSky or trace.HitNormal.z < 0.65 then
        ply:ChatPrint("[GE] Aim at level world ground to place the nuclear strike.")
        return
    end
    if #ents.FindByClass("ge_nuke_strike") >= 1 then
        ply:ChatPrint("[GE] A nuclear strike is already active.")
        return
    end
    local ground = trace.HitPos
    local ceiling = util.TraceLine({start = ground + Vector(0, 0, 8),
        endpos = ground + Vector(0, 0, self.MaxDropHeight + 96), mask = MASK_SOLID_BRUSHONLY})
    local height = ceiling.Hit and (ceiling.HitPos.z - ground.z - 96) or self.MaxDropHeight
    if ceiling.StartSolid or height < 512 then
        ply:ChatPrint("[GE] Choose open ground with more space overhead.")
        return
    end
    local entity = ents.Create("ge_nuke_strike")
    if not IsValid(entity) then return end
    entity:SetPos(ground + Vector(0, 0, 2))
    entity:SetDropHeight(math.min(height, self.MaxDropHeight))
    entity:SetGroundNormal(trace.HitNormal)
    entity:Spawn()
    return entity
end

function ENT:Initialize()
    if #ents.FindByClass("ge_nuke_strike") > 1 or self:GetDropHeight() < 512 then
        self:Remove()
        return
    end
    self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_NONE)
    self:DrawShadow(false)
    self:SetStrikeStart(CurTime() + 0.3)
end

function ENT:UpdateTransmitState()
    return TRANSMIT_ALWAYS
end

function ENT:Think()
    local impact = self:GetStrikeStart() + self.DescentTime
    local now = CurTime()
    if now >= impact and not self.Impacted then
        self.Impacted = true
        local ground = self:GetPos() - Vector(0, 0, 2)
        if GEFXServer then
            GEFXServer.Impact(ground, 650, 156, {nuke = true, time = impact, normal = self:GetGroundNormal()})
        end
        util.ScreenShake(ground, 10, 7, 2, 4200, true)
        if file.Exists("sound/" .. impactWav, "GAME") then
            sound.Play(impactWav, ground, 140, 100, 1)
        else
            sound.Play("ambient/explosions/explode_9.wav", ground, 140, 72, 1)
            sound.Play("ambient/explosions/explode_4.wav", ground, 130, 62, 0.65)
        end
    end
    if now > impact + 3.5 then self:Remove(); return end
    self:NextThink(now + 0.02)
    return true
end
