#!/usr/bin/env python3
"""Render three original, deterministic 12-bar game loops using only NumPy.

Run from any directory: python3 tools/gen_bgm.py
Notes and effect tails wrap around the sample-accurate musical timeline. WAVs
are mono PCM16 at 22050 Hz; the unavoidable fractional final sample is rounded.
"""

from pathlib import Path
import wave

import numpy as np


SR = 22050
BARS = 12
OUT = Path(__file__).resolve().parents[1] / "game/assets/audio/bgm"


def oscillator(freq, t, kind="square", duty=0.5):
    """Band-limited additive voices keep bright chip tones free of alias fizz."""
    phase = 2 * np.pi * freq * t
    if kind == "sine":
        return np.sin(phase)
    if kind == "bell":
        return (np.sin(phase) + 0.32 * np.sin(2 * phase) * np.exp(-6 * t)
                + 0.16 * np.sin(3 * phase) * np.exp(-12 * t)) / 1.48
    result = np.zeros_like(t)
    harmonics = min(45, int(0.45 * SR / freq))
    for k in range(1, harmonics + 1):
        if kind == "triangle":
            if k % 2:
                result += (-1) ** ((k - 1) // 2) * np.sin(k * phase) / k**2
        elif kind == "pulse":
            result += (2 * np.sin(np.pi * k * duty) / (np.pi * k)
                       * np.cos(k * phase - np.pi * k * duty))
        elif k % 2:
            result += 4 / np.pi * np.sin(k * phase) / k
    return result * (8 / np.pi**2 if kind == "triangle" else 0.8)


class Song:
    def __init__(self, bpm, seed):
        self.beat = 60 / bpm
        self.length = round(BARS * 4 * self.beat * SR)
        self.rng = np.random.default_rng(seed)
        self.layers = {name: np.zeros(self.length) for name in
                       ("lead", "arp", "bass", "pad", "drums")}

    def add(self, layer, beat, sound, gain):
        start = round(beat * self.beat * SR)
        indices = (start + np.arange(len(sound))) % self.length
        np.add.at(self.layers[layer], indices, gain * sound)

    def note(self, layer, beat, midi, duration, gain, kind="square", detune=0):
        seconds = duration * self.beat
        release = 0.045 if layer == "bass" else 0.075
        t = np.arange(round((seconds + release) * SR)) / SR
        freq = 440 * 2 ** ((midi - 69) / 12)
        sound = oscillator(freq, t, kind, 0.32)
        if detune:
            sound = (sound + oscillator(freq * 2 ** (detune / 1200), t,
                                        kind, 0.37)) * 0.5
        attack = 0.004 if layer != "pad" else 0.035
        env = np.sin(np.minimum(t / attack, 1) * np.pi / 2) ** 2
        env *= 0.72 + 0.28 * np.exp(-t * 9)
        env *= np.cos(np.clip((t - seconds) / release, 0, 1) * np.pi / 2) ** 2
        if kind == "bell":
            env *= np.exp(-3.5 * t)
        self.add(layer, beat, sound * env, gain)

    def drum(self, beat, kind, gain=1):
        duration = {"kick": 0.24, "snare": 0.18, "hat": 0.055,
                    "open": 0.19, "zap": 0.095}[kind]
        t = np.arange(round(duration * SR)) / SR
        noise = self.rng.standard_normal(len(t))
        bright = noise - np.convolve(noise, np.ones(5) / 5, mode="same")
        if kind == "kick":
            # Integrating the pitch sweep keeps oscillator phase continuous.
            phase = 2 * np.pi * (48 * t + 105 * 0.024 * (1 - np.exp(-t / 0.024)))
            sound = (np.sin(phase) * np.exp(-18 * t)
                     + 0.13 * bright * np.exp(-240 * t))
        elif kind == "snare":
            sound = (0.48 * bright * np.exp(-29 * t)
                     + 0.35 * np.sin(2 * np.pi * 185 * t) * np.exp(-32 * t))
        elif kind == "zap":
            sound = np.sin(2 * np.pi * (1600 * t - 6500 * t**2)) * np.exp(-55 * t)
        else:
            sound = 0.25 * bright * np.exp(-(65 if kind == "hat" else 24) * t)
        # Smooth both ends, including random noise transients.
        sound *= np.minimum(t / 0.0015, 1)
        sound *= np.minimum((duration - t) / 0.012, 1).clip(0, 1)
        self.add("drums", beat, sound, gain)

    def render(self, filename):
        lead, arp = self.layers["lead"], self.layers["arp"]
        # Circular delays are steady-state effects, including on the first bar.
        for delay, gain in ((0.75, 0.19), (1.5, 0.09)):
            lead = lead + gain * np.roll(self.layers["lead"], round(delay * self.beat * SR))
        arp = arp + 0.22 * np.roll(arp, round(0.75 * self.beat * SR))
        pad = self.layers["pad"]
        pad = pad + 0.3 * np.roll(pad, round(0.037 * SR))
        mix = lead + arp + pad + self.layers["bass"] + self.layers["drums"]
        mix -= np.mean(mix)
        mix = np.tanh(mix * 1.15)
        # A 2 ms raised-cosine splice makes the seam exactly zero with a flat
        # slope, without a musical fade-out or sacrificing wrapped effect tails.
        n = round(0.002 * SR)
        taper = np.sin(np.linspace(0, np.pi / 2, n)) ** 2
        mix[:n] *= taper
        mix[-n:] *= taper[::-1]
        mix *= 0.84 / np.max(np.abs(mix))
        pcm = np.rint(mix * 32767).astype("<i2")
        path = OUT / filename
        with wave.open(str(path), "wb") as wav:
            wav.setparams((1, 2, SR, 0, "NONE", "not compressed"))
            wav.writeframes(pcm.tobytes())
        verify(path, self.length)


def melody(song, bar, events, kind="square", gain=0.23):
    for offset, midi, length in events:
        song.note("lead", bar * 4 + offset, midi, length, gain, kind)


def overworld():
    song = Song(140, 140)
    # E major: a memorable pickup-and-answer hook, then a rising bridge.
    chords = [(40, (64, 68, 71)), (35, (63, 66, 71)),
              (37, (64, 68, 73)), (33, (64, 69, 73))] * 3
    hooks = [
        [(0, 76, .65), (.75, 80, .2), (1, 83, .4), (1.5, 80, .4),
         (2.25, 78, .2), (2.5, 76, .4), (3, 73, .4), (3.5, 76, .35)],
        [(0, 78, .65), (.75, 75, .2), (1, 71, .4), (1.5, 75, .4),
         (2, 78, .4), (2.5, 83, .4), (3.25, 81, .2), (3.5, 78, .35)],
        [(0, 80, .65), (.75, 83, .2), (1, 85, .65), (1.75, 83, .2),
         (2, 80, .4), (2.5, 76, .4), (3, 78, .4), (3.5, 80, .35)],
        [(0, 81, .4), (.5, 80, .4), (1, 76, .7), (2, 73, .4),
         (2.5, 76, .4), (3, 75, .2), (3.25, 78, .2), (3.5, 75, .35)],
    ]
    for bar, (root, chord) in enumerate(chords):
        base = bar * 4
        melody(song, bar, hooks[bar % 4])
        if 4 <= bar < 8:
            # Quiet octave answer gives the second phrase its own color.
            for off, pitch, length in hooks[bar % 4][-3:]:
                song.note("lead", base + off, pitch + 12, length, .045, "bell")
        for step in range(8):
            song.note("bass", base + step / 2, root + (12 if step % 4 == 3 else 0),
                      .39, .30, "triangle")
        for step in range(16):
            pitch = chord[(0, 1, 2, 1)[step % 4]] + (12 if bar >= 8 else 0)
            song.note("arp", base + step / 4, pitch, .13, .065, "pulse")
        for off in (0, 1.5, 2, 3.5):
            song.drum(base + off, "kick", .55)
        for off in (1, 3):
            song.drum(base + off, "snare", .48)
        for step in range(8):
            song.drum(base + step / 2, "hat", .55 if step % 2 else .35)
        if bar % 4 == 3:
            for off in (3.25, 3.75):
                song.drum(base + off, "snare", .21)
    song.render("overworld_paradigm.wav")


def ice_factory():
    song = Song(132, 132)
    # F# minor, Dmaj7, Aadd9, C# dominant: cold space with a tense turnaround.
    chords = [(30, (66, 69, 73, 80)), (26, (66, 69, 73, 78)),
              (33, (64, 69, 71, 76)), (25, (65, 68, 73, 77))] * 3
    contours = [(85, 80, 81, 78), (81, 78, 80, 73),
                (83, 80, 76, 80), (80, 77, 73, 77)]
    for bar, (root, chord) in enumerate(chords):
        base = bar * 4
        for step in range(16):
            pitch = chord[(0, 2, 1, 3, 2, 1, 0, 2)[step % 8]]
            song.note("arp", base + step / 4, pitch, .16,
                      .09 if step % 4 == 0 else .058, "pulse", 9)
        for off, length in ((0, 1.35), (1.5, .35), (2, 1.35), (3.5, .35)):
            song.note("bass", base + off, root, length, .34, "sine")
            song.note("bass", base + off, root + 12, length, .065, "triangle")
        for pitch in chord[:3]:
            song.note("pad", base, pitch - 12, 3.8, .035, "triangle", -6)
        notes = contours[bar % 4]
        melody(song, bar, [(.5, notes[0], .6), (1.5, notes[1], .35),
                           (2.25, notes[2], .55), (3.25, notes[3], .5)],
               "bell", .22 if bar >= 4 else .16)
        for off in (0, 2, 2.75):
            song.drum(base + off, "kick", .58)
        for off in (1, 3):
            song.drum(base + off, "snare", .34)
        for step in range(8):
            song.drum(base + step / 2, "open" if step == 7 else "hat", .35)
        if bar % 2:
            song.drum(base + 3.75, "zap", .09)
    song.render("ice_factory.wav")


def core_boss():
    song = Song(155, 155)
    roots = [33, 29, 26, 28] * 3
    riffs = [(81, 81, 84, 88, 84, 81, 79, 76),
             (81, 84, 89, 88, 84, 81, 77, 76),
             (81, 86, 89, 88, 86, 84, 81, 77),
             (80, 83, 88, 87, 88, 83, 80, 76)]
    for bar, root in enumerate(roots):
        base = bar * 4
        riff = riffs[bar % 4]
        for step in range(16):
            # Repeated hook, answering descent, and occasional glitch stutters.
            pitch = riff[step % 8] - (12 if 8 <= step < 12 else 0)
            song.note("lead", base + step / 4, pitch, .17, .18, "square")
            if bar in (3, 7, 11) and step in (13, 15):
                song.note("lead", base + step / 4 + .125, pitch + 12,
                          .055, .09, "pulse")
            song.note("bass", base + step / 4, root + (12 if step % 2 else 0),
                      .18, .21, "triangle")
        chord = (root + 36, root + (40 if bar % 4 == 3 else 39), root + 43)
        for step in range(8):
            song.note("arp", base + step / 2 + .125, chord[step % 3],
                      .18, .065, "pulse", 5)
        for off in (0, .75, 1.5, 2, 2.5, 3.75):
            song.drum(base + off, "kick", .62)
        for off in (1, 3):
            song.drum(base + off, "snare", .60)
        for off in (1.75, 2.75):
            song.drum(base + off, "snare", .18)
        for step in range(16):
            song.drum(base + step / 4, "open" if step == 10 else "hat",
                      .4 if step % 2 == 0 else .19)
        if bar % 4 == 3:
            for off in (3.25, 3.5, 3.875):
                song.drum(base + off, "snare", .32)
            song.drum(base + 3.5, "zap", .14)
    song.render("core_boss.wav")


def verify(path, frames):
    """Read the actual deliverable back, rather than checking the float mix."""
    with wave.open(str(path), "rb") as wav:
        assert (wav.getnchannels(), wav.getsampwidth(), wav.getframerate(),
                wav.getcomptype(), wav.getnframes()) == (1, 2, SR, "NONE", frames)
        samples = np.frombuffer(wav.readframes(frames), dtype="<i2").astype(float) / 32768
    peak = np.max(np.abs(samples))
    rms = np.sqrt(np.mean(samples**2))
    assert np.isfinite(samples).all() and 0.01 < rms and peak <= 0.85
    assert samples[0] == samples[-1] == 0, "Nonzero loop-seam discontinuity"
    assert abs(samples[1]) < .002 and abs(samples[-2]) < .002
    print(f"{path.name}: {frames / SR:.6f}s, {frames} frames, "
          f"mono PCM16/{SR}Hz, peak={peak:.5f}, RMS={rms:.5f}, seam=0")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    overworld()
    ice_factory()
    core_boss()


if __name__ == "__main__":
    main()
