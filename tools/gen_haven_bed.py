#!/usr/bin/env python3
"""Synthesise audio/music/haven_bed.wav — Level 4's bed.

Still air in a warm room: a drone that swells so slowly you do not hear it
move, a bowl struck now and then, and a wash of air over the top. No rhythm
and no progression, because the Haven has no urgency.

This is the second pass. The first one was built like a temple bell — minor
pentatonic, a bowl ringing at its real inharmonic ratios, half-hertz beating
and a bright tremoloed shimmer — and came out mysterious and faintly tense,
which is the wrong feeling for the end of the story. Everything that carried
that reading was named and softened; see each part for which.

Every oscillator's period divides the loop length exactly, and a bowl struck
near the end wraps its tail round to the front, so the loop is seamless —
the lesson from audio/music/grove_bed.wav, where an LFO that did not close
put an audible seam at the join.

Run from the repo root:  python3 tools/gen_haven_bed.py
"""
import math, wave
import numpy as np

RATE = 22050
LOOP = 48.0                       # seconds
N = int(RATE * LOOP)
T = np.arange(N) / RATE
rng = np.random.default_rng(1104)

## A2, and a scale with no minor interval in it. The first pass used a minor
## pentatonic (6/5, 9/5) — a minor third is the single strongest cue for
## "mysterious", and it was doing most of the work. These are the major
## pentatonic degrees with the fourth in place of the sixth: open, consonant,
## and neither bright nor sad, which is what calm sounds like.
ROOT = 110.0
SCALE = [1.0, 9 / 8, 4 / 3, 3 / 2, 5 / 3]
## A struck bowl is not harmonic, and the first pass used the ratios a real
## one rings at (2.75, 5.38, 8.93...). Those clashing partials are what makes
## a singing bowl sound ritual rather than restful. Here the loud partials are
## harmonic and only the quiet ones are detuned, so it still reads as struck
## metal rather than an organ pipe, without the clang.
BOWL = [(1.0, 1.0), (2.0, 0.30), (3.0, 0.12), (4.04, 0.055), (5.47, 0.022)]


def cycles(hz):
    """Round a rate to a whole number of cycles per loop, so it closes."""
    return max(1, round(hz * LOOP)) / LOOP


def lfo(hz, depth, phase=0.0):
    return 1.0 - depth + depth * (0.5 + 0.5 * np.sin(
        2 * np.pi * cycles(hz) * T + phase))


def drone():
    """Sustained partials, each paired with a copy a fraction of a hertz away.
    The pair drifts in and out of phase over tens of seconds, which is the
    slow swell you hear rather than any envelope."""
    out = np.zeros(N)
    # Weighted up the scale on purpose. A stack led by its fundamental puts
    # most of the energy under 120 Hz, which is felt rather than heard and
    # leaves the bed muddy — the mistake audio/music/grove_bed.wav had to be
    # rebuilt to fix. The low partials are here to be a floor, not the tune.
    #
    # `beat` is the detune within each pair, and it is the other half of what
    # made the first pass restless: at 0.3-0.6 Hz you hear the pair throb.
    # Under about 0.2 Hz the same mechanism becomes a swell with no edge to
    # count, which is the whole point of the technique.
    for ratio, gain, beat, swell in [
            (1.0, 0.16, 0.07, 1 / 24), (1.5, 0.15, 0.09, 1 / 19),
            (2.0, 0.19, 0.11, 1 / 21), (3.0, 0.16, 0.13, 1 / 16),
            (4.0, 0.11, 0.15, 1 / 13), (6.0, 0.06, 0.17, 1 / 11)]:
        f = cycles(ROOT * ratio)
        pair = (np.sin(2 * np.pi * f * T)
                + np.sin(2 * np.pi * cycles(ROOT * ratio + beat) * T))
        # Depth 0.3 rather than 0.45: the drone should never thin out enough
        # for its coming back to read as an event.
        out += gain * 0.5 * pair * lfo(swell, 0.30, rng.uniform(0, 6.28))
    return out


def strike(buf, at, f, gain):
    """One bowl, struck. Partials decay at their own rates — the high ones
    first — and anything past the end of the loop wraps to the front."""
    dur = min(14.0, LOOP)
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    tone = np.zeros(n)
    for ratio, amp in BOWL:
        # Slower overall decay than the first pass, so each bowl is still
        # fading when the next arrives and the bed never falls to bare drone.
        decay = np.exp(-t * (0.17 + 0.42 * math.log1p(ratio)))
        # A touch of wobble per partial: a bowl is never quite steady.
        wob = 1.0 + 0.0014 * np.sin(2 * np.pi * rng.uniform(3.0, 6.5) * t)
        tone += amp * decay * np.sin(2 * np.pi * f * ratio * wob * t)
    # A quarter-second bloom rather than the first pass's near-instant one.
    # The transient was the third thing reading as tense: a bowl that arrives
    # already loud is a signal, one that swells in is just the room changing.
    tone *= 1.0 - np.exp(-t * 12.0)
    i = int(at * RATE)
    for k in range(n):
        buf[(i + k) % N] += gain * tone[k]


