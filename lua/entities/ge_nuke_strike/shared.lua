ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Nuclear Strike"
ENT.Category = "General Explosions"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT
ENT.DescentTime = 5.2
ENT.MaxDropHeight = 12000

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "StrikeStart")
    self:NetworkVar("Float", 1, "DropHeight")
    self:NetworkVar("Vector", 0, "GroundNormal")
end
