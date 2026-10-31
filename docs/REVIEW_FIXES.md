# PR #1 preservation follow-up

Addresses [the latest review](https://github.com/Gnelfling/general_explosions/pull/1#issuecomment-6540031134).

## Safe deployment

Keep the existing `general_explosions-main` directory. Back it up, including
custom WAVs, the generated Lua manifest and every VTF/VMT. Merge updated scripts
except `lua/general_explosions/data/ground_explosion.lua`. Never replace the
entire addon with a clone. Preserve local compiled shaders as well.

Inventory distinction: Git tracks two compiled VCS files (859/251 bytes), the
unchanged 188-record manifest, shader sources and supplied audio. VTF/VMT frames
are not tracked. The owner's full local 200-frame manifest may differ from Git.
Unknown frames 188–199 cannot be reconstructed or declared empty from Git alone.
Package complete matching textures as a separate release asset, not a 1.56-GiB
ordinary Git commit. The manifest and shader files alone are insufficient.

Run the read-only verifier on the actual installed folder:

```powershell
./tools/verify_install.ps1 -AddonPath 'C:\path\to\garrysmod\addons\general_explosions-main'
```

It inventories required files and every referenced VTF/VMT, reports short
sequences without rejecting legitimate shorter exports, and modifies nothing.
It cannot verify visual output or texture/shader compatibility.

Build the default overlay using `python tools/package_update.py update.zip`.
It excludes generated manifests, VTF/VMT, VCS and **all WAVs**, preserving custom
audio. `--include-audio` is an explicit replacement option, requiring a backup
and owner choice. Original unnormalized cue data is retained in audio_sources/.
The old audio-replacing ZIP should be superseded by this default overlay.

Audio starts remain 0/3/3.2 seconds; lengths are **not 3/1/5 seconds**. Current
policy is untrimmed overlapping tails (~3.135/5.085/13.377 seconds). Shortened
variants require an explicit owner decision; no working cue is silently cut.

## Runtime and evidence

Each consumer safely loads the shared runtime itself; it no longer depends on
autorun order or a map entity. Missing runtime files produce an actionable
diagnostic. The volume emits a nonblocking warning when the manifest ends before
199. No aesthetic convars or source frames are reset.

Restart server and clients together: v1 and v2 wire formats are incompatible.
Fresh startup and hot reload are separate acceptance checks. All working effects
are retained. The original shader binaries/sources and manifest are unchanged.

**UNTESTED IN GMOD:** standalone commands, actual 200-frame playback at speeds
1 and 0.5, opacity 100/fire 0.15/steps 40, client/server startup and hot reload,
late joins/resync/duplicates/3.2-second impact timing, all colors and presets,
near/far/side/behind-wall views, radii, audio tails, stencil, cleanup and undo.
Use the matrix in RAILGUN.md and attach actual video/console/frame-time evidence.
Automated mocked execution is not a substitute. Keep PR #1 unmerged pending
review and this owner-side evidence.
