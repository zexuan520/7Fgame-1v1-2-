"""锻造台的“零件库”：人形的腿、手臂、躯干、下摆、头、各种帽子盔甲背饰。角色函数（chars*.py）拿这些拼。
坐标（小格）：脚底 y=0，面朝 +x，+z 是右手。标准人形关节见 human_joints()。
"""
import numpy as np
from forge import Forge, std_joints

C = {
    "skin": "#e2b48a", "skin_d": "#b9845e", "skin_old": "#c99c78", "skin_pale": "#d8cfc6",
    "hair": "#1c1820", "hair_w": "#dcdad6", "hair_g": "#8f8a86",
    "straw": "#dcb867", "straw_d": "#a9813d", "straw_l": "#f0d48c",
    "red": "#c23a2c", "red_d": "#7d2119", "red_l": "#e05a46",
    "robe": "#1f8a52", "robe_d": "#126039", "robe_l": "#3aa46a",   # 绿色系：主角皮肤换色时整块换掉（只用在主角身上）
    "cream": "#e8dcbf", "cream_d": "#b9aa88",
    "char": "#2a2630", "char_l": "#423c4a",
    "boot": "#2b211f", "boot_l": "#4a3a33",
    "bone": "#e9e0c8", "bone_d": "#b7a988", "bone_l": "#fbf5e2",
    "gap": "#1b1416",
    "rag": "#4a2c26", "rag_d": "#2e1b18", "rag_l": "#6b4033",
    "iron": "#5c5f68", "iron_d": "#34363d", "iron_l": "#8b8f99", "rust": "#7d4a2e",
    "eye": "#ff3b2a", "eye_c": "#4fe3ff", "eye_v": "#c46bff", "eye_g": "#7dff5a", "eye_o": "#ff9a2a", "eye_y": "#ffd760",
    "grey": "#a3a5ab", "grey_d": "#73767e", "grey_l": "#c6c8cc",
    "steel": "#6f7480", "steel_d": "#474b55", "steel_l": "#959aa5",
    "lacq": "#26232a", "lacq_l": "#45404d",
    "brass": "#c99a3e", "brass_d": "#8a6424", "brass_l": "#ecc46a",
    "bronze": "#a8743e", "bronze_d": "#6b4523", "bronze_l": "#d09a5a", "patina": "#5f9c8c",
    "gold": "#e0b040", "gold_d": "#9a7020", "gold_l": "#ffe08a",
    "wood": "#7a5432", "wood_d": "#4e3420", "wood_l": "#9c7046",
    "paper": "#efe6cf", "paper_d": "#c9bc98",
    "leather": "#7b5236", "leather_d": "#4f3322",
    "saffron": "#d8892e", "saffron_d": "#9c5c1a", "maroon": "#7a2a2a", "maroon_d": "#4e1818",
    "navy": "#2f3b5c", "navy_d": "#1d253c", "navy_l": "#4b5a82",
    "purple": "#5b3a7a", "purple_d": "#36224a", "purple_l": "#8460a8",
    "teal": "#2e6b70", "teal_d": "#1b4245",
    "fire": "#ff7a1a", "fire_y": "#ffd040", "fire_r": "#ff3a10",
    "pink": "#e89ab8", "pink_d": "#b0607e", "pink_l": "#ffc8dc",
}


def human_joints(heavy=False, small=False):
    if heavy:
        return std_joints(neck=73, sh_y=68, sh_z=15, hip_y=43, leg_z=7, knee_y=22, ankle_y=6)
    return std_joints(neck=72, sh_y=67, sh_z=14, hip_y=42, leg_z=6, knee_y=22, ankle_y=6)


SIDES = ((1, "f"), (-1, "b"))


