-- Safe to include from any consumer, independent of autorun ordering.
if GERuntime and GERuntime.Frame and GERuntime.Number and GERuntime.Position then return true end
local ok, err = pcall(include, "general_explosions/runtime.lua")
if not ok or not GERuntime or not GERuntime.Frame or not GERuntime.Number or not GERuntime.Position then
    ErrorNoHalt("[GE] Runtime unavailable; install lua/general_explosions/runtime.lua and restart both server and clients: " .. tostring(err) .. "\n")
    return false
end
return true
