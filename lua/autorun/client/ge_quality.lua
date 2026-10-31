-- General Explosions: client quality presets for the visual effects.
if not CLIENT then return end

local presets = {
    low = { steps = 24, volumeMax = 2, detail = 0, craterMax = 6, dust = 0.25 },
    balanced = { steps = 40, volumeMax = 3, detail = 1, craterMax = 12, dust = 0.65 },
    high = { steps = 64, volumeMax = 4, detail = 2, craterMax = 20, dust = 1.0 },
}

local function apply(name)
    local p = presets[string.lower(tostring(name or ""))]
    if not p then
        print("[GE] Quality presets: low, balanced, high")
        return
    end
    RunConsoleCommand("ge_volume_steps", tostring(p.steps))
    RunConsoleCommand("ge_volume_max_instances", tostring(p.volumeMax))
    RunConsoleCommand("ge_crater_detail", tostring(p.detail))
    RunConsoleCommand("ge_crater_max", tostring(p.craterMax))
    RunConsoleCommand("ge_fx_particle_amount", tostring(p.dust))
    print("[GE] Quality set to " .. name .. "; current smoke/fire color settings retained.")
end

concommand.Add("ge_quality", function(_, _, args) apply(args[1]) end)
concommand.Add("ge_quality_low", function() apply("low") end)
concommand.Add("ge_quality_balanced", function() apply("balanced") end)
concommand.Add("ge_quality_high", function() apply("high") end)