def legs(f, thigh, shin, boot, z=6, r=(4.4, 4.0, 3.9, 3.5), wraps=None, greave=None, boot_l=None, top=41):
    """两条腿。wraps：绑腿暗线颜色；greave：护胫（前面一块亮色）"""
    for s, sd in SIDES:
        zz = z * s
        pu, pl = "leg_u_" + sd, "leg_l_" + sd
        f.fill(f.seg((0, top, zz), (0, 22, zz), r[0], r[1]), pu, thigh)
        f.fill(f.seg((0, 22, zz), (0, 8, zz), r[2], r[3]), pl, shin)
        if wraps:
            for y in range(10, 22, 4):
                f.paint(f.box(-9, 9, y, y + 1, zz - 6, zz + 6), wraps, part=pl)
        if greave:
            f.fill(f.box(1, r[2] + 1.6, 10, 22, zz - r[2], zz + r[2]) & f.ell((0, 16, zz), (r[2] + 1.6, 9, r[2] + 0.8)), pl, greave)
        f.fill(f.box(-4, 9, 0, 8, zz - 4.2, zz + 4.2) & f.ell((2, 2, zz), (8, 9, 5.2)), pl, boot)
        if boot_l:
            f.paint(f.box(-5, 10, 6, 8, zz - 5, zz + 5), boot_l, part=pl)


def arms(f, sleeve, fore, hand, z=14, ru=(5.0, 4.6), rl=(3.9, 3.6), cuff=None, bracer=None, sh_y=66, wide=0.0):
    """两条胳膊（竖直下垂）。wide > 0：宽袖口（道袍、僧袍）往下张开"""
    el = sh_y - 15
    wr = el - 12
    for s, sd in SIDES:
        zz = z * s
        pu, pl = "arm_u_" + sd, "arm_l_" + sd
        f.fill(f.seg((0, sh_y, zz), (0, el, zz), ru[0], ru[1]), pu, sleeve)
        if cuff:
            f.fill(f.cyl(0, zz, ru[1] + 0.8, el - 1, el + 2), pu, cuff)
        f.fill(f.seg((0, el, zz), (0, wr, zz), rl[0], rl[1]), pl, fore)
        if wide > 0:
            f.fill(f.cone(0, zz, rl[0] + 0.5, el, rl[0] + wide, wr + 3) & ~f.cone(0, zz, rl[0] - 0.5, el - 1, rl[0] + wide - 1.2, wr + 2), pl, sleeve)
        if bracer:
            f.fill(f.cyl(0, zz, rl[1] + 0.5, wr + 1, wr + 5), pl, bracer)
        f.fill(f.ell((0.5, wr - 4, zz), (rl[1] + 0.5, 4.4, rl[1] + 0.5)), pl, hand)


def torso(f, cloth, rx=8, rz=11, cy=57, ry=14, sh=13.5, sh_y=65):
    f.fill(f.ell((0, cy, 0), (rx, ry, rz)), "torso", cloth)
    f.fill(f.ell((0, sh_y, 0), (rx - 0.5, 6.5, sh)), "torso", cloth)


def cross_collar(f, inner, edge, y0=52):
    """交领：里衣露出一个 V"""
    f.paint(f.side("x", ">", 2) & (np.abs(f.Z + 1.5) < (f.Y - y0) * 0.42) & f.side("y", ">", y0), inner, part="torso")
    f.paint(f.side("x", ">", 2) & (np.abs(np.abs(f.Z + 1.5) - (f.Y - y0) * 0.42) < 1.2) & f.side("y", ">", y0), edge, part="torso")


def belt(f, color, buckle=None, y=47, rx=8.2, rz=11):
    f.fill(f.ell((0, y, 0), (rx, 3.6, rz)), "torso", color)
    if buckle:
        f.fill(f.box(rx - 2, rx + 1.5, y - 2.5, y + 2.5, -2.5, 2.5), "torso", buckle)


def skirt(f, color, dark=None, top=46, bottom=29, r0=9.5, r1=12.5, split=True, side_split=False):
    """袍子下摆（胯部件，跟着胯走）。split：前面开衩露腿"""
    sk = f.cone(0, 0, r0, top, r1, bottom, squash=1.25) & ~f.cone(0, 0, r0 - 3, top, r1 - 3, bottom, squash=1.25)
    sk &= f.side("y", "<", top)
    if split:
        sk &= ~(f.side("x", ">", 2) & (np.abs(f.Z) < 4.5) & f.side("y", "<", top - 5))
    if side_split:
        sk &= ~((np.abs(f.Z) > r0 - 1) & (np.abs(f.X) < 3) & f.side("y", "<", top - 5))
    f.fill(sk, "hips", color)
    f.fill(f.cone(0, 0, r0 - 1, top - 5, r0, top, squash=1.25), "hips", color)
    if dark:
        f.paint(f.side("y", "<", bottom + 3), dark, part="hips")


