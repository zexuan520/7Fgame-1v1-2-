"""第一、二层的人形敌人：行头（外观）和姿势表，按敌人数据表里用到的招式生成动作。

每个敌人一份行头 COSTUMES[kind]，一份姿势 POSES（所有人形敌人共用，个别敌人覆盖）。
动作的名字游戏里直接用：
  idle_far / idle_near     远处放松、近处戒备（呼吸循环）
  walk_far / walk_near     走动（往后退时游戏里倒着播）
  guard / hit / broken / death
  "<蓄力姿势>><出手姿势>"   一段招式：前摇 2 帧、出手 2 帧（带刀光）、收势 2 帧，phases = [2, 2, 2]
  fl_<花样>                浪人走着走着耍的花样
游戏里 Enemy 按 EnemyData 里每招的 poses 拼出动作名去找；找不到的退回 "raise1>cut1"。
"""
import math
from humanoid import pose as P, lerp_pose

SKIN = ["5a3424", "9a6448", "c88a62", "e0a880"]
OUT = "1c1424"


def _hc(r, extra=None):
    """头的调色：r 是行头的 ramps"""
    c = {"K": OUT, "H": r["hair"][2], "h": r["hair"][3], "S": r["skin"][2], "s": r["skin"][1], "G": r["skin"][3], "E": "1a1418",
         "e": "f0e0b0", "B": r["hair"][1], "R": "7a3a32"}
    if "hat" in r:
        c.update({"T": r["hat"][2], "t": r["hat"][1], "L": r["hat"][3]})
    if "metal" in r:
        c.update({"M": r["metal"][2], "m": r["metal"][1], "N": r["metal"][3]})
    if "band" in r:
        c.update({"W": r["band"][2], "w": r["band"][1]})
    if extra:
        c.update(extra)
    return c


def _costume(**kw):
    c = dict(scale=1.0, sleeves="wide", legs="hakama", feet="sandal", skirt=0, cape=None, armor=False,
             weapon="katana", shield=False, quiver=False, sheath=False, band_tails=False, swlen=22.0, width=1.0)
    c.update(kw)
    c["head_colors"] = _hc(c["ramps"], c.pop("head_extra", None))
    return c


STEEL = ["2a2e38", "8a929e", "c4ccd6", "eef2f8"]
WRAP = ["2a2014", "6a5434", "9a8058", "c4aa7c"]       # 草鞋、绑腿（草色）

