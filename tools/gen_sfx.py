"""Generate the Echo Clash sound set procedurally (no external assets). Writes assets/sfx/*.wav.
Palette: dry clicks, paper snaps, blunt impacts and two-note cues, all short and distinct by function."""
import math, os, random, struct, wave

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "sfx")
os.makedirs(OUT, exist_ok=True)
random.seed(7)


def write(name, samples):
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32000)) for s in samples))
    print("wrote", path, len(samples) / RATE, "s")


def env(t, a, d, total):
    if t < a:
        return t / a
    return max(0.0, 1.0 - (t - a) / max(d, 1e-6)) if t < total else 0.0


def tone(freq_fn, dur, a=0.004, d=None, shape="sine", gain=0.8, noise=0.0):
    d = dur if d is None else d
    out = []
    phase = 0.0
    for i in range(int(dur * RATE)):
        t = i / RATE
        f = freq_fn(t)
        phase += 2 * math.pi * f / RATE
        if shape == "sine":
            v = math.sin(phase)
        elif shape == "square":
            v = 1.0 if math.sin(phase) > 0 else -1.0
        elif shape == "saw":
            v = 2.0 * ((phase / (2 * math.pi)) % 1.0) - 1.0
        else:
            v = math.sin(phase) + 0.5 * math.sin(2 * phase)
        v += noise * (random.random() * 2 - 1)
        out.append(v * env(t, a, d, dur) * gain)
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    out = [0.0] * n
    for p in parts:
        for i, s in enumerate(p):
            out[i] += s
    return out


def lowpass(samples, alpha):
    out = []
    y = 0.0
    for s in samples:
        y += alpha * (s - y)
        out.append(y)
    return out


# Pulse Caster shot: short bright click with a falling body
write("shot", mix(
    tone(lambda t: 1800 * math.exp(-t * 40), 0.12, 0.002, 0.1, "square", 0.35),
    lowpass(tone(lambda t: 140, 0.14, 0.002, 0.12, "sine", 0.0, 0.9), 0.25),
))
# Hit confirm: two-note tick
write("hit", mix(tone(lambda t: 880, 0.05, 0.002, 0.05, "sine", 0.5), [0.0] * int(0.05 * RATE) + tone(lambda t: 1320, 0.06, 0.002, 0.05, "sine", 0.5)))
# Elimination: blunt impact + low drop
write("elim", mix(
    lowpass(tone(lambda t: 90 * math.exp(-t * 6), 0.4, 0.003, 0.35, "sine", 0.9, 0.3), 0.2),
    tone(lambda t: 600 * math.exp(-t * 20), 0.15, 0.002, 0.12, "saw", 0.25),
))
# Echo cast: dry click + rising dotted telegraph
write("echo_cast", mix(
    tone(lambda t: 2400, 0.03, 0.001, 0.03, "square", 0.3),
    [0.0] * int(0.08 * RATE) + tone(lambda t: 420 + 300 * t, 0.5, 0.01, 0.45, "sine", 0.35),
))
# Echo materialize: paper snap (noise burst) + chord
write("echo_materialize", mix(
    lowpass(tone(lambda t: 0, 0.08, 0.001, 0.07, "sine", 0.0, 1.0), 0.5),
    tone(lambda t: 523, 0.4, 0.01, 0.35, "sine", 0.3),
    tone(lambda t: 784, 0.4, 0.01, 0.35, "sine", 0.2),
))
# Echo spectral shot: softer, detuned shot
write("echo_shot", tone(lambda t: 1300 * math.exp(-t * 30), 0.14, 0.002, 0.12, "saw", 0.25, 0.1))
# Echo break: glassy descending
write("echo_break", mix(
    tone(lambda t: 1600 * math.exp(-t * 8), 0.35, 0.002, 0.3, "square", 0.25, 0.2),
    tone(lambda t: 220, 0.3, 0.005, 0.25, "sine", 0.4),
))
# Reload: two mechanical clicks
clicks = tone(lambda t: 900, 0.03, 0.001, 0.03, "square", 0.3, 0.3)
write("reload", clicks + [0.0] * int(0.25 * RATE) + tone(lambda t: 1200, 0.03, 0.001, 0.03, "square", 0.3, 0.3))
# Capture / objective tick: rising two-note
write("capture", mix(tone(lambda t: 660, 0.09, 0.003, 0.08, "sine", 0.45), [0.0] * int(0.09 * RATE) + tone(lambda t: 990, 0.14, 0.003, 0.12, "sine", 0.45)))
# Round sting: brass-like swell
write("sting", mix(
    tone(lambda t: 196, 0.9, 0.05, 0.8, "rich", 0.35),
    tone(lambda t: 294, 0.9, 0.08, 0.75, "rich", 0.25),
    tone(lambda t: 392, 0.9, 0.12, 0.7, "sine", 0.2),
))
# UI click
write("ui", tone(lambda t: 1500, 0.04, 0.001, 0.035, "sine", 0.3))
# Dash whoosh
write("dash", lowpass(tone(lambda t: 0, 0.22, 0.01, 0.2, "sine", 0.0, 1.0), 0.12))
# Teleport / sling: sweep
write("warp", tone(lambda t: 300 + 1400 * t, 0.35, 0.01, 0.3, "sine", 0.35))

