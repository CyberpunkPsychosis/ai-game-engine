import JSZip from "jszip";
import type { Asset, Layer, Frame } from "./types";
import { worldMatrix, ordered } from "./transform";

interface ExportInput {
  assets: Record<string, Asset>;
  layers: Layer[];
  frames: Frame[];
  outW: number;
  outH: number;
  originX: number;
  originY: number;
  fps: number;
}

function loadImg(url: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = reject;
    img.src = url;
  });
}

function applyFrame(layers: Layer[], frame: Frame | null): Layer[] {
  if (!frame) return layers;
  return layers.map((l) => {
    const t = frame.transforms[l.id];
    return t ? { ...l, x: t.x, y: t.y, rotation: t.rotation, visible: t.visible } : l;
  });
}

function renderFrame(
  canvas: HTMLCanvasElement,
  layers: Layer[],
  imgs: Record<string, HTMLImageElement>,
  originX: number,
  originY: number,
  frameIndex: number
) {
  const ctx = canvas.getContext("2d")!;
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.imageSmoothingEnabled = false;
  for (const layer of ordered(layers)) {
    if (!layer.visible) continue;
    const img = imgs[layer.assetId];
    if (!img) continue;
    const m = new DOMMatrix().translate(originX, originY).multiply(worldMatrix(layer, layers));
    ctx.setTransform(m.a, m.b, m.c, m.d, m.e, m.f);
    const sf = Math.max(1, layer.sheetFrames || 1);
    if (sf > 1) {
      const fw = img.naturalWidth / sf;
      const sx = (frameIndex % sf) * fw;
      ctx.drawImage(img, sx, 0, fw, img.naturalHeight, -layer.pivotX, -layer.pivotY, fw, img.naturalHeight);
    } else {
      ctx.drawImage(img, -layer.pivotX, -layer.pivotY);
    }
  }
  ctx.setTransform(1, 0, 0, 1, 0, 0);
}

function canvasToBlob(canvas: HTMLCanvasElement): Promise<Blob> {
  return new Promise((resolve) => canvas.toBlob((b) => resolve(b!), "image/png"));
}

const GODOT_SCRIPT = `extends Node2D
## 由 Sprite Rigger 导出。把本脚本和导出的文件夹一起放进 Godot 项目，
## 在场景里挂一个 Node2D 并设置 rig_path 指向 rig.json，即可自动生成 AnimatedSprite2D 动画。
## 锚点(origin)已对齐：节点原点 = 角色根锚点。

@export var rig_path: String = "res://rig.json"
@export var autoplay: bool = true

func _ready() -> void:
	var f := FileAccess.open(rig_path, FileAccess.READ)
	if f == null:
		push_error("找不到 rig.json: %s" % rig_path)
		return
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var base := rig_path.get_base_dir()
	var sprite := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.add_animation("default")
	frames.set_animation_speed("default", float(data.get("fps", 12)))
	frames.set_animation_loop("default", true)
	for fr in data.get("frames", []):
		var tex_path := "%s/frames/%s" % [base, fr.get("file", "")]
		var tex := load(tex_path)
		if tex:
			frames.add_frame("default", tex)
	sprite.sprite_frames = frames
	sprite.animation = "default"
	add_child(sprite)
	if autoplay:
		sprite.play("default")
`;

const README = `# Sprite Rigger 导出包

- frames/      逐帧合成好的 PNG（已按锚点对齐）
- parts/       原始部件 PNG（如需在 Godot 里用骨骼重新拼装）
- rig.json     图层 / 层级 / 锚点 / 每帧变换数据
- godot_sprite_rig.gd  Godot 导入脚本

## 在 Godot 里用（最简单：逐帧动画）
1. 把整个文件夹拖进 Godot 项目（如 res://art/character/）
2. 场景里加一个 Node2D，挂上 godot_sprite_rig.gd
3. 设置 rig_path = res://art/character/rig.json
4. 运行即可看到 AnimatedSprite2D 动画，节点原点已对齐角色根锚点。

## 进阶（骨骼拼装）
rig.json 里有每个部件的 parent / pivot / 每帧 x,y,rotation，
可据此用 Sprite2D + 层级自行重建可换装/可程序化的角色。
`;

export async function exportRig(input: ExportInput): Promise<void> {
  const { assets, layers, frames, outW, outH, originX, originY, fps } = input;
  const usedAssetIds = Array.from(new Set(layers.map((l) => l.assetId)));
  const imgs: Record<string, HTMLImageElement> = {};
  for (const id of usedAssetIds) {
    if (assets[id]) imgs[id] = await loadImg(assets[id].url);
  }

  const canvas = document.createElement("canvas");
  canvas.width = outW;
  canvas.height = outH;

  const zip = new JSZip();
  const framesDir = zip.folder("frames")!;
  const partsDir = zip.folder("parts")!;

  // 帧：若没捕获帧，则用当前 live 姿势作为单帧
  const frameList: Frame[] =
    frames.length > 0
      ? frames
      : [{ id: "live", name: "frame", transforms: Object.fromEntries(layers.map((l) => [l.id, { x: l.x, y: l.y, rotation: l.rotation, visible: l.visible }])) }];

  const frameMeta: any[] = [];
  for (let i = 0; i < frameList.length; i++) {
    const posed = applyFrame(layers, frameList[i]);
    renderFrame(canvas, posed, imgs, originX, originY, i);
    const blob = await canvasToBlob(canvas);
    const file = `frame_${String(i).padStart(3, "0")}.png`;
    framesDir.file(file, blob);
    frameMeta.push({ name: frameList[i].name, file, transforms: frameList[i].transforms });
  }

  // 原始部件
  const assetFileName: Record<string, string> = {};
  for (const id of usedAssetIds) {
    const a = assets[id];
    if (!a) continue;
    const safe = a.name.replace(/[^\w.\-]+/g, "_");
    assetFileName[id] = safe;
    const blob = await (await fetch(a.url)).blob();
    partsDir.file(safe, blob);
  }

  const rig = {
    version: 1,
    canvas: { width: outW, height: outH },
    origin: { x: originX, y: originY },
    fps,
    layers: ordered(layers).map((l) => ({
      id: l.id,
      name: l.name,
      parent: l.parentId,
      z: l.z,
      pivot: { x: l.pivotX, y: l.pivotY },
      points: (l.points ?? []).map((p) => ({ name: p.name, x: p.x, y: p.y })),
      asset: assetFileName[l.assetId] ?? null,
    })),
    frames: frameMeta,
  };

  zip.file("rig.json", JSON.stringify(rig, null, 2));
  zip.file("godot_sprite_rig.gd", GODOT_SCRIPT);
  zip.file("README.md", README);

  const out = await zip.generateAsync({ type: "blob" });
  const url = URL.createObjectURL(out);
  const a = document.createElement("a");
  a.href = url;
  a.download = "sprite-rig.zip";
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 5000);
}
