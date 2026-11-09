"""角色定义：每个函数返回一个搭好的 Forge。数字都是小格（2 小格 = 1 游戏格 = 3.6 厘米），人高约 100 小格。
配色约定（斜俯视下靠三层明度分区认人）：
  主角：暖色斗笠（亮）+ 青色袍（中，绿色系 = 皮肤换色的键）+ 炭黑腰带裤靴（暗）+ 朱红点缀
  骷髅系：骨白（亮）+ 焦褐破布/锈铁（暗）+ 眼窝红光（点缀，不受明暗影响）
  灰衣营：灰布（中）+ 黑漆甲片（暗）+ 红缨（点缀）
"""
import numpy as np
from forge import Forge, std_joints, rgb

from kit import C


def hero_canren_old():
    """（2026-11-09 已换成 chars_hero.hero_c 白衣剑客，留着备查）主角·残刃：斗笠 + 青衫 + 红围巾（围巾是 HeroScarf 另画的）。顶视：一张暖色大圆盘，镜头里一眼找到自己"""
    J = std_joints(neck=72, sh_y=67, sh_z=14, hip_y=42, leg_z=6, knee_y=22, ankle_y=6)
    f = Forge("hero_canren_old", J, "本作自制 · 主角残刃（旧斗笠）")
    # ---- 腿 ----
    for s, (pu, pl) in ((1, ("leg_u_f", "leg_l_f")), (-1, ("leg_u_b", "leg_l_b"))):
        z = 6 * s
        f.fill(f.seg((0, 41, z), (0, 22, z), 4.4, 4.0), pu, C["char"])
        f.fill(f.seg((0, 22, z), (0, 8, z), 3.9, 3.5), pl, C["cream"])
        # 绑腿：一圈一圈的暗线
        for y in range(10, 22, 4):
            f.paint(f.box(-9, 9, y, y + 1, z - 6, z + 6), C["cream_d"], part=pl)
        # 靴子：往前伸，脚大一点才看得见步子
        f.fill(f.box(-4, 9, 0, 8, z - 4, z + 4) & f.ell((2, 2, z), (8, 9, 5)), pl, C["boot"])
        f.paint(f.box(-5, 10, 6, 8, z - 5, z + 5), C["boot_l"], part=pl)
    # ---- 胯：袍子下摆（前面开衩露出腿） ----
    skirt = f.cone(0, 0, 9.5, 44, 12.5, 29, squash=1.25) & ~f.cone(0, 0, 6.5, 44, 9.5, 29, squash=1.25)
    skirt &= f.side("y", "<", 45)
    skirt &= ~(f.side("x", ">", 2) & (np.abs(f.Z) < 4.5) & f.side("y", "<", 41))
    f.fill(skirt, "hips", C["robe"])
    f.fill(f.cone(0, 0, 8.5, 41, 9.5, 46, squash=1.25), "hips", C["robe"])
    f.paint(f.side("y", "<", 32), C["robe_d"], part="hips")     # 下摆一道深色边
    # ---- 躯干 ----
    f.fill(f.ell((0, 57, 0), (8, 14, 11)), "torso", C["robe"])
    f.fill(f.ell((0, 65, 0), (7.5, 6.5, 13.5)), "torso", C["robe"])      # 肩
    # 交领：里衣米白露出一个 V
    f.paint(f.side("x", ">", 2) & (np.abs(f.Z + 1.5) < (f.Y - 52) * 0.42) & f.side("y", ">", 52), C["cream"], part="torso")
    f.paint(f.side("x", ">", 2) & (np.abs(np.abs(f.Z + 1.5) - (f.Y - 52) * 0.42) < 1.2) & f.side("y", ">", 52), C["robe_d"], part="torso")
    # 腰带 + 红结
    f.fill(f.ell((0, 47, 0), (8.2, 3.6, 11)), "torso", C["char"])
    f.fill(f.box(5, 10, 43, 50, 2, 7), "torso", C["red"])
    f.fill(f.box(6, 9, 35, 44, 3, 5), "hips", C["red"])
    f.fill(f.box(6, 9, 37, 44, 5, 7), "hips", C["red_d"])
    # 左肩披的短斗篷（不对称，背后看得出是谁）
    f.fill(f.ell((-2, 64, -7), (9, 7, 9)) & f.side("y", ">", 58), "torso", C["robe_d"])
    f.paint(f.ell((-2, 64, -7), (9, 7, 9)) & f.side("y", ">", 58) & f.side("y", "<", 60), C["robe"], part="torso")
    # 背后斜挂的刀鞘（俯视能看到背上一条线）
    f.fill(f.seg((-8, 70, -9), (-9, 42, 9), 1.8), "torso", C["char_l"])
    f.fill(f.seg((-8.5, 70, -9), (-8.5, 66, -6), 2.2), "torso", C["brass"])
    # ---- 手臂 ----
    for s, (pu, pl) in ((1, ("arm_u_f", "arm_l_f")), (-1, ("arm_u_b", "arm_l_b"))):
        z = 14 * s
        f.fill(f.seg((0, 66, z), (0, 51, z), 5.0, 4.6), pu, C["robe"])
        f.fill(f.cyl(0, z, 5.6, 50, 53), pu, C["robe_d"])     # 袖口
        f.fill(f.seg((0, 51, z), (0, 39, z), 3.9, 3.6), pl, C["cream"])
        f.fill(f.cyl(0, z, 4.3, 40, 44), pl, C["char"])        # 护腕
        f.fill(f.ell((0.5, 35, z), (4.0, 4.5, 4.0)), pl, C["skin"])
    # ---- 头 ----
    f.fill(f.ell((0.5, 80, 0), (7.5, 8.5, 7.5)), "head", C["hair"])
    face = f.ell((1.2, 79.5, 0), (7.4, 8.0, 7.2)) & f.side("x", ">", 1.5) & f.side("y", "<", 86)
    f.paint(face, C["skin"], part="head")
    f.paint(face & f.side("y", "<", 76) & f.side("x", ">", 6), C["skin_d"], part="head")
    for s in (1, -1):
        f.paint(f.box(6, 10, 79, 82, s * 2 - 1 if s > 0 else -4, s * 2 + 2 if s > 0 else -1), C["gap"], part="head")
    f.fill(f.seg((-6, 84, 0), (-13, 74, -1), 3.0, 2.4) | f.seg((-13, 74, -1), (-15, 64, -2), 2.4, 1.4), "head", C["hair"])   # 马尾，从斗笠后面甩出来
    f.fill(f.cyl(-6, 0, 2.6, 82, 86), "head", C["red"])                       # 发带
    # 斗笠：扁圆锥，一圈一圈篾纹，帽檐上一道红箍
    hat = f.cone(0.5, 0, 19, 86, 1.5, 98) & ~f.cone(0.5, 0, 17, 86, 0, 95)
    hat |= f.cone(0.5, 0, 9, 86, 0, 97)
    f.fill(hat, "head", C["straw"])
    r = np.sqrt((f.X - 0.5) ** 2 + f.Z ** 2)
    f.paint(hat & ((np.floor(r / 2.5) % 3) == 0), C["straw_d"], part="head")
    f.paint(hat & (r > 17.4), C["straw_l"], part="head")
    f.fill(f.box(-1, 2, 97, 100, -1, 2), "head", C["straw_d"])
    return f


