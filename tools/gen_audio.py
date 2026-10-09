#!/usr/bin/env python3
"""合成游戏的音效和背景音乐（占位用，以后换正式素材直接覆盖同名文件）。

    python3 tools/gen_audio.py

输出：assets/sfx/*.wav（44.1kHz 单声道）、assets/music/*.wav（22.05kHz 单声道，首尾接得上，游戏里循环播放）。
只用 numpy。每个声音一个函数，改了重新跑一遍就行；同一个种子每次生成的都一样。
"""
import os
import wave
import numpy as np

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
SR = 44100
MSR = 22050
rng = np.random.default_rng(7)


def write(path, x, sr):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) if x.size else 1.0
    if peak > 0:
        x = x / peak * 0.9
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data.tobytes())


def t(dur, sr=SR):
    return np.arange(int(dur * sr)) / sr


def env(dur, attack=0.002, decay=0.2, sr=SR):
    """快起、指数衰减的包络"""
    tt = t(dur, sr)
    a = np.minimum(tt / max(attack, 1e-4), 1.0)
    return a * np.exp(-tt / decay)


def noise(dur, sr=SR):
    return rng.uniform(-1, 1, int(dur * sr))


def lowpass(x, cutoff, sr=SR):
    """一阶低通，简单够用"""
    a = np.exp(-2 * np.pi * cutoff / sr)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def bandpass(x, lo, hi, sr=SR):
    return lowpass(x, hi, sr) - lowpass(x, lo, sr)


def sweep_noise(dur, f0, f1, sr=SR):
    """噪声的频带从 f0 扫到 f1：刀风、风声"""
    n = noise(dur, sr)
    out = np.zeros_like(n)
    steps = 24
    seg = len(n) // steps
    for k in range(steps):
        f = f0 + (f1 - f0) * k / (steps - 1)
        s = slice(k * seg, (k + 1) * seg if k < steps - 1 else len(n))
        out[s] = bandpass(n[s], f * 0.6, f * 1.4, sr)
    return out


def tone(freq, dur, sr=SR, harm=((1, 1.0),), decay=0.3, attack=0.002):
    tt = t(dur, sr)
    x = sum(a * np.sin(2 * np.pi * freq * h * tt) for h, a in harm)
    return x * env(dur, attack, decay, sr)


def metal(freq, dur, decay=0.35):
    """金属撞击：几个不成整数倍的泛音"""
    tt = t(dur)
    parts = [(1.0, 1.0), (2.76, 0.6), (5.4, 0.35), (8.93, 0.2), (1.5, 0.3)]
    x = sum(a * np.sin(2 * np.pi * freq * r * tt) * np.exp(-tt / (decay / (1 + r * 0.25))) for r, a in parts)
    return x + 0.4 * noise(dur) * np.exp(-tt / 0.01)


def thud(freq, dur, decay=0.12):
    tt = t(dur)
    f = freq * (1 + 1.5 * np.exp(-tt / 0.02))
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-tt / decay)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def delay(x, sec, gain, sr=SR):
    d = int(sec * sr)
    out = np.concatenate([x, np.zeros(d)])
    out[d:] += x * gain
    return out


# ---------------- 音效 ----------------