COSTUMES = {
    # 堕落浪人：压低的斗笠、红褐色旧衣、破披风、长刀
    "ronin": _costume(scale=1.12, head="kasa", cape="ragged", width=1.12, swlen=26.0, sheath=True, ramps={
        "cloth": ["2a0e10", "5a2220", "7e3428", "a24a36"], "collar": ["3a3428", "8a8270", "b8ab96", "d8cdb8"],
        "pants": ["0e0c12", "24202a", "35303d", "4c4656"], "skin": SKIN, "hair": ["0c0808", "1e1412", "2a1a14", "44302a"],
        "belt": ["1e1810", "4a3e2a", "6d6247", "8e8262"], "cape": ["140c0c", "2e201e", "42302c", "5a443e"],
        "hat": ["3a2a14", "7a5e34", "a8885a", "cdb07c"], "wrap": WRAP, "blade": STEEL,
        "hilt": ["0c0a10", "2a2230", "3e3446", "5a4e66"], "guard": ["4a3410", "8a6a2a", "c9a24a", "eed27a"],
        "sheath": ["0a0808", "1e1616", "2e2222", "463434"]},
        head_extra={"e": "f8e8a0"}),
    # 弓手：绿褐短打、头带、绑腿、背箭袋
    "archer": _costume(scale=1.0, head="bandana", sleeves="tight", legs="wrapped", weapon="bow", quiver=True,
                       band_tails=True, ramps={
        "cloth": ["141a0c", "2e3a1e", "4d5a3a", "6f7e52"], "collar": ["3a3428", "8a8270", "a89f86", "c8bfa6"],
        "pants": ["140f0a", "2e2419", "4a3a28", "66543c"], "skin": SKIN, "hair": ["0c0808", "1e1612", "2e2018", "4a3426"],
        "belt": ["1e1408", "4a3218", "7a5a32", "9a7a4a"], "band": ["2a0a0a", "5a1a18", "8a2a24", "b0443a"],
        "wrap": WRAP, "wood": ["1e1208", "4a2e18", "6e4626", "946238"], "blade": STEEL}),
    # 盾兵：铁斗笠、铁甲片、木盾、长枪
    "shield": _costume(scale=1.08, head="jingasa", sleeves="tight", legs="wrapped", armor=True, weapon="spear",
                       shield=True, width=1.18, swlen=34.0, ramps={
        "cloth": ["10121a", "262a36", "3a3f4e", "545a6c"], "collar": ["3a3428", "7a7264", "9a9184", "bab0a2"],
        "pants": ["0e0d12", "1f1e24", "2b2a30", "434149"], "skin": SKIN, "hair": ["0c0a0a", "1e1816", "2a201c", "443630"],
        "belt": ["1e1408", "3a2c18", "5a4a33", "7a6848"], "metal": ["101218", "3a3f4a", "5c6270", "8a909e"],
        "wrap": ["1a1814", "3a362e", "5a5446", "7a7262"], "wood": ["1a0f08", "43301f", "6b4a2e", "8e6a44"],
        "blade": STEEL, "tassel": ["5a0e0e", "8a1e1a", "c0302a", "e04a3a"]}),
    # 柳江远：白灰长衣、深蓝外褂、白头带、长刀，个子高
    "liu": _costume(scale=1.16, head="liu", cape="haori", legs="hakama", feet="boot", skirt=12, sheath=True,
                    band_tails=True, swlen=28.0, width=1.05, ramps={
        "cloth": ["3a4250", "858fa0", "c8cdd4", "eef1f4"], "collar": ["0a1020", "1a2436", "2b3a52", "40567a"],
        "pants": ["0a1020", "1a2436", "2b3a52", "40567a"], "skin": ["5a3424", "a06a50", "e2b294", "f4cdb0"],
        "hair": ["0c0c10", "1e1e26", "2c2c36", "8a8a96"], "belt": ["0a1428", "1e2e4a", "33476b", "4a6a9a"],
        "cape": ["0c1424", "1e2e48", "2f4766", "45628a"], "band": ["8a929e", "c4ccd6", "e8ecf0", "ffffff"],
        "boot": ["0a0a10", "1a1a24", "2a2a36", "44445a"], "blade": ["2a3040", "8a98aa", "cad6e2", "f4f8ff"],
        "hilt": ["0a0c14", "1a2030", "2a3448", "40506a"], "guard": ["3a4250", "7a8494", "b8c0cc", "e8ecf0"],
        "sheath": ["0a0e18", "1a2234", "2a3448", "40506a"]}),
    # 教头：灰衣、发髻，新手引导里一招一招喂招
    "tutor": _costume(scale=1.08, head="topknot", width=1.08, swlen=24.0, sheath=True, ramps={
        "cloth": ["1e1e26", "3a3a44", "5a5a64", "7a7a86"], "collar": ["3a3428", "9a9282", "c8c0b0", "e0d8c8"],
        "pants": ["0e0d12", "1c1b20", "2e2c34", "46444e"], "skin": SKIN, "hair": ["0c0a0a", "1e1816", "2a201c", "443630"],
        "belt": ["1e1408", "4a3218", "8a6a3a", "aa8a5a"], "wrap": WRAP, "blade": STEEL,
        "hilt": ["0c0a10", "2a2230", "3e3446", "5a4e66"], "guard": ["4a3410", "8a6a2a", "c9a24a", "eed27a"],
        "sheath": ["0a0808", "1e1616", "2e2222", "463434"]}),

    # ===== 第二层：竹林古寺 =====
    # 僧兵：白布裹头、赭黄僧衣、绑腿草鞋、两头包铁的长棍
    "sohei": _costume(scale=1.1, head="sohei", sleeves="wide", legs="wrapped", skirt=8, weapon="staff", width=1.18,
                      swlen=30.0, grip_gap=7.0, canvas=(176, 120, 80, 110), ramps={
        "cloth": ["3a200c", "7a4a1c", "b8742e", "d8964a"], "collar": ["5a5040", "a89c84", "e0d0b0", "f4ecd8"],
        "pants": ["1a120c", "2e241a", "4a3a2a", "6a5440"], "skin": SKIN, "hair": ["0c0808", "1e1612", "2e2018", "4a3426"],
        "band": ["6a6252", "b0a894", "e0d8c8", "f6f2e8"], "belt": ["2a140a", "4a2410", "6a3a1a", "8a5a2e"],
        "wrap": ["2a2418", "6a6250", "a89e86", "d0c6ae"], "wood": ["1e1208", "4a2e18", "7a5432", "9a7448"],
        "metal": ["1e1c18", "4a4840", "7a766a", "a8a294"]}),
    # 忍者：一身黑、蒙面、红头带，短直刀，个子小
    "shinobi": _costume(scale=0.95, head="shinobi", sleeves="tight", legs="wrapped", band_tails=True, swlen=17.0,
                        width=0.92, ramps={
        "cloth": ["0a0a10", "1a1a22", "2a2a34", "3e3e4c"], "collar": ["0a0a10", "1a1a22", "22222c", "34343e"],
        "pants": ["08080c", "15151c", "22222c", "34343e"], "skin": SKIN, "hair": ["08080c", "15151c", "26262f", "3a3a46"],
        "band": ["4a0a0a", "7a1818", "a02a2a", "c84a3a"], "belt": ["140e0e", "2a1e1e", "3a2a2a", "543e3e"],
        "wrap": ["0a0a10", "1a1a22", "2a2a34", "40404e"], "blade": STEEL,
        "hilt": ["0a0a10", "1e1a22", "2e2832", "463e4c"], "guard": ["0e0e12", "2a2a30", "44444c", "62626c"]}),
    # 破戒僧：大个子、光头络腮胡、暗紫僧衣、胸前大念珠、铁箍长棍
    "hakai": _costume(scale=1.25, head="hakai", sleeves="wide", legs="hakama", skirt=10, weapon="staff", width=1.32,
                      swlen=32.0, grip_gap=8.0, beads=True, canvas=(176, 120, 80, 110), ramps={
        "cloth": ["1a0e14", "2e1a24", "4a2a3a", "6a3e54"], "collar": ["5a4a36", "8a7a5e", "c8b090", "e0d0b4"],
        "pants": ["0e0a0c", "1a1418", "2a2026", "40323a"], "skin": ["4a2a1c", "8a5a40", "b88468", "d8a888"],
        "hair": ["0c0808", "1e1410", "2e2018", "4a3426"], "belt": ["2a0808", "5a1414", "8a2a2a", "aa4040"],
        "wrap": WRAP, "wood": ["140c08", "2e2018", "4a3a2a", "6a5844"], "metal": ["3a2a08", "7a5a14", "c9a227", "eed27a"],
        "beads": ["1a0c06", "4a2a14", "7a4a24", "a8743c"]}),
    # 寂光：白僧衣、深红外褂和袈裟、光头，腰挂刀
    "jakko": _costume(scale=1.14, head="jakko", cape="haori", legs="hakama", skirt=12, sheath=True, kesa=True,
                      swlen=27.0, width=1.05, ramps={
        "cloth": ["5a5448", "9a9080", "d8d0c0", "f0ece4"], "collar": ["2a0e0e", "4a1a1a", "6a2a28", "8a3a36"],
        "pants": ["140c0c", "241a1a", "3a2a2a", "54403c"], "skin": ["5a3424", "a87858", "d8a888", "f0c8a8"],
        "hair": ["5a3424", "a87858", "c89878", "e0b494"], "belt": ["2a0808", "5a1414", "8a2a2a", "aa4040"],
        "cape": ["1e0a0a", "3a1616", "542424", "703430"], "kesa": ["3a0e0e", "6a1a18", "8e2c28", "b44c3c"],
        "wrap": WRAP, "blade": ["2a3040", "8a98aa", "cad6e2", "f4f8ff"],
        "hilt": ["0c0a10", "2a1a1a", "3e2626", "5a3a36"], "guard": ["3a2a08", "7a5a14", "c9a227", "eed27a"],
        "sheath": ["0a0606", "1e1010", "321a1a", "4a2828"]}),
}

