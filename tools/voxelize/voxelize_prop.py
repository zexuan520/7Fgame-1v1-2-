"""把不带骨骼的 glTF 摆设（KayKit 地牢、万圣节、中世纪等）体素化，给场景用。

用法（需要 python 包 trimesh numpy pillow scipy rtree）：
    python voxelize_prop.py 模型.gltf 输出.json --ppu 22 --vs 2 [--source 出处]
    python voxelize_prop.py --batch 清单.txt 输出目录 --ppu 22 --vs 2

--ppu：模型 1 个单位等于多少像素（KayKit 角色 2.25 单位高，对上游戏里 50 像素就是 22）。
--vs：一格体素多少像素（摆设用 2，比角色的 1 粗一点，省面数）。
--fit-h：直接指定整件摆设多高（像素），会覆盖 --ppu。
坐标：游戏坐标和模型一样（x 横、y 上、z 朝镜头，KayKit 摆设正面就是 +z），原点在底面中心。
输出 JSON：{"vs": 格子像素, "size": [宽, 高, 深]（格）, "vox": [x, y, z, r, g, b, ...]}，只存表面方块。
清单每行：输出名 模型路径 [ppu 或 h=像素高]，# 开头是注释。
"""
import gzip, argparse, json, os, sys
import numpy as np
import trimesh
from PIL import Image


def mesh_colors(m, pts, tri):
    """给每个体素中心取颜色：最近的三角形按重心插值 UV，再去贴图上取。"""
    cp = trimesh.triangles.closest_point(m.triangles[tri], pts)
    bary = trimesh.triangles.points_to_barycentric(m.triangles[tri], cp)
    vis = m.visual
    img = None
    base = np.array([200, 200, 200])
    if isinstance(vis, trimesh.visual.texture.TextureVisuals):
        mat = vis.material
        im = getattr(mat, "baseColorTexture", None) or getattr(mat, "image", None)
        if im is not None:
            img = np.asarray(im.convert("RGB"))
        bc = getattr(mat, "baseColorFactor", None)
        if bc is not None:
            base = np.array(bc[:3]) if np.max(bc[:3]) > 1.0 else np.array(bc[:3]) * 255
        if img is not None and vis.uv is not None:
            uv = vis.uv[m.faces[tri]]                     # (n, 3, 2)
            u, v = (uv * bary[:, :, None]).sum(1).T
            h, w, _ = img.shape
            # trimesh 读 glTF 时已经把 v 翻成了左下原点，这里再翻回来按行取
            ys = np.clip(((1.0 - (v % 1.0)) * h).astype(int), 0, h - 1)
            xs = np.clip(((u % 1.0) * w).astype(int), 0, w - 1)
            col = img[ys, xs].astype(float)
            if bc is not None and np.max(bc[:3]) <= 1.0:
                col = col * np.array(bc[:3])
            return col.astype(int)
    elif hasattr(vis, "face_colors"):
        return vis.face_colors[tri][:, :3].astype(int)
    return np.tile(base.astype(int), (len(pts), 1))


def voxelize(path, ppu, vs, fit_h=None, grip=False):
    scene = trimesh.load(path, force="scene")
    meshes = []
    for node in scene.graph.nodes_geometry:
        tf, gname = scene.graph[node]
        g = scene.geometry[gname].copy()
        g.apply_transform(tf)
        meshes.append(g)
    allv = np.concatenate([m.vertices for m in meshes])
    lo, hi = allv.min(0), allv.max(0)
    if fit_h:
        ppu = fit_h / max(hi[1] - lo[1], 1e-6)
    pitch = vs / ppu                                  # 一格是模型里多长
    center = np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])
    if grip:
        # 武器：原点留在握把（模型原点），刃朝 +y 的转成朝 -y（和 VoxelRig 的部件一样）
        center = np.zeros(3)
        for m in meshes:
            m.vertices = m.vertices * np.array([-1.0, -1.0, 1.0])
    occ = {}
    for m in meshes:
        m.vertices = (m.vertices - center) / pitch    # 换成格子单位
        try:
            vg = m.voxelized(1.0)
            try:
                vg = vg.fill()
            except Exception:
                pass
        except Exception:
            continue
        pts = vg.points
        if len(pts) == 0:
            continue
        _, _, tri = trimesh.proximity.closest_point(m, pts)
        cols = mesh_colors(m, pts, tri)
        for p, c in zip(np.floor(pts + 1e-6).astype(int), cols):
            occ.setdefault(tuple(int(x) for x in p), c)
    flat = []
    xs, ys, zs = [], [], []
    for (x, y, z), c in occ.items():
        if all((x + dx, y + dy, z + dz) in occ for dx, dy, dz in ((1,0,0),(-1,0,0),(0,1,0),(0,-1,0),(0,0,1),(0,0,-1))):
            continue
        flat += [x, y, z, int(c[0]), int(c[1]), int(c[2])]
        xs.append(x); ys.append(y); zs.append(z)
    size = [max(xs) - min(xs) + 1, max(ys) - min(ys) + 1, max(zs) - min(zs) + 1] if xs else [0, 0, 0]
    length = float((hi[1] - lo[1]) / pitch * vs)
    return {"vs": vs, "len": length, "size": size, "min": [min(xs), min(ys), min(zs)] if xs else [0, 0, 0], "vox": flat}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("model", nargs="?")
    ap.add_argument("out", nargs="?")
    ap.add_argument("--batch", default="")
    ap.add_argument("--ppu", type=float, default=22.0)
    ap.add_argument("--vs", type=float, default=2.0)
    ap.add_argument("--fit-h", type=float, default=0.0)
    ap.add_argument("--source", default="")
    ap.add_argument("--grip", action="store_true", help="武器：原点在握把，刃朝 -y")
    a = ap.parse_args()
    jobs = []
    if a.batch:
        os.makedirs(a.model, exist_ok=True)
        for line in open(a.batch, encoding="utf-8"):
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            ppu, fit = a.ppu, a.fit_h
            if len(parts) > 2:
                if parts[2].startswith("h="):
                    fit = float(parts[2][2:])
                else:
                    ppu = float(parts[2])
            jobs.append((parts[1], os.path.join(a.model, parts[0] + ".json"), ppu, fit, os.path.basename(parts[1])))
    else:
        jobs.append((a.model, a.out, a.ppu, a.fit_h, a.source))
    for src, out, ppu, fit, source in jobs:
        d = voxelize(src, ppu, a.vs, fit or None, a.grip)
        d["source"] = source
        with gzip.open(out + ".gz", "wt", compresslevel=9) as f:   # 存成 <out>.gz，游戏读 .json.gz（VoxelModel.read_data）
            json.dump(d, f, separators=(",", ":"))
        print(os.path.basename(out), "size", d["size"], "voxels", len(d["vox"]) // 6)


if __name__ == "__main__":
    main()