def sfx():
    S = {}
    S["slash"] = sweep_noise(0.16, 1200, 3800) * env(0.16, 0.01, 0.06)
    S["slash_heavy"] = mix(sweep_noise(0.26, 500, 2200) * env(0.26, 0.02, 0.1), thud(90, 0.2) * 0.4)
    S["hit"] = mix(thud(140, 0.18, 0.06) * 0.9, bandpass(noise(0.12), 400, 2500) * env(0.12, 0.001, 0.03) * 0.7)
    S["hit_heavy"] = mix(thud(80, 0.35, 0.12), bandpass(noise(0.2), 200, 1800) * env(0.2, 0.001, 0.05) * 0.8)
    S["block"] = mix(metal(320, 0.3, 0.12) * 0.7, thud(160, 0.12, 0.04) * 0.4)
    # 弹反：清亮的一声“叮”，带一点余音
    S["parry"] = delay(mix(metal(1180, 0.9, 0.5), metal(1770, 0.6, 0.3) * 0.4,
                           bandpass(noise(0.05), 3000, 9000) * env(0.05, 0.0005, 0.01) * 0.8), 0.07, 0.25)
    S["mikiri"] = mix(sweep_noise(0.3, 600, 4000) * env(0.3, 0.02, 0.12) * 0.6, metal(1500, 0.6, 0.3) * 0.5)
    S["execute"] = mix(thud(55, 0.9, 0.35), metal(220, 1.0, 0.6) * 0.5, bandpass(noise(0.4), 100, 1200) * env(0.4, 0.002, 0.1))
    S["posture_break"] = mix(metal(150, 1.2, 0.7) * 0.8, thud(70, 0.5, 0.2) * 0.5)
    S["guard_break"] = mix(metal(260, 0.5, 0.2) * 0.7, thud(100, 0.25, 0.08) * 0.6)
    S["hurt"] = mix(thud(110, 0.25, 0.08), bandpass(noise(0.15), 300, 1500) * env(0.15, 0.001, 0.04) * 0.6)
    S["dodge"] = sweep_noise(0.18, 800, 2400) * env(0.18, 0.03, 0.06) * 0.7
    S["jump"] = sweep_noise(0.1, 600, 1600) * env(0.1, 0.005, 0.03) * 0.5
    S["land"] = thud(120, 0.12, 0.03) * 0.6
    S["drink"] = mix(*[np.concatenate([np.zeros(int(k * 0.11 * SR)), tone(260 + k * 30, 0.08, decay=0.03)]) for k in range(3)])
    S["heal"] = mix(*[np.concatenate([np.zeros(int(k * 0.06 * SR)), tone(f, 0.4, harm=((1, 1), (2, 0.3)), decay=0.2)])
                      for k, f in enumerate([660, 880, 1320])])
    # 危：只狼那一声低沉的警告
    S["danger"] = mix(tone(110, 0.5, harm=((1, 1), (2, 0.5), (3, 0.3)), decay=0.25), thud(70, 0.3, 0.1) * 0.6,
                      metal(440, 0.4, 0.15) * 0.25)
    S["art"] = mix(sweep_noise(0.4, 400, 3000) * env(0.4, 0.05, 0.15), tone(520, 0.4, decay=0.15) * 0.3)
    S["wave"] = mix(sweep_noise(0.35, 2500, 6000) * env(0.35, 0.01, 0.12) * 0.7, tone(990, 0.35, decay=0.12) * 0.3)
    S["throw"] = sweep_noise(0.12, 2000, 5000) * env(0.12, 0.005, 0.03) * 0.6
    S["boom"] = mix(thud(60, 0.6, 0.18), lowpass(noise(0.5), 1500) * env(0.5, 0.001, 0.12) * 1.2,
                    bandpass(noise(0.08), 2000, 8000) * env(0.08, 0.0005, 0.02))
    S["smoke"] = lowpass(noise(0.6), 900) * env(0.6, 0.05, 0.2)
    S["flame"] = bandpass(noise(0.5), 300, 3000) * env(0.5, 0.03, 0.25) * (1 + 0.4 * np.sin(2 * np.pi * 25 * t(0.5)))
    S["hook"] = mix(metal(900, 0.15, 0.05) * 0.4, sweep_noise(0.25, 1200, 400) * env(0.25, 0.01, 0.1) * 0.6)
    S["bow"] = mix(tone(180, 0.25, harm=((1, 1), (2, 0.5), (3, 0.25)), decay=0.07), sweep_noise(0.15, 2000, 4000) * env(0.15, 0.01, 0.04) * 0.4)
    S["coin"] = mix(tone(1568, 0.12, decay=0.04), np.concatenate([np.zeros(int(0.05 * SR)), tone(2093, 0.15, decay=0.05)]))
    S["jade"] = delay(mix(tone(1047, 0.5, harm=((1, 1), (2.01, 0.3)), decay=0.25), tone(1568, 0.5, decay=0.2) * 0.5), 0.09, 0.3)
    S["pot"] = mix(bandpass(noise(0.3), 800, 5000) * env(0.3, 0.001, 0.06), thud(200, 0.12, 0.03) * 0.5)
    S["chest"] = mix(thud(150, 0.2, 0.05) * 0.5, *[np.concatenate([np.zeros(int(k * 0.07 * SR)), tone(f, 0.3, decay=0.15) * 0.5])
                                                for k, f in enumerate([784, 988, 1175])])
    S["door"] = mix(thud(90, 0.4, 0.15) * 0.6, lowpass(noise(0.4), 600) * env(0.4, 0.02, 0.15) * 0.5)
    S["reward"] = mix(*[np.concatenate([np.zeros(int(k * 0.08 * SR)), tone(f, 0.6, harm=((1, 1), (2, 0.25)), decay=0.3)])
                        for k, f in enumerate([523, 659, 784, 1047])])
    S["memory"] = delay(mix(*[np.concatenate([np.zeros(int(k * 0.15 * SR)), tone(f, 1.2, harm=((1, 1), (3, 0.15)), decay=0.6)])
                              for k, f in enumerate([440, 554, 659])]), 0.2, 0.35)
    S["death"] = mix(tone(98, 1.4, harm=((1, 1), (1.5, 0.4)), decay=0.6), lowpass(noise(1.0), 400) * env(1.0, 0.05, 0.4) * 0.5)
    S["boss"] = mix(thud(45, 1.6, 0.7), metal(130, 1.8, 1.0) * 0.6)
    S["ui_move"] = tone(880, 0.05, decay=0.015) * 0.5
    S["ui_select"] = mix(tone(660, 0.12, decay=0.05), np.concatenate([np.zeros(int(0.04 * SR)), tone(990, 0.12, decay=0.05)]))
    S["ui_back"] = tone(440, 0.1, decay=0.04) * 0.6
    S["step"] = bandpass(noise(0.05), 200, 1200) * env(0.05, 0.001, 0.012) * 0.4
    for name, x in S.items():
        write(os.path.join(ROOT, "sfx", name + ".wav"), x, SR)
    return len(S)


