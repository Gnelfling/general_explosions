# General Explosions — stencil crater system (experimental)

This module creates an apparent crater in Garry's Mod without modifying a map's BSP brushes or physics. It uses standard GMod procedural meshes and stencil/depth render functions. The project owner has already validated the separate OpenVDB smoke renderer; **this crater module still needs an actual GMod test**.

## Rendering flow

1. A local preview or cosmetic server event supplies a world point, crater radius, depression depth, and deterministic seed.
2. The client traces against world brushes around that point, creating concentric ring vertices with irregular angular outlines.
3. A hollow bowl mesh is built below the traced ground, an elevated rim is built around its edge, and a fading scorch blanket covers the perimeter.
4. During PostDrawOpaqueRenderables, the opening mesh writes a stencil region without writing color or depth.
5. Within that stencil, depth is cleared. The sunken bowl is rendered in the revealed region. Stencil is disabled afterward and rim/blanket meshes are drawn.
6. A render-state cleanup runs even if the draw fails. All meshes are destroyed when the map is cleaned or the crater limit is exceeded.

This is visually similar in principle to the virtual openings described in Facepunch's stencil-rendering documentation, but its geometry and code are authored for General Explosions and no V.A.C. files are redistributed.

## Test checklist

Use a local game on gm_construct. Enable the developer console, aim at ordinary fairly level world ground, and test:

    ge_crater_test 260 65
    ge_crater_status
    ge_crater_clear
    ge_crater_scorch
    ge_crater_detail 0
    ge_crater_test 260 65
    ge_crater_detail 2
    ge_crater_test 500 140

Then test the combined effect:

    ge_fx_local_test 260 65
    ge_fx_local_clear

The test point should be on the map world, not on a prop or player. Radius and depth are Source world units, not meters. A depth value of 0 creates a scorch-only mark.

## Expected visuals

- A dark, irregular depressed bowl, with a somewhat raised lip and surrounding scorched tint.
- Appearance changes with viewpoint because the bowl is true 3D geometry, not a flat decal.
- The apparent opening is a screen-space illusion; collision remains at the map's original ground height.

## Experimental caveats

- Stencil and depth clearing can uncover other render passes incorrectly, especially on complex terrain or when depth-sensitive effects are active.
- Transparent objects and world props may not participate in the hole illusion naturally.
- World brush traces cannot truly remove geometry. Do not promise the player can physically enter the hole.
- The initial surface material uses reliable UnlitGeneric + procedural vertex colors, not PBR or expensive custom shaders. Texture refinement will follow after testing.
- Tracing and building meshes has a one-time cost per new crater. Geometry LOD, maximum crater count and draw distance are adjustable.
- Multiple overlapping craters have not yet been validated.
- Cosmetic network events are admin-controlled on servers; server history synchronizes the visual crater list for late joiners.
- Any reported crashes or stencil artifacts should be investigated with isolated ge_crater_test commands before enabling combined effects.

## Developer module layout

    lua/autorun/client/ge_crater.lua     — geometry, stencil, renderer, cleanup
    lua/autorun/client/ge_impact_fx.lua  — small optional dust accents
    lua/autorun/client/ge_fx_client.lua  — client event handler and local tests
    lua/autorun/server/ge_fx_server.lua  — cosmetic event distribution and sync
    lua/autorun/client/ge_volume.lua     — existing real 3D smoke and fire renderer

References:
- https://wiki.facepunch.com/gmod/render_stencils
- https://wiki.facepunch.com/gmod/mesh.Begin
- https://wiki.facepunch.com/gmod/render.SetStencilEnable
