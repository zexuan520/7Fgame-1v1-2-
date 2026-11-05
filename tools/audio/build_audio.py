"""把 CC0 音频素材处理成游戏用的音效变体和背景音乐（需要 ffmpeg）。

用法：python tools/audio/build_audio.py 素材目录
素材目录里放 OpenGameArt 下载的原始压缩包和音乐（出处见素材目录的 SOURCES.md，
项目共享盘上是 /mnt/project-files/asset-library/audio-cc0/）。

输出：
  assets/sfx/<名字>/0.ogg 1.ogg ...   同一个音效的几个变体，游戏里随机挑一个（Game.sfx）
  assets/music/<曲名>.ogg             背景音乐，统一响度，循环播放（Game.music）
没列在这里的音效仍然用 assets/sfx/<名字>.wav 的合成占位声。
"""
import os, subprocess, sys, tempfile, zipfile, shutil

SRC = sys.argv[1] if len(sys.argv) > 1 else "/mnt/project-files/asset-library/audio-cc0"
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SFX_OUT = os.path.join(ROOT, "assets", "sfx")
MUSIC_OUT = os.path.join(ROOT, "assets", "music")

ZIPS = ["swishes.zip", "rpg_sound_pack.zip", "RPGsounds_Kenney.zip", "sfx_breaking_and_falling.zip",
        "sword_-_starninjas_1.zip", "sword_clash_-_starninjas_0.zip", "impact_-_starninjas.zip", "tinysized.zip"]

SW = "swishes/swishes/swish-%d.wav"
RPG = "rpg_sound_pack/RPG Sound Pack/%s.wav"
KEN = "RPGsounds_Kenney/OGG/%s.ogg"
BFH = "sfx_breaking_and_falling/bfh1_%s.ogg"
CLASH = "sword_clash_-_starninjas_0/sword_clash.%d.ogg"
TINY = "tinysized/sfx-cc0/%s.wav"

# 每个音效：变体列表。每个变体是 [(文件, 音量 dB, 音高倍数)...]，多个文件叠在一起；
# 后面是通用处理：最长秒数、淡出秒数
SFX = {
    # 挥刀：短促的风声
    "slash": ([[(SW % i, 0, 1.0)] for i in (1, 2, 3, 4, 6, 8, 9, 10, 11, 13)], 0.35, 0.08),
    # 重挥：降调的长挥，带一点低频
    "slash_heavy": ([[(RPG % "battle/swing", 0, 0.82)], [(RPG % "battle/swing2", 0, 0.8)], [(RPG % "battle/swing3", 0, 0.85)],
                     [(SW % 12, 0, 0.75)], [(SW % 7, 0, 0.72)]], 0.5, 0.12),
    # 命中：刀切进去 + 一记闷击
    "hit": ([[(KEN % "knifeSlice", 0, 1.0), (BFH % "hit_01", -9, 1.1)],
             [(KEN % "knifeSlice2", 0, 1.0), (BFH % "hit_03", -9, 1.1)],
             [(KEN % "chop", 0, 1.05), (BFH % "hit_05", -10, 1.0)],
             [(KEN % "knifeSlice", -1, 0.92), (BFH % "hit_07", -9, 1.15)],
             [(KEN % "chop", 0, 0.95), (BFH % "hit_02", -10, 1.1)]], 0.45, 0.12),
    # 重击：低沉的砸击 + 骨头脆响
    "hit_heavy": ([[(BFH % "hit_04", 0, 0.85), (KEN % "chop", -4, 0.8), (BFH % "wood_hit_01", -8, 1.0)],
                   [(BFH % "hit_06", 0, 0.85), (KEN % "knifeSlice2", -4, 0.8), (BFH % "wood_hit_02", -8, 1.0)],
                   [(BFH % "hit_10", 0, 0.85), (KEN % "chop", -4, 0.75), (BFH % "rock_hit_01", -8, 1.0)],
                   [(BFH % "hit_12", 0, 0.85), (KEN % "knifeSlice", -4, 0.8), (BFH % "wood_hit_03", -8, 1.0)]], 0.6, 0.2),
    # 格挡 / 打在硬东西上：刀剑相击
    "block": ([[(CLASH % i, 0, 1.0)] for i in (1, 3, 5, 7, 9)], 0.5, 0.25),
    # 骷髅碎掉：木头 / 石头断裂
    "death": ([[(BFH % "wood_breaking_01", 0, 1.0)], [(BFH % "wood_breaking_02", 0, 1.0)], [(BFH % "rock_breaking_01", 0, 1.1)],
               [(BFH % "breaking_02", 0, 1.0)], [(BFH % "wood_breaking_04", 0, 1.05)]], 0.8, 0.25),
    # 脚步
    "step": ([[(KEN % ("footstep%02d" % i), 0, 1.0)] for i in range(10)], 0.3, 0.06),
    # 翻滚：布料摩擦 + 低沉的风声
    "dodge": ([[(KEN % "cloth1", 0, 1.0), (SW % 5, -6, 0.7)], [(KEN % "cloth2", 0, 1.0), (SW % 9, -6, 0.7)],
               [(KEN % "cloth3", 0, 1.0), (SW % 3, -6, 0.7)], [(KEN % "cloth4", 0, 1.0), (SW % 11, -6, 0.7)]], 0.45, 0.12),
    # 铜钱
    "coin": ([[(KEN % "handleCoins", 0, 1.0)], [(KEN % "handleCoins2", 0, 1.0)], [(TINY % "coinflip-01", 0, 1.0)]], 0.45, 0.15),
    # 开宝箱：搭扣 + 吱呀
    "chest": ([[(KEN % "metalLatch", 0, 1.0), (KEN % "creak1", -3, 1.0)], [(KEN % "metalLatch", 0, 0.95), (KEN % "creak2", -3, 1.0)]], 1.0, 0.3),
    # 光门 / 门
    "door": ([[(KEN % "doorOpen_1", 0, 0.9)], [(KEN % "doorOpen_2", 0, 0.9)]], 1.0, 0.3),
    # 喝药：拔塞子 + 倒水
    "drink": ([[(TINY % "bottle-clay-uncork-01", 0, 1.0), (TINY % "water-pour-01", -6, 1.0)]], 0.9, 0.3),
}