def flaps(f, color, dark, light=None, top=45, bottom=29, w=9):
    """甲裙：前后两片方的，一排排甲片"""
    for x0, x1 in ((3, 9), (-9, -3)):
        f.fill(f.box(x0, x1, bottom, top, -w, w), "hips", color)
        for y in range(bottom + 1, top, 4):
            f.paint(f.box(x0 - 1, x1 + 1, y, y + 1, -w - 1, w + 1), dark, part="hips")
        if light:
            f.paint(f.box(x0 - 1, x1 + 1, top - 2, top, -w - 1, w + 1), light, part="hips")
    f.fill(f.box(-7, 7, 40, 46, -10, 10), "hips", dark)


def head(f, skin, hair=None, eyes=None, cx=0.5, cy=80, r=(7.5, 8.5, 7.5), eye_glow=0.0, bald=False, beard=None):
    """头：头发（后半）+ 脸（前半）+ 两只眼"""
    eyes = eyes or C["gap"]
    hd = f.ell((cx, cy, 0), r)
    f.fill(hd, "head", hair if (hair and not bald) else skin)
    face = f.ell((cx + 0.7, cy - 0.5, 0), (r[0] - 0.1, r[1] - 0.5, r[2] - 0.3)) & f.side("x", ">", cx + 1) & f.side("y", "<", cy + 6)
    f.paint(face, skin, part="head")
    f.paint(face & f.side("y", "<", cy - 4) & f.side("x", ">", cx + 5.5), C["skin_d"] if skin == C["skin"] else skin, part="head")
    for s in (1, -1):
        f.fill(f.box(cx + r[0] - 2, cx + r[0] + 1, cy - 1, cy + 2, 2.8 * s - 1.2, 2.8 * s + 1.2), "head", eyes, glow=eye_glow)
    if beard:
        f.fill(f.ell((cx + 5, cy - 6, 0), (4, 6, 5.5)) & f.side("x", ">", cx + 2), "head", beard)
        f.fill(f.seg((cx + 6, cy - 8, 0), (cx + 7, cy - 16, 0), 3.0, 1.2), "head", beard)


def mask_lower(f, color, cx=0.5, cy=80):
    """蒙面巾：遮住下半张脸"""
    f.paint(f.side("x", ">", cx + 1) & f.side("y", "<", cy - 1), color, part="head")


# ---------- 帽子、盔 ----------

def hat_straw(f, r=19, cx=0.5, y0=86, h=12, col=C["straw"], dark=C["straw_d"], light=C["straw_l"], band=None):
    """斗笠：扁圆锥"""
    hat = f.cone(cx, 0, r, y0, 1.5, y0 + h) & ~f.cone(cx, 0, r - 2, y0, 0, y0 + h - 3)
    hat |= f.cone(cx, 0, 9, y0, 0, y0 + h - 1)
    f.fill(hat, "head", col)
    rr = np.sqrt((f.X - cx) ** 2 + f.Z ** 2)
    f.paint(hat & ((np.floor(rr / 2.5) % 3) == 0), dark, part="head")
    f.paint(hat & (rr > r - 1.6), light, part="head")
    if band:
        f.paint(hat & (rr > 8) & (rr < 10.5) & f.side("y", "<", y0 + 6), band, part="head")
    f.fill(f.box(cx - 1.5, cx + 1.5, y0 + h - 1, y0 + h + 2, -1.5, 1.5), "head", dark)


