"""Bake an original procedural mushroom cloud into the existing GE VTF format."""
from pathlib import Path

import numpy as np

from vdb_to_vtf import lua_manifest, quantize, write_volume_vtf


FPS = 12
FRAMES = 120
WIDTH = 128
DEPTH = 64
PREFIX = 'general_explosions/nuke'


def smooth(value):
    value = np.clip(value, 0, 1)
    return value * value * (3 - 2 * value)


def bake_frame(t):
    # Distances are expressed in the same volume units as the original effect.
    growth = 1 - np.exp(-t * 0.42)
    radius = 14 + 57 * growth
    height = 9 + 117 * growth
    extent = int(np.ceil(48 + 111 * growth))
    ball_size = 9 + 35 * (1 - np.exp(-t * 3))
    top = int(np.ceil(max(height + radius * 0.75, ball_size * 1.65) + 8))
    low = [-extent, -extent, 0]
    high = [extent, extent, top]
    z, y, x = np.meshgrid(*(np.linspace(low[i], high[i], size, dtype=np.float32)
                           for i, size in ((2, DEPTH), (1, WIDTH), (0, WIDTH))),
                         indexing='ij', sparse=True)
    edge = smooth((extent - np.maximum(np.abs(x), np.abs(y))) / 12)
    # Wind shear and coherent eddies move with the cloud over successive frames.
    x = x - t * 1.2 * smooth(z / height)
    warp = (np.sin(x * .12 + z * .14 - t * 1.4) * np.cos(y * .15 - z * .07)
            + .45 * np.sin(y * .28 + z * .21 + t) * np.cos(x * .24 - z * .12)
            + .24 * np.sin(x * .49 + y * .36 - z * .4 - t * 2.1)
            + .16 * np.sin(x * .78 - z * .67 + t * 1.8) * np.cos(y * .71 + z * .37)
            + .09 * np.sin(y * 1.13 + z * .93 - t * 2.8) * np.cos(x * 1.02 - z * .45))
    r = np.hypot(x, y)
    radial = (r - radius * .49) / (radius * .63)
    # Lift the outer rim while billows curl back toward the underside.
    cap_center = height + radius * (.17 * smooth(r / radius) - .11)
    vertical = (z - cap_center) / (radius * .49)
    roll = np.sin(np.arctan2(vertical, radial) * 3 - t * 1.7 + warp) * .13
    cap = smooth((1 - np.hypot(radial, vertical) + warp * .32 + roll) * 1.65)
    stem_width = (7 + radius * .32) * (1 - .45 * smooth(z / height))
    stem = smooth((1 - r / stem_width + warp * .39) * 2) * smooth((height + 5 - z) / 20)
    skirt = smooth((1 - np.hypot((r - radius * .34) / (radius * .46),
                                 (z - height * .48) / (radius * .14)) + warp * .21) * 2)
    dust = smooth((1 - np.hypot((r - extent * .63) / (extent * .30),
                                (z - 4) / (6 + radius * .12)) + warp * .26) * 2)
    ball = smooth((1 - np.hypot(r, (z - ball_size * .66) * 1.1) / ball_size + warp * .12) * 1.8)
    rise = smooth(t / 1.65)
    envelope = smooth(z / 5) * smooth((top - z) / 8) * edge * (1 - smooth((t - 6) / 4))
    smoke = np.maximum.reduce([cap * .41, stem * .32, skirt * .16]) * rise
    smoke = (smoke + dust * .20 * smooth(t / .8) * np.exp(-t * .19)
             + ball * .26 * (1 - rise)) * envelope
    hot_billows = .55 + .45 * smooth(warp + .2)
    flame = (ball * 13 * np.exp(-t * 1.9)
             + cap**2 * hot_billows * 8 * rise * np.exp(-t * .82)) * envelope
    return low, high, smoke, flame


def main():
    root = Path(__file__).resolve().parents[1]
    folder = root / 'materials' / PREFIX
    frames = []
    for index in range(FRAMES):
        low, high, density, flame = bake_frame((index + 0.5) / FPS)
        voxels = np.zeros((DEPTH, WIDTH, WIDTH, 4), dtype=np.uint8)
        voxels[..., 0], density_scale = quantize(density)
        voxels[..., 1], flames_scale = quantize(flame)
        voxels[..., 3] = 255
        name = f'frame_{index:04d}'
        write_volume_vtf(folder / f'{name}.vtf', voxels)
        texture = f'{PREFIX}/{name}'
        (folder / f'{name}.vmt').write_text(
            f'"UnlitGeneric"\n{{\n  "$basetexture" "{texture}"\n  "$translucent" "1"\n}}\n', encoding='utf-8')
        frames.append(dict(frame=index, texture=texture, bounds_min=low, bounds_max=high,
                           density_scale=density_scale, flames_scale=flames_scale))
    manifest = lua_manifest(frames, FPS, (0, 0, 0), 0, FRAMES - 1)
    manifest = manifest.replace('tools/vdb_to_vtf.py', 'tools/bake_nuke.py', 1)
    (root / 'lua/general_explosions/data/nuke.lua').write_text(manifest, encoding='utf-8')


if __name__ == '__main__':
    main()
