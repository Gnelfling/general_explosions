# Technical audit — 2026-10-31

Baseline: `4af0b7c`. Reviewed every tracked source, test, workflow and document,
the generated manifest, and the headers of all four audio assets before edits.

## Confirmed integration problems

- Charge/fire WAV extensions were uppercase; Lua requested lowercase paths.
  This fails on case-sensitive installs. Explosion was 24-bit PCM; Source audio
  compatibility requires a 16-bit deliverable. Stereo cues also prevent useful
  positional attenuation. Normalize the three referenced cues to mono 16-bit
  PCM without trimming, resampling, or moving their scheduled starts.
- Audio lengths are 3.135s charge, 5.085s fire, 13.377s explosion; the old guide's
  3/1/5-second durations were inaccurate. The alternate fire(1) is unused.
- Impact packets had no timestamp or identifier. Latency restarted the volume,
  and a joining client received only crater history after an arbitrary delay.
- Lighting ignored the master visual toggle and removal had no explicit light
  retirement. API verification confirmed DynamicLight members are case
  insensitive; the original capitalization is **not** a runtime bug.
- Volume instances were deleted when rendering was disabled. Culled instances
  still selected and loaded frame textures. No map-cleanup hook cleared volumes.
- Crater generation traced the same center once per segment, added noisy,
  inconsistent center heights, and could leave a mesh allocated after failure.
  Scorch-only mode built unused rim geometry. Render failures repeated each
  frame; alpha-write state and shutdown cleanup were incomplete.
- Exporter skipped empty frames and derived duration from the last nonempty
  frame. The checked-in manifest has **188 records, frames 0–187**, not 200.
  There is no evidence here establishing whether frames 188–199 were empty or
  omitted. Do not invent missing simulation data or overwrite a user's local
  working manifest. Future exports must retain empty-frame timing explicitly.
- Server did not distribute the generated manifest with AddCSLuaFile, nor
  register audio for download. Resource distribution of the large local volume
  assets remains a deployment responsibility.

## Preservation boundary

Keep HLSL, FXC, c0–c3 meanings, 3D RGBA packing, anchor, existing manifest frame
records, VTFs and compiled VCS byte-for-byte unchanged. Keep the existing
raymarcher and stencil bowl. New beam/charge/particle work uses GMod APIs and
procedural geometry only. Keep cue offsets **0.0 / 3.0 / 3.2 seconds**. Actual
server delivery is tick-quantized; network and audio hardware add latency.

## Validation baseline and limits

Nine existing Python tests: eight pass; the temporary-file test initially
encountered restricted Windows temp-directory permissions. Use a workspace
temp directory for local validation. Existing railgun checks only inspect text;
they do not execute entity behavior or prove visuals.

This checkout has the tracked VCS shaders but no VTF/VMT sequence or attached GMod test session. Shader
appearance, stencil integration, positional audio, multiplayer under real
latency, and GPU frame times require the manual acceptance matrix in RAILGUN.md.
Original smoke/fire and animation were previously verified by the owner;
that evidence does not validate the new changes.

## Retained limitations

No temporal VDB interpolation or scene-depth termination inside the volume;
both would alter the preserved shader contract. Source controls texture
residency; instance/distance limits do not guarantee a VRAM cap. Stencil depth
clearing remains an illusion and can conflict with overlapping craters, props,
water, or other stencil users. No collision or gameplay changes are made.

API references: [dynamic lights](https://wiki.facepunch.com/gmod/Global.DynamicLight),
[stencil-scoped buffer clearing](https://wiki.facepunch.com/gmod/render.ClearBuffersObeyStencil),
[client readiness](https://wiki.facepunch.com/gmod/GM:InitPostEntity).
