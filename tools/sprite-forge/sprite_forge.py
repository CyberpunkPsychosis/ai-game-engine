#!/usr/bin/env python3
"""Sprite Forge —— 用「整表一次生成」法,从一张参考图出一整套一致的动作序列帧。

验证过的配方(2026 主流做法):
  1. 把参考角色图上传到 Scenario
  2. 用 GPT Image 2 / Gemini 3.1,一次性输出一整张「绿幕 + 网格」精灵表
     (一次生成所有帧 → 帧间天然一致,这是关键)
  3. 抠掉绿幕 → 按网格切帧 → 脚底对齐
  4. 产出:透明底单帧 + 引擎就绪的等格精灵表 + 预览 GIF + frames.json

为什么不逐帧生成:逐帧/文字驱动动画会"漂"(每帧角色都变样)。整表一次生成把
"一致性"交给单次生成,动作再交给确定性后期切帧,稳。

鉴权(只读环境变量,绝不写进仓库):
  export SCENARIO_AUTH_B64=<apikey:secret 的 base64>
  # 或分开给:
  export SCENARIO_API_KEY=api_xxx
  export SCENARIO_API_SECRET=xxx

用法:
  # 估成本(不扣费)
  python3 tools/sprite-forge/sprite_forge.py \
      --ref /path/monster.png --desc "红皮巨角恶魔,扛斧" \
      --action "melee axe attack" --frames 6 --dry-run

  # 正式出图
  python3 tools/sprite-forge/sprite_forge.py \
      --ref /path/monster.png --desc "a red horned demon brute holding an axe" \
      --action "melee axe attack" --frames 6 --name demon_attack \
      --model gpt-image-2 --out out/demon_attack

  # 只对已有整表重新切帧(不花钱,调切帧参数用)
  python3 tools/sprite-forge/sprite_forge.py \
      --process-only sheet.png --cols 3 --rows 2 --name demon_attack --out out/demon_attack

便宜提示:GPT Image 2 高质约 48 CU/张;Gemini 3.1 约 12 CU/张,批量用 --model gemini。
"""
import os, sys, json, time, base64, argparse, urllib.request
import numpy as np
from PIL import Image

URL = "https://mcp.scenario.com/mcp"
MODELS = {
    "gpt-image-2": "model_openai-gpt-image-2",
    "gemini": "model_google-gemini-3-1-flash",
}
GRID = {4: (2, 2), 6: (3, 2), 8: (4, 2), 9: (3, 3), 12: (4, 3), 16: (4, 4)}
CELL = 512  # 每帧目标网格边长(像素)


# ----------------------------- Scenario MCP 客户端 -----------------------------
class Scenario:
    def __init__(self):
        b64 = os.environ.get("SCENARIO_AUTH_B64")
        if not b64:
            k, s = os.environ.get("SCENARIO_API_KEY"), os.environ.get("SCENARIO_API_SECRET")
            if not (k and s):
                sys.exit("缺鉴权:设 SCENARIO_AUTH_B64,或 SCENARIO_API_KEY + SCENARIO_API_SECRET")
            b64 = base64.b64encode(f"{k}:{s}".encode()).decode()
        self.h = {"Authorization": f"Basic {b64}", "Content-Type": "application/json",
                  "Accept": "application/json, text/event-stream"}
        self._post({"jsonrpc": "2.0", "id": 1, "method": "initialize",
                    "params": {"protocolVersion": "2024-11-05", "capabilities": {},
                               "clientInfo": {"name": "sprite-forge", "version": "1.0"}}})
        self._post({"jsonrpc": "2.0", "method": "notifications/initialized"})

    def _post(self, payload, timeout=180):
        req = urllib.request.Request(URL, data=json.dumps(payload).encode(), headers=self.h)
        with urllib.request.urlopen(req, timeout=timeout) as r:
            body = r.read().decode()
        out = None
        for line in body.splitlines():
            line = line.strip()
            if line.startswith("data:"):
                line = line[5:].strip()
            if line.startswith("{"):
                try:
                    d = json.loads(line)
                    if "result" in d or "error" in d:
                        out = d
                except Exception:
                    pass
        return out

    def call(self, tool, args, timeout=180):
        d = self._post({"jsonrpc": "2.0", "id": 2, "method": "tools/call",
                        "params": {"name": tool, "arguments": args}}, timeout)
        r = (d or {}).get("result", {})
        if r.get("isError"):
            txt = " ".join(c.get("text", "") for c in r.get("content", []))
            raise RuntimeError(f"Scenario 报错: {txt[:400]}")
        for c in r.get("content", []):
            if c.get("type") == "text":
                try:
                    return json.loads(c["text"])
                except Exception:
                    return c["text"]
        return r


def upload_ref(scn, path):
    size = os.path.getsize(path)
    if size > 95000:
        sys.exit(f"参考图 {size}B 太大(>95KB 内联上限)。先缩小,或扩展本工具走 presigned 上传。")
    data = base64.b64encode(open(path, "rb").read()).decode()
    ext = os.path.splitext(path)[1].lstrip(".").lower() or "png"
    mime = "image/jpeg" if ext in ("jpg", "jpeg") else f"image/{ext}"
    r = scn.call("upload_asset", {"file_name": os.path.basename(path),
                                  "content_type": mime, "kind": "image", "data": data})
    return r["asset_id"]