# ---------------- 背景音乐 ----------------
# 都是五声音阶的小段，拨弦（Karplus-Strong）+ 竹笛（带颤音的正弦）+ 太鼓 + 持续低音，长度是小节的整数倍，首尾接得上

def pluck(freq, dur, sr=MSR, damp=0.996):
    n = int(dur * sr)
    period = max(2, int(sr / freq))
    buf = rng.uniform(-1, 1, period)
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = damp * 0.5 * (buf[i % period] + buf[(i + 1) % period])
    return out * np.exp(-np.arange(n) / sr / (dur * 0.5))


def flute(freq, dur, sr=MSR):
    tt = t(dur, sr)
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.2 * tt) * np.minimum(tt / 0.3, 1)
    ph = 2 * np.pi * np.cumsum(freq * vib) / sr
    body = np.sin(ph) + 0.2 * np.sin(2 * ph) + 0.08 * np.sin(3 * ph)
    breath = lowpass(rng.uniform(-1, 1, len(tt)), 3000, sr) * 0.06
    a = np.minimum(tt / 0.08, 1) * np.minimum((dur - tt) / 0.15, 1)
    return (body + breath) * np.clip(a, 0, 1)


def taiko(sr=MSR, big=True):
    dur = 0.6 if big else 0.25
    tt = t(dur, sr)
    f = (70 if big else 140) * (1 + np.exp(-tt / 0.03))
    ph = 2 * np.pi * np.cumsum(f) / sr
    return np.sin(ph) * np.exp(-tt / (0.18 if big else 0.06)) + lowpass(rng.uniform(-1, 1, len(tt)), 800, sr) * np.exp(-tt / 0.02) * 0.3


def place(track, x, at, gain=1.0, sr=MSR):
    i = int(at * sr)
    j = min(len(track), i + len(x))
    track[i:j] += x[:j - i] * gain


def note(root, deg):
    """五声音阶：宫商角徵羽（0 2 4 7 9），deg 可以超过 5 往上一组"""
    scale = [0, 2, 4, 7, 9]
    octv, k = divmod(deg, 5)
    return root * 2 ** ((scale[k] + 12 * octv) / 12)