# ---------------- 姿势（人形敌人共用；数字和主角同一套，按身材放大） ----------------
# 敌人双手握刀（和主角的单手剑区分开），出招前的蓄势拉得更开，好让玩家看清

POSES = {}


def _p(name, **kw):
    POSES[name] = kw


# 待机
_p("stalk", hip=(-1.0, -16.0), lean=0.15, ff=(7.0, 0.0), fb=(-6.5, 0.0), hf=(8.0, -22.5), sw=1.95, grip2=True)
_p("shoulder", hip=(0.0, -18.0), lean=0.02, ff=(3.5, 0.0), fb=(-3.5, 0.0), hf=(4.0, -24.5), sw=-2.55, sw_back=True,
   hb=(-3.0, -14.0), ebf=-1)
_p("st_gedan", hip=(-1.0, -16.5), lean=0.12, ff=(7.0, 0.0), fb=(-6.5, 0.0), hf=(9.0, -18.0), sw=1.05, grip2=True)
_p("st_jodan", hip=(-1.0, -17.0), lean=-0.06, ff=(7.0, 0.0), fb=(-6.5, 0.0), hf=(2.0, -36.0), sw=3.45, grip2=True,
   ebf=1, sw_back=True)
_p("st_iai", hip=(-1.0, -15.0), lean=0.28, ff=(8.0, 0.0), fb=(-7.0, 0.0), hf=(6.0, -18.0), hb=(1.5, -17.0))
# 八相：刀竖在右肩旁，刀尖朝天（寂光近处的架势）
_p("st_hasso", hip=(-1.0, -17.0), lean=0.04, ff=(7.0, 0.0), fb=(-6.5, 0.0), hf=(4.0, -28.0), sw=3.3, grip2=True,
   ebf=1)
