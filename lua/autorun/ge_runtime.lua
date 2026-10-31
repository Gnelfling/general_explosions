if SERVER then
    AddCSLuaFile()
    AddCSLuaFile("general_explosions/runtime.lua")
    AddCSLuaFile("general_explosions/load_runtime.lua")
    -- Autorun files auto-distribute; included generated data does not.
    AddCSLuaFile("general_explosions/data/ground_explosion.lua")
    if file.Exists("lua/general_explosions/data/vac_impact.lua", "GAME") then
        AddCSLuaFile("general_explosions/data/vac_impact.lua")
    end
end
include("general_explosions/load_runtime.lua")