# 背景音乐：曲名 → (文件, 是否先解压 zip 里的路径)
MUSIC = {
    "hub": "forest_whisper_theme.zip:Forest Whisper Theme/Forest Whisper.ogg",
    "village": "GameMusic_ForestTheme_24_0.mp3",
    "bamboo": "qubodup-yd-DarkShrineLoop-OpenGameArt.ogg",
    "boss": "Juhani Junkala - Epic Boss Battle [Seamlessly Looping].wav",
    "boss2": "battleThemeA.mp3",
    "secret": "dungeon002_0.ogg",
}


def run(args):
    subprocess.run(args, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)


def main():
    tmp = tempfile.mkdtemp()
    for z in ZIPS:
        with zipfile.ZipFile(os.path.join(SRC, z)) as f:
            f.extractall(os.path.join(tmp, z[:-4]))
    for name, (variants, max_len, fade) in SFX.items():
        out_dir = os.path.join(SFX_OUT, name)
        shutil.rmtree(out_dir, ignore_errors=True)
        os.makedirs(out_dir)
        for i, layers in enumerate(variants):
            args = ["ffmpeg", "-y"]
            filt = []
            for j, (path, db, pitch) in enumerate(layers):
                args += ["-i", os.path.join(tmp, path)]
                # 去掉开头静音，变调（改采样率再重采样），调音量，转单声道
                filt.append("[%d:a]aformat=channel_layouts=mono,silenceremove=start_periods=1:start_threshold=-45dB,"
                            "asetrate=44100*%.3f,aresample=44100,volume=%ddB[l%d]" % (j, pitch, db, j))
            mix = "".join("[l%d]" % j for j in range(len(layers)))
            filt.append("%samix=inputs=%d:normalize=0,atrim=0:%.2f,afade=t=out:st=%.2f:d=%.2f,alimiter=limit=0.89[o]"
                        % (mix, len(layers), max_len, max(max_len - fade, 0.0), fade))
            args += ["-filter_complex", ";".join(filt), "-map", "[o]", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "5",
                     os.path.join(out_dir, "%d.ogg" % i)]
            run(args)
        print(name, len(variants))
    for name, src in MUSIC.items():
        if ":" in src:
            z, inner = src.split(":", 1)
            with zipfile.ZipFile(os.path.join(SRC, z)) as f:
                path = f.extract(inner, tmp)
        else:
            path = os.path.join(SRC, src)
        # 统一响度（EBU R128 -18 LUFS），立体声 44.1k，ogg
        run(["ffmpeg", "-y", "-i", path, "-af", "loudnorm=I=-18:TP=-1.5:LRA=11", "-ar", "44100", "-ac", "2",
             "-c:a", "libvorbis", "-q:a", "4", os.path.join(MUSIC_OUT, name + ".ogg")])
        print("music", name)
    shutil.rmtree(tmp)


if __name__ == "__main__":
    main()