def bowls():
    out = np.zeros(N)
    at = 2.2
    while at < LOOP:
        # Mostly the middle of the register. The first pass reached two
        # octaves up often enough to keep catching the ear.
        octave = rng.choice([1.0, 2.0, 2.0, 4.0], p=[0.26, 0.42, 0.26, 0.06])
        f = ROOT * rng.choice(SCALE) * octave
        strike(out, at, f, rng.uniform(0.17, 0.25) / math.sqrt(octave))
        # Twice the spacing of the first pass. Long gaps are the point: a
        # bowl every five seconds is a pulse, one every ten is punctuation.
        at += rng.uniform(8.0, 13.0)
    return out


def air():
    """Noise rolled off at both ends — the room the bowls are in, not wind.
    It is the only thing in the bed above 2 kHz, and it has to be: measured
    without it, everything over 2 kHz came to 0.1% of the mix, which is not
    calm but muffled. Broadband noise at this level is heard as the room
    being open rather than as brightness, which tremoloed sine partials up
    there are not — see shimmer()."""
    n = rng.standard_normal(N)
    spec = np.fft.rfft(n)
    hz = np.fft.rfftfreq(N, 1 / RATE)
    band = np.exp(-((np.log2(np.maximum(hz, 1e-6) / 2400.0)) ** 2) / 2.4)
    band[hz < 240] = 0.0
    out = np.fft.irfft(spec * band, N)
    out /= np.max(np.abs(out)) + 1e-9
    return out * 0.11 * lfo(1 / 24, 0.5)


def shimmer():
    """Quiet partials high over the drone, so the bed reads as open air rather
    than merely low. All of them are harmonics of the root and in the scale —
    the first pass used 12x, 16x and 24x at nine-tenths tremolo depth, which
    is a shiver, not a sheen. The same ratios are still here at the top of
    the stack, but at a twentieth of the gain and a third of the depth, which
    is a sheen."""
    out = np.zeros(N)
    for ratio, rate, gain, depth in [
            (6.0, 1 / 17, 0.055, 0.50), (8.0, 1 / 13, 0.042, 0.50),
            (9.0, 1 / 15, 0.028, 0.50), (12.0, 1 / 11, 0.018, 0.45),
            (16.0, 1 / 19, 0.013, 0.35), (20.0, 1 / 23, 0.009, 0.35),
            (24.0, 1 / 21, 0.006, 0.35)]:
        out += gain * np.sin(2 * np.pi * cycles(ROOT * ratio) * T) * lfo(rate, depth)
    return out


def reverb(dry, seconds=3.6, wet=0.52):
    """Convolution with a decaying noise burst. Not a real room model, but at
    this length and this wet level it is only doing what a room does: blurring
    the strikes into each other so nothing has a hard edge. Longer and wetter
    than the first pass — more wash means less definition, and less definition
    is most of what makes a bed recede into the background."""
    n = int(seconds * RATE)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / RATE * 1.7)
    ir[: int(0.014 * RATE)] = 0.0                  # a little pre-delay
    ir /= np.sqrt(np.sum(ir ** 2))
    # Circular, at exactly the loop length: the tail that runs off the end
    # comes back in at the start, which is what the loop does anyway. Doing
    # it linearly and folding the overhang by hand leaves a step at the join
    # big enough to hear as a click once every loop.
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
    # against its *immediate* neighbours, not the whole file's average step:
    # a bass-heavy bed has tiny typical steps, so a join that lands on a
    # fast-moving part of the wave reads as a fault when it is continuous.
    d = np.abs(np.diff(mix))
    near = np.mean(np.concatenate([d[:3], d[-3:]]))
    seam = abs(mix[0] - mix[-1]) / near
    print(f"haven_bed.wav  {LOOP:.0f}s  peak {np.max(np.abs(mix)):.2f}  "
          f"rms {np.sqrt(np.mean(mix ** 2)):.3f}  "
          f"seam {seam:.2f}x its neighbouring steps")
    # Where the energy sits, measured rather than assumed: the grove bed's
    # first pass was 95% sub-120Hz rumble and had to be rebuilt.
    spec = np.abs(np.fft.rfft(mix))
    hz = np.fft.rfftfreq(N, 1 / RATE)
    tot = np.sum(spec ** 2)
    for lo, hi in [(0, 120), (120, 500), (500, 2000), (2000, 6000), (6000, 11025)]:
        band = np.sum(spec[(hz >= lo) & (hz < hi)] ** 2)
        print(f"   {lo:>5}-{hi:<5} Hz {100 * band / tot:5.1f}%")
    # Crest factor stands in for how "eventful" the bed is: a bed whose peaks
    # tower over its body has things in it that jump out, which is the
    # opposite of what this one is for.
    print(f"   crest {np.max(np.abs(mix)) / np.sqrt(np.mean(mix ** 2)):.1f}x")


main()
