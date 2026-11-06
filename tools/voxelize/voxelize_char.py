"""把带骨骼的 glTF 角色（KayKit 等）切成体素部件，给 VoxelRig 用。

用法（需要 python 包 trimesh numpy pillow pygltflib rtree）：
    python voxelize_char.py 模型.glb 输出.json --height 50 [--skip 网格名,网格名] [--extra 网格名:部件]

做法：
1. 按静止姿势算出每个骨骼的世界矩阵，蒙皮网格按权重变换到静止姿势；
2. 每个顶点归到权重最大的骨骼，再按骨骼归到部件（头、躯干、胯、上臂、前臂、大腿、小腿）；
   没蒙皮、挂在骨骼下面的网格（比如披风）归到它父骨骼的部件；
3. 整个模型转成游戏坐标（脚底 y=0，面朝 +x，+z 朝镜头），缩放到 --height 像素高；
4. 每个部件转到自己的局部坐标：原点在部件的起点关节，-y 指向终点关节（和 VoxelRig._place 一致），
   然后按 1 像素一格体素化，颜色从贴图上按 UV 取。
输出 JSON：joints（各关节静止位置）、parts（每块的起点、长度、体素列表 [x,y,z,r,g,b,...]）。
右手边（持刀手）算“前”（z+，靠镜头），左手边算“后”。
"""
import gzip, argparse, json, math
import numpy as np
import trimesh
from PIL import Image
from pygltflib import GLTF2
import io

GROUP = {
    "hips": "hips", "spine": "torso", "chest": "torso", "head": "head",
    "upperarm.r": "arm_u_f", "lowerarm.r": "arm_l_f", "wrist.r": "arm_l_f", "hand.r": "arm_l_f", "handslot.r": "arm_l_f",
    "upperarm.l": "arm_u_b", "lowerarm.l": "arm_l_b", "wrist.l": "arm_l_b", "hand.l": "arm_l_b", "handslot.l": "arm_l_b",
    "upperleg.r": "leg_u_f", "lowerleg.r": "leg_l_f", "foot.r": "leg_l_f", "toes.r": "leg_l_f",
    "upperleg.l": "leg_u_b", "lowerleg.l": "leg_l_b", "foot.l": "leg_l_b", "toes.l": "leg_l_b",
}
# 部件：起点关节 → 终点关节（None 表示竖直往下）
SPAN = {
    "torso": ("head", "hips"), "hips": ("hips", None), "head": ("head", None),
    "arm_u_f": ("upperarm.r", "lowerarm.r"), "arm_l_f": ("lowerarm.r", "wrist.r"),
    "arm_u_b": ("upperarm.l", "lowerarm.l"), "arm_l_b": ("lowerarm.l", "wrist.l"),
    "leg_u_f": ("upperleg.r", "lowerleg.r"), "leg_l_f": ("lowerleg.r", "foot.r"),
    "leg_u_b": ("upperleg.l", "lowerleg.l"), "leg_l_b": ("lowerleg.l", "foot.l"),
}
UPRIGHT = {"head"}   # 这些部件不按骨骼方向转，保持站直


def quat_mat(q):
    x, y, z, w = q
    return np.array([[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)],
                     [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)],
                     [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]])


def local_mat(n):
    m = np.eye(4)
    if n.matrix:
        return np.array(n.matrix).reshape(4, 4).T
    r = quat_mat(n.rotation) if n.rotation else np.eye(3)
    s = np.diag(n.scale) if n.scale else np.eye(3)
    m[:3, :3] = r @ s
    if n.translation:
        m[:3, 3] = n.translation
    return m


def accessor(g, blob, idx):
    a = g.accessors[idx]
    bv = g.bufferViews[a.bufferView]
    comp = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}[a.componentType]
    ncomp = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a.type]
    off = (bv.byteOffset or 0) + (a.byteOffset or 0)
    stride = bv.byteStride or (np.dtype(comp).itemsize * ncomp)
    raw = np.frombuffer(blob, dtype=np.uint8, count=stride * (a.count - 1) + np.dtype(comp).itemsize * ncomp, offset=off)
    out = np.lib.stride_tricks.as_strided(raw.view(np.uint8), shape=(a.count, np.dtype(comp).itemsize * ncomp), strides=(stride, 1))
    arr = np.frombuffer(out.copy().tobytes(), dtype=comp).reshape(a.count, ncomp)
    if a.normalized and comp != np.float32:
        arr = arr.astype(np.float32) / np.iinfo(comp).max
    return arr


