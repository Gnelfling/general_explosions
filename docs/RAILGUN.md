# Orbital Railgun — cinematic entity

The railgun is a cosmetic presentation, with no damage, projectile simulation,
physics impulses, BSP edits or collision changes. The original OpenVDB volume
and stencil crater remain the main impact systems. New geometry uses stock
GMod materials and APIs; no additional compiled shader is required.

**Validation status:** Lua 5.1 behavior, syntax, asset and preservation tests
pass. The upgraded effect has **not been visually tested in Garry's Mod**.
The owner's earlier smoke/fire test does not validate this upgrade. See
[AUDIT.md](AUDIT.md) for findings and retained limitations.

## Install without losing the working volume

Keep your existing addon folder, including a folder named
`general_explosions-main`. Back it up first. Update the Lua scripts **except**
your locally generated `lua/general_explosions/data/ground_explosion.lua`.
Preserve your custom WAVs. Only if you choose the supplied normalized cues, back up your existing audio first and copy the three lowercase WAV files from `sound/general_explosions/railgun/`
to the same location inside the installed addon. Restart the server and clients.

Keep all existing `materials/general_explosions/ground_explosion/` VTF/VMTs,
`shaders/fxc/ge_volume_*.vcs`, and your matching generated manifest. No shader
rebuild or volume conversion is needed. A clean clone includes the two compiled shaders but lacks the large local
VTF/VMT texture assets. The checked-in manifest contains **188 texture records (0–187)**;
missing records 188–199 cannot be reconstructed from this repository. Preserve
your working 200-frame export. The new exporter retains explicit empty frames
and the requested start/end range for future exports.

In multiplayer, distribute the same volume VTF/VMT/VCS assets through your
existing content package/FastDL setup. Lua, including the installed generated
manifest, is sent by the server; the three cues are registered with
`resource.AddFile`. This does not automatically distribute the large volume
textures or enable custom shaders on a client lacking them.

## Spawn and cancel

Use Sandbox Q → Entities → General Explosions → **Orbital Railgun (Visual)**,
or aim at fairly level world ground and run `ge_railgun_fire`. The Utilities
panel has the same action. Single-player and server admins can spawn it;
placement on props, sky or steep walls is rejected. There is a short 0.45-second
network lead-in before the cinematic clock starts.

`ge_railgun_status` reports active entities and radius. `ge_railgun_clear`
cancels active railguns and clears replicated impacts. Undo cancels an active
entity; after impact, the crater and volume have independent lifetimes.
Already playing world-positioned sound is allowed to finish. `ge_fx_resync`
requests retained history again (server limited to once per ten seconds).

## Timeline and sound contract

All offsets are relative to the networked `StartTime`, not the spawn click.

| Offset | Presentation | Sound cue start |
|---|---|---|
| 0.0 s | Rotating segmented aperture, converging motes, growing charge light | `railgun_charge.wav` |
| 3.0 s | Column descends from the sky, with white core and helical filaments | `railgun_fire.wav` |
| 3.2 s | Column reaches target; glare, double shock ring, crater, dust/sparks, original VDB | `railgun_explosion.wav` |
| 4.25 s | Beam completely faded | — |
| 4.95 s | Environmental afterlight retired | — |
| 5.25 s | Temporary entity removed | — |
| Impact + 6 s | Crater fissures cooled to black | — |
| Impact + 200/24 s | End of a full 200-frame volume at speed 1 | — |

The three sound offsets remain **0.0 / 3.0 / 3.2 seconds**. The server emits
each cue once on the first simulation tick reaching its offset. Tick spacing,
network transit and device buffering prevent a promise of sample-accurate
client playback. Joining players see the current animation phase and recent
volumes; historical sounds and old particle bursts are not replayed.

The included cue content is preserved without trimming or resampling. To make
it compatible with positional Source playback, stereo/24-bit originals were
mixed to **mono 16-bit PCM at 44.1 kHz**. Exact frame counts remain 138240,
224256 and 589875 (approximately 3.135, 5.085 and 13.377 seconds). These tails
overlap intentionally; they are not the old guide's stated 3/1/5-second lengths.
The unused `railgun_fire(1).WAV` is retained and never scheduled. The offline
conversion utility is `tools/prepare_audio.py`.

## Visual controls and budgets

| Client convar | Default | Purpose |
|---|---:|---|
| `ge_railgun_visuals` | 1 | Beam, charge, glare and railgun lighting |
| `ge_railgun_color` | blue | blue / purple / red |
| `ge_railgun_quality` | 1 | 0 / 1 / 2: segments, filaments, motes, collars |
| `ge_railgun_beam_height` | 6000 | Sky column height, 1000–10000 |
| `ge_railgun_distance` | 18000 | Draw cutoff with a fade over its last 20% |
| `ge_railgun_glow` | 1 | Charge motes and occlusion-aware impact glare |
| `ge_railgun_light` | 1 | World/entity dynamic illumination |
| `ge_railgun_light_budget` | 2 | Nearest simultaneous railgun lights, 0–4 |
| `ge_crater_heat` | 1 | Six-second cooling fracture accents |
| `ge_fx_particle_budget` | 192 | Conservative active impact-particle cap, 32–512 |
| `ge_fx_particle_amount` | 0.65 | Dust, inert flecks and spark density |

Server convars: `ge_railgun_radius 320` (80–900),
`ge_railgun_shake 1` (optional cosmetic camera shake),
`ge_railgun_max_active 2` (1–6). Radius scales the beam, shock rings, crater,
volume and particles together. Colors are a local preference, not server state.

