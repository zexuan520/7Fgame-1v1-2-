"""NPC 和可选角色、皮肤：拾骨婆、游商、老刀匠、守灯僧、阿禾、小满；主角的铁甲、兽皮两身，慧明。"""
import numpy as np
from forge import Forge
from kit import (C, human_joints, legs, arms, torso, cross_collar, belt, skirt, flaps, head, hat_straw, helm_round, hair_bun,
                 topknot, bandana, hood, pauldrons_round, chest_plate, cape, backpack, lantern_hand, jag)
from chars_foes import _man
from chars import hero_canren


def npc_hag():
    """拾骨婆：驼背老婆婆，灰白发髻，深褐披肩，背一筐骨头。顶视：一筐白骨 + 灰发髻"""
    f = _man("npc_hag", "拾骨婆", thigh=C["char"], shin=C["char"], boot=C["boot"], sleeve="#5a4a3e", fore="#5a4a3e", hand=C["skin_old"],
             body="#5a4a3e", sk="#4a3a30", sk_dark="#2e241e", sk_bottom=8, belt_col="#8a6a3a", skin=C["skin_old"], hair=C["hair_g"])
    f.fill(f.ell((-1, 64, 0), (9.5, 7, 13.5)) & f.side("y", ">", 58), "torso", "#3a2e28")
    f.paint(f.ell((-1, 64, 0), (9.6, 7.1, 13.6)) & f.side("y", "<", 59.5), "#6a3a2a", part="torso")
    hair_bun(f, top=87, col=C["hair_g"], pins=C["wood_l"])
    f.fill(f.cyl(-15, 0, 7.5, 50, 70) & ~f.cyl(-15, 0, 6, 52, 80), "torso", C["wood_l"])
    f.paint(f.cyl(-15, 0, 7.6, 50, 70) & ((np.floor(f.Y / 2) + np.floor(np.arctan2(f.Z, f.X + 15) * 3)) % 2 == 0), C["wood"], part="torso")
    for (x, z, r) in ((-15, 2, 3.2), (-13, -3, 2.6), (-17, -2, 2.8)):
        f.fill(f.ell((x, 72, z), (r, r, r)), "torso", C["bone_l"])
    f.fill(f.seg((-18, 70, 4), (-12, 76, 5), 1.0), "torso", C["bone"])
    return f


def npc_merchant():
    """游商：宽斗笠，圆肚子，背一座小山似的货架（挂着葫芦、布卷）。顶视：大货架"""
    f = _man("npc_merchant", "游商", thigh="#4a5a3a", shin=C["cream"], boot=C["boot"], wraps=C["cream_d"], sleeve="#8a6a3a",
             body="#8a6a3a", collar=(C["cream"], "#5a4424"), sk="#8a6a3a", sk_dark="#5a4424", belt_col=C["red_d"], fat=3, beard=C["hair"])
    hat_straw(f, r=17, h=10)
    f.fill(f.box(-22, -7, 38, 88, -11, 11), "torso", C["wood_d"])
    f.fill(f.box(-21, -8, 40, 86, -10, 10), "torso", C["wood"])
    f.fill(f.box(-21, -8, 52, 62, -12, 12), "torso", C["red"])
    f.fill(f.box(-21, -8, 70, 78, -12, 12), "torso", "#3a6a8a")
    f.fill(f.ell((-15, 92, -4), (4, 4, 4)) | f.ell((-15, 92, 5), (3.4, 3.4, 3.4)), "torso", "#c8902a")
    f.fill(f.seg((-7, 66, 7), (8, 60, 7), 1.0) | f.seg((-7, 66, -7), (8, 60, -7), 1.0), "torso", C["leather_d"])
    return f


def npc_smith():
    """老刀匠：壮实老头，白须、头巾，皮围裙，光着膀子。顶视：头巾 + 宽肩"""
    f = _man("npc_smith", "老刀匠", heavy=True, thigh=C["char"], shin=C["char"], boot=C["boot"], sleeve=C["skin_old"], fore=C["skin_old"],
             hand=C["skin_old"], body=C["skin_old"], sk=C["leather"], sk_dark=C["leather_d"], belt_col=C["leather_d"], buckle=C["iron_l"],
             skin=C["skin_old"], hair=C["hair_w"], beard=C["hair_w"])
    f.fill(f.box(5, 10, 30, 64, -8, 8) & f.ell((3, 48, 0), (8.6, 18, 11)), "torso", C["leather"])
    f.fill(f.seg((5, 64, -7), (-4, 70, -8), 1.0) | f.seg((5, 64, 7), (-4, 70, 8), 1.0), "torso", C["leather_d"])
    bandana(f, C["navy"], tails=True)
    return f


def npc_monk():
    """守灯僧：灰僧袍、土黄袈裟、光头，右手提一盏青灯。顶视：光头 + 一点青光"""
    f = _man("npc_monk", "守灯僧", thigh=C["grey_d"], shin=C["grey_l"], boot=C["boot"], wraps=C["grey_d"], sleeve=C["grey"], body=C["grey"],
             sk=C["grey"], sk_dark=C["grey_d"], sk_bottom=12, belt_col=None, bald=True, wide=4)
    sash = f.ell((0.5, 57, 0), (8.8, 14, 12.2)) & ~f.ell((0.5, 57, 0), (6.4, 11.5, 9.8)) & ((f.Y - 56) > -f.Z * 1.0 - 6)
    f.fill(sash, "torso", C["saffron"])
    lantern_hand(f, "f", C["eye_c"])
    return f