def texture_of(g, blob, prim):
    if prim.material is None:
        return None, None
    mat = g.materials[prim.material]
    pbr = mat.pbrMetallicRoughness
    base = np.array(pbr.baseColorFactor or [1, 1, 1, 1])[:3]
    if pbr.baseColorTexture is None:
        return None, base
    tex = g.textures[pbr.baseColorTexture.index]
    img = g.images[tex.source]
    if img.bufferView is not None:
        bv = g.bufferViews[img.bufferView]
        data = blob[(bv.byteOffset or 0):(bv.byteOffset or 0) + bv.byteLength]
        im = Image.open(io.BytesIO(data)).convert("RGB")
    else:
        import os
        im = Image.open(os.path.join(os.path.dirname(ARGS.model), img.uri)).convert("RGB")
    return np.asarray(im), base


def main():
    g = GLTF2().load(ARGS.model)
    blob = g.binary_blob()
    if blob is None:
        blob = g.load_file_uri(g.buffers[0].uri) if hasattr(g, "load_file_uri") else None
    n = len(g.nodes)
    parent = [-1] * n
    for i, nd in enumerate(g.nodes):
        for c in nd.children or []:
            parent[c] = i
    world = [None] * n

    def wm(i):
        if world[i] is None:
            m = local_mat(g.nodes[i])
            world[i] = (wm(parent[i]) @ m) if parent[i] >= 0 else m
        return world[i]
    for i in range(n):
        wm(i)
    name_of = {i: nd.name for i, nd in enumerate(g.nodes)}
    joint_world = {nd.name: world[i][:3, 3].copy() for i, nd in enumerate(g.nodes)}

    skip = set(filter(None, ARGS.skip.split(",")))
    extra = dict(e.split(":") for e in filter(None, ARGS.extra.split(",")))
    tris = []   # (三角形顶点 3x3, uv 3x2, 贴图, 底色, 部件)
    for i, nd in enumerate(g.nodes):
        if nd.mesh is None or nd.name in skip:
            continue
        mesh = g.meshes[nd.mesh]
        for prim in mesh.primitives:
            pos = accessor(g, blob, prim.attributes.POSITION).astype(np.float64)
            uv = accessor(g, blob, prim.attributes.TEXCOORD_0) if prim.attributes.TEXCOORD_0 is not None else np.zeros((len(pos), 2))
            ind = accessor(g, blob, prim.indices).reshape(-1, 3) if prim.indices is not None else np.arange(len(pos)).reshape(-1, 3)
            img, base = texture_of(g, blob, prim)
            if nd.skin is not None:
                skin = g.skins[nd.skin]
                ibm = accessor(g, blob, skin.inverseBindMatrices).reshape(-1, 4, 4).transpose(0, 2, 1)
                J = accessor(g, blob, prim.attributes.JOINTS_0).astype(int)
                W = accessor(g, blob, prim.attributes.WEIGHTS_0).astype(np.float64)
                mats = np.array([world[j] @ ibm[k] for k, j in enumerate(skin.joints)])
                hp = np.c_[pos, np.ones(len(pos))]
                out = np.zeros((len(pos), 3))
                for c in range(4):
                    m = mats[J[:, c]]
                    out += W[:, c:c+1] * np.einsum("nij,nj->ni", m, hp)[:, :3]
                pos_w = out
                dom = [name_of[skin.joints[j]] for j in J[np.arange(len(J)), W.argmax(1)]]
                vgroup = [GROUP.get(d, None) for d in dom]
            else:
                hp = np.c_[pos, np.ones(len(pos))]
                pos_w = (world[i] @ hp.T).T[:, :3]
                p = parent[i]
                grp = extra.get(nd.name)
                while grp is None and p >= 0:
                    grp = GROUP.get(name_of[p])
                    p = parent[p]
                vgroup = [grp] * len(pos)
            for f in ind:
                gs = [vgroup[k] for k in f]
                grp = max(set(gs), key=gs.count)
                if grp is None:
                    continue
                tris.append((pos_w[f], uv[f], img, base, grp))

    # 转到游戏坐标：面朝 +z → 面朝 +x，左手 (+x) → 后 (z-)
    allp = np.concatenate([t[0] for t in tris])
    y0, y1 = allp[:, 1].min(), allp[:, 1].max()
    scale = ARGS.height / (y1 - y0)

    def to_game(p):
        p = np.atleast_2d(p)
        return np.c_[p[:, 2], p[:, 1] - y0, -p[:, 0]] * scale

    joints = {k: to_game(v)[0] for k, v in joint_world.items()}
    parts = {}
    for part, (a, b) in SPAN.items():
        sel = [t for t in tris if t[4] == part]
        if not sel:
            continue
        A = joints[a]
        if b is None or part in UPRIGHT:
            d = np.array([0, -1.0, 0])
            L = 0.0 if b is None else float(np.linalg.norm(joints[b] - A))
        else:
            d = joints[b] - A
            L = float(np.linalg.norm(d))
            d = d / L
        # 最小旋转：d → (0,-1,0)
        tgt = np.array([0, -1.0, 0])
        v = np.cross(d, tgt)
        c = float(np.dot(d, tgt))
        if np.linalg.norm(v) < 1e-6:
            R = np.eye(3) if c > 0 else np.diag([1, -1, -1.0])
        else:
            vx = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
            R = np.eye(3) + vx + vx @ vx * (1 / (1 + c))
        V = np.concatenate([to_game(t[0]) for t in sel])
        V = (R @ (V - A).T).T
        F = np.arange(len(V)).reshape(-1, 3)
        m = trimesh.Trimesh(V, F, process=False)
        vg = m.voxelized(1.0)
        try:
            vg = vg.fill()
        except Exception:
            pass
        pts = vg.points
        cp, _, tri = trimesh.proximity.closest_point(m, pts)
        bary = trimesh.triangles.points_to_barycentric(m.triangles[tri], cp)
        cols = []
        for q, (ti, bb) in enumerate(zip(tri, bary)):
            _, uvs, img, base, _ = sel[ti]
            if img is None:
                rgb = (np.clip(base if base is not None else [0.8, 0.8, 0.8], 0, 1) * 255).astype(int)
            else:
                u, w = (uvs * bb[:, None]).sum(0)
                h, wd, _ = img.shape
                rgb = img[int(np.clip((w % 1) * h, 0, h - 1)), int(np.clip((u % 1) * wd, 0, wd - 1))]
                if base is not None:
                    rgb = (rgb * base).astype(int)
            cols.append(rgb)
        cells = np.floor(pts + 1e-6).astype(int)
        occ = {}
        for cc, rgb in zip(cells, cols):
            occ.setdefault(tuple(int(x) for x in cc), rgb)
        flat = []
        seen = set()
        for k, rgb in occ.items():
            x, y, z = k
            # 只留表面（六个面都被挡住的里层方块看不见，不存）
            if all((x + dx, y + dy, z + dz) in occ for dx, dy, dz in ((1,0,0),(-1,0,0),(0,1,0),(0,-1,0),(0,0,1),(0,0,-1))):
                continue
            seen.add(k)
            flat += [x, y, z, int(rgb[0]), int(rgb[1]), int(rgb[2])]
        parts[part] = {"anchor": [round(float(x), 2) for x in A], "len": round(L, 2), "vox": flat}
        print(part, "voxels", len(seen), "len", round(L, 1))
    keep = ["hips", "spine", "chest", "head", "upperarm.r", "lowerarm.r", "wrist.r", "upperarm.l", "lowerarm.l", "wrist.l",
            "upperleg.r", "lowerleg.r", "foot.r", "upperleg.l", "lowerleg.l", "foot.l"]
    # res：游戏里角色身高固定按 50 格算，身高给得越高体素切得越细（100 → 一格切成 2×2×2）
    out = {"source": ARGS.source, "license": ARGS.license, "height": ARGS.height, "res": round(ARGS.height / 50.0, 3),
           "joints": {k: [round(float(x), 2) for x in joints[k]] for k in keep if k in joints}, "parts": parts}
    with gzip.open(ARGS.out + ".gz", "wt", compresslevel=9) as f:   # 存成 <out>.gz，游戏读 .json.gz（VoxelModel.read_data）
        json.dump(out, f, separators=(",", ":"))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("model")
    ap.add_argument("out")
    ap.add_argument("--height", type=float, default=50.0)
    ap.add_argument("--skip", default="")
    ap.add_argument("--extra", default="")
    ap.add_argument("--source", default="")
    ap.add_argument("--license", default="CC0 1.0")
    ARGS = ap.parse_args()
    main()
