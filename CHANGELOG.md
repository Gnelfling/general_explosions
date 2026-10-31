# Changelog

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
