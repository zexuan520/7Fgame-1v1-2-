"""方案 B 配乐：三幕三种音色，音效时间点取自页面的 CUES 表。

用法：python3 score.py cues.json out.wav
第一幕 0–34s   8-bit 芯片音乐（方波旋律 + 三角波贝斯 + 噪声鼓）
转场 32–36s    芯片降调 + 上升音 → 36s 重击
第二幕 36–60s  电子鼓 + 锯齿贝斯 + 合成器重音
第三幕 60–84s  交响铺底 + 太鼓 + 古筝
结尾 84–92s    芯片动机放慢回归 + 关机音
"""
import json
import pathlib
import sys
import wave

import numpy as np

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / 'video'))
from score import SR, fft_filter, guzheng, kick, midi, pad, reverb, riser, taiko, whoosh  # noqa: E402

BPM = 120
BEAT = 60 / BPM
rng = np.random.default_rng(11)


def add(buf, sig, t, gain=1.0, pan=0.0):
    i = int(t * SR)
    if i >= buf.shape[1] or i + len(sig) <= 0:
        return
    if i < 0:
        sig, i = sig[-i:], 0
    sig = sig[: buf.shape[1] - i]
    l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
    buf[0, i:i + len(sig)] += sig * gain * l
    buf[1, i:i + len(sig)] += sig * gain * r


