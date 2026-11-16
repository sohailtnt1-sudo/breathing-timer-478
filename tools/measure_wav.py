"""Measure a WAV file objectively: RMS, peak, and spectral balance.

Prints RMS / peak (linear, 0..1), dBFS values, and the share of energy
above 4 kHz (the hiss band) and above 8 kHz. Used to prove the v4 rain
is softer and less hissy than the v3 rain.
"""
import sys, wave
import numpy as np


def measure(path):
    with wave.open(path, "rb") as w:
        n = w.getnframes()
        sr = w.getframerate()
        ch = w.getnchannels()
        sw = w.getsampwidth()
        raw = w.readframes(n)
    assert sw == 2, f"expected 16-bit PCM, got {sw} bytes"
    x = np.frombuffer(raw, dtype=np.int16).astype(np.float64) / 32768.0
    if ch > 1:
        x = x.reshape(-1, ch).mean(axis=1)
    rms = float(np.sqrt(np.mean(x ** 2)))
    peak = float(np.max(np.abs(x)))
    # Spectral balance via FFT (whole file, Hann window).
    win = np.hanning(len(x))
    spec = np.abs(np.fft.rfft(x * win)) ** 2
    freqs = np.fft.rfftfreq(len(x), 1.0 / sr)
    total = spec.sum()
    hf4 = float(spec[freqs >= 4000].sum() / total) if total else 0.0
    hf8 = float(spec[freqs >= 8000].sum() / total) if total else 0.0
    lf1 = float(spec[freqs < 1000].sum() / total) if total else 0.0
    db = lambda v: 20 * np.log10(v) if v > 0 else float("-inf")
    print(f"{path}")
    print(f"  sr={sr} frames={n} dur={n/sr:.1f}s")
    print(f"  RMS={rms:.4f} ({db(rms):.1f} dBFS)  peak={peak:.4f} ({db(peak):.1f} dBFS)")
    print(f"  energy <1kHz: {lf1*100:.1f}%   >=4kHz: {hf4*100:.1f}%   >=8kHz: {hf8*100:.1f}%")
    print(f"  nonzero samples: {int(np.count_nonzero(x))}/{len(x)}")
    return rms, peak, hf4


if __name__ == "__main__":
    for p in sys.argv[1:]:
        measure(p)
