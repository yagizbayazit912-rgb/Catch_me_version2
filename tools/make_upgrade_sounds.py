"""Adım 2.4: sikke ve yükseltme sesleri (assets/audio/) üretir.

- collect.wav    gelir toplama: klasik "bi-ding" sikke sesleri art arda
                 dökülür, sonda parlak büyük sikke + ışıltı.
- upgrade_N.wav  N = 2 ev, 3 otel, 4 gökdelen: animasyonla senkron, baştan
                 sona süren iz. Hepsi Do majörde; seviye arttıkça daha uzun,
                 daha zengin. Puf → kurulum notaları (yükselen) → final.
                 Gökdelende her kat bir nota (yükselen dizi) + altta
                 yükselen "riser", finalde darbe + fanfar + havai fişek.
- finale_N.wav   animasyon atlanınca çalan, sadece final bölümü.

Zamanlar GameConfig ile senkron olmalı: buildAnimMsByLevel,
buildAssembleEndByLevel, upgradeShrinkMs, skyTierFloors ve
building_model.dart'taki parça gecikmeleri. Değişirse bu dosyayı yeniden
çalıştır: python tools/make_upgrade_sounds.py
"""
import wave
from pathlib import Path

import numpy as np

SR = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"
RNG = np.random.default_rng(7)

ANIM_MS = {2: 2300, 3: 2900, 4: 4200}
ASSEMBLE_END = {2: 0.74, 3: 0.72, 4: 0.74}
SHRINK_S = 0.45
SKY_FLOORS = 24  # GameConfig.skyTierFloors toplamı

# Do majör frekansları (A4 = 440).
def note(name):
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    n = names[name[0]] + 12 * (int(name[-1]) - 4)
    return 440.0 * 2 ** (n / 12)


MAJOR = ["C", "D", "E", "F", "G", "A", "B"]


def scale(start_oct, count):
    return [note(f"{MAJOR[i % 7]}{start_oct + i // 7}") for i in range(count)]


