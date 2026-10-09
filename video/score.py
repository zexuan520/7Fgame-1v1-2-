"""根据场景时间点合成配乐：铺底和弦 + 鼓点 + 古筝五声拨弦 + 章节重击 / 转场音效。

用法：python3 score.py cues.json out.wav
"""
import json
import sys
import wave

import numpy as np

SR = 48000
BPM = 84
BEAT = 60 / BPM
rng = np.random.default_rng(7)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def env_adsr(n, a, d, s, r):
    e = np.ones(n) * s
    A, D, R = int(a * SR), int(d * SR), int(r * SR)
    e[:A] = np.linspace(0, 1, A)
    e[A:A + D] = np.linspace(1, s, len(e[A:A + D]))
    if R:
        e[-R:] *= np.linspace(1, 0, R)
    return e


def fft_filter(x, lo=None, hi=None):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    g = np.ones_like(f)
    if hi:
        g *= 1 / np.sqrt(1 + (f / hi) ** 4)
    if lo:
        g *= 1 / np.sqrt(1 + (lo / np.maximum(f, 1e-3)) ** 4)
    return np.fft.irfft(X * g, len(x))


def add(buf, sig, t, gain=1.0, pan=0.0):
    i = int(t * SR)
    if i >= buf.shape[1]:
        return
    sig = sig[: buf.shape[1] - i]
    l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
    buf[0, i:i + len(sig)] += sig * gain * l
    buf[1, i:i + len(sig)] += sig * gain * r


# ---------- instruments ----------
def kick(strength=1.0):
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    f = 45 + 75 * np.exp(-t * 28)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 7) * strength


def taiko():
    n = int(2.8 * SR)
    t = np.arange(n) / SR
    f = 38 + 80 * np.exp(-t * 14)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 2.2)
    skin = fft_filter(rng.standard_normal(n), hi=900) * np.exp(-t * 18) * 0.9
    sub = np.sin(2 * np.pi * 32 * t) * np.exp(-t * 1.4) * 0.6
    return np.tanh((body + skin + sub) * 1.6)


def riser(dur=1.4):
    n = int(dur * SR)
    t = np.arange(n) / SR
    noise = fft_filter(rng.standard_normal(n), lo=1500, hi=9000)
    sweep = np.sin(2 * np.pi * np.cumsum(220 * 2 ** (2.2 * t / dur)) / SR) * 0.25
    e = (t / dur) ** 2.5
    return (noise * 0.5 + sweep) * e


def whoosh(dur=0.9):
    n = int(dur * SR)
    t = np.arange(n) / SR
    e = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 2
    return fft_filter(rng.standard_normal(n), lo=300, hi=4000) * e * 0.6


def guzheng(freq, dur=2.6, bright=0.5):
    """Karplus–Strong 拨弦，加一点泛音模拟古筝。"""
    n = int(dur * SR)
    p = int(SR / freq)
    buf = rng.uniform(-1, 1, p)
    buf = fft_filter(np.tile(buf, 4), hi=2500 + 5000 * bright)[:p]
    out = np.empty(n)
    decay = 0.4985 + 0.0012 * bright
    idx = 0
    for i in range(n):
        v = buf[idx]
        nxt = buf[(idx + 1) % p]
        buf[idx] = decay * (v + nxt)
        out[i] = v
        idx = (idx + 1) % p
    t = np.arange(n) / SR
    out += 0.15 * np.sin(2 * np.pi * freq * 2 * t) * np.exp(-t * 3)  # 泛音
    out *= np.minimum(1, t * 400)
    return out / (np.max(np.abs(out)) + 1e-9)