def helm_round(f, col, dark, cx=0.5, y0=82, r=(9, 8, 8.6), rim=10.5, nose=True, crest=None, crest_col=None):
    """圆铁盔（锅盔）+ 可选红缨 crest='tassel' / 'plume' / 'spike'"""
    hm = f.ell((cx, y0, 0), r) & f.side("y", ">", y0 - 1)
    f.fill(hm, "head", col)
    f.paint(hm & f.side("y", "<", y0 + 1.5), dark, part="head")
    f.fill(f.cyl(cx, 0, rim, y0 - 1, y0 + 1), "head", dark)
    if nose:
        f.fill(f.box(cx + r[0] - 2, cx + r[0] + 2, y0 - 8, y0, -1, 1), "head", dark)
    top = y0 + r[1]
    if crest == "tassel":
        f.fill(f.cyl(cx, 0, 1.5, top - 1, top + 2), "head", C["brass"])
        f.fill(f.seg((cx, top + 2, 0), (cx - 4, top + 7, 0), 2.2, 2.8), "head", crest_col or C["red"])
    elif crest == "plume":
        f.fill(f.cyl(cx, 0, 1.5, top - 1, top + 3), "head", C["brass"])
        f.fill(f.seg((cx, top + 3, 0), (cx - 3, top + 9, 0), 2.0, 1.4) | f.seg((cx - 3, top + 9, 0), (cx - 12, top + 8, 0), 2.6, 1.6), "head", crest_col or C["red"])
    elif crest == "spike":
        f.fill(f.cone(cx, 0, 2.5, top - 1, 0.5, top + 7), "head", crest_col or dark)


def hat_official(f, col=C["lacq"], light=C["lacq_l"], cx=0.0, y0=85, wings=True):
    """乌纱帽：方顶 + 两侧平伸的帽翅（顶视：一根横杠，一眼认得）"""
    f.fill(f.box(cx - 7, cx + 6, y0, y0 + 6, -7.5, 7.5), "head", col)
    f.fill(f.box(cx - 8, cx - 1, y0 + 4, y0 + 10, -6.5, 6.5), "head", col)
    f.paint(f.box(cx - 9, cx + 7, y0, y0 + 1.2, -8, 8), light, part="head")
    if wings:
        for s in (1, -1):
            f.fill(f.box(cx - 5, cx - 3, y0 + 6, y0 + 8, 6 * s if s > 0 else -18, 18 if s > 0 else -6), "head", col)
            f.fill(f.box(cx - 6, cx - 2, y0 + 5, y0 + 9, 15 * s - 3 if s > 0 else -18, 18 if s > 0 else -15 + 3), "head", light)


def crown_mian(f, cx=0.5, y0=88, col=C["gold"], board=C["lacq"], bead=C["red"]):
    """冕旒：头顶一块长方平板，前后垂珠串（顶视：一块长方板，帝王）"""
    f.fill(f.cyl(cx, 0, 5.5, y0 - 2, y0 + 3), "head", col)
    f.fill(f.box(cx - 13, cx + 13, y0 + 3, y0 + 5, -8, 8), "head", board)
    f.paint(f.box(cx - 14, cx + 14, y0 + 4, y0 + 5, -9, 9) & ~f.box(cx - 12, cx + 12, 0, 200, -7, 7), col, part="head")
    for x in (cx + 12, cx - 12):
        for z in range(-6, 7, 3):
            f.fill(f.seg((x, y0 + 3, z), (x, y0 - 6, z), 0.8), "head", bead)
            f.fill(f.ell((x, y0 - 6, z), (1.1, 1.1, 1.1)), "head", C["gold_l"])


def hair_bun(f, cx=0.5, top=88, col=C["hair"], pins=C["gold"], big=False):
    """发髻 + 簪子"""
    r = 5.5 if big else 4
    f.fill(f.ell((cx - 1, top + r * 0.6, 0), (r, r, r)), "head", col)
    if pins:
        f.fill(f.seg((cx - 1, top + r, -r - 4), (cx - 1, top + r, r + 4), 0.9), "head", pins)


def topknot(f, cx=0.5, top=88, col=C["hair"], tie=C["red"]):
    f.fill(f.ell((cx - 1, top + 2, 0), (3.2, 3.5, 3.2)), "head", col)
    f.fill(f.cyl(cx - 1, 0, 2.6, top - 0.5, top + 1.2), "head", tie)


