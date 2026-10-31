# Original cue sources

These three files are byte-for-byte originals from main commit `4af0b7c`,
before mono/16-bit normalization. They are outside sound/ and are never loaded
or included in update overlays. They preserve the original stereo/24-bit data.
The normalized runtime cues retain all samples and sample rate; no trimming.

Cue starts stay 0.0 / 3.0 / 3.2 seconds. Actual lengths are approximately
3.135 / 5.085 / 13.377 seconds, **not** 3 / 1 / 5 seconds. Tails play to completion
and overlap. If short phase lengths are wanted, create separately named variants
from these originals and review them with the owner before changing playback.
No short-tail interpretation is silently imposed by this update.
