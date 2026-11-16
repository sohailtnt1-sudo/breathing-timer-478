"""Generate offline ambient WAV loops for the Breathing Timer app.

Rain  = pink noise (Paul Kellet filter) blended with brown noise,
        heavily low-passed so almost no energy sits above 4 kHz, at a
        much lower level than v3. v3 was white noise + an explicit
        high-pass hiss component: 51% of its energy was above 4 kHz and
        users reported it "bht irritating he, loud b he". v4 keeps the
        soft patter character but removes the hiss and drops the level
        ~10 dB (RMS ~0.18 -> ~0.06).
Ocean = brown-ish noise slowly modulated by a ~0.1 Hz swell envelope.
Both are seamless loops: the tail is crossfaded into the head so the
loop point is inaudible. 30 s, 22050 Hz, mono, 16-bit PCM. No downloads.
"""
import math, random, struct, wave, os

SR = 22050
DUR = 30
N = SR * DUR
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")

def write_wav(path, samples):
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        frames = b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples)
        w.writeframes(frames)

def seamless(samples):
    # 0.5 s equal-power crossfade of tail into head for a click-free loop.
    fade = SR // 2
    out = list(samples)
    for i in range(fade):
        t = i / fade
        out[i] = samples[i] * math.sin(t * math.pi / 2) ** 2 + samples[N - fade + i] * math.cos(t * math.pi / 2) ** 2
    return out[: N - fade] + out[:fade]  # keep length N

def rain():
    # v4 (Nov 2026): soft, gentle rain. Pink noise (Paul Kellet filter)
    # blended with brown noise, then a heavy one-pole low-pass so the
    # harsh high-frequency hiss of v3 is gone. Slow, shallow swell
    # (~0.08 Hz) so the loop breathes gently. Overall level ~10 dB
    # below v3 (target RMS ~0.06, peak < 0.3).
    rnd = random.Random(4784)
    b = [0.0] * 6
    coef = [0.99886, 0.99332, 0.96900, 0.86650, 0.55000, 0.11500]
    gain = [0.0555179, 0.0750759, 0.1538520, 0.3104856, 0.5329522, 0.1127760]
    out, lp, brown = [], 0.0, 0.0
    for i in range(N):
        white = rnd.uniform(-1, 1)
        pink = white * 0.1848
        for j in range(6):
            b[j] = coef[j] * b[j] + white * gain[j]
            pink += b[j]
        brown += 0.02 * (white - brown)      # deep body, almost no highs
        mixed = 0.55 * pink + 0.45 * brown
        lp += 0.08 * (mixed - lp)            # heavy low-pass: kills hiss
        swell = 0.88 + 0.12 * math.sin(2 * math.pi * 0.08 * i / SR)
        out.append(lp * swell)
    # Normalize to a fixed soft level instead of a guessed gain: the
    # Kellet filter output is far hotter than it looks, so a fixed gain
    # clipped v4's first draft (peak 0.96). Target RMS 0.06 (~-24 dBFS).
    looped = seamless(out)
    rms = math.sqrt(sum(s * s for s in looped) / len(looped))
    scale = 0.06 / rms if rms > 0 else 0.0
    return [s * scale for s in looped]

def ocean():
    rnd = random.Random(4787)
    out, lp = [], 0.0
    for i in range(N):
        white = rnd.uniform(-1, 1)
        lp += 0.02 * (white - lp)          # heavy low-pass -> deep rumble
        swell = 0.55 + 0.45 * math.sin(2 * math.pi * 0.1 * i / SR)  # ~10 s swell
        out.append(0.9 * lp * swell)
    return seamless(out)

os.makedirs(OUT, exist_ok=True)
write_wav(os.path.join(OUT, "rain.wav"), rain())
write_wav(os.path.join(OUT, "ocean.wav"), ocean())
print("wrote rain.wav and ocean.wav")

def chime():
    # Soft two-note bell (E5 -> B4), 2 s, used for session start / end.
    out = []
    for i in range(2 * SR):
        t = i / SR
        env = math.exp(-3.0 * t)
        s = (math.sin(2 * math.pi * 659.25 * t) * 0.5
             + math.sin(2 * math.pi * 987.77 * t) * 0.3 * (1 if t < 1.0 else 0)
             + math.sin(2 * math.pi * 493.88 * t) * 0.35 * (0 if t < 1.0 else 1))
        out.append(0.5 * s * env)
    return out

write_wav(os.path.join(OUT, "chime.wav"), chime())
print("wrote chime.wav")
