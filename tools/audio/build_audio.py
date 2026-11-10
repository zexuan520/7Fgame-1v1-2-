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
        "sword_-_starninjas_1.zip", "sword_clash_-_starninjas_0.zip", "impact_-_starninjas.zip", "tinysized.zip",
        # 第二、三幕加的（素材目录的 act23/ 子目录，出处同样记在 SOURCES.md）
        "act23/water-splash-slime-sfx.zip:water40", "act23/80-CC0-RPG-SFX_0.zip:rpg80", "act23/100-CC0-SFX_0.zip:sfx100"]

SW = "swishes/swishes/swish-%d.wav"
RPG = "rpg_sound_pack/RPG Sound Pack/%s.wav"
KEN = "RPGsounds_Kenney/OGG/%s.ogg"
BFH = "sfx_breaking_and_falling/bfh1_%s.ogg"
CLASH = "sword_clash_-_starninjas_0/sword_clash.%d.ogg"
TINY = "tinysized/sfx-cc0/%s.wav"
IMP = "impact_-_starninjas/impact.%d.ogg"
# 2026-11-10 第二档 H3：低频一层。SUB 是 ffmpeg 合成的下滑正弦“咚”（自制，见 s1-impact/），MEAT 是 qubodup 的 CC0 肉击
SUB = "s1-impact/sub_thump_%d.wav"
MEAT = "s1-impact/qubodupImpact/qubodupImpactMeat0%d.ogg"
PUNCH = "s1-impact/qubodupPunch/qubodupPunch0%d.ogg"
SWD = "sword_-_starninjas_1/sword - StarNinjas/sword.%d.ogg"
SHADE = "rpg_sound_pack/RPG Sound Pack/NPC/shade/shade%d.wav"
RINV = "rpg_sound_pack/RPG Sound Pack/inventory/%s.wav"
RBAT = "rpg_sound_pack/RPG Sound Pack/battle/%s.wav"
W40 = "water40/%s.ogg"
R80 = "rpg80/%s.ogg"
C100 = "sfx100/%s.ogg"
FS = "act23/fire_staff/fire_staff_%d.flac"
A23 = "act23/%s"