def discover_params(scn, model_id):
    """从模型 schema 找出 参考图入参名 与 是否有 background 参数。"""
    sch = scn.call("get_model_schema", {"model_id": model_id})
    img_param, has_bg = None, False
    for p in sch.get("parameters", []):
        t, name = p.get("type", ""), p.get("name", "")
        if img_param is None and (p.get("kind") == "image" or "file" in t) and name.lower() != "mask":
            img_param = name
        if name == "background":
            has_bg = True
    return img_param or "referenceImages", has_bg


def build_prompt(desc, action, n, cols, rows, beats):
    if beats:
        seq = "; ".join(f"({i+1}) {b.strip()}" for i, b in enumerate(beats))
        seq = "Frames read left-to-right, top-to-bottom: " + seq + "."
    else:
        seq = (f"The {n} frames read left-to-right, top-to-bottom and capture the FULL "
               f"motion of the action evenly from start to finish: anticipation / wind-up, "
               f"the main action at its peak, the strike/contact, follow-through, and recovery.")
    return (
        f"Using the provided reference character ({desc}), create a pixel-art SPRITE SHEET of "
        f"this exact same character performing: {action}. Lay out exactly {n} frames in a "
        f"{cols}x{rows} grid ({rows} rows, {cols} columns). {seq} "
        f"Side view, facing right. CRITICAL: keep the SAME character design, same colors, same "
        f"proportions, same pixel-art style in EVERY single frame. Every frame identical canvas "
        f"size, character centered, evenly spaced on a clean uniform grid, feet on a common "
        f"baseline. The ENTIRE background must be solid flat chroma-key green, exact hex #00FF00 "
        f"(RGB 0,255,0), with NO gradients, NO shadows, NO texture. Add a clean 2px white outline "
        f"around the character in every frame to separate it from the green. "
        f"No text, no numbers, no visible grid lines, no borders."
    )


def generate(scn, args, asset_id, cols, rows):
    model_id = MODELS[args.model]
    img_param, has_bg = discover_params(scn, model_id)
    params = {
        "prompt": build_prompt(args.desc, args.action, args.frames, cols, rows,
                               args.beats.split(";") if args.beats else None),
        img_param: [asset_id],
        "width": cols * CELL, "height": rows * CELL,
    }
    if args.model == "gpt-image-2":
        params["quality"] = args.quality
    if has_bg:
        params["background"] = "opaque"   # GPT 不支持 transparent,走绿幕

    if args.dry_run:
        r = scn.call("run_model", {"model_id": model_id, "parameters": params, "dry_run": True})
        print(f"[dry-run] 预计成本: {r.get('creativeUnitsCost')} CU  "
              f"({args.model}, {cols*CELL}x{rows*CELL}, quality={params.get('quality','-')})")
        return None

    print(f"[1/3] 提交生成 ({args.model}, {cols}x{rows} 网格)…")
    r = scn.call("run_model", {"model_id": model_id, "parameters": params, "wait": False})
    job_id = r.get("job", {}).get("jobId") or r.get("jobId")
    if not job_id:                      # 个别情况下直接同步返回了资产
        ids = (r.get("metadata", {}) or {}).get("assetIds") or r.get("assetIds")
        return _download_asset(scn, ids[0])
    print(f"      job={job_id},轮询中…")
    for _ in range(120):                # 最多约 4 分钟
        time.sleep(2)
        j = scn.call("manage_jobs", {"action": "check", "job_id": job_id})["job"]
        st = j.get("status")
        if st == "success":
            asset = j["metadata"]["assetIds"][0]
            print(f"[2/3] 生成完成,下载输出图 {asset}")
            return _download_asset(scn, asset)
        if st in ("failed", "canceled"):
            sys.exit(f"任务失败: {st}")
    sys.exit("轮询超时,稍后用 manage_jobs 查 job 状态")


def _download_asset(scn, asset_id):
    a = scn.call("manage_assets", {"action": "get", "asset_id": asset_id})["asset"]
    out = "/tmp/_sf_sheet_raw.png"
    urllib.request.urlretrieve(a["url"], out)
    return out


