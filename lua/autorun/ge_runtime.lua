if SERVER then
    AddCSLuaFile()
    AddCSLuaFile("general_explosions/runtime.lua")
    -- Autorun files auto-distribute; included generated data does not.
    AddCSLuaFile("general_explosions/data/ground_explosion.lua")
end
include("general_explosions/runtime.lua")
