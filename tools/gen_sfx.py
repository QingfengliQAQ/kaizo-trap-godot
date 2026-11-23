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


def celeste_sounds():
    """Independent seed preserves the original fifteen effects byte-for-byte."""
    rng = np.random.default_rng(2026)
    t = np.arange(round(0.19 * SAMPLE_RATE)) / SAMPLE_RATE
    air = rng.uniform(-1.0, 1.0, len(t))
    filtered = np.convolve(air, np.ones(9) / 9.0, mode="same")
    whoosh = (air - filtered) * np.sin(np.pi * t / 0.19) ** 2
    thump_phase = 2.0 * np.pi * np.cumsum(np.linspace(125.0, 38.0, len(t))) / SAMPLE_RATE
    dash = envelope(0.65 * whoosh + 0.8 * np.sin(thump_phase) * np.exp(-28.0 * t))

    crystal = np.zeros(round(0.55 * SAMPLE_RATE))
    for index, frequency in enumerate((1046.5, 1318.5, 1568.0, 2093.0)):
        note_t = np.arange(round(0.30 * SAMPLE_RATE)) / SAMPLE_RATE
        note = envelope((0.7 * np.sin(2.0 * np.pi * frequency * note_t)
                         + 0.3 * tone(frequency, frequency, 0.30, "square", decay=3.0))
                        * np.exp(-14.0 * note_t), release=0.04)
        start = round(index * 0.065 * SAMPLE_RATE)
        crystal[start:start + len(note)] += note

    t = np.arange(round(0.43 * SAMPLE_RATE)) / SAMPLE_RATE
    phase = np.cumsum(np.linspace(180.0, 690.0, len(t))) / SAMPLE_RATE
    whir = (2.0 * (phase % 1.0) - 1.0) * (0.65 + 0.35 * np.sin(2.0 * np.pi * 48.0 * t))
    zip_move = envelope(whir * 0.45, attack=0.012, release=0.04)
    clack = mix(noise(rng, 0.035, decay=7.0), tone(850, 160, 0.035, "triangle"))
    start = round(0.38 * SAMPLE_RATE)
    zip_move[start:start + len(clack)] += clack

    t = np.arange(round(0.62 * SAMPLE_RATE)) / SAMPLE_RATE
    phase = 2.0 * np.pi * np.cumsum(220.0 + 90.0 * np.sin(np.pi * t / 0.62)) / SAMPLE_RATE
    dream = 0.45 * np.sin(phase + 2.0 * np.sin(2.0 * np.pi * 5.0 * t))
    dream += 0.18 * np.sin(phase * 1.5) + 0.12 * np.sin(phase * 2.0)
    for start_time in (0.04, 0.13, 0.24, 0.37):
        bubble_t = np.arange(round(0.12 * SAMPLE_RATE)) / SAMPLE_RATE
        bubble_phase = 2.0 * np.pi * np.cumsum(np.linspace(480.0, 1800.0, len(bubble_t))) / SAMPLE_RATE
        bubble = envelope(0.3 * np.sin(bubble_phase) * np.exp(-35.0 * bubble_t))
        start = round(start_time * SAMPLE_RATE)
        dream[start:start + len(bubble)] += bubble
    return {"dash": dash, "crystal_refill": crystal, "zip_move": zip_move,
            "dream_through": envelope(dream, attack=0.015, release=0.13)}


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
        **celeste_sounds(),
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
        with wave.open(str(path), "rb") as wav:
            assert (wav.getnchannels(), wav.getsampwidth(), wav.getframerate()) == (1, 2, SAMPLE_RATE)
            assert wav.getnframes() == len(pcm) and wav.getcomptype() == "NONE"
            restored = np.frombuffer(wav.readframes(wav.getnframes()), dtype="<i2")
            assert np.array_equal(restored, pcm) and np.any(restored)
            assert restored[0] == 0 and restored[-1] == 0
        print(f"{path.name}: {len(pcm) / SAMPLE_RATE:.3f}s")
    assert len(sounds) == 19, "Expected fifteen original and four Celeste effects"
    print(f"Generated and verified {len(sounds)} SFX in {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
