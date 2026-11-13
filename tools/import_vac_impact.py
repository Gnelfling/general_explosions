"""Extract only the user-supplied impact resources into a new local addon pack.

Does not modify the source, existing addon, GE shaders, or OpenVDB manifest.
External assets are not committed to this repository or included by package_update.
"""
import argparse
from pathlib import Path
import shutil
import zipfile

FILES = ('shaders/fxc/vac_impactvol_ps30.vcs', 'shaders/fxc/vac_nukevol_vs30.vcs',
         'materials/vac/fx/impactvol/fields.vtf', 'materials/vac/fx/impactvol/coords.vtf',
         'materials/vac/fx/impactvol/light.vtf', 'materials/vac/fx/nukevol/noise.vtf')
DATA = 'lua/general_explosions/data/vac_impact.lua'


def extract(source: Path, target: Path):
    source, target = source.resolve(), target.resolve()
    if source == target or source in target.parents or target in source.parents:
        raise ValueError('Choose a separate new destination outside the source pack')
    metadata = source/'lua/vac/fx/cl_impact_vol_data.lua'
    for name in FILES:
        if not (source/name).is_file(): raise FileNotFoundError(source/name)
    text = metadata.read_text(encoding='utf-8')
    marker = 'VAC.FX.ImpactVolData = '
    if text.count(marker) != 1: raise ValueError('Unexpected metadata format')
    table = text.split(marker, 1)[1].strip()
    if not table.startswith('{') or not table.endswith('}'): raise ValueError('Unexpected metadata table')
    # Refuse any existing destination: never overlay installed textures/audio/data.
    if target.exists(): raise FileExistsError(target)
    target.mkdir(parents=True)
    for name in FILES:
        dest = target/name; dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source/name, dest)
    dest = target/DATA; dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text('-- Metadata from user-supplied VAC impact pack.\nreturn '+table+'\n', encoding='utf-8')
    return [*FILES, DATA]


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('target', type=Path)
    parser.add_argument('--zip', type=Path)
    args = parser.parse_args()
    if args.zip and args.zip.exists(): raise FileExistsError(args.zip)
    files = extract(args.source, args.target)
    if args.zip:
        with zipfile.ZipFile(args.zip, 'w', zipfile.ZIP_DEFLATED) as archive:
            for name in files: archive.write(args.target/name, name)
    print(f'Prepared {len(files)} optional resources; source and installed addon untouched.')