# 每个音效：变体列表。每个变体是 [(文件, 音量 dB, 音高倍数)...]，多个文件叠在一起；
# 后面是通用处理：最长秒数、淡出秒数
SFX = {
    # 挥刀：短促的风声
    "slash": ([[(SW % i, 0, 1.0)] for i in (1, 2, 3, 4, 6, 8, 9, 10, 11, 13)], 0.35, 0.08),
    # 重挥：降调的长挥，带一点低频
    "slash_heavy": ([[(RPG % "battle/swing", 0, 0.82)], [(RPG % "battle/swing2", 0, 0.8)], [(RPG % "battle/swing3", 0, 0.85)],
                     [(SW % 12, 0, 0.75)], [(SW % 7, 0, 0.72)]], 0.5, 0.12),
    # 命中：刀切进去 + 一记闷击
    "hit": ([[(KEN % "knifeSlice", 0, 1.0), (BFH % "hit_01", -9, 1.1), (SUB % 2, -11, 1.0)],
             [(KEN % "knifeSlice2", 0, 1.0), (BFH % "hit_03", -9, 1.1), (SUB % 0, -11, 1.05)],
             [(KEN % "chop", 0, 1.05), (BFH % "hit_05", -10, 1.0), (SUB % 2, -11, 0.95)],
             [(KEN % "knifeSlice", -1, 0.92), (BFH % "hit_07", -9, 1.15), (SUB % 0, -11, 1.0)],
             [(KEN % "chop", 0, 0.95), (BFH % "hit_02", -10, 1.1), (SUB % 2, -11, 1.1)]], 0.45, 0.12),
    # 重击：低沉的砸击 + 骨头脆响
    "hit_heavy": ([[(BFH % "hit_04", 0, 0.85), (KEN % "chop", -4, 0.8), (BFH % "wood_hit_01", -8, 1.0), (SUB % 1, -5, 1.0), (MEAT % 1, -9, 0.9)],
                   [(BFH % "hit_06", 0, 0.85), (KEN % "knifeSlice2", -4, 0.8), (BFH % "wood_hit_02", -8, 1.0), (SUB % 0, -5, 0.95), (MEAT % 2, -9, 0.9)],
                   [(BFH % "hit_10", 0, 0.85), (KEN % "chop", -4, 0.75), (BFH % "rock_hit_01", -8, 1.0), (SUB % 1, -5, 1.05), (MEAT % 1, -9, 0.85)],
                   [(BFH % "hit_12", 0, 0.85), (KEN % "knifeSlice", -4, 0.8), (BFH % "wood_hit_03", -8, 1.0), (SUB % 0, -5, 1.0), (MEAT % 2, -9, 0.95)]], 0.6, 0.2),
    # 锤、棍命中：闷重的砸击 + 地面一震（没有刀刃切肉声）
    "hit_blunt": ([[(IMP % 2, 0, 0.75), (BFH % "hit_04", -3, 0.8), (C100 % "slam_01", -9, 0.85), (SUB % 3, -4, 1.0)],
                   [(IMP % 6, 0, 0.72), (BFH % "hit_06", -3, 0.8), (C100 % "slam_03", -9, 0.85), (SUB % 1, -4, 0.95)],
                   [(IMP % 8, 0, 0.78), (BFH % "hit_10", -3, 0.85), (C100 % "slam_05", -9, 0.8), (SUB % 3, -4, 1.05)],
                   [(IMP % 10, 0, 0.74), (BFH % "wood_hit_02", -4, 0.75), (C100 % "slam_02", -9, 0.85), (SUB % 1, -4, 1.0)]], 0.55, 0.18),
    # 枪命中：短促的扎穿声（刃口高一点 + 一丝穿过去的风）
    "hit_pierce": ([[(KEN % "knifeSlice2", 0, 1.25), (R80 % "blade_01", -4, 1.2), (SW % 2, -8, 1.5)],
                    [(KEN % "knifeSlice", 0, 1.3), (R80 % "blade_02", -4, 1.15), (SW % 5, -8, 1.45)],
                    [(KEN % "knifeSlice2", 0, 1.2), (R80 % "blade_03", -4, 1.25), (SW % 8, -8, 1.5)]], 0.4, 0.12),
    # 见切：一声很亮的刀鸣 + 拉长的风声（慢镜头里听）
    "mikiri": ([[(CLASH % 3, 0, 1.45), (SW % 12, -5, 0.6), (C100 % "bell_02", -14, 1.6)],
                [(CLASH % 7, 0, 1.4), (SW % 7, -5, 0.62), (C100 % "bell_03", -14, 1.7)]], 0.9, 0.45),
    # 击杀：一声清脆的刀鸣 + 低沉的闷击（只在击杀那一下叠在命中音上）
    # 2026-11-10：垫一层低频“咚”和肉击，手机外放也听得出（SUB 带二次谐波，约 100Hz）
    "kill": ([[(IMP % i, 0, 0.8), (SWD % j, -5, 1.15), (SUB % k, -3, 1.0), (MEAT % m, -8, 0.95)]
              for i, j, k, m in ((1, 1, 1, 1), (3, 3, 0, 2), (5, 6, 1, 1), (7, 8, 3, 2), (9, 10, 0, 1))], 0.6, 0.25),
    # 会心：短促的高音刀鸣
    "crit": ([[(CLASH % i, -2, 1.3)] for i in (2, 4, 6)], 0.35, 0.15),
    # 头目倒下：很低的轰击 + 碎裂
    "boss_kill": ([[(IMP % 4, 0, 0.55), (BFH % "hit_12", -2, 0.6), (BFH % "rock_breaking_01", -4, 0.8), (SUB % 3, -1, 0.8)]], 1.6, 0.6),
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

    # ---------- 第二、三幕：小怪、机关、头目招式的专属声（FoeSfx 里按种类和招式挑） ----------
    # 水花：水骨/井鳗骨冒头、潜回，地宫涌泉
    "splash": ([[(W40 % ("splash_%02d" % i), 0, 1.0)] for i in (1, 3, 5, 7, 9, 11, 13)], 0.7, 0.2),
    # 大水：枯荣的水柱、水波、殿里涨水
    "water_big": ([[(W40 % "splash_02", 0, 0.7), (W40 % "splash_08", -3, 0.6), (W40 % "bubble_01", -6, 0.8)],
                   [(W40 % "splash_04", 0, 0.7), (W40 % "splash_12", -3, 0.6), (W40 % "bubble_02", -6, 0.8)],
                   [(W40 % "splash_06", 0, 0.65), (W40 % "splash_14", -3, 0.62), (W40 % "bubble_03", -6, 0.8)]], 1.4, 0.5),
    # 铁链：灯奴僧、枯荣、不夜将军的横扫
    "chain": ([[(R80 % ("chain_%02d" % i), 0, p), (SW % j, -6, 0.75)] for i, j, p in ((1, 12, 1.0), (2, 7, 0.95), (3, 10, 1.05))], 0.8, 0.25),
    # 长枪直刺：短促的破风 + 枪头的金属声
    "spear": ([[(SW % i, 0, 1.25), (R80 % ("blade_%02d" % j), -5, 1.1)] for i, j in ((1, 1), (4, 2), (8, 3), (11, 1))], 0.4, 0.12),
    # 镇魂铃 / 引魂灯童：小铃
    "bell_ward": ([[(C100 % "bell_01", 0, 1.0)], [(C100 % "bell_03", 0, 1.05)], [(A23 % "bell_ding1.wav", -2, 1.0)], [(A23 % "bell_ding3.wav", -2, 0.95)]], 1.6, 0.6),
    # 回血的灯：清脆的宝石声 + 一点法术
    "chime": ([[(R80 % ("item_gem_%02d" % i), 0, 1.0), (RBAT % "magic1", -10, 1.2)] for i in (1, 2, 3, 4)], 0.9, 0.35),
    # 锣：头目狂暴、长明帝点灯
    "gong": ([[(C100 % "gong_01", 0, 0.8)], [(C100 % "gong_02", 0, 0.75)]], 2.2, 0.9),
    # 号角：灰衣旗手举旗、头目叫人、押灯将列阵
    "horn": ([[(A23 % "theircoming.ogg", 0, 1.0, 0.0)], [(A23 % "theircoming.ogg", 0, 1.0, 10.4)], [(A23 % "theircoming3.ogg", 0, 1.0, 0.0)]], 1.8, 0.6),
    # 战鼓：旗手举旗那一下、灰衣营的号令
    "war_drum": ([[(A23 % "horde_war_drums.flac", 0, 1.0, t)] for t in (0.0, 2.1, 4.3, 8.6)], 1.6, 0.4),
    # 马蹄：冲骑、幽骑、押灯将的幽骑列阵
    "hooves": ([[(A23 % "Trot.ogg", 5, 1.35, t)] for t in (0.0, 2.0, 5.0, 9.5)], 1.1, 0.3),
    # 火：起火、火罐落地、天火、火场一圈
    "fire_burst": ([[(FS % i, 0, 1.0), (R80 % ("spell_fire_%02d" % j), -6, 1.0)] for i, j in ((1, 1), (3, 3), (6, 4), (8, 6), (11, 7))], 1.1, 0.4),
    # 施火法：焦明、提炉官、纵火手抬手那一下（呼的一声）
    "fire_cast": ([[(FS % i, 0, 1.0)] for i in (13, 15, 16, 17, 19)], 1.2, 0.4),
    # 罐子碎：泼油俑、纵火手、提炉官扔的罐子落地；灯童、护体灯碎掉
    "jar_break": ([[(BFH % ("glass_breaking_%02d" % i), 0, 1.0), (C100 % ("pot_%02d" % (1 + i % 2)), -4, 0.9)] for i in (1, 2, 3, 4, 5)], 0.9, 0.3),
    # 金属甲：刀砍在铜甲、金甲上
    "armor_clank": ([[(C100 % ("metal_%02d" % i), 0, 1.0), (RINV % "chainmail1", -8, 1.0)] for i in (1, 3, 5, 7, 9, 11)], 0.5, 0.2),
    # 甲士倒地：一堆铁片砸地
    "armor_fall": ([[(BFH % ("metal_falling_%02d" % i), 0, 0.9), (BFH % "hit_04", -6, 0.8)] for i in (1, 2, 3, 4, 5)], 1.2, 0.4),
    # 活人倒地：灰衣营、驿卒、灯兵（不是骨头碎）
    "body_fall": ([[(BFH % ("falling_%02d" % i), 0, 0.85), (KEN % "dropLeather", -3, 0.9), (KEN % ("cloth%d" % (1 + i % 4)), -6, 1.0)] for i in (1, 2, 3, 4, 5)], 0.9, 0.3),
    # 鬼：宫灯魂闪身、烬影/宫人魂/幽骑出现、死掉
    "ghost": ([[(SHADE % i, 0, 1.0)] for i in (1, 3, 5, 7, 9, 11)] + [[(A23 % "ghostbreath.flac", 18, 1.0)]], 1.4, 0.5),
    # 稻草人：草秆折断 + 布料
    "straw": ([[(TINY % "wood-twigs-break-01", 0, 1.0), (KEN % "cloth3", -4, 0.9)], [(TINY % "wood-twigs-break-02", 0, 1.0), (KEN % "cloth1", -4, 0.9)]], 0.7, 0.2),
    # 爬起来：灯兵再站起来、殉灯俑复活
    "rise": ([[(RBAT % "spell", 0, 0.8), (BFH % "wood_hit_02", -6, 0.8)], [(RBAT % "magic1", 0, 0.75), (BFH % "wood_hit_03", -6, 0.8)]], 1.2, 0.4),
    # 金光：长明帝的光柱、金光扇
    "holy": ([[(R80 % "spell_01", 0, 0.9), (C100 % "bell_02", -6, 0.8)], [(R80 % "spell_02", 0, 0.9), (C100 % "bell_01", -8, 0.7)]], 1.3, 0.5),
    # 箭落地：营地箭雨、押灯将箭雨（一声闷的扎地）
    "arrow_hit": ([[(BFH % ("wood_hit_%02d" % i), 0, 1.3), (KEN % "knifeSlice", -6, 1.2)] for i in (1, 2, 3)], 0.35, 0.12),
    # 箭雨放出去：一片破风
    "arrow_volley": ([[(SW % 3, 0, 1.4), (SW % 6, -2, 1.3, 0, 70), (SW % 10, -3, 1.5, 0, 150), (SW % 4, -4, 1.35, 0, 240)],
                      [(SW % 2, 0, 1.4), (SW % 9, -2, 1.3, 0, 90), (SW % 13, -3, 1.5, 0, 170), (SW % 8, -4, 1.35, 0, 260)]], 0.7, 0.3),
    # 铜汁滴下来：嗞的一声
    "sizzle": ([[(FS % 7, 0, 1.4), (TINY % "compressed-air-spray-01", -8, 0.8)], [(FS % 9, 0, 1.4), (TINY % "compressed-air-spray-02", -8, 0.8)]], 0.7, 0.3),
}

