"""Export OpenVDB smoke/flame frames to uncompressed 3D VTF textures.

Run inside Blender's bundled Python (which ships 'openvdb' and numpy):
  blender --background --python tools/vdb_to_vtf.py -- --input FILE_0000.vdb --out DIR --first 100 --last 100 --resolution 128

Each VTF stores density in R, flames in G, B=0, A=255, with x-fastest
voxel order, then y, then z. Trilinear volume resampling occurs on CPU.

No V.A.C. asset or shader code is required.
"""
from __future__ import annotations

import argparse
import json
import math
import re
import struct
import sys
from pathlib import Path

import numpy as np

# Offsets match VTF 7.2's 80-byte header. The V.A.C. noise volume also uses
# VTF 7.2, RGBA8888, no mipmaps and 3D depth.
VTF_FLAGS = 0x2300  # NOMIP | NOLOD | EIGHTBITALPHA
TEXTURE_PREFIX = "general_explosions/ground_explosion"


def make_vtf_header(width: int, height: int, depth: int) -> bytes:
    """One-frame RGBA8888 volume, one mip, no low-resolution thumbnail."""
    if any(v < 1 or v > 32767 or (v & (v - 1)) for v in (width, height, depth)):
        raise ValueError("VTF dimensions must be positive powers of two (max 32767)")
    b = bytearray(80)
    b[0:4] = b"VTF\x00"
    struct.pack_into("<II", b, 4, 7, 2)
    struct.pack_into("<I", b, 12, 80)
    struct.pack_into("<HH", b, 16, width, height)
    struct.pack_into("<I", b, 20, VTF_FLAGS)
    struct.pack_into("<HH", b, 24, 1, 0)  # frames, first frame
    struct.pack_into("<fff", b, 32, 0.0, 0.0, 0.0)
    struct.pack_into("<f", b, 48, 1.0)  # bumpmap scale
    struct.pack_into("<I", b, 52, 0)    # IMAGE_FORMAT_RGBA8888
    b[56] = 1                         # mip count
    struct.pack_into("<I", b, 57, 0xFFFFFFFF)  # no low-res thumbnail
    struct.pack_into("<H", b, 63, depth)
    return bytes(b)


def write_volume_vtf(path: Path, voxels_zyx_rgba: np.ndarray) -> None:
    if voxels_zyx_rgba.ndim != 4 or voxels_zyx_rgba.shape[3] != 4:
        raise ValueError("Expected (depth,height,width,4) RGBA volume")
    if voxels_zyx_rgba.dtype != np.uint8:
        raise ValueError("VTF pixels must be uint8")
    depth, height, width, _ = voxels_zyx_rgba.shape
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as out:
        out.write(make_vtf_header(width, height, depth))
        out.write(voxels_zyx_rgba.tobytes(order="C"))


def interp_axis(values: np.ndarray, coords: np.ndarray, origin: int, axis: int) -> np.ndarray:
    """Vectorised linear resampling of one xyz axis, including zero-padding."""
    local = np.clip(coords - origin, 0.0, values.shape[axis] - 1.0)
    i0 = np.floor(local).astype(np.intp)
    i1 = np.minimum(i0 + 1, values.shape[axis] - 1)
    alpha = local - i0
    shape = [1, 1, 1]
    shape[axis] = coords.size
    w = alpha.reshape(shape).astype(np.float32)
    return np.take(values, i0, axis=axis) * (1.0 - w) + np.take(values, i1, axis=axis) * w


def sample_grid(grid, bbox_min: tuple[int, int, int], bbox_max: tuple[int, int, int],
                resolution: int) -> np.ndarray:
    """Copy a padded index-space VDB block and trilinearly resample to xyz."""
    # Caller uses identical bounding boxes for density and flames.
    shape = tuple(bbox_max[i] - bbox_min[i] + 1 for i in range(3))
    if grid is None or grid.activeVoxelCount() == 0:
        return np.zeros((resolution,) * 3, dtype=np.float32)
    dense = np.zeros(shape, dtype=np.float32)
    grid.copyToArray(dense, ijk=tuple(bbox_min))
    sampled = dense
    for axis in range(3):
        coords = np.linspace(bbox_min[axis], bbox_max[axis], resolution, dtype=np.float32)
        sampled = interp_axis(sampled, coords, bbox_min[axis], axis)
    return np.maximum(sampled, 0.0)