`ge_quality low|balanced|high` now also selects beam detail and light budget.
Existing smoke/fire artistic settings are preserved. VDB speed remains a local
control; clients with different speed settings deliberately play it differently.

Safeguards: cached unit circles; distance-dependent beam detail; a single
visibility query per entity per engine tick; at most one world light per selected
entity, refreshed at 20 Hz; no per-frame particle emitter; at most eight impact
emitters and 128 particles per burst; no particle collisions; four-second emitter
retirement; one crater build per frame with 25/49/81 terrain traces by detail;
bounded queues/history/meshes/volumes. Distant volumes age without looking up
their frame materials. Source owns texture residency: these controls do not
guarantee a VRAM ceiling.

## Multiplayer and cleanup

Version 2 impact records carry a monotonic event ID, server impact timestamp,
position, surface normal, radius/depth and seed. Live events and client-ready
history snapshots share that format. Duplicate IDs suppress repeated particles
and volumes; snapshots rebuild retained craters and seek recent volumes to their
actual age. Old particles are skipped once the event is 0.35 seconds old.
The bounded history is authoritative for retained craters; older evicted history
does not reconstruct volumes for new players.

Map cleanup clears volumes, particles, mesh queues, crater meshes and railgun
lights. Pending showcase timers are invalidated. Crater draw failures reset
depth/color/alpha/stencil/blend state and quarantine the failed crater after one
diagnostic. Beam rendering does not install those overrides. Cleanup hides
particle emitters immediately; their remaining particles expire naturally.

## Automated validation

From the repository root, using Python 3.10+:

```text
python -m pip install -r tests/requirements.txt
python -m unittest discover -s tests -v
python -m py_compile tools/vdb_to_vtf.py tools/prepare_audio.py
```

Lupa provides a development-only Lua 5.1 runtime. Tests execute the actual Lua
against small GMod boundary mocks: exact cue offsets/one-shot dispatch,
network duplicates and late packets, 200-frame selection and empty timing,
all palettes/detail levels/phases, render failure cleanup, trace/particle/light
budgets, volume culling and hidden playback. Golden hashes protect the original
shader sources and checked-in manifest; audio tests protect sample counts and
PCM format. CI also parses scripts with the native Lua 5.1 compiler.

These tests cannot validate the GPU image, material availability, Source audio
attenuation, network transport, stencil interactions or frame time.

## Required in-game acceptance matrix (not yet executed)

Record build/branch, map, GMod version, GPU, resolution, graphics preset,
convars, player count and addon list with each run. Capture video and console
output; mark each row pass/fail with evidence before calling a build production
ready.

| Test | Method | Acceptance |
|---|---|---|
| Existing volume | `ge_volume_status`, then original preview and a full one-shot | Working local 200-frame sequence, unchanged color/anchor/scale; no missing-frame/material errors |
| Timeline | Record at 60 FPS; compare charge, fire, impact and audio waveform onsets | Scheduled 0/3/3.2 offsets; descending head meets flash; no duplicate cues |
| Composition | gm_construct daylight and a dark map; all three palettes at each preset | Charge readable, core distinct from aura, smoke/fire visible through controlled glare, no persistent whiteout |
| Ground | Flat concrete, gentle slopes, irregular terrain; radii 80/320/900 | Aperture follows surface; crater seam/rim acceptable; no loose center wedge or depth leaks |
| Occlusion | View through walls/props, behind terrain, in water, inside volume; test mirrors/RTs | Glare occludes; no unexpected through-wall rings, depth corruption or repeated visibility queries |
| Stencil integration | Overlap two craters; add depth/stencil-using addons | No leaked render state; document any retained hole-illusion artifacts |
| Multiplayer | Dedicated server + two clients; introduce 100/250 ms latency with supported test setup | Same beam phase and seeded geometry; VDB seeks rather than restarts; each live cue once |
| Joining | Join during charge, after impact, and after volume end; run `ge_fx_resync` twice | Current beam phase; recent volume at correct age; old crater without replayed flash/audio/particles |
| Lifecycle | Undo before impact; remove mid-beam; map cleanup during showcase; clear/resync | No delayed impact after cancellation, stuck light, visible old particles, leaked mesh or error spam |
| Budgets | One/two/max-active entities at low/balanced/high; near and far | Record baseline vs peak CPU/GPU frame times and hitch on crater build; choose budgets to meet target hardware's frame budget |
| Long run | Repeated spawns/clears for 10 minutes; inspect counts and frame time | Counts return to configured bounds; no increasing mesh/emitter count; no recurring Lua errors |
| Linux/content | Case-sensitive dedicated install and fresh client with intended content delivery | Lowercase cues audible and positional; manifest and all required local volume assets available |

Known limits remain: a stencil crater is not a physical opening; translucent
props, overlapping craters, water and other stencil users can expose artifacts.
The unchanged raymarcher does not stop at scene depth inside the volume and does
not interpolate frames. Tall columns can clip against map sky/far planes.

API references: [beams](https://wiki.facepunch.com/gmod/render_beams),
[pixel visibility](https://wiki.facepunch.com/gmod/util.PixelVisible),
[dynamic light fields](https://wiki.facepunch.com/gmod/Structures/DynamicLight),
[stencil-scoped clearing](https://wiki.facepunch.com/gmod/render.ClearBuffersObeyStencil),
[audio format basics](https://wiki.facepunch.com/gmod/sound_basics).