_p("liu_calm", hip=(0.0, -18.5), lean=-0.03, ff=(3.5, 0.0), fb=(-3.5, 0.0), hf=(5.5, -19.0), hb=(-4.5, -17.5))
# 招式：蓄力 / 出手
_p("raise1", hip=(-1.0, -17.5), lean=-0.1, ff=(7.0, 0.0), fb=(-7.0, 0.0), hf=(2.0, -35.0), sw=3.6, grip2=True,
   ebf=1, sw_back=True)
_p("cut1", hip=(2.0, -15.0), lean=0.3, ff=(11.0, 0.0), fb=(-7.0, 0.0), hf=(12.0, -18.0), sw=1.0, grip2=True, robe=2.0)
_p("raise2", hip=(-0.5, -15.0), lean=0.25, ff=(8.0, 0.0), fb=(-7.0, 0.0), hf=(-1.0, -16.0), sw=-1.05, grip2=True,
   sw_back=True)
_p("cut2", hip=(1.0, -18.0), lean=-0.05, ff=(10.0, 0.0), fb=(-5.0, -1.0), fba=0.4, hf=(8.0, -32.0), sw=2.9,
   grip2=True, lift=1.0)
_p("raise3", hip=(-2.0, -16.0), lean=-0.05, ff=(6.0, 0.0), fb=(-8.0, 0.0), hf=(0.0, -23.0), sw=1.6, grip2=True)
_p("cut3", hip=(3.0, -14.5), lean=0.35, ff=(13.0, 0.0), fb=(-9.0, 0.0), fba=0.4, hf=(16.0, -22.0), sw=1.6,
   grip2=True, robe=4.0)
# 迟砸：从上段整个砸到地上，身子跟着扑下去
_p("smash", hip=(3.0, -13.0), lean=0.5, ff=(13.0, 0.0), fb=(-9.0, 0.0), fba=0.4, hf=(15.0, -13.0), sw=1.42,
   grip2=True, robe=4.0)
_p("thrust_prep", hip=(-2.5, -15.0), lean=-0.06, ff=(6.0, 0.0), fb=(-9.0, 0.0), hf=(-2.0, -21.0), sw=1.6, grip2=True)
_p("sweep_prep", hip=(0.0, -12.0), lean=0.4, ff=(8.0, 0.0), fb=(-8.0, 0.0), hf=(-2.0, -11.0), sw=-1.35, grip2=True,
   sw_back=True)