# ----------------------------- 后期:抠绿 + 切帧 + 对齐 -----------------------------
def chroma_key(im):
    a = np.asarray(im.convert("RGBA")).astype(np.int16)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    bg = (g > 90) & (g > r * 1.35) & (g > b * 1.35)          # 纯绿背景
    a[..., 3][bg] = 0
    spill = (~bg) & (g > r) & (g > b) & ((g - np.maximum(r, b)) > 40)  # 去绿溢边
    a[..., 1][spill] = ((r + b) // 2)[spill]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def bbox(im):
    arr = np.asarray(im)[..., 3]
    ys, xs = np.where(arr > 8)
    if len(ys) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def checker(w, h, s=24):
    bg = np.zeros((h, w, 4), np.uint8)
    yy, xx = np.mgrid[0:h, 0:w]
    on = ((xx // s + yy // s) % 2 == 0)
    bg[on] = (58, 58, 66, 255); bg[~on] = (44, 44, 50, 255)
    return Image.fromarray(bg, "RGBA")


def process(raw_path, cols, rows, name, out_dir, fps):
    sheet = Image.open(raw_path).convert("RGBA")
    W, H = sheet.size
    cw, ch = W // cols, H // rows
    cells = []
    for ry in range(rows):
        for cx in range(cols):
            cell = chroma_key(sheet.crop((cx*cw, ry*ch, (cx+1)*cw, (ry+1)*ch)))
            bb = bbox(cell)
            cells.append(cell.crop(bb) if bb else cell)

    fw = max(c.width for c in cells) + 24
    fh = max(c.height for c in cells) + 12
    os.makedirs(out_dir, exist_ok=True)
    frames_dir = os.path.join(out_dir, "frames")
    os.makedirs(frames_dir, exist_ok=True)

    frames = []
    for i, c in enumerate(cells):
        canvas = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
        canvas.alpha_composite(c, ((fw - c.width) // 2, fh - c.height))   # 脚底贴底,水平居中
        canvas.save(os.path.join(frames_dir, f"{name}_{i}.png"))
        frames.append(canvas)

    # 引擎就绪:等格横排精灵表(透明底)
    sheet_out = Image.new("RGBA", (fw * len(frames), fh), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet_out.alpha_composite(f, (i * fw, 0))
    sheet_out.save(os.path.join(out_dir, f"{name}_sheet.png"))

    # 预览:接触表 + GIF
    base = checker(fw * len(frames), fh)
    base.alpha_composite(sheet_out)
    base.convert("RGB").save(os.path.join(out_dir, f"{name}_preview.png"))
    gb = checker(fw, fh)
    gif = []
    for f in frames:
        g = gb.copy(); g.alpha_composite(f); gif.append(g.convert("P", palette=Image.ADAPTIVE))
    gif[0].save(os.path.join(out_dir, f"{name}.gif"), save_all=True,
                append_images=gif[1:], duration=int(1000 / fps), loop=0, disposal=2)

    meta = {"name": name, "frame_count": len(frames), "frame_size": [fw, fh],
            "layout": "horizontal", "fps": fps, "anchor": "bottom-center",
            "sheet": f"{name}_sheet.png", "frames_dir": "frames/"}
    json.dump(meta, open(os.path.join(out_dir, "frames.json"), "w"), ensure_ascii=False, indent=2)
    print(f"[3/3] 完成 → {out_dir}/  ({len(frames)} 帧, 单帧 {fw}x{fh})")
    print(f"      精灵表 {name}_sheet.png · 预览 {name}.gif / {name}_preview.png · frames.json")
    return out_dir


# ----------------------------------- CLI -----------------------------------
def main():
    ap = argparse.ArgumentParser(description="Sprite Forge: 参考图 → 一致的动作序列帧")
    ap.add_argument("--ref", help="参考角色图(透明底/侧视最佳)")
    ap.add_argument("--desc", default="", help="角色描述(英文更准),如 'a red horned demon holding an axe'")
    ap.add_argument("--action", default="attack", help="动作,如 'melee axe attack' / 'walk cycle'")
    ap.add_argument("--frames", type=int, default=6, help="帧数(默认6)")
    ap.add_argument("--cols", type=int, help="网格列(默认按帧数推断)")
    ap.add_argument("--rows", type=int, help="网格行(默认按帧数推断)")
    ap.add_argument("--beats", default="", help="可选,分号分隔的逐帧动作描述")
    ap.add_argument("--model", choices=list(MODELS), default="gpt-image-2", help="生成模型")
    ap.add_argument("--quality", choices=["auto", "high", "medium", "low"], default="high")
    ap.add_argument("--name", default="sprite", help="输出文件名前缀")
    ap.add_argument("--out", default="out/sprite", help="输出目录")
    ap.add_argument("--fps", type=int, default=10, help="预览 GIF 帧率")
    ap.add_argument("--dry-run", action="store_true", help="只估成本,不生成")
    ap.add_argument("--process-only", help="跳过生成,直接对已有整表 PNG 切帧")
    a = ap.parse_args()

    cols = a.cols or GRID.get(a.frames, (min(a.frames, 4), (a.frames + 3) // 4))[0]
    rows = a.rows or GRID.get(a.frames, (min(a.frames, 4), (a.frames + 3) // 4))[1]

    if a.process_only:
        process(a.process_only, cols, rows, a.name, a.out, a.fps)
        return
    if not a.ref:
        ap.error("需要 --ref 参考图(或用 --process-only)")

    scn = Scenario()
    print(f"[0/3] 上传参考图 {a.ref}")
    asset_id = upload_ref(scn, a.ref)
    raw = generate(scn, a, asset_id, cols, rows)
    if raw is None:           # dry-run
        return
    process(raw, cols, rows, a.name, a.out, a.fps)


if __name__ == "__main__":
    main()