class Track:
    def __init__(self, dur):
        self.buf = np.zeros(int(SR * dur))

    def add(self, start, sig):
        s = int(start * SR)
        if s >= len(self.buf):
            return
        e = min(len(self.buf), s + len(sig))
        self.buf[s:e] += sig[: e - s]

    def save(self, name, peak=0.82):
        x = self.buf
        x = np.tanh(x * 1.2) / np.tanh(1.2)  # yumuşak sınırlayıcı
        m = np.max(np.abs(x)) or 1.0
        x = x / m * peak
        # Başta/sonda tık olmasın.
        f = int(0.004 * SR)
        x[:f] *= np.linspace(0, 1, f)
        x[-f:] *= np.linspace(1, 0, f)
        data = (x * 32767).astype("<i2").tobytes()
        with wave.open(str(OUT / name), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(data)
        print("yazıldı", name, f"{len(x) / SR:.2f} sn")


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env(t, attack, decay):
    return np.minimum(1, t / attack) * np.exp(-t / decay)


# ---- Enstrümanlar ----------------------------------------------------------

def coin(f1=988.0, f2=1319.0, amp=0.5):
    """Klasik sikke: kısa alt nota → uzun üst nota. Yumuşatılmış kare dalga
    (tek harmonikler azalarak) + metalik ışıltı kısmi tonu."""
    def sq(f, t):
        return sum(np.sin(2 * np.pi * f * k * t) / k ** 1.6 for k in (1, 3, 5, 7))

    t1 = t_axis(0.07)
    a = sq(f1, t1) * env(t1, 0.002, 0.08)
    t2 = t_axis(0.45)
    b = sq(f2, t2) * env(t2, 0.002, 0.16)
    b += 0.35 * np.sin(2 * np.pi * f2 * 2.76 * t2) * env(t2, 0.001, 0.05)
    return amp * np.concatenate([a, b])


def marimba(f, amp=0.5, dur=0.5):
    t = t_axis(dur)
    return amp * (
        np.sin(2 * np.pi * f * t) * env(t, 0.002, 0.16)
        + 0.25 * np.sin(2 * np.pi * f * 4 * t) * env(t, 0.001, 0.03)
    )


def bell(f, amp=0.4, dur=1.0):
    t = t_axis(dur)
    return amp * (
        np.sin(2 * np.pi * f * t) * env(t, 0.003, 0.35)
        + 0.45 * np.sin(2 * np.pi * f * 2.76 * t) * env(t, 0.002, 0.12)
        + 0.2 * np.sin(2 * np.pi * f * 5.4 * t) * env(t, 0.001, 0.05)
    )


def pad(freqs, amp=0.18, dur=1.6, attack=0.08):
    """Yumuşak akor: hafif detune'lu üçgen dalgalar, yavaş sönüm."""
    t = t_axis(dur)
    s = np.zeros_like(t)
    for f in freqs:
        for d in (-0.003, 0.003):
            ph = (f * (1 + d) * t) % 1.0
            s += 4 * np.abs(ph - 0.5) - 1
    return amp / len(freqs) * s * np.minimum(1, t / attack) * np.exp(-t / (dur * 0.45))


def noise_burst(dur, lo, hi, amp=0.4, decay=0.12, attack=0.01):
    """Bant geçiren gürültü (FFT ile): puf, toz, tıslama."""
    n = int(SR * dur)
    spec = np.fft.rfft(RNG.standard_normal(n))
    fr = np.fft.rfftfreq(n, 1 / SR)
    spec[(fr < lo) | (fr > hi)] = 0
    x = np.fft.irfft(spec, n)
    x /= np.max(np.abs(x)) or 1
    t = t_axis(dur)
    return amp * x * env(t, attack, decay)


def poof(amp=0.5):
    return noise_burst(0.45, 150, 2200, amp, decay=0.11, attack=0.015)


def thud(f=110.0, amp=0.6):
    t = t_axis(0.35)
    sweep = f * (1 + 0.6 * np.exp(-t / 0.02))
    return amp * np.sin(2 * np.pi * np.cumsum(sweep) / SR) * env(t, 0.002, 0.08)


def boom(amp=0.8):
    t = t_axis(1.2)
    sweep = 70 * (1 + 1.5 * np.exp(-t / 0.05))
    body = np.sin(2 * np.pi * np.cumsum(sweep) / SR) * env(t, 0.003, 0.35)
    return amp * body + noise_burst(1.2, 40, 900, 0.35 * amp, decay=0.25)


def riser(dur, amp=0.25):
    """Yükselen tıslama + yükselen ton: gerilim (gökdelen kurulumu)."""
    n = int(SR * dur)
    t = t_axis(dur)
    x = RNG.standard_normal(n)
    # Basit tek kutuplu alçak geçiren, kesim frekansı zamanla açılır.
    cut = 300 + 5000 * (t / dur) ** 2
    a = np.exp(-2 * np.pi * cut / SR)
    y = np.zeros(n)
    acc = 0.0
    for i in range(n):
        acc = a[i] * acc + (1 - a[i]) * x[i]
        y[i] = acc
    y /= np.max(np.abs(y)) or 1
    tone = np.sin(2 * np.pi * np.cumsum(220 + 440 * (t / dur) ** 1.5) / SR)
    shape = (t / dur) ** 1.8
    return amp * shape * (0.8 * y + 0.25 * tone)


def crackle(amp=0.3):
    """Havai fişek: patlama + çıtırtı."""
    s = noise_burst(0.9, 200, 6000, amp, decay=0.06, attack=0.002)
    for k in range(14):
        st = int(SR * (0.08 + RNG.random() * 0.6))
        pop = noise_burst(0.03, 2000, 9000, amp * 0.6, decay=0.006, attack=0.001)
        s[st:st + len(pop)] += pop[: len(s) - st]
    return s


def coin_cascade(tr, start, count, gap=0.075, amp=0.32):
    for i in range(count):
        semis = [0, 2, 4, 7, 9, 12, 14, 16, 19][i % 9]
        k = 2 ** (semis / 12)
        tr.add(start + i * gap * (0.93 ** i), coin(988 * k, 1319 * k, amp))


# ---- Finaller --------------------------------------------------------------

def finale(level, tr, t0):
    if level == 2:
        for i, n in enumerate(["C5", "E5", "G5"]):
            tr.add(t0 + i * 0.05, bell(note(n), 0.35))
        tr.add(t0, pad([note("C4"), note("E4"), note("G4")], 0.25, 1.4))
        coin_cascade(tr, t0 + 0.12, 4)
    elif level == 3:
        tr.add(t0, thud(98, 0.5))
        for i, n in enumerate(["C5", "E5", "G5", "C6"]):
            tr.add(t0 + i * 0.06, bell(note(n), 0.38))
        tr.add(t0, pad([note("C4"), note("E4"), note("G4"), note("C5")], 0.3, 1.8))
        for i, n in enumerate(["E6", "G6", "C7"]):
            tr.add(t0 + 0.32 + i * 0.07, bell(note(n), 0.22, 0.7))
        coin_cascade(tr, t0 + 0.15, 6)
    else:
        tr.add(t0, boom(0.85))
        fan = ["C5", "E5", "G5", "C6", "E6", "G6", "C7"]
        for i, n in enumerate(fan):
            tr.add(t0 + 0.02 + i * 0.055, bell(note(n), 0.36, 1.2))
        tr.add(
            t0,
            pad([note("C3"), note("G3"), note("C4"), note("E4"), note("G4"), note("D5")],
                0.4, 2.6, attack=0.05),
        )
        for d in (0.0, 0.2, 0.39):  # BuildFx havai fişek gecikmeleri (finale oranı)
            tr.add(t0 + 0.1 + d * 1.09, crackle(0.28))
        coin_cascade(tr, t0 + 0.2, 9, gap=0.07)


# ---- Kurulum izleri --------------------------------------------------------

def upgrade(level):
    total = ANIM_MS[level] / 1000
    end = total * ASSEMBLE_END[level]
    asm = end - SHRINK_S
    tr = Track(total + 2.2)
    at = lambda p: SHRINK_S + p * asm  # kurulum oranı → saniye

    tr.add(0.0, poof(0.55 if level < 4 else 0.7))
    if level == 2:
        # Duvarlar yükselir (yürüyen marimba), ışıklar (zil), çatı oturur (tok).
        for i, n in enumerate(["C4", "E4", "G4", "C5"]):
            tr.add(at(0.1 + i * 0.09), marimba(note(n), 0.5))
        for i, n in enumerate(["E6", "G6"]):
            tr.add(at(0.5 + i * 0.05), bell(note(n), 0.18, 0.5))
        tr.add(at(0.72), thud(130, 0.45))
        tr.add(at(0.86), marimba(note("G4"), 0.35))
    elif level == 3:
        # Her kat bir nota (yükselen), ışıklar kat kat zil, çatı + havuz.
        for i, f in enumerate(scale(4, 6)):
            tr.add(at(0.2 + i * 0.06), marimba(f, 0.5))
        for i, f in enumerate(scale(6, 6)):
            tr.add(at(0.5 + i * 0.04), bell(f, 0.14, 0.45))
        tr.add(at(0.72), thud(120, 0.45))
        tr.add(at(0.8), bell(note("A5"), 0.2, 0.6))
    else:
        # Altta gerilim (riser) + her kat yükselen nota (3+ oktav).
        tr.add(SHRINK_S, riser(end - SHRINK_S, 0.3))
        tr.add(0.0, thud(70, 0.5))
        notes = scale(3, SKY_FLOORS)
        for i in range(SKY_FLOORS):
            p = 0.14 + 0.62 * i / SKY_FLOORS
            tr.add(at(p), marimba(notes[i], 0.32 + 0.12 * i / SKY_FLOORS, 0.35))
        # Taç + iğne: parlak ziller.
        for i, n in enumerate(["G6", "C7", "E7"]):
            tr.add(at(0.8 + i * 0.05), bell(note(n), 0.2, 0.6))
    finale(level, tr, end)
    return tr


def finale_only(level):
    tr = Track(3.0 if level == 4 else 2.2)
    finale(level, tr, 0.0)
    return tr


def collect():
    """Gelir toplama: art arda dökülen sikkeler + büyük parlak sikke."""
    tr = Track(1.5)
    coin_cascade(tr, 0.0, 6, gap=0.1, amp=0.3)
    tr.add(0.62, coin(note("B5") * 1.5, note("E6") * 1.5, 0.42))
    tr.add(0.66, bell(note("E7"), 0.12, 0.6))
    return tr


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    collect().save("collect.wav")
    for lv in (2, 3, 4):
        upgrade(lv).save(f"upgrade_{lv}.wav")
        finale_only(lv).save(f"finale_{lv}.wav")