_p("sweep_cut", hip=(2.0, -11.0), lean=0.5, ff=(12.0, 0.0), fb=(-9.0, 0.0), hf=(14.0, -9.0), sw=1.45, grip2=True,
   robe=3.0)
_p("iai_cut", hip=(3.0, -14.5), lean=0.35, ff=(13.0, 0.0), fb=(-9.0, 0.0), hf=(16.0, -21.0), sw=1.6,
   hb=(-10.0, -22.0), ebb=1, robe=4.0)
_p("grab_prep", hip=(-1.0, -14.5), lean=0.25, ff=(8.0, 0.0), fb=(-8.0, 0.0), hf=(-3.0, -19.0), sw=-1.6,
   sw_back=True, hb=(7.0, -24.0), open_hand=True)
_p("grab_reach", hip=(3.0, -14.0), lean=0.5, ff=(13.0, 0.0), fb=(-9.0, 0.0), hf=(-1.0, -18.0), sw=-1.7,
   sw_back=True, hb=(17.0, -22.0), open_hand=True, robe=4.0)
_p("hop", hip=(-1.0, -19.5), lean=-0.15, ff=(3.0, -4.0), fb=(-5.0, -2.0), ffa=0.5, fba=0.7, hf=(7.0, -24.0), sw=2.2,
   grip2=True, robe=-2.0, lift=-1.0)
# 受击、格挡、倒下
_p("guard", hip=(-1.0, -16.0), lean=0.0, ff=(7.0, 0.0), fb=(-7.0, 0.0), hf=(7.0, -26.0), sw=2.75, grip2=True)
_p("hit", hip=(-2.0, -17.0), lean=-0.25, ff=(6.0, 0.0), fb=(-7.0, 0.0), hf=(5.0, -19.0), sw=1.2, head="h",
   hb=(-8.0, -23.0), robe=-1.5, sleeve=-2.0)
_p("broken", hip=(0.0, -14.0), lean=0.6, ff=(7.0, 0.0), fb=(-6.0, 0.0), hf=(7.0, -11.0), sw=1.3, hb=(1.0, -10.0),
   head="h")
_p("kneel", hip=(0.0, -10.0), lean=0.3, ff=(7.0, 0.0), fb=(-5.0, 0.0), fba=1.3, hf=(7.0, -8.0), sw=1.45,
   hb=(2.0, -8.0), head="c")
# 弓手
_p("bow_idle", hip=(0.0, -18.0), lean=0.0, ff=(3.5, 0.0), fb=(-3.5, 0.0), hf=(5.0, -15.5), hb=(-3.0, -14.0), bowv=True)
_p("bow_ready", hip=(-1.0, -17.0), lean=0.05, ff=(6.0, 0.0), fb=(-6.0, 0.0), hf=(11.0, -23.0), hb=(4.0, -21.0))
_p("bow_draw", hip=(-1.5, -17.0), lean=-0.05, ff=(7.0, 0.0), fb=(-6.5, 0.0), hf=(13.0, -25.0), hb=(0.0, -25.0),
   ebb=1, pull=True)
_p("bow_loose", hip=(-1.5, -17.0), lean=-0.08, ff=(7.0, 0.0), fb=(-6.5, 0.0), hf=(13.0, -25.0), hb=(-6.0, -27.0),
   ebb=1)
_p("kick_prep", hip=(-1.0, -18.0), lean=-0.08, ff=(4.0, -8.0), fb=(-4.0, 0.0), hf=(8.0, -22.0), hb=(-6.0, -22.0))
_p("kick", hip=(-2.0, -18.5), lean=-0.25, ff=(13.0, -11.0), fb=(-4.0, 0.0), hf=(6.0, -22.0), hb=(-8.0, -24.0))
# 盾兵：盾在后手、枪在前手
_p("shield_stance", hip=(-1.0, -16.5), lean=0.1, ff=(7.0, 0.0), fb=(-6.5, 0.0), hb=(8.0, -17.0), hf=(3.0, -27.0),
   sw=1.66)