def env(n, a=.004, rel=.05):
    e = np.ones(n)
    A, R = min(n, max(1, int(a * SR))), min(n // 2, max(1, int(rel * SR)))
    e[:A] = np.linspace(0, 1, A)
    e[-R:] *= np.linspace(1, 0, R)
    return e


# ---------- 芯片乐器 ----------
def square(f, dur, duty=.25, vib=0.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    ph = np.cumsum(f * (1 + vib * np.sin(2 * np.pi * 6 * t))) / SR
    return np.where((ph % 1) < duty, 1.0, -1.0) * env(n)


def tri(f, dur):
    n = int(dur * SR)
    ph = (np.arange(n) * f / SR) % 1
    return (4 * np.abs(ph - .5) - 1) * env(n, .002, .02)


def nnoise(dur, decay=40, hp=4000):
    n = int(dur * SR)
    t = np.arange(n) / SR
    return fft_filter(rng.uniform(-1, 1, n), lo=hp) * np.exp(-t * decay)


def blip(f, dur=.035):
    return square(f, dur, .5) * .6


# ---------- 电子乐器 ----------
def saw(f, dur, cutoff=900):
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = sum(np.sin(2 * np.pi * f * h * t + h) / h for h in range(1, 12))
    return fft_filter(s, hi=cutoff) * env(n, .005, .08)


def stab(notes, dur=.45, bright=2600):
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = np.zeros(n)
    for m in notes:
        for det in (-.08, .08):
            f = midi(m) * 2 ** (det / 12)
            s += sum(np.sin(2 * np.pi * f * h * t) / h for h in range(1, 9))
    return fft_filter(s, hi=bright) * np.exp(-t * 5) * env(n, .003, .1)


def clap():
    n = int(.25 * SR)
    t = np.arange(n) / SR
    e = sum(np.exp(-np.maximum(0, t - d) * 60) * (t >= d) for d in (0, .01, .022))
    return fft_filter(rng.uniform(-1, 1, n), lo=900, hi=6000) * e * .6


def main(cues_path, out_path):
    data = json.load(open(cues_path))
    total, cues = data['total'], data['cues']
    N = int((total + .6) * SR)
    chip, elec, orch, fx = (np.zeros((2, N)) for _ in range(4))

    # ===== 第一幕：芯片音乐 Am F C G =====
    prog = [57, 53, 48, 55]                     # 和弦根音
    tones = {57: [57, 60, 64], 53: [53, 57, 60], 48: [48, 52, 55], 55: [55, 59, 62]}
    melody = [76, 72, 74, 76, 79, 76, 74, 72, 69, 72, 74, 72, 67, 69, 72, 74]   # 一小节 8 个八分音符 × 2
    t = 0.0
    bar = 0
    while t < 32.0:
        root = prog[bar % 4]
        for b in range(4):                      # 三角波贝斯：每拍
            add(chip, tri(midi(root - 12) * (1 if b % 2 == 0 else 2), BEAT * .9), t + b * BEAT, .32)
        for e in range(8):                      # 方波琶音
            arp = tones[root][e % 3] + 12
            add(chip, square(midi(arp), BEAT / 2 * .8, .125), t + e * BEAT / 2, .05, pan=.3)
        if t >= 6.0:                            # 旋律从开机后进入
            for e in range(8):
                m = melody[(bar % 2) * 8 + e]
                if bar % 4 == 3 and e > 5:
                    continue
                add(chip, square(midi(m), BEAT / 2 * .85, .25, vib=.004), t + e * BEAT / 2, .085, pan=-.2)
        if t >= 6.0:                            # 噪声鼓
            for b in range(4):
                add(chip, kick(.8)[: int(.18 * SR)], t + b * BEAT, .35)
                add(chip, nnoise(.04, 90, 7000), t + b * BEAT + BEAT / 2, .12, pan=.2)
                if b % 2 == 1:
                    add(chip, nnoise(.12, 30, 1500), t + b * BEAT, .22)
        t += 4 * BEAT
        bar += 1
    # 转场：芯片音阶下滑
    for i in range(12):
        add(chip, square(midi(84 - i * 3), .12, .5), 32.0 + i * .15, .07 * (1 - i / 14))

    # ===== 第二幕：电子 =====
    t = 36.0
    i = 0
    while t < 59.0:
        add(elec, kick(1.0), t, .62)
        if i % 2 == 1:
            add(elec, clap(), t, .45, pan=.1)
        add(elec, nnoise(.05, 70, 8000), t + BEAT / 2, .1, pan=.35)
        root = [45, 41, 48, 43][(i // 8) % 4]
        add(elec, saw(midi(root), BEAT / 2 * .9, 700 + 500 * ((i % 8) / 8)), t + BEAT / 2, .28)
        t += BEAT
        i += 1
    add(elec, pad([45, 57, 60, 64], 24.5), 36.0, .045)

    # ===== 第三幕：交响 + 太鼓 + 古筝 =====
    for k, (start, chord) in enumerate([(60, [45, 57, 60, 64]), (66, [41, 57, 60, 65]), (72, [48, 55, 60, 64]), (78, [43, 55, 59, 62])]):
        add(orch, pad(chord, 7.5), start, .1)
    t = 60.0
    i = 0
    while t < 83.5:
        if i % 4 == 0:
            add(orch, taiko() * .55, t, .5, pan=-.15)
        if i % 4 == 2:
            add(orch, kick(.9), t, .35)
        t += BEAT
        i += 1
    pent = [69, 72, 74, 76, 79, 81, 84]
    for j in range(40):                          # 古筝：每半拍一音，按五声音阶游走
        tt = 61.0 + j * BEAT * 1.5
        if tt > 83.0:
            break
        idx = [0, 2, 3, 4, 3, 2, 4, 5][j % 8] + (j // 16)
        add(orch, guzheng(midi(pent[min(idx, 6)]), 2.4, .5), tt, .16, pan=-.3 + .6 * ((j % 5) / 4))

    # ===== 结尾：芯片动机放慢 =====
    for e in range(8):
        add(chip, square(midi(melody[e]), BEAT * .9, .25, vib=.004), 85.0 + e * BEAT, .07, pan=-.1)
    add(chip, tri(midi(45), 5.0), 85.0, .2)

    # ===== 音效 =====
    for c in cues:
        ct, k = c['t'], c['kind']
        if k == 'type':
            add(fx, blip(1400 + rng.uniform(-80, 80)), ct, .1, pan=rng.uniform(-.3, .3))
        elif k == 'boot':
            add(fx, square(midi(72), .09, .5), ct, .12); add(fx, square(midi(79), .14, .5), ct + .1, .12)
            add(fx, nnoise(.4, 6, 300) * .5, ct, .18)
        elif k in ('hit', 'yearhit'):
            add(fx, kick(1.0), ct, .5); add(fx, nnoise(.15, 25, 2500), ct, .2)
        elif k == 'land':
            add(fx, kick(1.0), ct, .45); add(fx, kick(1.0), ct + .18, .4)
        elif k == 'pop':
            add(fx, square(midi(67), .06, .5), ct, .1); add(fx, square(midi(74), .08, .5), ct + .06, .1)
        elif k == 'ding':
            add(fx, guzheng(midi(88), 1.2, .9), ct, .2)
        elif k == 'clash':
            add(fx, nnoise(.5, 9, 600), ct, .35); add(fx, kick(1.0), ct, .4)
        elif k == 'riser':
            add(fx, riser(4.0), ct, .4)
        elif k == 'step':
            add(fx, kick(1.0), ct, .4); add(fx, whoosh(.4), ct - .2, .25)
        elif k == 'boom':
            add(fx, taiko(), ct, .85); add(fx, riser(1.2), ct - 1.2, .25)
        elif k == 'boomsoft':
            add(fx, taiko() * .6, ct, .5)
        elif k == 'led':
            for q in range(6):
                add(fx, blip(2200 + q * 180, .02), ct + q * .05, .07)
        elif k in ('stab', 'stabhi'):
            add(fx, stab([57, 60, 64] if k == 'stab' else [64, 69, 72]), ct, .22)
        elif k == 'whoosh':
            add(fx, whoosh(.8), ct - .4, .4, pan=.2)
        elif k == 'lightsoff':
            for q in range(4):
                add(fx, kick(.6)[: int(.12 * SR)], ct + q * .22, .35)
                add(fx, nnoise(.05, 60, 3000), ct + q * .22, .15)
        elif k == 'taiko':
            add(fx, taiko(), ct, .6)
        elif k == 'poweroff':
            n = int(.7 * SR)
            tt = np.arange(n) / SR
            add(fx, np.sin(2 * np.pi * np.cumsum(900 * np.exp(-tt * 5)) / SR) * np.exp(-tt * 4), ct, .25)
            add(fx, nnoise(.05, 80, 2000), ct + .65, .3)

    # ===== 混音 =====
    def fade(a, b, fi=.3, fo=.6):
        e = np.zeros(N)
        A, B = int(a * SR), min(N, int(b * SR))
        e[A:B] = 1
        e[A:A + int(fi * SR)] = np.linspace(0, 1, int(fi * SR))
        e[B - int(fo * SR):B] *= np.linspace(1, 0, int(fo * SR))
        return e

    chip *= np.maximum(fade(0, 33.8, .8, 1.6), fade(84.6, total + .6, .3, 1.2))
    elec *= fade(35.9, 60.2, .05, .8)
    orch *= fade(59.9, 84.2, .05, .9)
    mix = reverb(chip * 1.5, .9, .12) + reverb(elec, 1.3, .14) + reverb(orch, 3.0, .32) + reverb(fx, 1.8, .22)
    mix = np.tanh(mix * 1.2)
    mix *= .89 / np.max(np.abs(mix))
    pcm = (mix.T * 32767).astype(np.int16)
    with wave.open(out_path, 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print('score written:', out_path, f'{total:.1f}s')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