def music_track(name, bpm, bars, root, melody, drums, flute_line, drone_gain, mood_dark=False):
    beat = 60.0 / bpm
    total = bars * 4 * beat
    tr = np.zeros(int(total * MSR) + MSR)
    # 低音持续
    tt = t(total, MSR)
    drone = np.sin(2 * np.pi * root / 2 * tt) + 0.4 * np.sin(2 * np.pi * root * 0.75 * tt)
    if mood_dark:
        drone += 0.3 * np.sin(2 * np.pi * root * 0.53 * tt)
    place(tr, drone * drone_gain * (0.8 + 0.2 * np.sin(2 * np.pi * tt / (beat * 8))), 0)
    # 拨弦旋律：melody 是 [(第几拍, 音阶位置, 拍数)]，一段旋律重复填满
    span = max(b + d for b, _, d in melody)
    rep = 0
    while rep * span < bars * 4:
        for b, deg, d in melody:
            at = (rep * span + b) * beat
            if at < total:
                place(tr, pluck(note(root * 2, deg), d * beat + 0.5), at, 0.5)
        rep += 1
    # 鼓：drums 是一小节里的 [(拍, 大鼓?)]
    for bar in range(bars):
        for b, big in drums:
            place(tr, taiko(big=big), (bar * 4 + b) * beat, 0.7 if big else 0.35)
    # 笛子：隔几小节吹一句
    for start_bar, line in flute_line:
        at = start_bar * 4 * beat
        for b, deg, d in line:
            place(tr, flute(note(root * 4, deg), d * beat), at + b * beat, 0.28)
    # 首尾接上：把多出来的尾巴叠回开头
    n = int(total * MSR)
    tr[:len(tr) - n] += tr[n:]
    tr = tr[:n]
    write(os.path.join(ROOT, "music", name + ".wav"), tr, MSR)


def music():
    # 破庙：慢、安静，只有拨弦和远远的笛子
    music_track("hub", 66, 8, 196.0,
                [(0, 4, 2), (2, 3, 1), (3, 2, 1), (4, 0, 3), (8, 2, 1), (9, 3, 1), (10, 4, 2), (12, 1, 4)],
                [], [(2, [(0, 7, 3), (3, 6, 1), (4, 5, 4)]), (6, [(0, 5, 2), (2, 4, 2), (4, 2, 4)])], 0.18)
    # 荒村：紧一点，有太鼓
    music_track("village", 92, 8, 220.0,
                [(0, 2, 1), (1, 4, 1), (2, 5, 1), (3, 4, 1), (4, 2, 2), (6, 1, 1), (7, 0, 1),
                 (8, 2, 1), (9, 4, 1), (10, 7, 2), (12, 5, 1), (13, 4, 1), (14, 2, 2)],
                [(0, True), (2.5, False), (3, True)], [(4, [(0, 9, 2), (2, 7, 2), (4, 5, 4)])], 0.14)
    # 竹林古寺：笛子为主，空灵
    music_track("bamboo", 76, 8, 233.08,
                [(0, 0, 2), (3, 2, 1), (4, 4, 2), (7, 3, 1), (8, 2, 3), (12, 0, 4)],
                [(0, True)], [(0, [(0, 7, 2), (2, 9, 2), (4, 7, 1), (5, 5, 3)]), (2, [(0, 5, 2), (2, 4, 2), (4, 2, 4)]),
                              (4, [(0, 9, 3), (3, 7, 1), (4, 10, 4)]), (6, [(0, 7, 2), (2, 5, 2), (4, 4, 4)])], 0.16)
    # 头目：快、重，太鼓密
    music_track("boss", 128, 8, 174.61,
                [(0, 0, 0.5), (0.5, 0, 0.5), (1, 2, 0.5), (1.5, 3, 0.5), (2, 4, 1), (3, 3, 1),
                 (4, 0, 0.5), (4.5, 0, 0.5), (5, 2, 0.5), (5.5, 4, 0.5), (6, 5, 1), (7, 4, 1)],
                [(0, True), (1, False), (1.5, False), (2, True), (3, False), (3.5, True)],
                [(4, [(0, 7, 1), (1, 8, 1), (2, 9, 2)]), (6, [(0, 9, 1), (1, 8, 1), (2, 7, 2)])], 0.2, True)


if __name__ == "__main__":
    n = sfx()
    music()
    print("音效 %d 个，音乐 4 首" % n)