_p("bash_prep", hip=(-2.0, -16.5), lean=-0.05, ff=(6.0, 0.0), fb=(-8.0, 0.0), hb=(4.0, -17.0), hf=(0.0, -27.0),
   sw=1.66)
_p("bash", hip=(3.0, -15.0), lean=0.35, ff=(12.0, 0.0), fb=(-8.0, 0.0), hb=(15.0, -18.0), hf=(6.0, -27.0), sw=1.66,
   robe=3.0)
_p("spear_prep", hip=(-2.5, -16.0), lean=-0.06, ff=(6.0, 0.0), fb=(-9.0, 0.0), hb=(6.0, -17.0), hf=(-5.0, -27.0),
   sw=1.62)
_p("spear", hip=(3.0, -14.5), lean=0.35, ff=(13.0, 0.0), fb=(-9.0, 0.0), hb=(10.0, -17.0), hf=(14.0, -26.0),
   sw=1.62, robe=3.0)


# 每个敌人只用到一部分姿势：远处、近处待机 + 招式里的姿势对
USES = {
    "ronin": {"idle": ("shoulder", "stalk"),
              "pairs": [("raise1", "cut1"), ("raise2", "cut2"), ("sweep_prep", "sweep_cut"), ("thrust_prep", "cut3")]},
    "archer": {"idle": ("bow_idle", "bow_ready"), "weaponless": True,
               "pairs": [("bow_draw", "bow_loose"), ("kick_prep", "kick"), ("hop", "hop")]},
    "shield": {"idle": ("shield_stance", "shield_stance"),
               "pairs": [("bash_prep", "bash"), ("spear_prep", "spear")]},
    "liu": {"idle": ("liu_calm", "st_gedan"),
            "pairs": [("raise1", "cut1"), ("raise2", "cut2"), ("raise3", "cut3"), ("st_jodan", "cut1"),
                      ("thrust_prep", "cut3"), ("sweep_prep", "sweep_cut"), ("grab_prep", "grab_reach"),
                      ("st_iai", "iai_cut"), ("hop", "hop")]},
    "tutor": {"idle": ("st_gedan", "st_gedan"),
              "pairs": [("raise1", "cut1"), ("sweep_prep", "sweep_cut"), ("thrust_prep", "cut3")]},
    "sohei": {"idle": ("shoulder", "stalk"),
              "pairs": [("raise1", "cut1"), ("raise2", "cut2"), ("sweep_prep", "sweep_cut"), ("spear_prep", "spear")]},
    "shinobi": {"idle": ("stalk", "stalk"),
                "pairs": [("thrust_prep", "cut3"), ("raise2", "cut2"), ("hop", "hop")]},
    "hakai": {"idle": ("shoulder", "stalk"),
              "pairs": [("raise1", "cut1"), ("raise2", "cut2"), ("raise3", "cut3"), ("st_jodan", "smash"),
                        ("sweep_prep", "sweep_cut"), ("spear_prep", "spear")]},
    "jakko": {"idle": ("liu_calm", "st_hasso"),
              "pairs": [("raise1", "cut1"), ("raise2", "cut2"), ("raise3", "cut3"), ("st_jodan", "cut1"),
                        ("thrust_prep", "cut3"), ("sweep_prep", "sweep_cut"), ("grab_prep", "grab_reach"),
                        ("st_iai", "iai_cut"), ("st_iai", "st_iai"), ("hop", "hop")]},
}

# 危招（不能挡）用红色刀光
DANGER_PAIRS = {("sweep_prep", "sweep_cut"), ("thrust_prep", "cut3"), ("grab_prep", "grab_reach"), ("spear_prep", "spear")}


def get(kind, name, **over):
    d = dict(POSES[name])
    d.update(over)
    if USES[kind].get("weaponless"):
        d["sw"] = None
        d["grip2"] = False
    if kind == "shield" and d.get("grip2"):
        # 盾兵不双手握：后手拿盾
        d["grip2"] = False
        d["hb"] = d.get("hb") or (8.0, -20.0)
    if COSTUMES[kind]["weapon"] == "staff" and name in ("spear_prep", "spear"):
        # 长棍戳出去是双手推的（盾兵那套是单手枪）
        d["grip2"] = True
    return P(**d)