def series_path(template: Path, frame: int) -> Path:
    match = re.fullmatch(r"(.*?)(\d+)(\.vdb)", template.name, re.IGNORECASE)
    if match is None:
        raise ValueError("--input filename must end in a number, such as ground_explosion_0000.vdb")
    prefix, digits, suffix = match.groups()
    return template.with_name(f"{prefix}{frame:0{len(digits)}d}{suffix}")


def active_bounds(grids: dict) -> tuple[tuple[int, int, int], tuple[int, int, int]] | None:
    boxes = [g.evalActiveVoxelBoundingBox() for g in grids.values()
             if g is not None and g.activeVoxelCount() > 0]
    if not boxes:
        return None
    # Two inactive-voxel layers avoid edge replication from the resampler.
    mn = tuple(min(b[0][i] for b in boxes) - 2 for i in range(3))
    mx = tuple(max(b[1][i] for b in boxes) + 2 for i in range(3))
    return mn, mx


def quantize(field: np.ndarray) -> tuple[np.ndarray, float]:
    peak = float(field.max())
    if peak <= 0:
        return np.zeros(field.shape, dtype=np.uint8), 0.0
    q = np.rint(np.clip(field / peak, 0.0, 1.0) * 255.0).astype(np.uint8)
    return q, peak


def export_frame(vdb, path: Path, target: Path, frame: int, resolution: int) -> dict:
    read_result = vdb.readAll(str(path))
    grids = {g.name: g for g in read_result[0]}
    density, flames = grids.get("density"), grids.get("flames")
    bounds = active_bounds({"density": density, "flames": flames})
    if bounds is None:
        print(f"[GE] Frame {frame}: empty density and flames, timing retained")
        return {"frame": frame, "empty": True}
    mn, mx = bounds
    # Index-space sampling currently assumes that smoke and flames share a
    # matching transform; fail explicitly if the voxel spacing differs.
    if density is not None and flames is not None:
        if tuple(density.transform.voxelSize()) != tuple(flames.transform.voxelSize()):
            raise ValueError("density and flames voxel spacings differ")
    voxels = np.zeros((resolution, resolution, resolution, 4), dtype=np.uint8)
    scales = {}
    for channel, name, grid in ((0, "density", density), (1, "flames", flames)):
        field = sample_grid(grid, mn, mx, resolution)
        packed, scale = quantize(field)
        # OpenVDB arrays are x,y,z. VTF slices are z,y,x.
        voxels[:, :, :, channel] = packed.transpose(2, 1, 0)
        scales[name] = scale
        del field, packed
    voxels[:, :, :, 3] = 255
    stem = f"frame_{frame:04d}"
    out = target / "materials" / TEXTURE_PREFIX
    write_volume_vtf(out / f"{stem}.vtf", voxels)
    # Standard material allows Material(name):GetTexture("$basetexture")
    # from GLua, so the custom shader can change frames via SetTexture.
    (out / f"{stem}.vmt").write_text(
        '"UnlitGeneric"\n{\n  "$basetexture" "' + TEXTURE_PREFIX + '/' + stem +
        '"\n  "$translucent" "1"\n}\n', encoding="utf-8")
    meta = {
        "frame": frame, "texture": TEXTURE_PREFIX + "/" + stem,
        "bounds_min": list(mn), "bounds_max": list(mx),
        "resolution": [resolution] * 3,
        "voxel_size": list((density or flames).transform.voxelSize()),
        "density_scale": scales["density"], "flames_scale": scales["flames"],
    }
    print(f"[GE] Frame {frame}: {resolution}^3 -> {stem}.vtf "
          f"(density max={scales['density']:.4f}, flames max={scales['flames']:.4f})")
    return meta


