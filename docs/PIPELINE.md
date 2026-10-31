# Volume pipeline

## Scope

Target: the real 200-frame GroundExplosionVDB, reading density and flames without substituting a procedural effect.

The following are authored but not yet validated in GMod: conversion into VTF 7.2 RGBA8888 3D textures, HLSL ray marching, and GLua material/hull rendering. **The repository does not yet contain compiled VCS shader binaries.** Do not expect visible smoke in GMod before they are compiled and tested.

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

For Shader Model 3.0, both vertex and pixel shaders need to be compiled to .vcs using a suitable Source shader compiler and the standard Source include headers. HLSL is not directly loaded by GMod. Install the resulting binaries here:

    GarrysMod/garrysmod/shaders/fxc/ge_volume_ps30.vcs
    GarrysMod/garrysmod/shaders/fxc/ge_volume_vs30.vcs

A restart is often required to load new binaries. V.A.C. compiled shaders are NOT interchangeable with our volume format. The project does not redistribute any V.A.C. code or assets.

## GLua integration

1. Put this repository's lua folder into garrysmod/addons/general_explosions/lua.
2. Copy generated output/materials and generated output/lua data into the same addon folder.
3. Install the new compiled shaders into the base garrysmod/shaders/fxc directory.
4. Restart GMod.
5. Use client console command ge_volume_status, then ge_volume_preview 1400, and ge_volume_stop.

Quality controls: ge_volume_steps, ge_volume_opacity, ge_volume_unit_scale, ge_volume_ambient, ge_volume_fire.

## Major known limitations

- Pixel/vertex shader source has NOT been compiled in this environment or validated in-game.
- True 3D texture sampling on an RX 6600 needs testing. One GMod shader guide warns of possible AMD issues for its volume-texture example.
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