# ---------------- 骷髅一家 ----------------
# 同一副骨架，靠“头上戴的东西 + 肩上那块 + 手里的家伙”区分兵种：顶视最先看到的就是头和肩

def _skeleton(name, src, head="bare", shoulder="pauldron", rag=C["rag"], rag_d=C["rag_d"], hunch=3, eye=C["eye"], bones=None, eye_glow=0.45):
    """bones=(骨, 暗骨, 亮骨)；返回的 f 可以再往上加东西（头顶的 x 偏移 = hunch * 0.6）"""
    J = std_joints(neck=70, sh_y=66, sh_z=13, hip_y=42, leg_z=5, knee_y=22, ankle_y=6)
    f = Forge(name, J, src)
    B, Bd, Bl = bones or (C["bone"], C["bone_d"], C["bone_l"])
    G = C["gap"]
    # ---- 腿：细骨头 + 膝盖骨疙瘩 + 长脚掌 ----
    for s, (pu, pl) in ((1, ("leg_u_f", "leg_l_f")), (-1, ("leg_u_b", "leg_l_b"))):
        z = 5 * s
        f.fill(f.seg((0, 41, z), (0, 22, z), 3.6, 3.1), pu, B)
        f.fill(f.ell((0, 39, z), (4.4, 4.4, 4.4)), pu, B)
        f.fill(f.seg((0, 22, z), (0, 7, z), 3.2, 2.8), pl, B)
        f.fill(f.ell((1.2, 22, z), (4.3, 4.2, 4.2)), pl, Bl)
        f.fill(f.seg((-2, 4, z), (8, 2, z), 2.6, 2.0), pl, B)          # 脚掌
        f.fill(f.box(5, 10, 0, 3, z - 3, z + 3), pl, Bd)               # 脚趾
    # ---- 胯：盆骨 + 破布条 ----
    f.fill(f.ell((0, 42, 0), (4.5, 3.5, 7.5)), "hips", B)
    f.paint(f.ell((0, 42, 0), (4.5, 3.5, 7.5)) & f.side("y", "<", 41), Bd, part="hips")
    if rag:
        cloth = f.cone(0, 0, 8.5, 46, 10.5, 28, squash=1.15) & ~f.cone(0, 0, 6.5, 46, 8.5, 28, squash=1.15) & f.side("y", "<", 46)
        # 下摆参差不齐：每两格一条，长短随机
        ang = np.floor((np.arctan2(f.Z, f.X) + np.pi) / (2 * np.pi) * 18)
        cut = 30 + (np.sin(ang * 12.9898) * 43758.5453 % 1.0) * 10
        cloth &= f.Y > cut
        cloth &= ~(np.abs(f.Z) > 6.5)          # 两侧开口，腿看得见
        f.fill(cloth, "hips", rag)
        f.paint(cloth & (f.Y < cut + 3), rag_d, part="hips")
        f.fill(f.ell((0, 45, 0), (6.5, 2.4, 9)), "hips", rag_d)       # 系绳
    # ---- 躯干：脊柱 + 肋骨笼（横缝要黑，远看才有“骨头”的条纹） ----
    lean = hunch
    f.fill(f.seg((-3, 43, 0), (-3 + lean * 0.4, 70, 0), 2.2), "torso", Bd)
    cage_c = (lean * 0.5, 58, 0)
    cage = f.ell(cage_c, (7.8, 10.5, 11.5)) & ~f.ell(cage_c, (5.4, 8.1, 9.1)) & f.side("y", ">", 49)
    f.fill(cage, "torso", B)
    f.carve(cage & ((np.floor(f.Y) % 3) == 0) & ~((f.X < -2) & (np.abs(f.Z) < 2.5)) & (np.abs(f.Z) > 1.5) & f.side("y", "<", 65), "torso")
    f.fill(f.ell(cage_c, (5.3, 8.0, 9.0)) & f.side("y", ">", 49), "torso", G)   # 笼子里面是黑的（从缝里看进去）
    f.fill(f.box(5 + lean * 0.5, 7.5 + lean * 0.5, 50, 66, -1.5, 1.5), "torso", Bl)   # 胸骨
    f.fill(f.ell((lean * 0.4, 65, 0), (6, 3.8, 12.5)), "torso", B)       # 锁骨肩胛
    f.fill(f.seg((-2, 46, 0), (-2 + lean * 0.2, 50, 0), 2.6), "torso", B)
    # ---- 手臂 ----
    for s, (pu, pl) in ((1, ("arm_u_f", "arm_l_f")), (-1, ("arm_u_b", "arm_l_b"))):
        z = 13 * s
        f.fill(f.ell((0, 65, z), (4.6, 4.6, 4.6)), pu, Bl)
        f.fill(f.seg((0, 65, z), (0, 50, z), 3.2, 2.8), pu, B)
        f.fill(f.ell((0, 50, z), (3.9, 3.9, 3.9)), pl, Bl)
        f.fill(f.seg((0, 50, z), (0, 37, z), 2.8, 2.6), pl, B)
        f.fill(f.ell((0.5, 34, z), (3.8, 4.4, 4.0)), pl, Bd)           # 爪子
        f.fill(f.box(0, 4, 29, 33, z - 2, z + 2), pl, B)
    # ---- 肩上那块（不对称；顶视认兵种的第二个记号） ----
    if shoulder == "pauldron":
        p = f.ell((0, 68, -13), (8.5, 6, 8)) & f.side("y", ">", 63)
        f.fill(p, "arm_u_b", C["iron"])
        f.paint(p & f.side("y", ">", 70), C["iron_l"], part="arm_u_b")
        f.paint(p & ((np.floor(f.X + 20) % 4) == 0), C["rust"], part="arm_u_b")
        f.fill(f.seg((-4, 70, -13), (-4, 77, -14), 1.3) | f.seg((0, 70, -13), (0, 79, -14), 1.3) | f.seg((4, 70, -13), (4, 76, -14), 1.3), "arm_u_b", C["iron_d"])   # 刺
    elif shoulder == "rag":
        f.fill(f.ell((0, 65, -9), (7.5, 5, 6)) & f.side("y", ">", 61), "torso", rag)
    # ---- 头：大骷髅（比人类头大一点，凶） ----
    hx = lean * 0.6
    sk = f.ell((hx + 1.5, 80, 0), (9.2, 9.4, 8.8))
    f.fill(sk, "head", B)
    f.paint(sk & f.side("y", "<", 75), Bd, part="head")
    f.fill(f.box(hx + 2, hx + 9, 69, 74, -4.5, 4.5) & f.ell((hx + 3, 72, 0), (6.5, 4, 5)), "head", B)   # 下巴
    for z0 in range(-4, 5, 2):
        f.paint(f.box(hx + 7, hx + 10, 72, 74, z0, z0 + 1), G, part="head")    # 牙缝
    for s in (1, -1):
        sock = f.ell((hx + 8, 79.5, 3.2 * s), (2.8, 2.6, 2.4))
        f.carve(sock, "head")
        f.fill(f.ell((hx + 6.5, 79.5, 3.2 * s), (2.0, 2.2, 2.0)), "head", G)
        f.fill(f.box(hx + 7, hx + 9, 79, 81, 3.2 * s - 1, 3.2 * s + 1), "head", eye, glow=eye_glow)
    f.carve(f.box(hx + 8, hx + 10, 75, 77, -0.8, 0.8), "head")            # 鼻孔
    if head == "helmet":
        # 盾骷髅：铁锅盔，顶上一根红缨（顶视：灰圆盘中间一点红）
        hm = f.ell((hx + 1, 82, 0), (9, 8, 8.6)) & f.side("y", ">", 81)
        f.fill(hm, "head", C["iron"])
        f.paint(hm & f.side("y", "<", 83.5), C["iron_d"], part="head")
        f.fill(f.cyl(hx + 1, 0, 10.5, 81, 83), "head", C["iron_d"])
        f.fill(f.box(hx + 7, hx + 11, 74, 82, -1, 1), "head", C["iron_d"])   # 护鼻
        f.fill(f.seg((hx + 1, 89, 0), (hx - 3, 94, 0), 2.2, 2.8), "head", C["red"])
        f.fill(f.cyl(hx + 1, 0, 1.5, 88, 91), "head", C["brass"])
    elif head == "hood":
        # 骨弩手：破斗篷兜帽，尖往后垂（顶视：暗色的泪滴）
        hd = f.ell((hx, 82, 0), (10.5, 10.5, 10)) & ~f.ell((hx + 3.5, 79.5, 0), (8.6, 8.9, 8.2))
        hd &= ~(f.side("x", ">", hx + 5) & f.side("y", "<", 87))
        f.fill(hd, "head", rag)
        f.fill(f.seg((hx - 6, 88, 0), (hx - 13, 76, 0), 4.2, 1.6), "head", rag)
        f.fill(f.seg((hx + 2, 92, 0), (hx - 5, 92, 0), 3.0, 4.0), "head", rag)   # 兜帽尖
        f.fill(f.ell((0, 66, 0), (8.5, 5.5, 13)) & f.side("y", ">", 62), "torso", rag)   # 披肩
        f.paint(f.side("y", ">", 90) & (f.part == 2), C["rag_l"] if rag == C["rag"] else rag, part="head")
    elif head == "horns":
        # 冲阵骨：牛角盔
        hm = f.ell((hx + 1, 82, 0), (8.6, 7.4, 8.2)) & f.side("y", ">", 81)
        f.fill(hm, "head", C["iron_d"])
        for s in (1, -1):
            f.fill(f.seg((hx, 86, 6 * s), (hx + 1, 90, 12 * s), 2.2, 1.8) | f.seg((hx + 1, 90, 12 * s), (hx + 4, 97, 13 * s), 1.8, 0.8), "head", C["bone_l"])
    return f


