import { useEffect, useRef } from "react";
import { useStore } from "../store";
import { worldMatrix, parentWorldMatrix, ordered } from "../lib/transform";
import type { Layer } from "../lib/types";

export default function CanvasStage() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const wrapRef = useRef<HTMLDivElement>(null);
  const imgCache = useRef<Record<string, HTMLImageElement>>({});
  const drag = useRef<{ mode: "layer" | "pan" | null; id?: string; grabX: number; grabY: number; startPanX: number; startPanY: number }>({
    mode: null,
    grabX: 0,
    grabY: 0,
    startPanX: 0,
    startPanY: 0,
  });

  const assets = useStore((s) => s.assets);
  const layers = useStore((s) => s.layers);
  const view = useStore((s) => s.view);
  const settings = useStore((s) => s.settings);
  const selectedId = useStore((s) => s.selectedId);
  const anchorMode = useStore((s) => s.anchorMode);

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
    const list = ordered(layers);
    for (let i = list.length - 1; i >= 0; i--) {
      const l = list[i];
      if (!l.visible) continue;
      const a = assets[l.assetId];
      if (!a) continue;
      const inv = worldMatrix(l, layers).inverse();
      const p = inv.transformPoint(new DOMPoint(wx, wy));
      if (p.x >= -l.pivotX && p.x <= a.width - l.pivotX && p.y >= -l.pivotY && p.y <= a.height - l.pivotY) {
        return l;
      }
    }
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
      ctx.drawImage(img, -l.pivotX, -l.pivotY);
    }
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

    // 锚点 + 选中框（屏幕空间）
    if (settings.showAnchors) {
      for (const l of layers) {
        const wm = worldMatrix(l, layers);
        const o = wm.transformPoint(new DOMPoint(0, 0));
        const sx = panX + o.x * zoom;
        const sy = panY + o.y * zoom;
        const sel = l.id === selectedId;
        ctx.strokeStyle = sel ? "#cc785c" : "#b9b4a6";
        ctx.lineWidth = sel ? 2 : 1;
        ctx.beginPath();
        ctx.moveTo(sx - 6, sy);
        ctx.lineTo(sx + 6, sy);
        ctx.moveTo(sx, sy - 6);
        ctx.lineTo(sx, sy + 6);
        ctx.stroke();
      }
    }
    const selected = layers.find((l) => l.id === selectedId);
    if (selected) {
      const a = assets[selected.assetId];
      if (a) {
        const wm = new DOMMatrix().translate(panX, panY).scale(zoom).multiply(worldMatrix(selected, layers));
        const corners = [
          new DOMPoint(-selected.pivotX, -selected.pivotY),
          new DOMPoint(a.width - selected.pivotX, -selected.pivotY),
          new DOMPoint(a.width - selected.pivotX, a.height - selected.pivotY),
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

  const onPointerDown = (e: React.PointerEvent) => {
    (e.target as Element).setPointerCapture(e.pointerId);
    const { x: sx, y: sy } = getLocalXY(e);
    const w = screenToWorld(sx, sy);
    const st = useStore.getState();

    if (st.anchorMode && st.selectedId) {
      // 设锚点：把点击处设为选中图层的锚点，且部件视觉不动
      const l = st.layers.find((q) => q.id === st.selectedId);
      if (l) {
        const localClicked = worldMatrix(l, st.layers).inverse().transformPoint(new DOMPoint(w.x, w.y));
        const ix = Math.round(localClicked.x + l.pivotX);
        const iy = Math.round(localClicked.y + l.pivotY);
        const pinv = parentWorldMatrix(l, st.layers).inverse();
        const local = pinv.transformPoint(new DOMPoint(w.x, w.y));
        st.patchLayer(l.id, { pivotX: ix, pivotY: iy, x: Math.round(local.x), y: Math.round(local.y) });
      }
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
    if (!drag.current.mode) return;
    const { x: sx, y: sy } = getLocalXY(e);
    const st = useStore.getState();
    if (drag.current.mode === "pan") {
      st.setView({ panX: drag.current.startPanX + (sx - drag.current.grabX), panY: drag.current.startPanY + (sy - drag.current.grabY) });
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

  const onPointerUp = () => {
    drag.current.mode = null;
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

  return (
    <div ref={wrapRef} className="relative h-full w-full overflow-hidden bg-surface">
      <canvas
        ref={canvasRef}
        className="h-full w-full"
        style={{ cursor: anchorMode ? "crosshair" : "default" }}
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
    </div>
  );
}
