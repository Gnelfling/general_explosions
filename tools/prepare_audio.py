"""Prepare existing PCM WAV cues for Source positional playback, without trimming.

Usage: python tools/prepare_audio.py source.wav destination.wav
Keeps frame count and sample rate. Mixes channels equally, converts 24/16-bit
PCM to 16-bit mono. This is an offline asset tool, not an addon dependency.
"""
import argparse
from pathlib import Path
import wave

import numpy as np


def prepare(source: Path, target: Path) -> None:
    with wave.open(str(source), "rb") as audio:
        channels, width, rate, frames, compression, _ = audio.getparams()
        if compression != "NONE" or width not in (2, 3):
            raise ValueError("Expected 16- or 24-bit uncompressed PCM WAV")
        raw = audio.readframes(frames)
    if width == 2:
        samples = np.frombuffer(raw, dtype="<i2").astype(np.float64)
    else:
        data = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3).astype(np.int32)
        samples = data[:, 0] | (data[:, 1] << 8) | (data[:, 2] << 16)
        samples = ((samples ^ 0x800000) - 0x800000).astype(np.float64) / 256
    mono = np.clip(np.rint(samples.reshape(-1, channels).mean(axis=1)), -32768, 32767)
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_suffix(".tmp.wav")
    with wave.open(str(temporary), "wb") as audio:
        audio.setparams((1, 2, rate, frames, "NONE", "not compressed"))
        audio.writeframes(mono.astype("<i2").tobytes())
    temporary.replace(target)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("target", type=Path)
    args = parser.parse_args()
    prepare(args.source, args.target)
