#!/usr/bin/env python3
"""video2sprites — 把 AI 生成的角色循环动作视频转成游戏精灵动画。

流程: 读视频 -> 自动检测动作循环周期 -> isnet-anime ML 抠图 -> alpha 曲线重映射
      -> 地面阴影去除(可选) -> 统一裁剪对齐 -> 导出逐帧 PNG / 精灵表 / GIF / JSON

依赖: pip install opencv-python-headless pillow numpy "rembg[cpu]"

用法:
  python3 tools/video2sprites.py input.mp4 -o assets/characters/foo
  python3 tools/video2sprites.py input.mp4 -o out --no-shadow-removal --cols 8
"""
import argparse, json, os
import cv2
import numpy as np
from PIL import Image


def load_frames(path):
    v = cv2.VideoCapture(path)
    fps = v.get(cv2.CAP_PROP_FPS) or 24
    frames = []
    while True:
        ok, f = v.read()
        if not ok:
            break
        frames.append(f)
    if not frames:
        raise SystemExit(f"无法读取视频: {path}")
    return frames, fps


def detect_cycle(frames, kmin=6, kmax=48):
    """帧间自相关找动作周期; 注意半周期(左右脚镜像)得分也低, 取分数相近时较大的 k。"""
    small = [cv2.cvtColor(cv2.resize(f, (104, 140)), cv2.COLOR_BGR2GRAY).astype(np.float32)
             for f in frames]
    kmax = min(kmax, len(small) // 2)
    scores = {}
    for k in range(kmin, kmax):
        scores[k] = float(np.mean([np.abs(small[i] - small[i + k]).mean()
                                   for i in range(len(small) - k)]))
    best_k = min(scores, key=scores.get)
    # 若 2*best_k 的分数也接近最优, best_k 很可能只是半周期
    if 2 * best_k in scores and scores[2 * best_k] < scores[best_k] * 1.3:
        best_k = 2 * best_k
    # 选首尾衔接误差最小的起始帧
    lo = min(5, len(frames) - best_k - 1)
    s = min(range(lo, len(frames) - best_k),
            key=lambda i: np.abs(small[i] - small[i + best_k]).mean())
    return s, best_k


def matte_frames(frames, model="isnet-anime"):
    from rembg import remove, new_session
    sess = new_session(model)
    outs = []
    for f in frames:
        rgba = remove(cv2.cvtColor(f, cv2.COLOR_BGR2RGB), session=sess)
        outs.append(cv2.cvtColor(np.array(rgba), cv2.COLOR_RGBA2BGRA))
    return outs


def remap_alpha(rgba, lo=30, hi=210):
    """isnet 输出的主体 alpha 普遍在 170~250, 直接用会半透明; 拉曲线让实心区=255。"""
    a = rgba[:, :, 3].astype(np.float32)
    rgba[:, :, 3] = (np.clip((a - lo) / (hi - lo), 0, 1) * 255).astype(np.uint8)
    return rgba


def remove_ground_shadow(rgba, ground_y, hue=(157, 173), sat=(45, 165), val_min=135):
    """去掉脚下的地面投影(只在触地帧出现, 循环播放时会闪烁)。
    三步: 阴影主色 HSV 键控 -> 暗色描边残留过滤 -> 删除完全位于地面区的孤立连通域。
    hue/sat 阈值需按素材采样调整(本仓库素材: 粉色阴影 H165-168 / S85-129)。"""
    a = rgba[:, :, 3]
    hsv = cv2.cvtColor(rgba[:, :, :3], cv2.COLOR_BGR2HSV)
    H, S, V = hsv[:, :, 0].astype(int), hsv[:, :, 1].astype(int), hsv[:, :, 2].astype(int)
    zone = np.zeros_like(a, bool)
    zone[ground_y:, :] = True
    body = (H >= hue[0]) & (H <= hue[1]) & (S >= sat[0]) & (S <= sat[1]) & (V >= val_min)
    rim = (V >= 70) & (V <= 160) & (S <= 105)          # 阴影的灰褐描边(黑描边 V<70 不受影响)
    soft = a < 235                                       # 被删阴影留下的软边
    a[zone & (body | rim | soft)] = 0
    n, lab, stats, _ = cv2.connectedComponentsWithStats((a > 0).astype(np.uint8))
    for c in range(1, n):
        ys = np.where((lab == c).any(1))[0]
        if ys.min() >= ground_y - 10 or stats[c, cv2.CC_STAT_AREA] < 60:
            a[lab == c] = 0
    rgba[:, :, 3] = a
    return rgba


def union_crop(cuts, margin=10):
    boxes = []
    for c in cuts:
        ys, xs = np.where(c[:, :, 3] > 0)
        boxes.append((xs.min(), ys.min(), xs.max(), ys.max()))
    h, w = cuts[0].shape[:2]
    x0 = max(0, min(b[0] for b in boxes) - margin)
    y0 = max(0, min(b[1] for b in boxes) - margin)
    x1 = min(w, max(b[2] for b in boxes) + margin)
    y1 = min(h, max(b[3] for b in boxes) + margin)
    return [c[y0:y1, x0:x1] for c in cuts]


def export(cuts, outdir, fps, cols, sheet_scale=0.5, gif_scale=1 / 3):
    os.makedirs(f"{outdir}/frames", exist_ok=True)
    for i, c in enumerate(cuts):
        cv2.imwrite(f"{outdir}/frames/run_{i+1:02d}.png", c)
    imgs = [Image.fromarray(cv2.cvtColor(c, cv2.COLOR_BGRA2RGBA)) for c in cuts]
    w, h = imgs[0].size
    rows = (len(imgs) + cols - 1) // cols
    sw, sh = int(w * sheet_scale), int(h * sheet_scale)
    sheet = Image.new("RGBA", (sw * cols, sh * rows), (0, 0, 0, 0))
    for i, im in enumerate(imgs):
        r, c = divmod(i, cols)
        sheet.alpha_composite(im.resize((sw, sh), Image.LANCZOS), (c * sw, r * sh))
    sheet_name = f"sheet_{cols}x{rows}.png"
    sheet.save(f"{outdir}/{sheet_name}")
    gw, gh = int(w * gif_scale), int(h * gif_scale)
    prev = []
    for im in imgs:
        bg = Image.new("RGBA", (gw, gh), (255, 255, 255, 255))
        bg.alpha_composite(im.resize((gw, gh), Image.LANCZOS))
        prev.append(bg.convert("P", palette=Image.ADAPTIVE))
    prev[0].save(f"{outdir}/preview.gif", save_all=True, append_images=prev[1:],
                 duration=int(1000 / fps), loop=0, disposal=2)
    json.dump({
        "loop": True, "fps": fps, "frame_count": len(cuts), "frame_size_full": [w, h],
        "sheet": {"file": sheet_name, "columns": cols, "rows": rows, "frame_size": [sw, sh]},
        "frames": [f"run_{i+1:02d}.png" for i in range(len(cuts))],
    }, open(f"{outdir}/animation.json", "w"), indent=2, ensure_ascii=False)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("video")
    ap.add_argument("-o", "--out", required=True)
    ap.add_argument("--cols", type=int, default=10)
    ap.add_argument("--model", default="isnet-anime")
    ap.add_argument("--no-shadow-removal", action="store_true")
    ap.add_argument("--ground", type=float, default=0.86,
                    help="地面区起始位置(画面高度比例), 阴影过滤只作用于该线以下")
    args = ap.parse_args()

    frames, fps = load_frames(args.video)
    s, k = detect_cycle(frames)
    print(f"循环: 第{s}帧起, 周期{k}帧 (@{fps:.0f}fps ≈ {k/fps:.2f}s/圈)")
    cycle = frames[s:s + k]
    cuts = matte_frames(cycle, args.model)
    cuts = [remap_alpha(c) for c in cuts]
    if not args.no_shadow_removal:
        gy = int(frames[0].shape[0] * args.ground)
        cuts = [remove_ground_shadow(c, gy) for c in cuts]
    cuts = union_crop(cuts)
    export(cuts, args.out, fps, args.cols)
    print(f"完成: {args.out}/ (frames/, sheet, preview.gif, animation.json)")


if __name__ == "__main__":
    main()
