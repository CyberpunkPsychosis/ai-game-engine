#!/usr/bin/env python3
"""战斗角色姿势入库：把按 `动作_序号.png` 命名的关键姿势，
统一对齐到"脚底锚点"(双脚踩同一基线、水平居中于腿部)，输出到
assets/char/<name>/ 并生成 poses.json(供 Godot 角色加载器使用)。

用法:
    python3 tools/char_intake/intake.py <src_dir> <char_name>
例:
    python3 tools/char_intake/intake.py incoming/viir_poses viir
"""
import os, sys, re, json, glob
import numpy as np
from PIL import Image

# 各动作默认帧率/是否循环
DEFAULTS = {
    "idle": (6, True), "run": (12, True), "jump": (1, False), "fall": (1, False),
    "atk1": (14, False), "atk2": (14, False), "up": (14, False), "down": (14, False),
    "dash": (1, False), "hurt": (8, False), "cast": (10, False), "death": (8, False),
}
PAD = 16

def content_bbox(a):
    ys = np.where(a.any(1))[0]; xs = np.where(a.any(0))[0]
    if len(ys) == 0: return None
    return xs[0], ys[0], xs[-1] + 1, ys[-1] + 1

def foot_x(mask, y0, y1):
    # 取内容底部 20% 行的水平中点 = 较稳定的"双脚中心"
    h = y1 - y0
    band = mask[max(y0, y1 - max(4, int(h * 0.2))):y1]
    cols = np.where(band.any(0))[0]
    return (cols[0] + cols[-1]) / 2.0 if len(cols) else (np.where(mask.any(0))[0].mean())

def main(src, name):
    files = [f for f in glob.glob(os.path.join(src, "*.png"))
             if not os.path.basename(f).startswith(".")]
    if not files:
        print("没找到 PNG:", src); return
    # 解析 动作_序号
    items = []
    for f in files:
        b = os.path.splitext(os.path.basename(f))[0]
        m = re.match(r"(.+?)_(\d+)$", b)
        act, idx = (m.group(1), int(m.group(2))) if m else (b, 1)
        items.append((act, idx, f))
    items.sort(key=lambda t: (t[0], t[1]))

    # 先扫一遍求统一画幅(内容最大宽高 + 脚底位置)
    metas = []
    maxw = maxh = 0
    for act, idx, f in items:
        im = Image.open(f).convert("RGBA"); a = np.array(im)[:, :, 3] > 16
        bb = content_bbox(a)
        if bb is None: continue
        x0, y0, x1, y1 = bb
        fx = foot_x(a, y0, y1)
        metas.append((act, idx, im, bb, fx))
        maxw = max(maxw, x1 - x0); maxh = max(maxh, y1 - y0)
    CW = int(maxw + PAD * 2)
    CH = int(maxh + PAD * 2)
    base_y = int(CH - PAD)               # 脚底基线
    out_dir = os.path.join("assets/char", name)
    os.makedirs(out_dir, exist_ok=True)
    actions = {}
    for act, idx, im, bb, fx in metas:
        x0, y0, x1, y1 = bb
        crop = im.crop((x0, y0, x1, y1))
        canvas = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
        # 锚点：脚中心 fx 对齐画幅中线，脚底 y1 对齐基线
        px = int(CW / 2 - (fx - x0))
        py = int(base_y - (y1 - y0))
        canvas.alpha_composite(crop, (px, py))
        fn = f"{act}_{idx}.png"
        canvas.save(os.path.join(out_dir, fn))
        fps, loop = DEFAULTS.get(act, (10, False))
        actions.setdefault(act, {"frames": [], "fps": fps, "loop": loop})
        actions[act]["frames"].append(fn)
    poses = {"name": name, "frame": [CW, CH], "anchor": [CW // 2, base_y],
             "actions": actions}
    json.dump(poses, open(os.path.join(out_dir, "poses.json"), "w"),
              indent=2, ensure_ascii=False)
    print(f"✓ {name}: {len(metas)} 帧 -> {out_dir}  画幅 {CW}x{CH}")
    for act, d in actions.items():
        print(f"   {act:8s} {len(d['frames'])}帧 fps={d['fps']} loop={d['loop']}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(__doc__); sys.exit(1)
    main(sys.argv[1], sys.argv[2])