def skel_grunt():
    """骷髅兵：光头骷髅 + 左肩锈铁护肩（带刺）+ 焦褐破布。数量最多的杂兵，顶视：白头 + 一侧铁块"""
    return _skeleton("skel_grunt", "本作自制 · 骷髅兵")


def skel_shield():
    """盾骷髅：铁锅盔 + 红缨，护肩换成布。顶视：灰盔中间一点红"""
    return _skeleton("skel_shield", "本作自制 · 盾骷髅", head="helmet", shoulder="rag", rag=C["iron_d"], rag_d=C["lacq"], hunch=1)


def skel_archer():
    """骨弩手：兜帽，弯腰更厉害。顶视：暗色泪滴"""
    f = _skeleton("skel_archer", "本作自制 · 骨弩手", head="hood", shoulder="none", rag="#6a5f3e", rag_d="#3f3826", hunch=5,
                  bones=("#d6c8a0", "#a39370", "#ece0bc"))
    # 斗篷从兜帽一直披到腰下（背上一大片土绿），背一只箭壶露出红羽
    cp = f.ell((-2, 60, 0), (9.5, 14, 13.6)) & f.side("y", ">", 40) & f.side("x", "<", 3)
    f.fill(cp, "torso", "#6a5f3e")
    f.paint(cp & f.side("y", "<", 44), "#3f3826", part="torso")
    f.fill(f.seg((-10, 46, 5), (-11, 72, -3), 3.0), "torso", C["leather"])
    for dz in (-2, 0, 2):
        f.fill(f.seg((-11, 72, -3 + dz), (-12, 80, -5 + dz), 0.9), "torso", C["red"])
    return f