def bandana(f, col, cx=0.5, y=84, tails=True):
    """头巾：额头一圈 + 脑后两条飘带"""
    f.paint(f.ell((cx, 80, 0), (8, 9, 8)) & f.side("y", ">", y - 1.5) & f.side("y", "<", y + 2), col, part="head")
    f.fill(f.ell((cx, 80, 0), (7.9, 8.9, 7.9)) & ~f.ell((cx, 80, 0), (7.2, 8.2, 7.2)) & f.side("y", ">", y - 1.5) & f.side("y", "<", y + 2), "head", col)
    if tails:
        f.fill(f.seg((cx - 7, y, 1.5), (cx - 15, y - 9, 3), 1.5, 1.0) | f.seg((cx - 7, y, -1.5), (cx - 14, y - 11, -3), 1.5, 1.0), "head", col)


def hood(f, col, light=None, cx=0.5, pointed=True):
    hd = f.ell((cx - 0.5, 82, 0), (10.5, 10.5, 10)) & ~f.ell((cx + 3, 79.5, 0), (8.6, 8.9, 8.2))
    hd &= ~(f.side("x", ">", cx + 4.5) & f.side("y", "<", 87))
    f.fill(hd, "head", col)
    if pointed:
        f.fill(f.seg((cx + 1, 92, 0), (cx - 7, 91, 0), 3.0, 4.2), "head", col)
    f.fill(f.ell((0, 66, 0), (8.5, 5.5, 13)) & f.side("y", ">", 62), "torso", col)
    if light:
        f.paint(hd & f.side("y", ">", 89), light, part="head")


def tall_hat(f, col, band=None, cx=0.5, y0=86, h=14, r0=7.5, r1=5.5, brim=0):
    f.fill(f.cone(cx, 0, r0, y0, r1, y0 + h), "head", col)
    if brim:
        f.fill(f.cyl(cx, 0, brim, y0, y0 + 2), "head", col)
    if band:
        f.paint(f.cone(cx, 0, r0 + 0.2, y0, r1 + 0.2, y0 + h) & f.side("y", "<", y0 + 3), band, part="head")


# ---------- 肩、甲、背 ----------

def pauldrons_square(f, col, dark, light, edge=None, w=6, zin=8, zout=20, y0=65, y1=71):
    for s, sd in SIDES:
        pu = "arm_u_" + sd
        z0, z1 = (zin, zout) if s > 0 else (-zout, -zin)
        sp = f.box(-7, 8, y0, y1, z0, z1)
        f.fill(sp, pu, col)
        f.paint(sp & f.side("y", ">", y1 - 1.5), light, part=pu)
        f.paint(sp & f.side("y", "<", y0 + 1.5), edge or dark, part=pu)
        f.paint(sp & ((np.floor(f.X + 20) % 4) == 0) & f.side("y", ">", y0 + 1.5), dark, part=pu)


def pauldrons_round(f, col, dark, light, z=14, r=(7.5, 5.5, 7), y=68, spikes=None, one_side=False):
    for s, sd in SIDES:
        if one_side and s > 0:
            continue
        pu = "arm_u_" + sd
        p = f.ell((0, y, z * s), r) & f.side("y", ">", y - 4)
        f.fill(p, pu, col)
        f.paint(p & f.side("y", ">", y + r[1] - 2), light, part=pu)
        f.paint(p & f.side("y", "<", y - 2.5), dark, part=pu)
        if spikes:
            f.fill(f.cone(0, z * s * 1.05, 1.8, y + r[1] - 1, 0.3, y + r[1] + 6), pu, spikes)


def chest_plate(f, col, dark, light, lamellar=True, rx=8.4, rz=10, y0=51, y1=65):
    f.fill(f.box(-rx, rx, y0, y1, -rz, rz) & f.ell((0, (y0 + y1) / 2, 0), (rx + 1, (y1 - y0) * 0.75, rz + 2)), "torso", col)
    if lamellar:
        for y in range(y0 + 1, y1, 3):
            f.paint(f.box(rx - 1.5, rx + 1, y, y + 1, -rz - 1, rz + 1) | f.box(-rx - 1, -rx + 1.5, y, y + 1, -rz - 1, rz + 1), dark, part="torso")
    f.paint(f.box(-rx - 1, rx + 1, y1 - 1, y1, -rz - 1, rz + 1), light, part="torso")


