# General Explosions — volumetric visual effects for Garry's Mod

An original visual-effects-only addon using a real 200-frame GroundExplosionVDB animation, Shader Model 3.0 volume raymarching, and custom 3D VTF textures.

**Status:** Smoke, fire and the full animation have been verified in-game by the project owner. The crater, impact accents and multiplayer synchronization added afterward are new code and still require testing in GMod. No gameplay damage, projectiles or weapons are implemented.

## Features

- Real animated volumetric smoke and fire, generated from OpenVDB density/flames fields.
- Looping preview and independent one-shot instances, each with its own position, scale and lifetime.
- Playback speed, opacity, fire gain, smoke tint, size, ambient and GPU step count controls.
- Procedural visual crater: irregular opening, sunken mesh bowl, rim, scorched soil blanket, stencil/depth hole illusion.
- Crater geometry detail controls, culling, instance limits and cleanup.
- Lightweight ground dust accents and combined local preview.
- Multiplayer broadcasts of cosmetic effects; saved crater positions synchronized for later joining players.
- Repeatable PowerShell shader compile script and CI syntax checks.

## Developer installation

Install the repository as:

    GarrysMod/garrysmod/addons/general_explosions/

The locally compiled shader binaries must be present in the addon:

    shaders/fxc/ge_volume_ps30.vcs
    shaders/fxc/ge_volume_vs30.vcs

Your generated Blender/OpenVDB volume files must also be installed:

    materials/general_explosions/ground_explosion/frame_0000.vtf ...
    materials/general_explosions/ground_explosion/frame_0000.vmt ...
    lua/general_explosions/data/ground_explosion.lua

Compiled VCS and exported VTF files are Git-ignored and not provided in a fresh clone. Run tools/build_shaders.ps1 with your own ShaderCompile.exe, and see docs/PIPELINE.md for the OpenVDB exporter. Existing working compiled shaders do not need rebuilding for these Lua-only changes.

The addon includes client autorun files for craters, dust, networking and volumes, plus a server autorun file for shared cosmetic events. Restart GMod after updating them.

## First commands to test in GMod

Aim at fairly flat world ground on gm_construct, then use the developer console:

    ge_crater_test 260 65      - original stencil crater, radius/depth in Source units
    ge_crater_scorch           - flattened scorch mark
    ge_crater_status           - print crater count
    ge_crater_clear            - remove clientside craters
    ge_fx_local_test 260 65    - combined crater, dust and 3D volume
    ge_fx_local_clear          - remove local crater and one-shot volume effects
    ge_volume_status           - inspect manifest/shader file status
    ge_volume_preview 1400 1  - existing looping preview
    ge_volume_stop             - stop looping preview
    ge_volume_spawn 1400 1    - new one-shot volume
    ge_volume_clear            - clear one-shot volumes

On the server, available to administrators or local games:

    ge_fx_impact 260 65        - networked cosmetic impact at viewed ground
    ge_fx_showcase 200         - three staggered cosmetic impacts
    ge_fx_clear                - clear synchronized crater visuals

## Runtime convars

| Convar | Default | Meaning |
|---|---:|---|
| ge_volume_opacity | 100 | Smoke extinction |
| ge_volume_fire | 0.15 | Flame emission |
| ge_volume_steps | 40 | Raymarch steps, 8–96 |
| ge_volume_unit_scale | 8 | World-space scale |
| ge_volume_speed | 1 | Playback rate (0.5 = half speed) |
| ge_volume_ambient | 0.18 | Ambient contribution |
| ge_volume_smoke_r/g/b | 0.40 / 0.42 / 0.44 | Smoke color |
| ge_volume_max_instances | 3 | Simultaneous one-shot volumes |
| ge_crater_enabled | 1 | Toggle crater render |
| ge_crater_detail | 1 | Geometry detail (0–2) |
| ge_crater_max | 12 | Maximum client craters |
| ge_crater_distance | 12000 | Crater draw cutoff |
| ge_fx_dust | 1 | Enable dust |
| ge_fx_particle_amount | 0.65 | Dust density |

GMod saves many client convars. Values you set during earlier tests may override these new defaults.

## Current limitations

- A stencil crater is a visual illusion. The world collision mesh remains untouched, so players and props do not actually fall into it.
- Craters may expose artifacts on sloped ground, overlapping props, unusual maps, or when other addons manipulate the stencil/depth buffer.
- 200 uncompressed 128-cubed RGBA8 frames occupy about 1.56 GiB; animation frame swaps can affect VRAM and frame time.
- Volume frame interpolation and opaque-scene depth termination are not yet implemented.
- New gameplay-facing systems are experimental; GitHub syntax checks cannot substitute for real GMod rendering tests.
- Original code only. No V.A.C. assets, shaders or Lua source are redistributed.

See docs/CRATERS.md for the crater design and test plan; docs/PIPELINE.md for shaders and texture conversion.
