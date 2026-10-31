# Changelog

## Optional VAC impact volume

- Added separate impact shader/atlas binding alongside the original VDB.
- Added a non-destructive local resource importer; external assets stay out of Git.
- Added seek, cull, expiry, draw failure and import tests. GPU output remains untested.

## Wider laser, impact shake and configurable damage

- User-requested scope change: railgun impact now deals server-side explosion damage (150 default, 0 for cinematic mode), once at 3.2 seconds.
- Beam width defaults to 1.75x with a client slider; impact shake is stronger and includes airborne players.
- Preserves all visual layers, shaders, local volume assets and sound cue starts. Actual engine damage and visuals still need testing.

## Additional railgun choreography

- Added rising canted containment hoops, final axial latches, an energized
  orbital iris, a beam-head compression ring, pressure-dome arcs and ion trails.
- Retained all existing visual layers, palettes, performance controls, sound
  timings, audio files, shader contracts and volume/frame data.
- Added extreme-radius/slope geometry-budget and frame-independent replay tests.
  In-game appearance and performance remain unverified; PR stays unmerged.

## 2026-10-31 — orbital cinematic upgrade

- Audited all tracked sources, docs, tests, shaders, manifest and WAV headers.
  Findings and preservation limits are recorded in docs/AUDIT.md.
- Fixed sound filename case and Source PCM/positional compatibility, preserving
  original sample counts/rate and the 0.0/3.0/3.2 cue starts without trimming.
- Added version 2 timestamped/seeded impact records, duplicate suppression,
  client-ready history and age-correct recent volume reconstruction.
- Added segmented charge apertures and analytic motes, a descending layered
  column with helical filaments and moving collars, occlusion-aware impact glare,
  scaled double shock rings, charge/impact/afterglow illumination, crater heat,
  deterministic dust/flecks/sparks and quality budgets.
- Retained the original VDB raymarcher, shader contracts, generated frame data,
  stencil bowl, three audio cues and cinematic-only behavior.
- Reduced crater tracing to a shared terrain lattice; added shared-center
  geometry, procedural fractures/strata, safe failure handling and bounded
  reconstruction. Added render-state and map/shutdown cleanup.
- Fixed hidden volume lifetime, culling order and cleanup; added frame lookup,
  manifest validation and empty-frame timing for future exports.
- Added Lua 5.1 behavior tests, asset/format/preservation checks and a detailed
  in-game acceptance matrix. New visuals remain unverified in Source/GMod.
