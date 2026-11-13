"""Bake a turbulent hemispherical condensation shell for the nuke renderer."""
from pathlib import Path

import numpy as np

from bake_nuke import smooth
from vdb_to_vtf import write_volume_vtf


def main():
    root = Path(__file__).resolve().parents[1]
    texture = 'general_explosions/nuke/condensation'
    target = root / 'materials' / texture
    z, y, x = np.meshgrid(np.linspace(0, 88, 64), np.linspace(-112, 112, 64),
                          np.linspace(-112, 112, 64), indexing='ij', sparse=True)
    distance = np.sqrt((x / 94)**2 + (y / 94)**2 + (z / 72)**2)
    turbulence = (np.sin(x * .14 + z * .16) * np.cos(y * .13)
                  + .38 * np.sin(y * .32 - z * .27) * np.cos(x * .31)
                  + .16 * np.sin(x * .51 + y * .38 - z * .61))
    shell = smooth(1 - abs(distance - 1 + turbulence * .055) / .13)
    shell *= smooth(z / 6) * (.65 + .35 * smooth(turbulence + .4))
    voxels = np.zeros((64, 64, 64, 4), dtype=np.uint8)
    voxels[..., 0] = np.rint(shell * 255).astype(np.uint8)
    voxels[..., 3] = 255
    write_volume_vtf(target.with_suffix('.vtf'), voxels)
    target.with_suffix('.vmt').write_text(
        f'"UnlitGeneric"\n{{\n  "$basetexture" "{texture}"\n  "$translucent" "1"\n}}\n', encoding='utf-8')


if __name__ == '__main__':
    main()
