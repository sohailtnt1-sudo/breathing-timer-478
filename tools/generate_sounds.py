"""Generate offline ambient WAV loops for the Breathing Timer app.

Rain  = white noise through a gentle low-pass (one-pole) filter.
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
    rnd = random.Random(478)
    out, lp = [], 0.0
    for _ in range(N):
        white = rnd.uniform(-1, 1)
        lp += 0.18 * (white - lp)          # gentle low-pass -> soft patter
        hp = white - lp                    # a little high-frequency hiss
        out.append(0.55 * lp + 0.25 * hp)
    return seamless(out)

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
