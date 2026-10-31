# Reference inspection: V.A.C. volumetric visuals

These notes describe the files provided for inspection. They do not ship or reproduce V.A.C.'s source, textures, or compiled shader files.

## Observed layout

The supplied addon's client script cl_nuke_vol.lua references:
- vac_nukevol_ps30 and vac_nukevol_vs30, compiled Source .vcs files.
- fields.vtf, coords.vtf, light.vtf, and noise.vtf.
- baked simulation frame timing and profile data.
- a hull around a simulated cloud, rendering the faces toward the viewer.
- an alternative renderer / preview path for missing shader support.

The supplied noise.vtf header identifies a 128 x 128 x 128 VTF 7.2 RGBA8888 3D texture with flags 0x2300. The other three VTF files are 2D maps carrying baked data, and their exact encodings are specific to V.A.C.

The script mentions developer scripts for simulation, texture baking, and HLSL shader source. Those originals were not in the inspected addon packages. The binaries alone do not give us a drop-in generic OpenVDB decoder.

## Architectural difference

V.A.C. primarily encodes an axisymmetric smoke simulation reconstructed around a central axis. GroundExplosionVDB is a true three-dimensional grid sequence, including two distinct scalar fields. Our approach retains both 3D fields in an independently generated real 3D VTF. This is conceptually related GPU volumetric rendering, not a byte-compatible adaptation.

## Cautions

- DO NOT copy V.A.C. textures, .vcs binaries or gameplay scripts into this project without the relevant rights.
- This repo uses new shader names and a new texture/parameter contract.
- An in-game result matching V.A.C.'s visual polish is not established by reading its file headers.
- The original shader's exact sampling logic and shaders' compilation parameters were not available.
