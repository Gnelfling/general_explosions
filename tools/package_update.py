"""Build a preservation-first overlay; audio replacement requires explicit opt-in."""
import argparse
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def package(target: Path, include_audio: bool = False):
    files = [p for p in (ROOT/'lua').rglob('*.lua') if 'data' not in p.relative_to(ROOT).parts]
    files += list((ROOT/'docs').glob('*.md')) + [ROOT/'README.md', ROOT/'CHANGELOG.md', ROOT/'tools/verify_install.ps1']
    if include_audio:
        files += [ROOT/'sound/general_explosions/railgun'/name for name in
                  ('railgun_charge.wav', 'railgun_fire.wav', 'railgun_explosion.wav')]
    with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(files):
            archive.write(path, path.relative_to(ROOT).as_posix())
        archive.writestr('INSTALL.txt', 'Back up the installed addon first. Extract inside the existing general_explosions-main folder.\n'
                         'Generated manifest, VTF/VMT and VCS are deliberately omitted. Preserve them.\n'
                         + ('AUDIO OPT-IN: this package replaces the three standard cues. Back up custom WAVs first.\n' if include_audio else
                            'Custom WAVs are preserved: this package contains no audio.\n')
                         + 'Restart server and clients together (v1/v2 networking is incompatible). Read docs/REVIEW_FIXES.md.\n'
                         'No in-game validation is claimed. This is an update overlay, not a complete fresh volume installation.\n')
    with zipfile.ZipFile(target) as archive:
        assert archive.testzip() is None
        assert not any('/data/' in n or n.endswith(('.vtf', '.vmt', '.vcs')) for n in archive.namelist())


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('target', type=Path)
    parser.add_argument('--include-audio', action='store_true')
    args = parser.parse_args()
    package(args.target, args.include_audio)