# 背景音乐：曲名 → 文件（"压缩包:里面的路径" 先解压），或者 {"src": 文件, "cut": (从第几秒, 到第几秒), "fade": (淡入, 淡出), "q": 质量}
# cut/fade 给不是循环曲的去掉开头结尾的静音、免得循环时断一截；q 是 libvorbis 质量（不写就用 MUSIC_Q）
# 网页版整个包要先下完才能玩，音乐占大头：q0 约 64kbps，18 首约 11MB（原来 q2~q4 约 21MB）
MUSIC_Q = 0
SFX_Q = 3   # 音效是短的单声道，q3 听不出区别

MUSIC = {
    # 2026-11-10 第二档 S1：标题、山门、歇脚房换国风（Tozan 的 CC0 曲，OpenGameArt）；原来的林间曲不再用
    "hub": {"src": "s1-oriental/asianoriental2_0.ogg"},     # 山门 / 标题：古筝 + 笛 + 弦，作者说是“中国风”
    "calm": {"src": "s1-oriental/orien1_0.ogg"},            # 商人、土地庙、奇遇、故人房：Orient Peace Valley
    "village": "GameMusic_ForestTheme_24_0.mp3",
    "bamboo": "qubodup-yd-DarkShrineLoop-OpenGameArt.ogg",
    "boss": "Juhani Junkala - Epic Boss Battle [Seamlessly Looping].wav",
    "boss2": "battleThemeA.mp3",
    "secret": "dungeon002_0.ogg",
    # ---------- 第二幕 · 入山 ----------
    "well": {"src": "act23/music/cursed_tower.ogg"},                   # 青井地宫：闹鬼的低音 + 鼓点
    "vault": {"src": "act23/music/great_labyrinth.ogg"},               # 烛国灯冢：管弦地宫曲，又悲又重
    "camp": {"src": "act23/music/march_loop.flac"},                    # 灰衣营：行军鼓
    "boss_well": {"src": "act23/music/dramatic_boss.flac", "cut": (0, 37.9), "fade": (0.05, 0.6)},   # 枯荣：鼓 + 提琴
    "boss_vault": {"src": "act23/music/heavy_boss2.ogg"},              # 不夜将军：沉重的头目曲
    "boss_camp": {"src": "act23/music/determined_pursuit.flac"},       # 烬：急促的弦乐和号
    # ---------- 第三幕 · 出山 ----------
    "liuxi": {"src": "act23/music/looted_village.ogg"},                # 柳溪村：回乡发现村子遭了劫
    "post": {"src": "act23/music/last_journey.mp3", "cut": (0, 59.3), "fade": (0.05, 1.5)},   # 官道驿站：管弦行路曲
    "palace": {"src": "act23/music/journey_noname.mp3"},               # 长明宫：宏大的史诗配乐
    "boss_liuxi": {"src": "act23/music/fire_dragon_loop.flac", "cut": (0.96, 0)},   # 火师焦明：火龙
    "boss_post": {"src": "act23/music/call_to_war.flac"},              # 押灯将霍长风：军鼓和号
    "boss_palace": {"src": "act23/music/epic_endgame.flac", "cut": (0, 89.3), "fade": (0.05, 1.2)},  # 长明帝：女声合唱 + 号 + 低音
}


