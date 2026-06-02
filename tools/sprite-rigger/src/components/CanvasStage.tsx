import { useEffect, useRef } from "react";
import { useStore } from "../store";
import { worldMatrix, parentWorldMatrix, ordered } from "../lib/transform";
import type { Layer } from "../lib/types";

export default function CanvasStage() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const wrapRef = useRef<HTMLDivElement>(null);
  const imgCache = useRef<Record<string, HTMLImageElement>>({});
  const drag = useRef<{
    mode: "layer" | "pan" | "point" | "pivot" | null;
    id?: string;
    pointId?: string;
    grabX: number;
    grabY: number;
    startPanX: number;
    startPanY: number;
  }>({
    mode: null,
    grabX: 0,
    grabY: 0,
    startPanX: 0,
    startPanY: 0,
  });
  const pointers = useRef<Map<number, { x: number; y: number }>>(new Map());
  const pinch = useRef<{ startDist: number; startZoom: number; startPanX: number; startPanY: number; midX: number; midY: number } | null>(null);

  const assets = useStore((s) => s.assets);
  const layers = useStore((s) => s.layers);
  const view = useStore((s) => s.view);
  const settings = useStore((s) => s.settings);
  const selectedId = useStore((s) => s.selectedId);
  const placeMode = useStore((s) => s.placeMode);
  const frames = useStore((s) => s.frames);
  const currentFrameId = useStore((s) => s.currentFrameId);
  const frameIndex = Math.max(0, frames.findIndex((f) => f.id === currentFrameId));
  const currentFrame = frames.find((f) => f.id === currentFrameId);

  // 点在当前帧的有效位置（帧覆盖优先，否则基准位）
  const effPoint = (pt: { id: string; x: number; y: number }, frame?: { points?: Record<string, { x: number; y: number }> }) =>
    frame?.points?.[pt.id] ?? { x: pt.x, y: pt.y };

  // 图层在当前帧应显示的子帧宽度与起始 x（精灵表）
  const sheetInfo = (l: Layer) => {
    const a = assets[l.assetId];
    const sf = Math.max(1, l.sheetFrames || 1);
    const fw = a ? a.width / sf : 0;
    const sx = (frameIndex % sf) * fw;
    return { fw, sx, h: a ? a.height : 0 };
  };

  // 预加载图片到缓存
  useEffect(() => {
    let changed = false;
    for (const a of Object.values(assets)) {
      if (!imgCache.current[a.id]) {
        const img = new Image();
        img.onload = () => draw();
        img.src = a.url;
        imgCache.current[a.id] = img;
        changed = true;
      }
    }
    if (changed) draw();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [assets]);

  const screenToWorld = (sx: number, sy: number) => ({
    x: (sx - view.panX) / view.zoom,
    y: (sy - view.panY) / view.zoom,
  });

  const snap = (v: number) => (settings.snap ? Math.round(v / settings.gridSize) * settings.gridSize : v);

  const hitTest = (wx: number, wy: number): Layer | null => {
    // 在所有"盖住手指点"的部件里，选离其中心最近的（不再只认最上层）
    let best: Layer | null = null;
    let bestD = Infinity;
    for (const l of layers) {
      if (!l.visible || l.locked) continue;
      const a = assets[l.assetId];
      if (!a) continue;
      const { fw } = sheetInfo(l);
      const p = worldMatrix(l, layers).inverse().transformPoint(new DOMPoint(wx, wy));
      if (p.x >= -l.pivotX && p.x <= fw - l.pivotX && p.y >= -l.pivotY && p.y <= a.height - l.pivotY) {
        const cx = fw / 2 - l.pivotX;
        const cy = a.height / 2 - l.pivotY;
        const d = Math.hypot(p.x - cx, p.y - cy);
        if (d < bestD) {
          bestD = d;
          best = l;
        }
      }
    }
    return best;
  };

  // 命中选中图层的挂点/锚点手柄（屏幕空间，半径阈值适配触屏）
  const handleHit = (sx: number, sy: number): { mode: "point" | "pivot"; pointId?: string } | null => {
    const st = useStore.getState();
    const sel = st.layers.find((l) => l.id === st.selectedId);
    if (!sel) return null;
    const { zoom, panX, panY } = st.view;
    const wm = worldMatrix(sel, st.layers);
    const frame = st.frames.find((f) => f.id === st.currentFrameId);
    const R = 14;
    for (const pt of sel.points) {
      const ep = frame?.points?.[pt.id] ?? { x: pt.x, y: pt.y };
      const wp = wm.transformPoint(new DOMPoint(ep.x - sel.pivotX, ep.y - sel.pivotY));
      if (Math.hypot(panX + wp.x * zoom - sx, panY + wp.y * zoom - sy) <= R) return { mode: "point", pointId: pt.id };
    }
    const o = wm.transformPoint(new DOMPoint(0, 0));
    if (Math.hypot(panX + o.x * zoom - sx, panY + o.y * zoom - sy) <= R) return { mode: "pivot" };
    return null;
  };

  function draw() {
    const canvas = canvasRef.current;
    const wrap = wrapRef.current;
    if (!canvas || !wrap) return;
    const dpr = window.devicePixelRatio || 1;
    const W = wrap.clientWidth;
    const H = wrap.clientHeight;
    if (canvas.width !== W * dpr || canvas.height !== H * dpr) {
      canvas.width = W * dpr;
      canvas.height = H * dpr;
    }
    const st = useStore.getState();
    if (st.canvasW !== W || st.canvasH !== H) st.setCanvasSize(W, H);
    const ctx = canvas.getContext("2d")!;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, W, H);

    // 背景
    ctx.fillStyle = "#fffefb";
    ctx.fillRect(0, 0, W, H);

    const { zoom, panX, panY } = view;

    // 网格
    if (settings.showGrid && zoom >= 2) {
      const step = settings.gridSize * zoom;
      if (step >= 4) {
        ctx.strokeStyle = "#ece8de";
        ctx.lineWidth = 1;
        ctx.beginPath();
        for (let x = panX % step; x < W; x += step) {
          ctx.moveTo(x + 0.5, 0);
          ctx.lineTo(x + 0.5, H);
        }
        for (let y = panY % step; y < H; y += step) {
          ctx.moveTo(0, y + 0.5);
          ctx.lineTo(W, y + 0.5);
        }
        ctx.stroke();
      }
    }

    // 输出画布范围 + 角色根锚点
    const ox = panX + settings.originX * zoom;
    const oy = panY + settings.originY * zoom;
    ctx.strokeStyle = "#d9d4c7";
    ctx.setLineDash([4, 4]);
    ctx.strokeRect(panX + 0.5, panY + 0.5, settings.outW * zoom, settings.outH * zoom);
    ctx.setLineDash([]);

    // 图层
    ctx.imageSmoothingEnabled = false;
    for (const l of ordered(layers)) {
      if (!l.visible) continue;
      const img = imgCache.current[l.assetId];
      if (!img || !img.complete) continue;
      const m = new DOMMatrix().translate(panX, panY).scale(zoom).multiply(worldMatrix(l, layers));
      ctx.setTransform(dpr * m.a, dpr * m.b, dpr * m.c, dpr * m.d, dpr * m.e, dpr * m.f);
      const { fw, sx, h } = sheetInfo(l);
      if ((l.sheetFrames || 1) > 1) ctx.drawImage(img, sx, 0, fw, h, -l.pivotX, -l.pivotY, fw, h);
      else ctx.drawImage(img, -l.pivotX, -l.pivotY);
    }
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

    // 选中框（屏幕空间）
    const selected = layers.find((l) => l.id === selectedId);
    if (selected) {
      const a = assets[selected.assetId];
      if (a) {
        const fw = a.width / Math.max(1, selected.sheetFrames || 1);
        const wm = new DOMMatrix().translate(panX, panY).scale(zoom).multiply(worldMatrix(selected, layers));
        const corners = [
          new DOMPoint(-selected.pivotX, -selected.pivotY),
          new DOMPoint(fw - selected.pivotX, -selected.pivotY),
          new DOMPoint(fw - selected.pivotX, a.height - selected.pivotY),
          new DOMPoint(-selected.pivotX, a.height - selected.pivotY),
        ].map((p) => wm.transformPoint(p));
        ctx.strokeStyle = "#cc785c";
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.moveTo(corners[0].x, corners[0].y);
        for (let i = 1; i < 4; i++) ctx.lineTo(corners[i].x, corners[i].y);
        ctx.closePath();
        ctx.stroke();
      }
    }

    // 标记点（屏幕空间）
    ctx.font = "10px ui-sans-serif, system-ui, sans-serif";
    if (settings.showAnchors)
    for (const l of layers) {
      for (const pt of l.points) {
        const ep = effPoint(pt, currentFrame);
        const wp = worldMatrix(l, layers).transformPoint(new DOMPoint(ep.x - l.pivotX, ep.y - l.pivotY));
        const px = panX + wp.x * zoom;
        const py = panY + wp.y * zoom;
        const r = l.id === selectedId ? 6 : 3.5;
        ctx.fillStyle = "#cc785c";
        ctx.beginPath();
        ctx.arc(px, py, r, 0, Math.PI * 2);
        ctx.fill();
        ctx.strokeStyle = "#ffffff";
        ctx.lineWidth = 1.5;
        ctx.stroke();
        ctx.fillStyle = "#5a574f";
        ctx.fillText(pt.name, px + r + 2, py - 4);
      }
    }
  }

  // 重绘
  useEffect(draw);

  // 窗口尺寸变化重绘
  useEffect(() => {
    const ro = new ResizeObserver(() => draw());
    if (wrapRef.current) ro.observe(wrapRef.current);
    return () => ro.disconnect();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const getLocalXY = (e: React.PointerEvent) => {
    const rect = canvasRef.current!.getBoundingClientRect();
    return { x: e.clientX - rect.left, y: e.clientY - rect.top };
  };

  const startPinch = () => {
    const pts = Array.from(pointers.current.values());
    if (pts.length < 2) return;
    const [a, b] = pts;
    pinch.current = {
      startDist: Math.hypot(a.x - b.x, a.y - b.y) || 1,
      startZoom: view.zoom,
      startPanX: view.panX,
      startPanY: view.panY,
      midX: (a.x + b.x) / 2,
      midY: (a.y + b.y) / 2,
    };
  };

  const doPinch = () => {
    const pts = Array.from(pointers.current.values());
    if (pts.length < 2 || !pinch.current) return;
    const [a, b] = pts;
    const dist = Math.hypot(a.x - b.x, a.y - b.y) || 1;
    const midX = (a.x + b.x) / 2;
    const midY = (a.y + b.y) / 2;
    const z = Math.min(32, Math.max(0.5, pinch.current.startZoom * (dist / pinch.current.startDist)));
    const worldX = (pinch.current.midX - pinch.current.startPanX) / pinch.current.startZoom;
    const worldY = (pinch.current.midY - pinch.current.startPanY) / pinch.current.startZoom;
    useStore.getState().setView({ zoom: z, panX: midX - worldX * z, panY: midY - worldY * z });
  };

  const onPointerDown = (e: React.PointerEvent) => {
    (e.target as Element).setPointerCapture(e.pointerId);
    const local = getLocalXY(e);
    pointers.current.set(e.pointerId, local);
    if (pointers.current.size >= 2) {
      drag.current.mode = null; // 进入双指：取消单指拖动
      startPinch();
      return;
    }
    const { x: sx, y: sy } = local;
    const w = screenToWorld(sx, sy);
    const st = useStore.getState();

    if (st.placeMode) {
      const pm = st.placeMode;
      const l = st.layers.find((q) => q.id === pm.layerId);
      if (l) {
        if (pm.target === "position") {
          // 按帧定位：把本部件(连同子件)整体移到点击处（本帧），保持模式以便逐帧点
          const pinv = parentWorldMatrix(l, st.layers).inverse();
          const local = pinv.transformPoint(new DOMPoint(w.x, w.y));
          st.patchLayer(l.id, { x: Math.round(local.x), y: Math.round(local.y) });
          return;
        }
        const localClicked = worldMatrix(l, st.layers).inverse().transformPoint(new DOMPoint(w.x, w.y));
        const ix = Math.round(localClicked.x + l.pivotX);
        const iy = Math.round(localClicked.y + l.pivotY);
        if (pm.target === "addpoint") {
          // 吸附到所点像素格的中心（floor + 0.5）
          const cx = Math.floor(localClicked.x + l.pivotX) + 0.5;
          const cy = Math.floor(localClicked.y + l.pivotY) + 0.5;
          st.addPointAt(l.id, cx, cy);
          st.setPlaceMode(null); // 一次只加一个，避免误点一堆
          return;
        }
        if (pm.target === "pivot") {
          // 改锚点且部件视觉不动
          const pinv = parentWorldMatrix(l, st.layers).inverse();
          const local = pinv.transformPoint(new DOMPoint(w.x, w.y));
          st.patchLayer(l.id, { pivotX: ix, pivotY: iy, x: Math.round(local.x), y: Math.round(local.y) });
        } else {
          st.updatePoint(l.id, pm.target, { x: ix, y: iy });
        }
      }
      st.setPlaceMode(null);
      return;
    }

    // 优先抓挂点/锚点手柄（选中图层）
    const hh = handleHit(sx, sy);
    if (hh) {
      drag.current = { mode: hh.mode, id: st.selectedId!, pointId: hh.pointId, grabX: 0, grabY: 0, startPanX: 0, startPanY: 0 };
      return;
    }

    const hit = hitTest(w.x, w.y);
    if (hit) {
      st.selectLayer(hit.id);
      const wm = worldMatrix(hit, st.layers);
      const origin = wm.transformPoint(new DOMPoint(0, 0));
      drag.current = { mode: "layer", id: hit.id, grabX: w.x - origin.x, grabY: w.y - origin.y, startPanX: 0, startPanY: 0 };
    } else {
      st.selectLayer(null);
      drag.current = { mode: "pan", grabX: sx, grabY: sy, startPanX: view.panX, startPanY: view.panY };
    }
  };

  const onPointerMove = (e: React.PointerEvent) => {
    if (pointers.current.has(e.pointerId)) pointers.current.set(e.pointerId, getLocalXY(e));
    if (pointers.current.size >= 2) {
      doPinch();
      return;
    }
    if (!drag.current.mode) return;
    const { x: sx, y: sy } = getLocalXY(e);
    const st = useStore.getState();
    if (drag.current.mode === "pan") {
      st.setView({ panX: drag.current.startPanX + (sx - drag.current.grabX), panY: drag.current.startPanY + (sy - drag.current.grabY) });
      return;
    }
    if (drag.current.mode === "point" && drag.current.id && drag.current.pointId) {
      const l = st.layers.find((q) => q.id === drag.current.id);
      if (!l) return;
      const w = screenToWorld(sx, sy);
      const local = worldMatrix(l, st.layers).inverse().transformPoint(new DOMPoint(w.x, w.y));
      st.setPointPos(l.id, drag.current.pointId, Math.floor(local.x + l.pivotX) + 0.5, Math.floor(local.y + l.pivotY) + 0.5);
      return;
    }
    if (drag.current.mode === "pivot" && drag.current.id) {
      const l = st.layers.find((q) => q.id === drag.current.id);
      if (!l) return;
      const w = screenToWorld(sx, sy);
      const localClicked = worldMatrix(l, st.layers).inverse().transformPoint(new DOMPoint(w.x, w.y));
      const ix = Math.round(localClicked.x + l.pivotX);
      const iy = Math.round(localClicked.y + l.pivotY);
      const pinv = parentWorldMatrix(l, st.layers).inverse();
      const local = pinv.transformPoint(new DOMPoint(w.x, w.y));
      st.patchLayer(l.id, { pivotX: ix, pivotY: iy, x: Math.round(local.x), y: Math.round(local.y) });
      return;
    }
    if (drag.current.mode === "layer" && drag.current.id) {
      const l = st.layers.find((q) => q.id === drag.current.id);
      if (!l) return;
      const w = screenToWorld(sx, sy);
      const targetOrigin = new DOMPoint(w.x - drag.current.grabX, w.y - drag.current.grabY);
      const pinv = parentWorldMatrix(l, st.layers).inverse();
      const local = pinv.transformPoint(targetOrigin);
      st.patchLayer(l.id, { x: snap(local.x), y: snap(local.y) });
    }
  };

  const onPointerUp = (e: React.PointerEvent) => {
    pointers.current.delete(e.pointerId);
    if (pointers.current.size < 2) pinch.current = null;
    if (pointers.current.size === 0) drag.current.mode = null;
  };

  const onWheel = (e: React.WheelEvent) => {
    const { x: sx, y: sy } = (() => {
      const rect = canvasRef.current!.getBoundingClientRect();
      return { x: e.clientX - rect.left, y: e.clientY - rect.top };
    })();
    const st = useStore.getState();
    const old = st.view.zoom;
    const factor = e.deltaY < 0 ? 1.15 : 1 / 1.15;
    const z = Math.min(32, Math.max(0.5, old * factor));
    // 以光标为中心缩放
    const wx = (sx - st.view.panX) / old;
    const wy = (sy - st.view.panY) / old;
    st.setView({ zoom: z, panX: sx - wx * z, panY: sy - wy * z });
  };

  // 选中部件右上角的旋转手柄位置（屏幕坐标）
  const selectedLayer = layers.find((l) => l.id === selectedId);
  let handle: { x: number; y: number } | null = null;
  if (selectedLayer) {
    const a = assets[selectedLayer.assetId];
    if (a) {
      const fw = a.width / Math.max(1, selectedLayer.sheetFrames || 1);
      const wm = new DOMMatrix()
        .translate(view.panX, view.panY)
        .scale(view.zoom)
        .multiply(worldMatrix(selectedLayer, layers));
      const c = wm.transformPoint(new DOMPoint(fw - selectedLayer.pivotX, -selectedLayer.pivotY));
      handle = { x: c.x, y: c.y };
    }
  }

  const rotate45 = () => {
    const st = useStore.getState();
    const l = st.layers.find((x) => x.id === st.selectedId);
    if (!l) return;
    let r = Math.round(l.rotation / 45) * 45 + 45;
    while (r > 180) r -= 360;
    while (r <= -180) r += 360;
    st.patchLayer(l.id, { rotation: r });
  };

  return (
    <div ref={wrapRef} className="relative h-full w-full overflow-hidden bg-surface">
      <canvas
        ref={canvasRef}
        className="h-full w-full"
        style={{ cursor: placeMode ? "crosshair" : "default" }}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={onPointerUp}
        onWheel={onWheel}
        onDragOver={(e) => e.preventDefault()}
        onDrop={(e) => {
          e.preventDefault();
          const id = e.dataTransfer.getData("text/assetId");
          if (!id) return;
          const rect = canvasRef.current!.getBoundingClientRect();
          const w = screenToWorld(e.clientX - rect.left, e.clientY - rect.top);
          useStore.getState().addLayer(id, Math.round(w.x), Math.round(w.y));
        }}
      />

      {handle && !placeMode && (
        <button
          onPointerDown={(e) => e.stopPropagation()}
          onClick={(e) => {
            e.stopPropagation();
            rotate45();
          }}
          title="旋转 45°"
          className="absolute z-10 flex h-7 w-7 items-center justify-center rounded-full border border-line bg-surface text-sm text-clay-600 shadow-md hover:bg-claysoft"
          style={{ left: handle.x, top: handle.y, transform: "translate(20%, -120%)", touchAction: "none" }}
        >
          ↻
        </button>
      )}
    </div>
  );
}
