#!/usr/bin/env python3
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path("godot/assets/audio")
OUT.mkdir(parents=True, exist_ok=True)
random.seed(7321)


def write_wav(name, seconds, sample_fn):
    n = int(RATE * seconds)
    path = OUT / name
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        frames = bytearray()
        for i in range(n):
            t = i / RATE
            v = max(-1.0, min(1.0, float(sample_fn(t, i, n))))
            frames.extend(struct.pack("<h", int(v * 32767)))
        f.writeframes(frames)
    print(path, path.stat().st_size)


def env(t, duration, attack=0.02, release=0.12):
    return min(1.0, t / max(attack, 1e-4), (duration - t) / max(release, 1e-4))


def step_wave(freq, duration, noise=0.20, thump=0.65):
    def fn(t, i, n):
        e = max(0.0, env(t, duration, 0.008, duration * 0.62))
        low = math.sin(2 * math.pi * freq * t) * math.exp(-t * 18.0)
        grit = (random.random() * 2 - 1) * math.exp(-t * 24.0)
        return e * (low * thump + grit * noise)
    return fn


def splash(t, i, n):
    duration = n / RATE
    e = max(0.0, env(t, duration, 0.006, 0.25))
    noise = (random.random() * 2 - 1)
    bubble = math.sin(2 * math.pi * (105 + 55 * math.exp(-t * 5)) * t)
    return e * (0.42 * noise * math.exp(-t * 4.5) + 0.22 * bubble * math.exp(-t * 3.0))


def mud(t, i, n):
    duration = n / RATE
    e = max(0.0, env(t, duration, 0.02, 0.18))
    wobble = math.sin(2 * math.pi * (58 + 16 * math.sin(t * 8)) * t)
    grit = (random.random() * 2 - 1) * 0.22
    return e * (0.48 * wobble + grit) * math.exp(-t * 2.2)


def click(t, i, n):
    duration = n / RATE
    e = max(0.0, env(t, duration, 0.002, 0.055))
    return e * (0.34 * math.sin(2 * math.pi * 720 * t) + 0.18 * math.sin(2 * math.pi * 1180 * t))


def crunch(t, i, n):
    duration = n / RATE
    pulse = (int(t * 7.5) % 2) == 0
    e = max(0.0, env(t, duration, 0.01, 0.12))
    grit = (random.random() * 2 - 1) * (0.22 if pulse else 0.08)
    jaw = math.sin(2 * math.pi * 88 * t) * 0.11
    return e * (grit + jaw)


def lap(t, i, n):
    duration = n / RATE
    phase = (t * 3.7) % 1.0
    pulse = math.exp(-phase * 9.0)
    noise = (random.random() * 2 - 1) * 0.16
    water = math.sin(2 * math.pi * 135 * t) * 0.06
    return max(0.0, env(t, duration, 0.01, 0.15)) * pulse * (noise + water)


def ambience(t, i, n):
    wind = (random.random() * 2 - 1) * 0.035
    water = 0.018 * math.sin(2 * math.pi * 0.19 * t) + 0.012 * math.sin(2 * math.pi * 0.41 * t)
    insect_gate = 1.0 if int(t * 1.7) % 19 in (0, 1) else 0.0
    insects = insect_gate * 0.012 * math.sin(2 * math.pi * (3300 + 130 * math.sin(t * 2.2)) * t)
    return wind + water + insects


write_wav("hippo_step.wav", 0.38, step_wave(58, 0.38, 0.15, 0.72))
write_wav("pig_step.wav", 0.30, step_wave(78, 0.30, 0.20, 0.54))
write_wav("dog_step.wav", 0.24, step_wave(105, 0.24, 0.17, 0.42))
write_wav("water_splash.wav", 0.95, splash)
write_wav("mud_squelch.wav", 0.75, mud)
write_wav("eat_crunch.wav", 1.25, crunch)
write_wav("drink_lap.wav", 1.65, lap)
write_wav("ui_click.wav", 0.11, click)
write_wav("sanctuary_ambience.wav", 24.0, ambience)
