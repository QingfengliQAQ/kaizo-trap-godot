#!/usr/bin/env python3
"""Generate deterministic retro SFX; run from any working directory with numpy installed."""

from pathlib import Path
import wave

import numpy as np


SAMPLE_RATE = 22050
OUTPUT_DIR = Path(__file__).resolve().parents[1] / "game/assets/audio/sfx"


def envelope(signal, attack=0.002, release=0.015):
    """Short ramps prevent boundary clicks while retaining sharp transients."""
    signal = np.asarray(signal, dtype=np.float64).copy()
    attack_n = min(len(signal), max(2, round(attack * SAMPLE_RATE)))
    release_n = min(len(signal), max(2, round(release * SAMPLE_RATE)))
    signal[:attack_n] *= np.linspace(0.0, 1.0, attack_n)
    signal[-release_n:] *= np.linspace(1.0, 0.0, release_n)
    return signal


def tone(start, end, duration, shape="square", decay=2.0):
    t = np.arange(round(duration * SAMPLE_RATE)) / SAMPLE_RATE
    frequency = np.linspace(start, end, len(t))
    phase = np.cumsum(frequency) / SAMPLE_RATE
    if shape == "square":
        signal = np.where(phase % 1.0 < 0.5, 1.0, -1.0)
    elif shape == "triangle":
        signal = 4.0 * np.abs(phase % 1.0 - 0.5) - 1.0
    elif shape == "saw":
        signal = 2.0 * (phase % 1.0) - 1.0
    else:
        raise ValueError(f"Unknown waveform: {shape}")
    return envelope(signal * np.exp(-decay * t / duration))


def noise(rng, duration, decay=5.0, hold=1):
    count = round(duration * SAMPLE_RATE)
    signal = np.repeat(rng.uniform(-1.0, 1.0, (count + hold - 1) // hold), hold)[:count]
    return envelope(signal * np.exp(-decay * np.arange(count) / count))


def mix(*sounds):
    result = np.zeros(max(map(len, sounds)))
    for sound in sounds:
        result[:len(sound)] += sound
    return result


def melody(notes, duration=0.09):
    gap = np.zeros(round(0.012 * SAMPLE_RATE))
    return np.concatenate([np.concatenate((tone(note, note, duration, decay=1.5), gap)) for note in notes])


def synthesize():
    rng = np.random.default_rng(1985)
    glitch = noise(rng, 0.42, decay=2.0, hold=7)
    t = np.arange(len(glitch)) / SAMPLE_RATE
    glitch *= np.where((t * 37.0) % 1.0 < 0.6, 1.0, 0.1)
    return {
        "jump": tone(420, 1100, 0.13),
        "wall_jump": mix(tone(650, 1650, 0.16), 0.3 * noise(rng, 0.055)),
        "slide": mix(noise(rng, 0.23, decay=3.0, hold=2), 0.3 * tone(180, 65, 0.23, "saw")),
        "land": mix(tone(130, 45, 0.09, "triangle"), 0.45 * noise(rng, 0.06)),
        "kaizo_block": mix(tone(900, 160, 0.12), 0.3 * tone(1320, 320, 0.12)),
        "death_spike": mix(tone(1500, 70, 0.32, "saw"), 0.65 * noise(rng, 0.28)),
        "death_glitch": mix(glitch, 0.6 * tone(1800, 90, 0.42, decay=1.5)),
        "death_coconut": mix(tone(250, 35, 0.23, "triangle"), 0.65 * noise(rng, 0.08, hold=3)),
        "key_get": melody([1046.5, 1318.5, 1568.0, 2093.0]),
        "spring": np.concatenate((tone(180, 350, 0.06), tone(350, 1900, 0.25, decay=1.5))),
        "door": mix(tone(260, 65, 0.30, "square"), 0.45 * noise(rng, 0.30, hold=12)),
        "laser": tone(2800, 160, 0.19, "saw", decay=3.0),
        "secret": melody([523.25, 659.25, 783.99, 1046.5, 1568.0], duration=0.14),
        "manual_flip": mix(noise(rng, 0.075, decay=3.0), 0.25 * tone(1100, 600, 0.06, "triangle")),
        "dos_beep": tone(880, 880, 0.12, decay=0.0),
    }


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    sounds = synthesize()
    for name, signal in sounds.items():
        # 8-bit amplitude steps inside a standard little-endian 16-bit PCM WAV.
        signal = signal / max(float(np.max(np.abs(signal))), 1e-9)
        signal = envelope(np.round(signal * 110.0) / 128.0, attack=0.001, release=0.006)
        pcm = np.rint(signal * 32767.0).astype("<i2")
        path = OUTPUT_DIR / f"{name}.wav"
        with wave.open(str(path), "wb") as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(SAMPLE_RATE)
            wav.writeframes(pcm.tobytes())
        print(f"{path.name}: {len(pcm) / SAMPLE_RATE:.3f}s")
    print(f"Generated {len(sounds)} SFX in {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
