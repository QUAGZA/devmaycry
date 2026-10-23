"""Procedural ambience loops for ECHO CLASH (original, no samples).

Writes 22.05 kHz 16-bit mono WAV loops into assets/sfx/:
  amb_oracle.wav   soft garden wind with sparse glassy chimes
  amb_tideline.wav wind over open water with slow sea swell
  amb_foundry.wav  low machine hum, harmonics and a slow kinetic pulse
Loops are made seamless by cross-fading the tail into the head.
Run:  python tools/gen_ambience.py
"""
import os
import wave
import numpy as np

SR = 22050
DUR = 20.0
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")


def lowpass(x, a):
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


def seamless(x, fade=1.0):
    n = int(fade * SR)
    head, tail = x[:n].copy(), x[-n:].copy()
    ramp = np.linspace(0.0, 1.0, n)
    x = x[:-n].copy()
    x[:n] = head * ramp + tail * (1.0 - ramp)
    return x


def write(name, x):
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.6
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("wrote", name, len(data) / SR, "s")


rng = np.random.default_rng(2026)
t = np.arange(int((DUR + 1.0) * SR)) / SR

# Oracle: wind (filtered noise with slow gusts) + sparse chimes
wind = lowpass(rng.standard_normal(len(t)), 0.02)
gust = 0.6 + 0.4 * np.sin(2 * np.pi * t / 7.3) * np.sin(2 * np.pi * t / 3.1 + 1.0)
oracle = wind * gust
for k in range(9):
    t0 = rng.uniform(0.5, DUR - 1.0)
    f = rng.choice([880.0, 1174.7, 1318.5, 1567.98])
    env = np.where(t > t0, np.exp(-(t - t0) * 2.2), 0.0)
    oracle += 0.08 * env * np.sin(2 * np.pi * f * (t - t0)) * (t > t0)
write("amb_oracle.wav", seamless(oracle))

# Tideline: broadband sea wash with slow swell + higher wind whistle
sea = lowpass(rng.standard_normal(len(t)), 0.05)
swell = 0.5 + 0.5 * np.sin(2 * np.pi * t / 6.5) ** 2
whistle = lowpass(rng.standard_normal(len(t)), 0.25) * 0.15 * (0.5 + 0.5 * np.sin(2 * np.pi * t / 9.0))
tide = sea * swell + whistle
write("amb_tideline.wav", seamless(tide))

# Foundry: hum at 55 Hz with harmonics, slow press pulse, faint grit
hum = sum(a * np.sin(2 * np.pi * f * t) for f, a in [(55, 1.0), (110, 0.45), (165, 0.2), (220, 0.12)])
pulse = 0.65 + 0.35 * (np.sin(2 * np.pi * t / 2.5) > 0.6)
grit = lowpass(rng.standard_normal(len(t)), 0.1) * 0.25
foundry = hum * pulse * 0.6 + grit
write("amb_foundry.wav", seamless(foundry))
