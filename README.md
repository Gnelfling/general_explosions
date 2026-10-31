# General Explosions — volumetric VFX for Garry's Mod

An original, open development project for **animated 3D smoke and fire** in Garry's Mod. The first asset target is the user's `GroundExplosionVDB` (200-frame OpenVDB sequence, grids `density` and `flames`).

## Status — work in progress

**This is not yet a working GMod effect.** The repo starts with a Blender/OpenVDB volume-to-VTF conversion pipeline, an HLSL ray-marching design, and a GMod integration scaffold. The custom Source shaders have **not** been compiled into `.vcs` or validated in-game. If you do not have compiled shaders, **GMod cannot render the new material**.

## Why this pipeline?

- Real 3D texture sampling (`sampler3D` / `tex3D`), rather than billboarded sprites or axisymmetric reconstruction.
- One texture per frame, with `R=density`, `G=flames`, preserving distinct smoke/fire fields.
- Dense, volume-preserving trilinear resampling with explicit source bounds and density scales.
- SM3.0 GPU ray marching with absorption and emissive flames.
- Source-compatible **VTF 7.2 RGBA8888 volume textures** with one mip level.
- Project-owned shader names / assets. **No V.A.C. compiled shaders or textures are redistributed.**

## Layout

```
tools/vdb_to_vtf.py          Blender Python / OpenVDB converter
shaders/src/ge_volume_ps30.hlsl    Pixel shader source (uncompiled)
shaders/src/ge_volume_vs30.hlsl    Vertex shader source (uncompiled)
lua/autorun/client/ge_volume.lua  Experimental renderer scaffold
docs/PIPELINE.md            Data contract, limitations, build workflow
docs/VAC_NOTES.md           Technical comparison, no copied code
tests/test_vtf_header.py    Small writer-format tests
```

## Export the real VDB sequence

Run from **PowerShell** (replace the Blender executable and input paths for your installation):

```powershell
& "C:\Program Files (x86)\Steam\steamapps\common\Blender\blender.exe" --background --python "tools\vdb_to_vtf.py" -- --input "C:\Users\klein\Downloads\blender workspace\GroundExplosionVDB\ground_explosion\ground_explosion_VDB\ground_explosion_0000.vdb" --out "output\ground_explosion" --first 100 --last 100 --resolution 128
```

To process the animation, change `--first 0 --last 199` after verifying your files exist. Conversion output is **not** committed to Git: 200 frames of 128³ RGBA8 volumes would consume ~1.56 GiB before compression.

Read [the pipeline notes](docs/PIPELINE.md) for GMod placement and the current rendering blockers.

## Development principles

- Work on the **actual** OpenVDB, not a stand-in procedural explosion.
- Keep shader and texture format specs in sync.
- Do not claim game compatibility until the shaders compile and the visual is verified in GMod.
- Keep visual effects separate from any gameplay damage or weapon mechanics.

Reference APIs: [GMod screenspace_general](https://wiki.facepunch.com/gmod/Shaders/screenspace_general), [GMod custom shaders](https://wiki.facepunch.com/gmod/custom_shaders), [OpenVDB Python array extraction](https://www.openvdb.org/documentation/doxygen/python.html).