def lua_manifest(frames: list[dict], fps: float, anchor: tuple[float, float, float],
                 first_frame: int | None = None, last_frame: int | None = None) -> str:
    """Emit a Lua table, no runtime JSON parser or network traffic required."""
    lines = ["-- Generated by tools/vdb_to_vtf.py. Do not edit.", "return {",
             f"    fps = {fps:g},",
             "    anchor = {" + ", ".join(f"{v:.8g}" for v in anchor) + "},"]
    if first_frame is not None and last_frame is not None:
        lines.extend([f"    first_frame = {first_frame},", f"    last_frame = {last_frame},"])
    lines.append("    frames = {")
    for f in frames:
        if f.get("empty"):
            lines.append(f'        {{frame={f["frame"]}, empty=true}},')
            continue
        fmt = lambda seq: "{" + ", ".join(str(v) for v in seq) + "}"
        lines.append(
            f'        {{frame={f["frame"]}, texture="{f["texture"]}", '
            f'min={fmt(f["bounds_min"])}, max={fmt(f["bounds_max"])}, '
            f'density_scale={f["density_scale"]:.9g}, '
            f'flames_scale={f["flames_scale"]:.9g}}},')
    lines.extend(["    }", "}", ""])
    return "\n".join(lines)


def main() -> int:
    args_in = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    p = argparse.ArgumentParser(description="Blender/OpenVDB -> GMod 3D RGBA8 VTF")
    p.add_argument("--input", required=True, type=Path, help="First/any numbered .vdb in sequence")
    p.add_argument("--out", required=True, type=Path, help="GMod addon root to generate into")
    p.add_argument("--first", type=int, default=100)
    p.add_argument("--last", type=int, default=100)
    p.add_argument("--step", type=int, default=1)
    p.add_argument("--fps", type=float, default=24.0)
    p.add_argument("--resolution", type=int, default=128, choices=(32, 64, 128, 256))
    args = p.parse_args(args_in)
    if args.first < 0 or args.last < args.first or args.step < 1 or not math.isfinite(args.fps) or args.fps <= 0:
        p.error("Use nonnegative first <= last, step >= 1, fps > 0")
    try:
        import openvdb
    except ImportError as exc:
        raise SystemExit("Run inside Blender Python, which includes 'openvdb'") from exc
    target = args.out.resolve()

    # The cloud must remain in the same world-space position as it grows.
    # Derive a stable XY origin and ground level from the first VDB frame,
    # even when we are exporting only a later frame.
    anchor_file = series_path(args.input, 0)
    if not anchor_file.is_file():
        anchor_file = series_path(args.input, args.first)
    anchor_grids = {g.name: g for g in openvdb.readAll(str(anchor_file))[0]}
    anchor_bounds = active_bounds(anchor_grids)
    if anchor_bounds is None:
        raise ValueError("The anchor VDB frame is empty")
    a_min, a_max = anchor_bounds
    anchor = ((a_min[0] + a_max[0]) * 0.5,
              (a_min[1] + a_max[1]) * 0.5, float(a_min[2] + 2))
    frames = []
    for frame in range(args.first, args.last + 1, args.step):
        path = series_path(args.input, frame)
        if not path.is_file():
            raise FileNotFoundError(f"Missing VDB frame: {path}")
        meta = export_frame(openvdb, path, target, frame, args.resolution)
        frames.append(meta)
    manifest = {
        "schema": 1, "source": args.input.name, "fps": args.fps,
        "format": "VTF7.2_RGBA8888_3D", "channels": "R=density,G=flames",
        "coordinate_space": "VDB index coordinates (z-up expected by renderer)",
        "anchor": list(anchor), "frames": frames, "first_frame": args.first, "last_frame": args.last
    }
    out_json = target / "docs" / "generated"
    out_json.mkdir(parents=True, exist_ok=True)
    (out_json / "ground_explosion.json").write_text(
        json.dumps(manifest, indent=2), encoding="utf-8")
    out_lua = target / "lua" / "general_explosions" / "data"
    out_lua.mkdir(parents=True, exist_ok=True)
    (out_lua / "ground_explosion.lua").write_text(
        lua_manifest(frames, args.fps, anchor, args.first, args.last), encoding="utf-8")
    print(f"[GE] Exported {len(frames)} frames to {target}")
    print("[GE] Generated volume VTFs, VMTs, Lua manifest and JSON metadata")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