def cape(f, col, dark, top=68, bottom=30, w=12, back=-6):
    """披风：从肩后垂下（躯干部件）"""
    cp = f.box(back - 3.5, back + 0.5, bottom, top, -w, w)
    cp &= (np.abs(f.Z) < w - (top - f.Y) * 0.0 + (top - f.Y) * 0.12)
    f.fill(cp, "torso", col)
    f.paint(cp & f.side("y", "<", bottom + 3), dark, part="torso")
    f.fill(f.ell((back + 2, top - 2, 0), (5, 4, w + 1)) & f.side("y", ">", top - 4), "torso", col)


def back_flag(f, col, pole=C["wood"], cloth2=None, h=118):
    """背旗：顶视最显眼的一块颜色（旗手、押灯将）"""
    f.fill(f.cyl(-8, 0, 1.2, 40, h), "torso", pole)
    fl = f.box(-9, -7, h - 22, h - 2, 0, 15)
    f.fill(fl, "torso", col)
    if cloth2:
        f.paint(fl & f.side("z", ">", 11), cloth2, part="torso")
    f.fill(f.cone(-8, 0, 1.6, h, 0.3, h + 4), "torso", C["brass"])


def back_pole_lantern(f, glow_col, pole=C["wood"], h=104, paper=C["paper"]):
    """背上一根竹竿挑着灯（灯兵、押灯将）"""
    f.fill(f.seg((-8, 42, 0), (-10, h, 0), 1.2), "torso", pole)
    f.fill(f.seg((-10, h, 0), (-4, h + 4, 0), 1.0), "torso", pole)
    f.fill(f.ell((-3, h - 2, 0), (3.6, 4.6, 3.6)), "torso", paper)
    f.paint(f.ell((-3, h - 2, 0), (3.7, 3.4, 3.7)) & ~f.ell((-3, h - 2, 0), (3.7, 2.4, 3.7)), glow_col, part="torso", glow=0.5)
    f.paint(f.ell((-3, h - 2, 0), (3.7, 4.7, 3.7)) & (f.Y > h + 1.8), C["lacq"], part="torso")


def backpack(f, col, dark, strap=None, h=78, w=10):
    f.fill(f.box(-17, -7, 44, h, -w, w), "torso", col)
    f.paint(f.box(-18, -6, h - 3, h, -w - 1, w + 1), dark, part="torso")
    f.paint(f.box(-18, -6, 44, 47, -w - 1, w + 1), dark, part="torso")
    if strap:
        for s in (1, -1):
            f.fill(f.box(-8, 9, 60, 69, 6 * s - 1, 6 * s + 1) & f.ell((0, 58, 0), (9, 14, 12)) & ~f.ell((0, 58, 0), (7.6, 12.6, 10.6)), "torso", strap)


def quiver(f, col=C["leather"], fletch=C["red"]):
    f.fill(f.seg((-9, 46, 6), (-10, 72, -4), 3.2), "torso", col)
    for dz in (-1.5, 0, 1.5):
        f.fill(f.seg((-10, 72, -4 + dz), (-11, 79, -6 + dz), 0.8), "torso", fletch)


def lantern_hand(f, side, glow_col, paper=C["paper"]):
    """手里提一盏小灯（挂在前臂部件上，跟着手走）"""
    s = 1 if side == "f" else -1
    z = 14 * s
    pl = "arm_l_" + side
    f.fill(f.seg((1, 31, z), (1, 26, z), 0.7), pl, C["wood_d"])
    f.fill(f.ell((1, 22, z), (3.4, 4.4, 3.4)), pl, paper)
    f.paint(f.ell((1, 22, z), (3.5, 3.2, 3.5)), glow_col, part=pl, glow=0.5)


def glow_bits(f, mask, col, part=None, g=0.5):
    f.paint(mask, col, part=part, glow=g)


def jag(f, top, length, n=18, seed=12.9898):
    """参差不齐的下摆：返回一个“每列多长”的门限高度"""
    ang = np.floor((np.arctan2(f.Z, f.X) + np.pi) / (2 * np.pi) * n)
    return top - length + (np.sin(ang * seed) * 43758.5453 % 1.0) * length * 0.6
