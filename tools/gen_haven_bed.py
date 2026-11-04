#!/usr/bin/env python3
"""Synthesise audio/music/haven_bed.wav — Level 4's bed.

Singing bowls in a still room: a low drone that beats against itself, a bowl
struck every six seconds or so on a pentatonic scale, and a breath of air
over the top. No rhythm and no progression, because the Haven has no urgency.

Every oscillator's period divides the loop length exactly, and a bowl struck
near the end wraps its tail round to the front, so the loop is seamless —
the lesson from audio/music/grove_bed.wav, where an LFO that did not close
put an audible seam at the join.

Run from the repo root:  python3 tools/gen_haven_bed.py
"""
import math, struct, wave
import numpy as np

RATE = 22050
LOOP = 32.0                       # seconds
N = int(RATE * LOOP)
T = np.arange(N) / RATE
rng = np.random.default_rng(1104)

## A2 pentatonic — the scale the whole bed is built from.
ROOT = 110.0
SCALE = [1.0, 6 / 5, 4 / 3, 3 / 2, 9 / 5]      # minor pentatonic ratios
## A struck bowl is not harmonic: these are the ratios a real one rings at.
BOWL = [(1.0, 1.0), (2.75, 0.42), (5.38, 0.18), (8.93, 0.07), (13.3, 0.03)]


def cycles(hz):
    """Round a rate to a whole number of cycles per loop, so it closes."""
    return max(1, round(hz * LOOP)) / LOOP


def lfo(hz, depth, phase=0.0):
    return 1.0 - depth + depth * (0.5 + 0.5 * np.sin(
        2 * np.pi * cycles(hz) * T + phase))


def drone():
    """Four sustained partials, each paired with a copy a fraction of a hertz
    away. The pair drifts in and out of phase over tens of seconds, which is
    the slow swell you hear rather than any envelope."""
    out = np.zeros(N)
    # Weighted up the scale on purpose. A stack led by its fundamental puts
    # most of the energy under 120 Hz, which is felt rather than heard and
    # leaves the bed muddy — the mistake audio/music/grove_bed.wav had to be
    # rebuilt to fix. The low partials are here to be a floor, not the tune.
    for ratio, gain, beat, swell in [
            (1.0, 0.17, 0.18, 1 / 16), (1.5, 0.15, 0.25, 1 / 11),
            (2.0, 0.19, 0.33, 1 / 13), (3.0, 0.17, 0.41, 1 / 9),
            (4.0, 0.12, 0.52, 1 / 7), (6.0, 0.07, 0.63, 1 / 5)]:
        f = cycles(ROOT * ratio)
        pair = (np.sin(2 * np.pi * f * T)
                + np.sin(2 * np.pi * cycles(ROOT * ratio + beat) * T))
        out += gain * 0.5 * pair * lfo(swell, 0.45, rng.uniform(0, 6.28))
    return out


def strike(buf, at, f, gain):
    """One bowl, struck. Partials decay at their own rates — the high ones
    first — and anything past the end of the loop wraps to the front."""
    dur = min(11.0, LOOP)
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    tone = np.zeros(n)
    for ratio, amp in BOWL:
        decay = np.exp(-t * (0.26 + 0.5 * math.log1p(ratio)))
        # A touch of wobble per partial: a bowl is never quite steady.
        wob = 1.0 + 0.0016 * np.sin(2 * np.pi * rng.uniform(3.0, 6.5) * t)
        tone += amp * decay * np.sin(2 * np.pi * f * ratio * wob * t)
    # Soften the attack so it blooms rather than clicks.
    tone *= 1.0 - np.exp(-t * 90.0)
    i = int(at * RATE)
    for k in range(n):
        buf[(i + k) % N] += gain * tone[k]