def pad(notes, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for m in notes:
        f = midi(m)
        for det in (-0.12, 0.0, 0.11):
            ff = f * 2 ** (det / 12)
            for h in range(1, 7):
                out += np.sin(2 * np.pi * ff * h * t + rng.uniform(0, 6)) / h ** 1.6
    out = fft_filter(out, hi=1400)
    lfo = 0.8 + 0.2 * np.sin(2 * np.pi * 0.15 * t)
    return out * lfo * env_adsr(n, min(2.5, dur / 3), 0.5, 0.85, min(2.5, dur / 3))


def reverb(x, secs=2.8, wet=0.32):
    n = int(secs * SR)
    t = np.arange(n) / SR
    out = np.empty_like(x)
    for ch in range(2):
        ir = rng.standard_normal(n) * np.exp(-t * 6.9 / secs)
        ir = fft_filter(ir, hi=6000)
        ir /= np.sqrt(np.sum(ir ** 2))
        L = len(x[ch]) + n
        size = 1 << (L - 1).bit_length()
        y = np.fft.irfft(np.fft.rfft(x[ch], size) * np.fft.rfft(ir, size), size)[: len(x[ch])]
        out[ch] = x[ch] * (1 - wet) + y * wet * 1.5
    return out


# ---------- arrangement ----------
def main(cues_path, out_path):
    data = json.load(open(cues_path))
    total, cues = data['total'], data['cues']
    N = int((total + 0.5) * SR)
    music = np.zeros((2, N))
    drums = np.zeros((2, N))
    fx = np.zeros((2, N))

    # D 羽调式五声：D F G A C
    scale = [50, 53, 55, 57, 60, 62, 65, 67, 69, 72, 74, 77]
    chords = [[38, 50, 53, 57], [34, 50, 53, 58], [41, 53, 57, 60], [36, 52, 55, 60]]  # Dm Bb F C

    title_t = cues[1]['t']
    final_t = cues[-1]['t']
    booms = [c['t'] for c in cues if c['sfx'] in ('boom', 'final')]

    # 铺底和弦：每 8 拍换一次
    bar = 8 * BEAT
    t = 0.0
    k = 0
    while t < total:
        dur = min(bar + 1.5, total + 0.5 - t)
        g = 0.05 if t < title_t else 0.075
        add(music, pad(chords[k % 4], dur), t, g, pan=0)
        t += bar
        k += 1

    # 冷开场：心跳
    t = 0.6
    while t < title_t - 1.5:
        add(drums, kick(0.7), t, 0.55)
        add(drums, kick(0.5), t + 0.28, 0.4)
        t += 1.6

    # 主体鼓点：每拍底鼓，后半拍轻微沙锤；章节卡前后留白
    t = title_t + 3.0
    i = 0
    while t < final_t - 0.2:
        near_boom = any(-1.6 < t - b < 0.9 for b in booms)
        if not near_boom:
            intensity = 0.55 if i % 4 else 0.8
            add(drums, kick(intensity), t, 0.5)
            hat = fft_filter(rng.standard_normal(int(0.06 * SR)), lo=6000) * np.exp(-np.arange(int(0.06 * SR)) / SR * 70)
            add(drums, hat, t + BEAT / 2, 0.05, pan=0.3)
            if i % 8 == 6:
                add(drums, taiko() * 0.35, t + BEAT * 0.5, 0.35, pan=-0.2)
        t += BEAT
        i += 1

    # 场景音效 + 古筝动机
    motif_i = 0
    for c in cues:
        ct, kind = c['t'], c['sfx']
        if kind in ('boom', 'final'):
            add(fx, riser(1.4), ct - 1.4, 0.35)
            add(fx, taiko(), ct, 0.9)
            add(music, guzheng(midi(38 + 12), 4.0, 0.3), ct + 0.02, 0.35, pan=-0.1)
        elif kind == 'whoosh':
            add(fx, whoosh(0.9), ct - 0.45, 0.45, pan=0.2)
        elif kind == 'hit':
            add(fx, whoosh(0.6), ct - 0.3, 0.3, pan=-0.2)
            add(fx, kick(1.0), ct, 0.6)
        if kind in ('whoosh', 'hit', 'drone', 'final'):
            # 每个场景开头一段上行琶音，音高逐渐抬升
            base = motif_i % 5
            seq = [base, base + 2, base + 4, base + 5] if motif_i % 2 == 0 else [base + 4, base + 3, base + 1, base + 2]
            for j, s in enumerate(seq):
                note = scale[min(s, len(scale) - 1)]
                add(music, guzheng(midi(note), 2.6, 0.5), ct + 0.15 + j * BEAT / 2, 0.22, pan=-0.4 + 0.25 * j)
            motif_i += 1

    # 片尾：长和弦渐弱 + 尾音
    add(music, pad([38, 50, 57, 62, 65], total - final_t + 0.5), final_t, 0.09)
    for j, s in enumerate([5, 7, 9, 10]):
        add(music, guzheng(midi(scale[s]), 4.0, 0.4), final_t + 2.0 + j * BEAT, 0.25, pan=-0.3 + 0.2 * j)

    mix = reverb(music, 3.2, 0.38) + reverb(drums, 1.2, 0.15) + reverb(fx, 2.4, 0.3)
    # 首尾淡入淡出
    fade = np.ones(N)
    fi, fo = int(0.8 * SR), int(2.5 * SR)
    fade[:fi] = np.linspace(0, 1, fi)
    fade[-fo:] = np.linspace(1, 0, fo)
    mix *= fade
    mix = np.tanh(mix * 1.3)
    mix *= 0.89 / np.max(np.abs(mix))

    pcm = (mix.T * 32767).astype(np.int16)
    with wave.open(out_path, 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print('score written:', out_path, f'{total:.1f}s')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
