# Volume pipeline

## Scope

Target: the real 200-frame GroundExplosionVDB, reading density and flames without substituting a procedural effect.

The project owner has successfully compiled the two HLSL shaders using the standalone ShaderCompile utility and visually verified the full 200-frame smoke/fire animation in Garry's Mod. The compiled VCS files and 3D VTF textures remain local/ignored by Git. The new crater, multivolume and network features are experimental and need separate in-game validation.

## Source data contract

- OpenVDB Python readAll returns a tuple: (list_of_grids, metadata).
- Both density and flames are float grids.
- Numpy copyToArray copies the sparse grid into a padded dense block in X,Y,Z coordinate order.
- Trilinear interpolation resamples to a selected fixed output dimension (32, 64, 128, or 256 on each axis).
- The texture stores R = density / per-frame density peak, G = flames / per-frame flames peak, B = 0, A = 255.
- Those peaks are saved in the frame manifest and decoded again in the shader.
- Output VTF volume storage is Z slices, then Y rows, with X changing fastest.
- Each frame has individual bounds. The global spatial anchor is derived from the earliest VDB frame, so the smoke expands without being recentered vertically.
- Only matching axis-aligned, z-up grid transforms are currently supported.

## Export using Blender 5.2

Run from PowerShell in the checked-out repo:

    & "C:\Program Files (x86)\Steam\steamapps\common\Blender\blender.exe" --background --python "tools\vdb_to_vtf.py" -- --input "C:\Users\klein\Downloads\blender workspace\GroundExplosionVDB\ground_explosion\ground_explosion_VDB\ground_explosion_0000.vdb" --out "output" --first 100 --last 100 --resolution 128

When frame 100 is exported correctly, change first to 0 and last to 199 to export the full sequence. You can also use step 2 to skip alternating frames. 128-cubed RGBA8888 uses 8 MiB per frame and approximately 1.56 GiB for 200 frames before compression/overhead. Output should not be checked into Git.

Generated addon-relative structure:

    output/
      materials/general_explosions/ground_explosion/frame_0100.vtf
      materials/general_explosions/ground_explosion/frame_0100.vmt
      lua/general_explosions/data/ground_explosion.lua
      docs/generated/ground_explosion.json

VTF header: version 7.2, size 80 bytes, format RGBA8888 (0), flags 0x2300, one mip, no thumbnail, depth equal to texture resolution.

## Source shader contract

GMod screenspace_general allows custom compiled shaders. Our shader names are ge_volume_vs30 and ge_volume_ps30. The vertex shader maps the local cube's 3D texture coordinates to the pixel shader. The pixel shader intersects the camera ray with the unit box, samples the 3D texture, and performs front-to-back smoke absorption and flame emission.

Custom pixel constants:

- c0.xyz: camera position in normalized volume box; c0.w: extinction strength.
- c1.xyz: directional light; c1.w: number of ray steps.
- c2.x: density decode scale; c2.y: flame decode scale; c2.z: flame gain; c2.w: ambient.
- c3.rgb: smoke tint; c3.w: opacity fade.

For Shader Model 3.0, both shaders are compiled to .vcs by the standalone ShaderCompile utility. The vertex shader no longer requires Source SDK header downloads. Source HLSL itself is not loaded by GMod. Run tools/build_shaders.ps1 on Windows, or follow the commands in the script. The resulting local binaries go into the **addon**:

    GarrysMod/garrysmod/addons/general_explosions/shaders/fxc/ge_volume_ps30.vcs
    GarrysMod/garrysmod/addons/general_explosions/shaders/fxc/ge_volume_vs30.vcs

The addon-contained compiled shader layout was verified working in the project owner's local GMod session. A restart is required after replacing shaders. V.A.C. shader binaries do not work with our data contract, and no V.A.C. assets are redistributed.

## GLua integration

1. Install the repository as garrysmod/addons/general_explosions.
2. Export OpenVDB textures and the Lua manifest into that addon, or copy the previously generated files there.
3. Compile the two HLSL shaders locally using tools/build_shaders.ps1 and put the generated .vcs files in the addon's shaders/fxc directory.
4. Restart GMod after changes.
5. Use ge_volume_status, ge_volume_preview 1400, and ge_volume_stop. For one-shots use ge_volume_spawn 1400 and ge_volume_clear. For craters use ge_crater_test 260 65, then ge_crater_clear.

Volume controls: ge_volume_steps, ge_volume_opacity, ge_volume_unit_scale, ge_volume_ambient, ge_volume_fire, ge_volume_speed, ge_volume_smoke_r, ge_volume_smoke_g, ge_volume_smoke_b, ge_volume_max_instances. Separate crater controls are documented in docs/CRATERS.md.

## Major known limitations

- Compiled shaders and full animation were confirmed by the project owner in GMod on an RX 6600. That does not guarantee compatibility on other GPUs, maps or shader configurations.
- The new visual crater engine and multiplayer event handling still need an in-game test.
- A depth-tested hull does not stop marching at opaque objects *inside* the volume; genuine scene-depth termination must be added.
- Animation uses frame swaps rather than interpolation between two temporally adjacent volumes.
- Full 200-frame distribution is large; cache controls, GPU memory management and compression are future work.
- Lighting is a cheap directional approximation, not physically accurate multiple scattering.
- Source index-to-world transform conversion is not implemented for arbitrary transformed VDB grids.
- There is no gameplay damage, ballistic or weapon implementation: these are visual effects only.

## References

Facepunch shader documentation: https://wiki.facepunch.com/gmod/Shaders/screenspace_general
Facepunch custom shader installation: https://wiki.facepunch.com/gmod/custom_shaders
OpenVDB NumPy copyToArray: https://www.openvdb.org/documentation/doxygen/python.html
GMod shader guide (volume textures example): https://github.com/meetric1/gmod_shader_guide
Source ShaderCompile: https://github.com/SCell555/ShaderCompile
