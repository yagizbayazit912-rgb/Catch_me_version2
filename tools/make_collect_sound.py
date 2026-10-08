"""Adım 2.3: gelir toplama sesi (assets/audio/collect.wav) üretir.

Sikkeler sayaca düşerken hızlanan, yükselen küçük "şıng"lar (metal çan
kısmi tonları, uyumsuz oranlar) + sonda yumuşak, parlak bir "kasa" akoru.
Yumuşak, kısa, sinir bozmayan (plan 14.1-D). Uygulama her çalışta hızı
hafifçe değiştirir (ton farkı).

Çalıştır: python tools/make_collect_sound.py
"""
import math
import struct
import wave
from pathlib import Path

SR = 44100
DUR = 1.1
N = int(SR * DUR)
out = [0.0] * N


def add(start_s, dur_s, fn):
    s = int(start_s * SR)
    for i in range(int(dur_s * SR)):
        if s + i < N:
            out[s + i] += fn(i / SR)


def clink(freq, amp):
    # Küçük sikke: temel + uyumsuz kısmi tonlar (metalik), çok kısa sönüm.
    def fn(t):
        attack = min(1.0, t / 0.002)
        return amp * attack * (
            math.sin(2 * math.pi * freq * t) * math.exp(-t / 0.09)
            + 0.5 * math.sin(2 * math.pi * freq * 2.76 * t) * math.exp(-t / 0.05)
            + 0.25 * math.sin(2 * math.pi * freq * 5.40 * t) * math.exp(-t / 0.025)
        )

    return fn


# 1) Sikkeler: aralık daralır, ton yükselir (pentatonik: Do6 Re6 Mi6 Sol6 La6 Do7).
notes = [1046.5, 1174.7, 1318.5, 1568.0, 1760.0, 2093.0]
t0 = 0.0
gap = 0.11
for i, f in enumerate(notes):
    add(t0, 0.35, clink(f, 0.30 + 0.03 * i))
    t0 += gap
    gap *= 0.86


# 2) Kasa: yumuşak, parlak akor (Do6 + Mi6 + Sol6), hafif titreşimli.
def chime(freq, amp):
    def fn(t):
        attack = min(1.0, t / 0.01)
        vib = 1 + 0.003 * math.sin(2 * math.pi * 6 * t)
        return amp * attack * math.exp(-t / 0.22) * (
            math.sin(2 * math.pi * freq * vib * t)
            + 0.3 * math.sin(2 * math.pi * freq * 2 * t)
        )

    return fn


for f in (1046.5, 1318.5, 1568.0):
    add(t0 + 0.04, 0.55, chime(f, 0.22))

# Normalize + uç yumuşatma
peak = max(abs(x) for x in out) or 1
fade = int(0.02 * SR)
for i in range(fade):
    out[N - 1 - i] *= i / fade
data = b"".join(
    struct.pack("<h", int(max(-1, min(1, x / peak * 0.75)) * 32767)) for x in out
)

path = Path(__file__).resolve().parent.parent / "assets" / "audio" / "collect.wav"
with wave.open(str(path), "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(data)
print(f"yazıldı: {path} ({DUR:.2f} sn)")