# ---------------- 灰衣营 ----------------

def grey_blade():
    """灰衣刀手：方肩甲片 + 宽檐笠盔 + 蒙面巾，人比主角壮。形状语言是方的（主角圆、骷髅尖、灰衣方）。
    灰布是主色（中明度，暗地上看得见），甲片钢灰，黑漆只做边，红缨红臂章做点缀"""
    J = std_joints(neck=73, sh_y=68, sh_z=14, hip_y=43, leg_z=6, knee_y=22, ankle_y=6)
    f = Forge("grey_blade", J, "本作自制 · 灰衣刀手")
    G_, Gd, Gl = "#a3a5ab", "#73767e", "#c6c8cc"
    S_, Sd, Sl = "#6f7480", "#474b55", "#959aa5"
    L_ = C["lacq"]
    for s, (pu, pl) in ((1, ("leg_u_f", "leg_l_f")), (-1, ("leg_u_b", "leg_l_b"))):
        z = 6 * s
        f.fill(f.seg((0, 42, z), (0, 22, z), 4.6, 4.2), pu, Gd)
        f.fill(f.seg((0, 22, z), (0, 8, z), 4.1, 3.8), pl, Gl)               # 白绑腿
        for y in range(10, 22, 4):
            f.paint(f.box(-9, 9, y, y + 1, z - 6, z + 6), Gd, part=pl)
        f.fill(f.box(-4, 9, 0, 8, z - 4.5, z + 4.5) & f.ell((2, 2, z), (8, 9, 5.5)), pl, L_)
    # 下摆：前后两片甲裙（方的，钢灰甲片一排一排）
    for x0, x1 in ((3, 9), (-9, -3)):
        f.fill(f.box(x0, x1, 29, 45, -9, 9), "hips", S_)
        for y in range(30, 45, 4):
            f.paint(f.box(x0 - 1, x1 + 1, y, y + 1, -10, 10), Sd, part="hips")
        f.paint(f.box(x0 - 1, x1 + 1, 29, 30, -10, 10), L_, part="hips")
    f.fill(f.box(-7, 7, 40, 46, -10, 10), "hips", Gd)
    # 躯干：灰布衣 + 钢灰札甲胸片
    f.fill(f.box(-6.5, 7, 46, 70, -10.5, 10.5), "torso", G_)
    f.fill(f.box(-7.5, 8, 51, 65, -9, 9), "torso", S_)
    for y in range(52, 65, 3):
        f.paint(f.box(7, 9, y, y + 1, -10, 10) | f.box(-9, -7, y, y + 1, -10, 10), Sd, part="torso")
    f.paint(f.box(-9, 9, 64, 65, -10, 10), Sl, part="torso")
    f.fill(f.box(-7, 8, 46, 50, -11, 11), "torso", L_)                    # 黑腰带 + 铜扣
    f.fill(f.box(7, 9, 46, 50, -2, 2), "torso", C["brass"])
    # 方肩甲：大平板，顶视最显眼
    for s in (1, -1):
        pu = "arm_u_f" if s > 0 else "arm_u_b"
        z0, z1 = (8, 20) if s > 0 else (-20, -8)
        sp = f.box(-7, 8, 65, 71, z0, z1)
        f.fill(sp, pu, S_)
        f.paint(sp & f.side("y", ">", 69.5), Sl, part=pu)
        f.paint(sp & f.side("y", "<", 66.5), L_, part=pu)
        f.paint(sp & ((np.floor(f.X + 20) % 4) == 0) & f.side("y", ">", 66.5), Sd, part=pu)
    for s, (pu, pl) in ((1, ("arm_u_f", "arm_l_f")), (-1, ("arm_u_b", "arm_l_b"))):
        z = 14 * s
        f.fill(f.seg((0, 65, z), (0, 52, z), 4.4, 4.1), pu, G_)
        f.fill(f.cyl(0, z, 4.8, 56, 60), pu, C["red"])                      # 红臂章：灰衣营的记号
        f.fill(f.seg((0, 52, z), (0, 39, z), 3.8, 3.5), pl, Sd)
        f.fill(f.ell((0.5, 36, z), (3.6, 4.2, 3.6)), pl, Gd)
    # 头：灰巾蒙面，只露一条眼缝；宽檐笠盔（顶视：钢灰八角大盘 + 正中红缨）
    f.fill(f.ell((0.5, 81, 0), (7.5, 8.5, 7.5)), "head", G_)
    f.paint(f.side("x", ">", 4) & f.side("y", ">", 78) & f.side("y", "<", 83), C["skin"], part="head")
    for s in (1, -1):
        f.fill(f.box(6.5, 8.5, 79.5, 81.5, 3 * s - 1, 3 * s + 1), "head", C["gap"])
    oct_ = (np.abs(f.X - 0.5) + np.abs(f.Z)) < 19
    brim = f.cyl(0.5, 0, 16, 86, 89) & oct_
    f.fill(brim, "head", S_)
    f.paint(brim & ~(f.cyl(0.5, 0, 14.5, 80, 100) & ((np.abs(f.X - 0.5) + np.abs(f.Z)) < 17.5)), L_, part="head")
    f.fill(f.cone(0.5, 0, 9.5, 89, 6, 94), "head", Sl)
    f.fill(f.cyl(0.5, 0, 3.8, 94, 99), "head", C["red"])
    f.paint(f.cyl(0.5, 0, 3.8, 98, 99), "#e05a46", part="head")
    f.fill(f.cyl(0.5, 0, 1.6, 93, 95), "head", C["brass"])
    return f


from chars_foes import FOES
from chars_boss import BOSSES
from chars_npc import NPCS
from chars_hero import HEROES, HERO_DRAFTS

ALL = {
    "skel_grunt": skel_grunt,
    "skel_shield": skel_shield,
    "skel_archer": skel_archer,
    "grey_blade": grey_blade,
}
ALL.update(FOES)
ALL.update(BOSSES)
ALL.update(NPCS)
ALL.update(HEROES)
DRAFTS = dict(HERO_DRAFTS)
