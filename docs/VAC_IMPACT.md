# Optional VAC impact shader

The user-supplied shader now runs as a second volume at the 3.2-second impact.
The original OpenVDB, beam, particles, crater, damage and sound remain intact.
The full VAC addon is not required or loaded; no VAC globals are created.

## Install

Merge the updated Lua overlay into the existing addon, preserving your working
OpenVDB manifest, textures, shaders and custom audio. Separately extract the
local `vac-impact-resources.zip` into that same folder on server and clients.
Restart both after installing compiled shaders. The seven extracted files are:

- `shaders/fxc/vac_impactvol_ps30.vcs` (3182 bytes)
- `shaders/fxc/vac_nukevol_vs30.vcs` (294 bytes)
- `materials/vac/fx/impactvol/fields.vtf`
- `materials/vac/fx/impactvol/coords.vtf`
- `materials/vac/fx/impactvol/light.vtf`
- `materials/vac/fx/nukevol/noise.vtf`
- `lua/general_explosions/data/vac_impact.lua`

These resources are extracted from the supplied gmpublisher folder, not bundled
in the public repository or normal update overlay. Respect ownership/permissions
when distributing external assets. The six binaries are unchanged; generated
metadata is converted to a returned table without executing VAC code.

Recreate with `python tools/import_vac_impact.py SOURCE NEW_DIRECTORY --zip NEW.zip`.
Existing destinations/archives are refused. Source and installed files are never
modified. Distribute binary assets through your existing content setup; only the
installed metadata is sent with AddCSLuaFile.

## Controls

- `ge_railgun_vac_impact 1`: optional layer enabled when resources exist; 0 disables.
- `ge_railgun_vac_status`: reports resources/metadata/material, not GPU validity.
- `ge_railgun_vac_max 1`: concurrent limit, maximum 2.
- `ge_railgun_vac_distance 8000`: distance cutoff.

The master railgun visual toggle also hides this layer. Missing optional files
leave every original effect working. Late entity arrivals seek the networked
impact age. Old snapshots after the railgun entity expired do not replay it.
VAC's authored 0–40-second animation is retimed to 200/24 seconds, independent of
the OpenVDB speed preference. World scale is crater radius / 20, matching the
observed atlas reference. No new sounds, lights, particles or damage are added.

## Binding and validation limits

The separate screenspace_general material binds the matching VAC vertex shader,
noise at s0 and fields/coords/light at textures 1/2/3. c0 carries frame index,
interpolation, layer weight and authored time; c1 carries layer restarts, fade,
illumination; c2 carries sun direction and world scale; c3 carries origin and
packed radius/height bounds. These are not GE's OpenVDB shader contracts.

Outside the volume, a convex box draws entry faces; inside, a near-eye quad
matches the supplied renderer's approach. No low-resolution compositor is loaded.
The box may shade more empty pixels than VAC's shaped hull. Keep the default
one-instance limit; full-resolution raymarching can be costly. Error paths reset
depth overrides, finish an interrupted mesh and discard failed instances.

Tests cover interpolation, age seeking, missing files, culling, expiry, failed
draw cleanup, one-shot dispatch and non-destructive import. Actual supplied
metadata is parsed locally. **GPU output is untested in GMod**: verify blending
with the VDB, depth/occlusion, camera-inside appearance, water/reflections, timing
and frame cost using the RAILGUN.md acceptance matrix before merging. Material
existence cannot prove compiled shader compatibility. Never remove the original
VDB if the optional layer fails.
