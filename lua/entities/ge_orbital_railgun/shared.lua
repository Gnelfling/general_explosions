-- General Explosions: orbital railgun visual sequence.
-- No damage, physics, projectiles, or map modifications.
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Orbital Railgun (Visual)"
ENT.Category = "General Explosions"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

-- All timestamps are offsets from the same networked StartTime.
-- Sound files: charge 0.0 s (3 s), fire 3.0 s (1 s),
-- explosion 3.2 s (5 s). No audio assets are shipped.
ENT.GEChargeAt = 0.0
ENT.GEFireAt = 3.0
ENT.GEImpactAt = 3.2
ENT.GEBeamEnd = 4.25
ENT.GELifetime = 5.25

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "StartTime")
    self:NetworkVar("Float", 1, "ImpactRadius")
end
