"""Adım 2.2: inşa sesi (assets/audio/build.wav) üretir.

Claim sesinden ayrı karakter: toz "puf" (yumuşak gürültü) + tahta "tok"
(yukarı kayan kısa ton, squash & stretch'e eşlik) + marimba tınısında
yükselen iki nota (Mi6 → La6). Yumuşak, kısa, sinir bozmayan (plan 14.1-D).

Çalıştır: python tools/make_build_sound.py
"""
import math
import random
import struct
import wave
from pathlib import Path

SR = 44100
DUR = 0.95
N = int(SR * DUR)
out = [0.0] * N
rnd = random.Random(7)


def add(start_s, dur_s, fn):
    s = int(start_s * SR)
    for i in range(int(dur_s * SR)):
        if s + i < N:
            out[s + i] += fn(i / SR)


# 1) Toz "puf": alçak geçirgen gürültü, hızlı yükselip sönen.
lp = 0.0
puff = []
for i in range(int(0.14 * SR)):
    lp += 0.08 * (rnd.uniform(-1, 1) - lp)
    t = i / SR
    puff.append(lp * min(1, t / 0.01) * math.exp(-t / 0.035) * 1.6)
add(0.0, 0.14, lambda t: puff[min(int(t * SR), len(puff) - 1)])


# 2) Tahta "tok": 190 → 430 Hz kayan, çok kısa sönümlü (çadır zıplar).
def thunk(t):
    # Faz = frekansın integrali (ilk 60 ms'de doğrusal kayış, sonra sabit).
    phase = 2 * math.pi * (190 * t + 120 * min(t, 0.06) ** 2 / 0.06)
    return 0.55 * math.sin(phase) * math.exp(-t / 0.045) * min(1, t / 0.003)


add(0.09, 0.22, thunk)


# 3) Marimba: temel + 4x kısmi (hızlı söner), yumuşak atak.
def marimba(freq, amp):
    def fn(t):
        env = min(1, t / 0.004)
        return amp * env * (
            math.sin(2 * math.pi * freq * t) * math.exp(-t / 0.28)
            + 0.35 * math.sin(2 * math.pi * freq * 3.93 * t) * math.exp(-t / 0.05)
        )

    return fn


add(0.24, 0.6, marimba(1318.5, 0.32))  # Mi6
add(0.37, 0.58, marimba(1760.0, 0.36))  # La6

# Normalize + uç yumuşatma
peak = max(abs(x) for x in out) or 1
fade = int(0.02 * SR)
for i in range(fade):
    out[N - 1 - i] *= i / fade
data = b"".join(
    struct.pack("<h", int(max(-1, min(1, x / peak * 0.8)) * 32767)) for x in out
)

path = Path(__file__).resolve().parent.parent / "assets" / "audio" / "build.wav"
with wave.open(str(path), "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(data)
print(f"yazıldı: {path} ({DUR:.2f} sn)")