def npc_he():
    """阿禾：村里的姑娘，一条长辫子，蓝布碎花衣，围裙。顶视：黑发 + 长辫"""
    B = "#4a6a9a"
    f = _man("npc_he", "阿禾", thigh=B, shin=B, boot=C["boot"], sleeve=B, body=B, collar=(C["paper"], "#2e4468"), sk=B, sk_dark="#2e4468",
             sk_bottom=14, belt_col=C["red"])
    f.paint((f.part >= 0) & (np.abs(f.col[..., 2] - 0x9a) < 10) & ((np.floor(f.X / 3) * 5 + np.floor(f.Y / 3) * 3 + np.floor(f.Z / 3)) % 7 == 0), C["paper"])
    f.fill(f.box(7, 10, 28, 50, -6, 6), "hips", C["paper"])
    f.fill(f.seg((-7, 84, 0), (-9, 60, 1), 2.4, 1.6), "head", C["hair"])
    f.fill(f.cyl(-9, 1, 2.2, 60, 63), "head", C["red"])
    return f


def npc_kid():
    """小满：小孩（游戏里缩小），两个小发髻，红袄。顶视：两团发髻"""
    f = _man("npc_kid", "小满", thigh=C["char"], shin=C["char"], boot=C["boot"], sleeve=C["red"], body=C["red"], collar=(C["gold"], C["red_d"]),
             sk=C["red"], sk_dark=C["red_d"], sk_bottom=30, belt_col=C["gold_d"])
    for s in (1, -1):
        f.fill(f.ell((-1, 88, 5 * s), (3.6, 3.6, 3.6)), "head", C["hair"])
        f.fill(f.cyl(-1, 5 * s, 3.8, 86, 87.5), "head", C["red"])
    return f


def hero_armor():
    """主角·铁甲（皮肤）：斗笠换成铁盔，身上铁札甲。袍子仍是绿色系，跟着皮肤换色"""
    f = _man("hero_armor", "主角铁甲", heavy=True, thigh=C["char"], shin=C["steel"], boot=C["lacq"], greave=C["steel_l"], sleeve=C["robe"],
             fore=C["steel"], hand=C["steel_d"], body=C["robe"], sk=C["steel"], sk_dark=C["steel_d"], sk_kind="flaps", belt_col=C["lacq"], buckle=C["brass"])
    chest_plate(f, C["steel"], C["steel_d"], C["steel_l"])
    pauldrons_round(f, C["steel"], C["steel_d"], C["steel_l"], z=15, r=(8, 6, 8))
    helm_round(f, C["steel"], C["steel_d"], crest="plume", crest_col=C["red"])
    cape(f, C["robe"], C["robe_d"], bottom=26, w=13, back=-8)
    return f


def hero_wild():
    """主角·北地蛮勇（皮肤）：狼头皮兜帽、毛皮披肩、光膀子绑皮带。顶视：一张灰狼皮"""
    W, Wd, Wl = "#8a8070", "#5a5246", "#b0a894"
    f = _man("hero_wild", "主角兽皮", heavy=True, thigh=C["leather_d"], shin=C["leather"], boot=C["boot"], wraps=C["leather_d"], sleeve=C["skin"],
             body=C["skin"], sk=C["leather"], sk_dark=C["leather_d"], belt_col=C["leather_d"], buckle=C["iron_l"])
    f.fill((np.abs((f.Y - 56) - f.Z * 0.9) < 2.0) & f.ell((0, 57, 0), (9.2, 15, 12.2)) & ~f.ell((0, 57, 0), (7.4, 13, 10.4)), "torso", C["leather_d"])
    hd = f.ell((0, 83, 0), (10, 9, 9.5)) & ~f.ell((3.5, 80, 0), (8.2, 8.6, 7.8)) & ~(f.side("x", ">", 5) & f.side("y", "<", 85))
    f.fill(hd, "head", W)
    f.fill(f.ell((7, 89, 0), (5, 3.5, 4.5)), "head", Wd)
    for s in (1, -1):
        f.fill(f.cone(-1, 6 * s, 2.2, 89, 0.4, 96), "head", Wd)
        f.fill(f.box(10, 12, 88, 90, 3 * s - 1, 3 * s + 1), "head", C["eye_y"])
    fur = f.ell((-2, 66, 0), (11, 7, 17)) & f.side("y", ">", 60)
    f.fill(fur, "torso", W)
    f.paint(fur & ((np.floor(f.X / 2) + np.floor(f.Z / 2)) % 3 == 0), Wl, part="torso")
    f.fill(f.box(-11, -6, 34, 66, -12, 12), "torso", Wd)
    return f


def huiming():
    """慧明（可选角色，云游僧）：大斗笠、灰袍土黄袈裟、背一只行脚箱。袍子用绿色系，跟着皮肤换色"""
    f = _man("huiming", "慧明", heavy=True, thigh=C["grey_d"], shin=C["cream"], boot=C["boot"], wraps=C["cream_d"], sleeve=C["robe"],
             body=C["robe"], sk=C["robe"], sk_dark=C["robe_d"], sk_bottom=16, belt_col=None, bald=True, wide=4)
    sash = f.ell((0.5, 57, 0), (9.0, 15, 12.6)) & ~f.ell((0.5, 57, 0), (6.6, 12.5, 10.2)) & ((f.Y - 56) > -f.Z * 1.0 - 6)
    f.fill(sash, "torso", C["saffron"])
    hat_straw(f, r=20, h=8, y0=88)
    f.fill(f.box(-20, -8, 42, 76, -9, 9), "torso", C["wood"])
    f.fill(f.box(-21, -7, 74, 78, -10, 10), "torso", C["wood_d"])
    return f


NPCS = {
    "npc_hag": npc_hag, "npc_merchant": npc_merchant, "npc_smith": npc_smith, "npc_monk": npc_monk, "npc_he": npc_he, "npc_kid": npc_kid,
    "hero_armor": hero_armor, "hero_wild": hero_wild, "huiming": huiming,
}