def run(args):
    subprocess.run(args, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)


def main():
    tmp = tempfile.mkdtemp()
    for z in ZIPS:
        z, _, into = z.partition(":")
        with zipfile.ZipFile(os.path.join(SRC, z)) as f:
            f.extractall(os.path.join(tmp, into or os.path.basename(z)[:-4]))
    only = [x for x in os.environ.get("ONLY", "").split(",") if x]   # ONLY=kill,crit 只重做这几个
    for name, (variants, max_len, fade) in SFX.items():
        if only and name not in only:
            continue
        out_dir = os.path.join(SFX_OUT, name)
        shutil.rmtree(out_dir, ignore_errors=True)
        os.makedirs(out_dir)
        for i, layers in enumerate(variants):
            args = ["ffmpeg", "-y"]
            filt = []
            for j, layer in enumerate(layers):
                path, db, pitch = layer[:3]
                p = os.path.join(tmp, path)
                if not os.path.exists(p):
                    p = os.path.join(SRC, path)     # 不在压缩包里的单个文件
                if len(layer) > 3 and layer[3] > 0:
                    args += ["-ss", "%.2f" % layer[3]]   # 从长录音里截一段（号角、马蹄、鼓）
                args += ["-i", p]
                delay = layer[4] if len(layer) > 4 else 0   # 第五项：晚几毫秒进来（一片箭雨错开）
                # 去掉开头静音，变调（改采样率再重采样），调音量，转单声道
                filt.append("[%d:a]aformat=channel_layouts=mono,silenceremove=start_periods=1:start_threshold=-45dB,"
                            "asetrate=44100*%.3f,aresample=44100,volume=%ddB,adelay=%d[l%d]" % (j, pitch, db, delay, j))
            mix = "".join("[l%d]" % j for j in range(len(layers)))
            filt.append("%samix=inputs=%d:normalize=0,atrim=0:%.2f,afade=t=out:st=%.2f:d=%.2f,alimiter=limit=0.89[o]"
                        % (mix, len(layers), max_len, max(max_len - fade, 0.0), fade))
            args += ["-filter_complex", ";".join(filt), "-map", "[o]", "-ar", "44100", "-c:a", "libvorbis", "-q:a", str(SFX_Q),
                     os.path.join(out_dir, "%d.ogg" % i)]
            run(args)
        print(name, len(variants))
    for name, spec in MUSIC.items():
        if only and name not in only:
            continue
        spec = spec if isinstance(spec, dict) else {"src": spec}
        src = spec["src"]
        if ":" in src:
            z, inner = src.split(":", 1)
            with zipfile.ZipFile(os.path.join(SRC, z)) as f:
                path = f.extract(inner, tmp)
        else:
            path = os.path.join(SRC, src)
        # 统一响度（EBU R128 -18 LUFS），立体声 44.1k，ogg
        af = []
        if "cut" in spec:
            a, b = spec["cut"]
            af.append("atrim=start=%.2f%s,asetpts=PTS-STARTPTS" % (a, (":end=%.2f" % b) if b > 0 else ""))
        if "fade" in spec:
            fi, fo = spec["fade"]
            dur = spec["cut"][1] - spec["cut"][0]
            af.append("afade=t=in:d=%.2f,afade=t=out:st=%.2f:d=%.2f" % (fi, dur - fo, fo))
        af.append("loudnorm=I=-18:TP=-1.5:LRA=11")
        run(["ffmpeg", "-y", "-i", path, "-af", ",".join(af), "-ar", "44100", "-ac", "2",
             "-c:a", "libvorbis", "-q:a", str(spec.get("q", MUSIC_Q)), os.path.join(MUSIC_OUT, name + ".ogg")])
        print("music", name)
    shutil.rmtree(tmp)


if __name__ == "__main__":
    main()
