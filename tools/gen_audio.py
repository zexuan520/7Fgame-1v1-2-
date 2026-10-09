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
    # 头目登场：一记铜管味的和弦重音加镲片（不用锣，不要日式味）
    stab = mix(*[tone(f, 1.4, harm=((1, 1), (2, 0.5), (3, 0.35), (4, 0.2)), decay=0.5, attack=0.01) for f in (110, 165, 220, 262)])
    S["boss"] = mix(stab * 0.8, thud(50, 1.0, 0.3) * 0.8, bandpass(noise(1.4), 3000, 10000) * env(1.4, 0.002, 0.45) * 0.5)
    S["ui_move"] = tone(880, 0.05, decay=0.015) * 0.5
    S["ui_select"] = mix(tone(660, 0.12, decay=0.05), np.concatenate([np.zeros(int(0.04 * SR)), tone(990, 0.12, decay=0.05)]))
    S["ui_back"] = tone(440, 0.1, decay=0.04) * 0.6
    S["step"] = bandpass(noise(0.05), 200, 1200) * env(0.05, 0.001, 0.012) * 0.4
    for name, x in S.items():
        write(os.path.join(ROOT, "sfx", name + ".wav"), x, SR)
    return len(S)


# ---------------- 背景音乐 ----------------
# 轻快的大调小段（头目战用小调）：和弦进行 + 木琴琶音 + 主旋律 + 贝斯 + 轻鼓组。
# 每首长度是小节的整数倍，尾巴叠回开头，首尾接得上。

MAJOR = [0, 2, 4, 5, 7, 9, 11]
MINOR = [0, 2, 3, 5, 7, 8, 10]


def pitch(root, scale, deg):
    """音阶上第 deg 级（0 = 主音，可以是负数或超过 7）"""
    octv, k = divmod(int(deg), 7)
    return root * 2 ** ((scale[k] + 12 * octv) / 12)


def marimba(freq, dur, sr=MSR):
    tt = t(dur, sr)
    return (np.sin(2 * np.pi * freq * tt) * np.exp(-tt / 0.22)
            + 0.35 * np.sin(2 * np.pi * freq * 4 * tt) * np.exp(-tt / 0.04)
            + 0.08 * np.sin(2 * np.pi * freq * 10 * tt) * np.exp(-tt / 0.01))


def lead(freq, dur, sr=MSR, soft=False):
    """主旋律：柔和的方波（只取奇次谐波、再低通），轻微颤音，起音不硬"""
    tt = t(dur + 0.12, sr)
    vib = 1 + 0.003 * np.sin(2 * np.pi * 5.5 * tt) * np.clip((tt - 0.15) / 0.2, 0, 1)
    ph = 2 * np.pi * np.cumsum(freq * vib) / sr
    if soft:
        body = np.sin(ph) + 0.15 * np.sin(2 * ph)
    else:
        body = np.sin(ph) + np.sin(3 * ph) / 3 * 0.6 + np.sin(5 * ph) / 5 * 0.3
    a = np.clip(tt / 0.015, 0, 1) * np.clip((dur + 0.12 - tt) / 0.12, 0, 1) * (0.75 + 0.25 * np.exp(-tt / 0.1))
    return body * a


def bass(freq, dur, sr=MSR):
    tt = t(dur, sr)
    body = np.sin(2 * np.pi * freq * tt) + 0.35 * np.sin(4 * np.pi * freq * tt) + 0.12 * np.sin(6 * np.pi * freq * tt)
    return body * np.clip(tt / 0.006, 0, 1) * np.exp(-tt / max(0.08, dur * 0.7))


def kick(sr=MSR):
    tt = t(0.3, sr)
    f = 55 * (1 + 2.5 * np.exp(-tt / 0.025))
    return np.sin(2 * np.pi * np.cumsum(f) / sr) * np.exp(-tt / 0.11)


def snare(sr=MSR):
    tt = t(0.22, sr)
    return (bandpass(rng.uniform(-1, 1, len(tt)), 1500, 7000, sr) * np.exp(-tt / 0.05) * 0.8
            + np.sin(2 * np.pi * 190 * tt) * np.exp(-tt / 0.04) * 0.5)


def hat(sr=MSR, open_=False):
    dur = 0.18 if open_ else 0.05
    tt = t(dur, sr)
    x = rng.uniform(-1, 1, len(tt))
    x = x - lowpass(x, 6000, sr)
    return x * np.exp(-tt / (0.06 if open_ else 0.012))


def shaker(sr=MSR):
    tt = t(0.08, sr)
    x = bandpass(rng.uniform(-1, 1, len(tt)), 4000, 9000, sr)
    return x * np.sin(np.pi * np.clip(tt / 0.08, 0, 1)) ** 2


def place(track, x, at, gain=1.0, sr=MSR):
    i = int(at * sr)
    if i >= len(track):
        return
    j = min(len(track), i + len(x))
    track[i:j] += x[:j - i] * gain