# ---- v2 cues: temporal abilities, Core states, fields, weapons
# Reverse Entropy: low pull, descending sweep, crisp confirm
write("rewind", mix(
    lowpass(tone(lambda t: 70, 0.5, 0.01, 0.45, "sine", 0.7, 0.2), 0.15),
    tone(lambda t: 1200 - 900 * t / 0.6, 0.6, 0.01, 0.55, "sine", 0.3),
    [0.0] * int(0.55 * RATE) + tone(lambda t: 1800, 0.05, 0.001, 0.045, "square", 0.25),
))
# Fast-Forward: accelerating pulse train with a harsh short transient
ff = []
for i in range(14):
    gap = 0.16 - i * 0.009
    ff += tone(lambda t: 420 + i * 40, 0.04, 0.001, 0.035, "saw", 0.35) + [0.0] * int(max(0.02, gap) * RATE)
write("ff", mix(ff, tone(lambda t: 3000 * math.exp(-t * 60), 0.06, 0.001, 0.05, "square", 0.3, 0.6)))
# Core drop: blunt ceramic knock
write("core_drop", lowpass(tone(lambda t: 180 * math.exp(-t * 12), 0.25, 0.002, 0.2, "sine", 0.9, 0.4), 0.3))
# Field enter / exit: soft two-note chords
write("field_enter", mix(tone(lambda t: 392, 0.35, 0.02, 0.3, "sine", 0.3), tone(lambda t: 587, 0.35, 0.04, 0.3, "sine", 0.22)))
write("field_exit", mix(tone(lambda t: 587, 0.3, 0.02, 0.25, "sine", 0.25), tone(lambda t: 392, 0.3, 0.05, 0.25, "sine", 0.2)))
# Volatility warning tick
write("warn", tone(lambda t: 1046, 0.08, 0.002, 0.07, "square", 0.3))
# Detonation: long low noise burst with sub thump
write("detonate", mix(
    lowpass(tone(lambda t: 0, 1.4, 0.005, 1.3, "sine", 0.0, 1.0), 0.08),
    lowpass(tone(lambda t: 45 * math.exp(-t * 2.0), 1.2, 0.005, 1.1, "sine", 1.0), 0.2),
))
# Restoration: reassembly (rising noise sweep) then a clean chord
write("restore", mix(
    lowpass(tone(lambda t: 0, 0.45, 0.2, 0.2, "sine", 0.0, 0.8), 0.35),
    [0.0] * int(0.4 * RATE) + tone(lambda t: 659, 0.35, 0.01, 0.3, "sine", 0.3),
    [0.0] * int(0.4 * RATE) + tone(lambda t: 988, 0.35, 0.02, 0.3, "sine", 0.2),
))
# Weapons
write("shot_shotgun", mix(lowpass(tone(lambda t: 0, 0.22, 0.001, 0.2, "sine", 0.0, 1.0), 0.18), tone(lambda t: 110 * math.exp(-t * 8), 0.3, 0.002, 0.28, "sine", 0.9)))
write("shot_sniper", mix(tone(lambda t: 2600 * math.exp(-t * 50), 0.08, 0.001, 0.07, "square", 0.5), lowpass(tone(lambda t: 0, 0.5, 0.002, 0.45, "sine", 0.0, 0.8), 0.12)))
write("shot_mg", mix(tone(lambda t: 1500 * math.exp(-t * 45), 0.07, 0.001, 0.06, "square", 0.4), lowpass(tone(lambda t: 120, 0.09, 0.002, 0.08, "sine", 0.0, 0.9), 0.3)))
# Footstep
write("step", lowpass(tone(lambda t: 0, 0.06, 0.002, 0.05, "sine", 0.0, 0.7), 0.25))
# Zip / portal / pad
write("zip", tone(lambda t: 500 + 200 * math.sin(t * 30), 0.6, 0.02, 0.5, "saw", 0.12, 0.2))
write("portal", mix(tone(lambda t: 220 + 660 * t, 0.4, 0.01, 0.35, "sine", 0.3), tone(lambda t: 880 - 500 * t, 0.4, 0.05, 0.3, "sine", 0.2)))
write("pad", mix(lowpass(tone(lambda t: 90, 0.2, 0.005, 0.18, "sine", 0.8, 0.3), 0.3), tone(lambda t: 300 + 900 * t, 0.3, 0.01, 0.25, "sine", 0.3)))
