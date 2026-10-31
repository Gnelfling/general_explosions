# General Explosions — volumetric visual effects for Garry's Mod

An original visual-effects-only addon using a real 200-frame GroundExplosionVDB animation, Shader Model 3.0 volume raymarching, and custom 3D VTF textures.

**Status:** The owner previously verified the volumetric smoke/fire animation in-game. The upgraded railgun, crater and synchronization pass automated code checks but still require the [GMod acceptance matrix](docs/RAILGUN.md#required-in-game-acceptance-matrix-not-yet-executed). The railgun now applies configurable explosion damage (150 by default); use ge_railgun_damage 0 for cinematic mode. No projectile or BSP destruction is added.

## Features

- Real animated volumetric smoke and fire, generated from OpenVDB density/flames fields.
- Looping preview and independent one-shot instances, each with its own position, scale and lifetime.
- Playback speed, opacity, fire gain, smoke tint, size, ambient and GPU step count controls.
- Procedural visual crater: irregular opening, sunken mesh bowl, rim, scorched soil blanket, stencil/depth hole illusion.
- Crater geometry detail controls, culling, instance limits and cleanup.
- Lightweight ground dust accents and combined local preview.
- Orbital cinematic: assembling charge aperture, converging motes, descending layered beam, helical filaments, impact glare, paired shock rings, cooling crater fractures, seeded dust/flecks/sparks and environmental illumination.
- Multiplayer broadcasts of cosmetic effects; saved crater positions synchronized for later joining players.
- Timestamped, deduplicated impacts; client-ready snapshots seek recent volumes to their current age.
- Distance/detail/particle/light budgets, cleanup and Lua 5.1 behavioral tests, plus converter/audio tests and CI syntax checks.

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

The two compiled VCS files are tracked (pixel: 859 bytes; vertex: 251 bytes). Exported VTF/VMT frames are not tracked; a fresh clone cannot render the volume without matching local textures. Run tools/build_shaders.ps1 with your own ShaderCompile.exe, and see docs/PIPELINE.md for the OpenVDB exporter. Existing working compiled shaders do not need rebuilding for these Lua-only changes.

The addon includes shared/client/server autorun files and the orbital entity. **If your installed folder is general_explosions-main, preserve it and its generated files:** update Lua **except your existing generated ground_explosion.lua manifest**, and preserve custom WAVs; copy the supplied normalized WAVs only after backing up and explicitly choosing them. Keep all local VTF/VMT/VCS files. Restart GMod afterward. See the [installation guide](docs/RAILGUN.md#install-without-losing-the-working-volume).

The checked-in manifest contains 188 texture records (0–187). Their source data is preserved unchanged; the repository cannot establish whether 188–199 were empty or omitted. Keep your working 200-frame local export. Future exports retain empty-frame timing and the requested frame range explicitly.

## Orbital railgun cinematic entity

Optional user-supplied VAC impact shader integration is available alongside
the original OpenVDB renderer. Its required resources are now included in the GitHub branch ZIP;
see [installation and limitations](docs/VAC_IMPACT.md).

Latest controls: `ge_railgun_beam_width 1.75` (client, 0.5–3), `ge_railgun_shake 1`, `ge_railgun_shake_strength 8`, `ge_railgun_damage 150` (server, 0–1000). Damage occurs once at 3.2 seconds within the impact radius (320 by default); damage 0 restores cinematic-only operation. Generic crater/volume/FX previews remain cosmetic.

The spawnable entity lives in `lua/entities/ge_orbital_railgun/`. It combines procedural orbital energy visuals with the existing volumetric explosion and stencil bowl. The beam requires no new compiled shaders or downloadable textures.

- Spawn through **Q menu → Entities → General Explosions → Orbital Railgun** and click relatively flat map ground.
- Or aim at flat world ground and run `ge_railgun_fire` in the developer console.
- Only available in single-player or to server admins.
- Sound cue starts remain **0.0 s**, **3.0 s**, and **3.2 s**, relative to the networked cinematic start. Server scheduling is tick-quantized; client audio also has network/device latency.

The owner's three WAV cues ship under `sound/general_explosions/railgun/` with lowercase names. They are now mono 16-bit PCM at the original 44.1 kHz rate, with original frame counts and no trimming (approximately 3.135/5.085/13.377 seconds). Missing sounds do not block visuals. The unused alternate fire WAV is retained.

Client color can be set with `ge_railgun_color blue`, `ge_railgun_color purple`, or `ge_railgun_color red`. Admin/server console can adjust `ge_railgun_radius 320`. The volumetric component still requires the original shaders, manifest and VTF sequence.

**Game-testing status:** entity Lua compiles; in-game visual/audio sync and compatibility still need verification. See [the complete railgun guide](docs/RAILGUN.md).

Use `ge_railgun_clear` to cancel active sequences and clear replicated impacts, and `ge_fx_resync` to request history again. Quality presets also control orbital detail and light budget. Read [the technical audit](docs/AUDIT.md) for confirmed bugs, preservation boundaries and remaining limits.

## In-game controls

Open the Sandbox spawn menu (Q), switch to Utilities, and look for **General Explosions → Visual Effects**. The panel has buttons for smoke, craters, combined previews and quality controls.

Quality presets can also be switched with these commands:

    ge_quality low
    ge_quality balanced
    ge_quality high

The balanced preset uses the previously tested 40-step raymarch setting. Quality changes do not overwrite your smoke tint or fire intensity.

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
| ge_fx_particle_budget | 192 | Impact particle budget, 32–512 |
| ge_railgun_quality | 1 | Procedural beam detail, 0–2 |
| ge_railgun_distance | 18000 | Orbital visual cutoff |
| ge_railgun_light_budget | 2 | Nearest railgun world lights, 0–4 |
| ge_crater_heat | 1 | Six-second cooling fissures |

GMod saves many client convars. Values you set during earlier tests may override these new defaults.

## Current limitations

- A stencil crater is a visual illusion. The world collision mesh remains untouched, so players and props do not actually fall into it.
- Craters may expose artifacts on sloped ground, overlapping props, unusual maps, or when other addons manipulate the stencil/depth buffer.
- 200 uncompressed 128-cubed RGBA8 frames occupy about 1.56 GiB; animation frame swaps can affect VRAM and frame time.
- Volume frame interpolation and opaque-scene depth termination are not yet implemented.
- New cinematic systems require visual acceptance; automated code checks cannot substitute for real GMod rendering tests.
- Original code only. No V.A.C. assets, shaders or Lua source are redistributed.

See docs/CRATERS.md for the crater design and test plan; docs/PIPELINE.md for shaders and texture conversion.

## Automated development checks

```text
python -m pip install -r tests/requirements.txt
python -m unittest discover -s tests -v
python -m py_compile tools/vdb_to_vtf.py tools/prepare_audio.py
```

Python 3.10+; NumPy and Lupa are offline development/test dependencies only. The addon adds no runtime dependency. Tests execute actual Lua 5.1 with mocked GMod boundaries and protect the unchanged shader/manifest sources. CI also runs the native Lua 5.1 parser. No automated check here renders Source images or measures GPU performance.