ARPS = {
    # 一小节 8 个八分音符，弹和弦里的第几个音（0 根音 1 三音 2 五音 3 高八度根音）
    "up": [0, 1, 2, 3, 2, 1, 2, 1],
    "bounce": [0, 2, 1, 2, 3, 2, 1, 2],
    "wide": [0, 2, 3, 2, 1, 3, 2, 3],
}


def _b_section(melody, chords_a, chords_b, lift=0):
    """B 段旋律：照 A 段的节奏，每个音换成 B 段和弦里离原来最近的和弦音（可以整体抬高 lift 级）"""
    out = []
    for b, deg, d in melody:
        bar = int(b // 4)
        if bar >= len(chords_b):
            continue
        ch = chords_b[bar]
        target = deg + lift
        cands = [ch + k + 7 * o for o in range(-2, 3) for k in (0, 2, 4)]
        # 强拍落在和弦音上，弱拍保留原来的经过音
        if b % 1 == 0:
            target = min(cands, key=lambda c: (abs(c - target), c))
        out.append((b + len(chords_a) * 4, target, d))
    return out


def song(name, bpm, root, scale, chords, melody, drums, arp="up", bass_pat=(0, 2), lead_soft=False,
         lead_gain=0.32, arp_gain=0.22, bass_gain=0.42, drum_gain=1.0, echo=0.25, chords_b=None, lift=0):
    """chords：每小节一个和弦（音阶级数）；melody：[(拍, 音阶级数, 拍数)]，从第 0 小节开始，循环填满整首；
    drums：{"kick": [拍...], "snare": [...], "hat": [...], "shaker": [...]}（一小节内）"""
    beat = 60.0 / bpm
    if chords_b:
        melody = list(melody) + _b_section(melody, chords, chords_b, lift)
        chords = list(chords) + list(chords_b)
    bars = len(chords)
    total = bars * 4 * beat
    tr = np.zeros(int(total * MSR) + MSR * 2)
    for bar, ch in enumerate(chords):
        t0 = bar * 4 * beat
        tones = [pitch(root, scale, ch), pitch(root, scale, ch + 2), pitch(root, scale, ch + 4), pitch(root, scale, ch + 7)]
        # 琶音（高一个八度）
        for i, k in enumerate(ARPS[arp]):
            place(tr, marimba(tones[k] * 2, 0.6), t0 + i * beat / 2, arp_gain * (1.0 if i % 2 == 0 else 0.75))
        # 贝斯：根音，在 bass_pat 的拍子上；反拍跳一下高八度
        for b in bass_pat:
            place(tr, bass(tones[0] / 2, beat * 0.9), t0 + b * beat, bass_gain)
            place(tr, bass(tones[0], beat * 0.4), t0 + (b + 1.5) * beat, bass_gain * 0.45)
        # 鼓
        for b in drums.get("kick", []):
            place(tr, kick(), t0 + b * beat, 0.8 * drum_gain)
        for b in drums.get("snare", []):
            place(tr, snare(), t0 + b * beat, 0.45 * drum_gain)
        for b in drums.get("hat", []):
            place(tr, hat(), t0 + b * beat, 0.18 * drum_gain)
        for b in drums.get("shaker", []):
            place(tr, shaker(), t0 + b * beat, 0.16 * drum_gain)
    # 主旋律（高一个八度），带一点回声
    span = 4 * max(1, int(np.ceil(max(b + d for b, _, d in melody) / 4)))
    mel = np.zeros_like(tr)
    rep = 0
    while rep * span < bars * 4:
        for b, deg, d in melody:
            at = (rep * span + b) * beat
            if at < total:
                place(mel, lead(pitch(root * 2, scale, deg), d * beat * 0.92, soft=lead_soft), at, lead_gain)
        rep += 1
    tr += mel + delay(mel, beat * 0.75, echo, MSR)[:len(mel)]
    # 首尾接上：把多出来的尾巴叠回开头
    n = int(total * MSR)
    tr[:len(tr) - n] += tr[n:]
    tr = tr[:n]
    # 最后 10 毫秒慢慢靠到开头那个采样上，循环接缝不爆音
    k = int(0.01 * MSR)
    tr[-k:] = tr[-k:] + (tr[0] - tr[-1]) * np.linspace(0, 1, k)
    write(os.path.join(ROOT, "music", name + ".wav"), tr, MSR)


def music():
    # 破庙：温和轻快，回到据点歇口气
    song("hub", 96, 174.61, MAJOR, [0, 5, 3, 4, 0, 5, 3, 4],
         [(0, 4, 1), (1, 2, 0.5), (1.5, 4, 0.5), (2, 5, 1), (3, 4, 1),
          (4, 2, 1.5), (5.5, 0, 0.5), (6, 1, 1), (7, 2, 1),
          (8, 3, 1), (9, 5, 1), (10, 7, 1), (11, 5, 1),
          (12, 4, 2), (14, 6, 1), (15, 4, 1),
          (16, 7, 1), (17, 6, 0.5), (17.5, 7, 0.5), (18, 9, 1), (19, 7, 1),
          (20, 5, 2), (22, 4, 1), (23, 2, 1),
          (24, 3, 1), (25, 2, 1), (26, 3, 1), (27, 5, 1),
          (28, 6, 1), (29, 4, 1), (30, 1, 2)],
         {"kick": [0, 2.5], "shaker": [0.5, 1.5, 2.5, 3.5], "snare": [3]},
         arp="up", bass_pat=(0, 2), lead_soft=True, lead_gain=0.3, drum_gain=0.6, chords_b=[3, 4, 2, 5, 3, 4, 0, 0])
    # 荒村：出发冒险，蹦蹦跳跳
    song("village", 124, 196.0, MAJOR, [0, 4, 5, 3, 0, 4, 3, 4],
         [(0, 4, 0.5), (0.5, 4, 0.5), (1, 5, 0.5), (1.5, 4, 0.5), (2, 2, 1), (3, 4, 1),
          (4, 4, 0.5), (4.5, 6, 0.5), (5, 8, 1), (6, 6, 1), (7, 4, 1),
          (8, 5, 0.5), (8.5, 5, 0.5), (9, 7, 0.5), (9.5, 5, 0.5), (10, 4, 1), (11, 2, 1),
          (12, 3, 1), (13, 2, 0.5), (13.5, 3, 0.5), (14, 4, 2),
          (16, 7, 1), (17, 6, 0.5), (17.5, 5, 0.5), (18, 4, 1), (19, 2, 1),
          (20, 1, 0.5), (20.5, 2, 0.5), (21, 4, 1), (22, 6, 2),
          (24, 5, 1), (25, 7, 1), (26, 8, 0.5), (26.5, 7, 0.5), (27, 5, 1),
          (28, 4, 1.5), (29.5, 6, 0.5), (30, 4, 2)],
         {"kick": [0, 1.5, 2], "snare": [1, 3], "hat": [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5]},
         arp="bounce", bass_pat=(0, 2), lead_gain=0.3, chords_b=[5, 3, 0, 4, 5, 3, 1, 4], lift=2)
    # 竹林古寺：清亮，风吹竹叶的感觉
    song("bamboo", 108, 146.83, MAJOR, [0, 2, 3, 4, 5, 3, 0, 4],
         [(0, 7, 1.5), (1.5, 8, 0.5), (2, 9, 1), (3, 7, 1),
          (4, 6, 2), (6, 4, 1), (7, 6, 1),
          (8, 5, 1), (9, 7, 1), (10, 10, 1.5), (11.5, 9, 0.5),
          (12, 8, 3), (15, 6, 1),
          (16, 9, 1.5), (17.5, 8, 0.5), (18, 7, 1), (19, 5, 1),
          (20, 5, 1), (21, 6, 1), (22, 7, 2),
          (24, 9, 1), (25, 7, 1), (26, 4, 1), (27, 7, 1),
          (28, 6, 2), (30, 8, 2)],
         {"kick": [0, 2], "snare": [3], "shaker": [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5]},
         arp="wide", bass_pat=(0, 2), lead_soft=True, lead_gain=0.32, drum_gain=0.75, echo=0.3,
         chords_b=[3, 4, 5, 2, 3, 1, 4, 4])
    # 头目：快、有劲（小调，但不是日式音阶）
    song("boss", 148, 220.0, MINOR, [0, 5, 2, 6, 0, 5, 3, 4],
         [(0, 4, 0.5), (0.5, 4, 0.5), (1, 7, 1), (2, 6, 0.5), (2.5, 4, 0.5), (3, 2, 1),
          (4, 2, 0.5), (4.5, 4, 0.5), (5, 5, 1), (6, 4, 1), (7, 2, 1),
          (8, 4, 0.5), (8.5, 4, 0.5), (9, 7, 1), (10, 9, 1), (11, 8, 1),
          (12, 6, 2), (14, 4, 1), (15, 6, 1),
          (16, 7, 1), (17, 9, 1), (18, 8, 0.5), (18.5, 7, 0.5), (19, 6, 1),
          (20, 7, 0.5), (20.5, 6, 0.5), (21, 4, 1), (22, 2, 2),
          (24, 3, 1), (25, 5, 1), (26, 7, 1), (27, 8, 1),
          (28, 6, 2), (30, 4, 1), (31, 6, 1)],
         {"kick": [0, 1, 2, 3], "snare": [1, 3], "hat": [0.5, 1.5, 2.5, 3.5], "shaker": [0.25, 0.75, 1.25, 1.75, 2.25, 2.75, 3.25, 3.75]},
         arp="bounce", bass_pat=(0, 1, 2, 3), lead_gain=0.3, bass_gain=0.36, chords_b=[5, 6, 0, 0, 3, 4, 5, 4], lift=2)


if __name__ == "__main__":
    n = sfx()
    music()
    print("音效 %d 个，音乐 4 首" % n)