def bowls():
    out = np.zeros(N)
    at = 1.4
    while at < LOOP:
        octave = rng.choice([1.0, 2.0, 2.0, 4.0], p=[0.2, 0.4, 0.25, 0.15])
        f = ROOT * rng.choice(SCALE) * octave
        strike(out, at, f, rng.uniform(0.26, 0.40) / math.sqrt(octave))
        at += rng.uniform(4.0, 6.5)
    return out


def air():
    """Noise rolled off at both ends — the room the bowls are in, not wind."""
    n = rng.standard_normal(N)
    spec = np.fft.rfft(n)
    hz = np.fft.rfftfreq(N, 1 / RATE)
    band = np.exp(-((np.log2(np.maximum(hz, 1e-6) / 3000.0)) ** 2) / 1.9)
    band[hz < 400] = 0.0
    out = np.fft.irfft(spec * band, N)
    out /= np.max(np.abs(out)) + 1e-9
    return out * 0.10 * lfo(1 / 19, 0.7)


def shimmer():
    """Two very quiet partials two octaves up, tremoloed against each other.
    This is what makes the bed read as 'ethereal' rather than merely low."""
    out = np.zeros(N)
    for ratio, rate, gain in [(8.0, 1 / 7, 0.085), (12.0, 1 / 5, 0.062),
                              (16.0, 1 / 6, 0.040), (24.0, 1 / 4, 0.022)]:
        out += gain * np.sin(2 * np.pi * cycles(ROOT * ratio) * T) * lfo(rate, 0.9)
    return out


def reverb(dry, seconds=2.6, wet=0.42):
    """Convolution with a decaying noise burst. Not a real room model, but at
    this length and this wet level it is only doing what a room does: blurring
    the strikes into each other so nothing has a hard edge."""
    n = int(seconds * RATE)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / RATE * 2.3)
    ir[: int(0.012 * RATE)] = 0.0                  # a little pre-delay
    ir /= np.sqrt(np.sum(ir ** 2))
    # Circular, at exactly the loop length: the tail that runs off the end
    # comes back in at the start, which is what the loop does anyway. Doing
    # it linearly and folding the overhang by hand leaves a step at the join
    # big enough to hear as a click once every 32 seconds.
    out = np.fft.irfft(np.fft.rfft(dry, N) * np.fft.rfft(ir, N), N)
    return dry + wet * out


def main():
    mix = drone() + bowls() + shimmer()
    mix = reverb(mix)
    mix += air()
    mix -= np.mean(mix)                       # the convolution leaves a little DC
    mix /= np.max(np.abs(mix)) / 0.86
    data = (np.clip(mix, -1.0, 1.0) * 32767).astype("<i2")
    with wave.open("audio/music/haven_bed.wav", "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    # Every part of this is either an integer-cycle oscillator, a circular
    # convolution or a strike that wraps, so the join should be no bigger a
    # step than any other pair of neighbouring samples. Measured as a ratio
    # against the typical step, because |mix[0] - mix[-1]| on its own says
    # nothing: neighbouring samples of any signal differ.
    step = np.mean(np.abs(np.diff(mix)))
    seam = abs(mix[0] - mix[-1]) / step
    print(f"haven_bed.wav  {LOOP:.0f}s  peak {np.max(np.abs(mix)):.2f}  "
          f"rms {np.sqrt(np.mean(mix ** 2)):.3f}  "
          f"seam {seam:.1f}x the average sample step")
    # Where the energy sits, measured rather than assumed: the grove bed's
    # first pass was 95% sub-120Hz rumble and had to be rebuilt.
    spec = np.abs(np.fft.rfft(mix))
    hz = np.fft.rfftfreq(N, 1 / RATE)
    tot = np.sum(spec ** 2)
    for lo, hi in [(0, 120), (120, 500), (500, 2000), (2000, 6000), (6000, 11025)]:
        band = np.sum(spec[(hz >= lo) & (hz < hi)] ** 2)
        print(f"   {lo:>5}-{hi:<5} Hz {100 * band / tot:5.1f}%")


main()
