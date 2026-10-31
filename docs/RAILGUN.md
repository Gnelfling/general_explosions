# Orbital railgun — visual-only Sandbox entity

**Status: implemented, Lua syntax checked by CI, not yet visually tested in Garry's Mod.** This is a cinematic in-game effect: no damage, projectiles, physics, actual ground removal, or weapon simulation. A server entity coordinates beam timing and the existing client visual explosion framework.

## How to spawn

In a local GMod Sandbox map (e.g. gm_construct), restart after installing updated Lua. Aim at reasonably level **world** ground (not a prop).

- Q menu → **Entities** → **General Explosions** → **Orbital Railgun (Visual)**, then click ground; or
- Developer console: ge_railgun_fire; or
- Q menu → **Utilities** → **General Explosions** → **Visual Effects** → **Trigger orbital railgun visual**.

Spawning is limited to single-player or server administrators. The entity removes itself after its beam animation, leaving the original volume and crater effects managed by their own renderers.

## Precise audiovisual timeline

| Time | Event | User-supplied audio | Audio length |
|---|---|---|---:|
| 0.0s | Animated charge rings begin | railgun_charge.wav | 3.0s |
| 3.0s | Orbital blue-white column fires | railgun_fire.wav | 1.0s |
| 3.2s | Flash, shockwave, crater, debris/dust and VDB volume start | railgun_explosion.wav | 5.0s |
| 4.25s | Beam fades away completely | — | — |
| 5.25s | Temporary beam entity auto-removes | — | — |
| ~11.5s | Default 200-frame volumetric animation ends (24 FPS at speed 1) | — | — |

**These sound cues are triggered by the server at 0.0, 3.0 and 3.2 seconds, using sound.Play at the effect's world position.** Sound length is authored in the WAV itself and is not force-trimmed by the entity. The animation continues normally if any WAV files are missing.

Create this exact folder **inside the installed addon**, not in lua/:

    sound/general_explosions/railgun/railgun_charge.wav
    sound/general_explosions/railgun/railgun_fire.wav
    sound/general_explosions/railgun/railgun_explosion.wav

Use standard GMod-compatible uncompressed PCM WAV files. Sound volume/attenuation depend on GMod's positional audio engine; file loudness is controlled by the audio producer.

## Implementation

- lua/entities/ge_orbital_railgun/shared.lua — entity identity, Spawnmenu category, networkvars and timing constants.
- lua/entities/ge_orbital_railgun/init.lua — admin-only spawn validation, networked start time, timed optional audio cues, impact FX event, auto cleanup.
- lua/entities/ge_orbital_railgun/cl_init.lua — charge rings, layered animated render.DrawBeam column, electrical accents, flash/shockwave, optional DynamicLight.
- lua/autorun/server/ge_fx_server.lua — existing multiplayer cosmetic effect replication and retained crater data.
- lua/autorun/client/ge_fx_client.lua — receives cosmetic impact and instantiates the procedural crater, dust and 200-frame VDB smoke.

No additional VCS shaders or proprietary assets are required for the **beam**. To see the **volumetric explosion**, the compiled volume shader VCS files, generated Lua manifest, and the frame VTF/VMT files must already be correctly installed.

## Settings

Clientside:

    ge_railgun_color blue
    ge_railgun_color purple
    ge_railgun_color red
    ge_railgun_visuals 1
    ge_railgun_glow 1
    ge_railgun_light 1
    ge_railgun_beam_height 6000

Serverside (admin/server console):

    ge_railgun_radius 320
    ge_railgun_shake 1
    ge_railgun_max_active 2

The impact radius affects crater size and the scale of the existing smoke effect. Playback speed of the VDB is separately controlled with ge_volume_speed. For performance: ge_quality low, ge_quality balanced, or ge_quality high (client).

## First in-game validation

1. ge_volume_status must report the compiled volume shaders and a non-empty manifest. Ideally it should report 200 frame records.
2. With client graphics presets set to balanced, trigger ge_railgun_fire at a level world surface.
3. Expect charge rings for 3 seconds; bright sky beam at 3 seconds; impact at 3.2 seconds; beam gone around 4.25 seconds; smoke persists.
4. Check console for [GE] error messages. If the beam renders but smoke does not, investigate the exported VTF/manifest and VCS installation first.
5. Verify appearance on flat ground, then irregular terrain. The crater stencil is still experimental; collision does not change.
6. Check multiplayer timing, rejoining snapshots, culling at long distances, and performance with 2 active effect entities.

Known risks: engine far-plane clipping of the tall beam, unusual map geometry, addon render-hook conflicts, FPS cost of multiple 128-cubed volumes, and the unverified stencil crater technique. CI Lua parsing cannot prove that the visual output is correct.

## Installation — preserve local volume assets

If your GMod addon directory is named general_explosions-main, **keep that folder name**. Pull the repo into your working clone and copy only the lua/ tree to your existing installed addon. Do **not** replace the entire addon folder with a clean Git clone because local shader binaries, manifest and large texture frames are Git-ignored and would be lost. Restart GMod after copying.

For API background see https://wiki.facepunch.com/gmod/ENTITY:SpawnFunction and https://wiki.facepunch.com/gmod/render_beams.
