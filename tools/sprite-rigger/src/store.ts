import { create } from "zustand";
import type { Asset, Layer, Frame, TreeNode, FrameTransform } from "./lib/types";
import { uid } from "./lib/zip";

interface View {
  zoom: number;
  panX: number;
  panY: number;
}
interface Settings {
  gridSize: number;
  snap: boolean;
  showGrid: boolean;
  showAnchors: boolean;
  outW: number;
  outH: number;
  originX: number;
  originY: number;
}

const TF_KEYS = ["x", "y", "rotation", "visible"] as const;

interface State {
  assets: Record<string, Asset>;
  tree: TreeNode | null;
  layers: Layer[];
  frames: Frame[];
  currentFrameId: string | null;
  selectedId: string | null;
  anchorMode: boolean;
  view: View;
  settings: Settings;
  canvasW: number;
  canvasH: number;

  importAssets: (assets: Asset[], tree: TreeNode) => void;
  addLayer: (assetId: string, x: number, y: number) => void;
  addLayerCentered: (assetId: string) => void;
  setCanvasSize: (w: number, h: number) => void;
  selectLayer: (id: string | null) => void;
  patchLayer: (id: string, patch: Partial<Layer>) => void;
  deleteLayer: (id: string) => void;
  moveZ: (id: string, dir: number) => void;
  setParent: (id: string, parentId: string | null) => void;

  selectFrame: (id: string) => void;
  deleteFrame: (id: string) => void;
  duplicateFrame: () => void;
  nextFrame: () => void;
  prevFrame: () => void;

  setView: (v: Partial<View>) => void;
  setSettings: (s: Partial<Settings>) => void;
  setAnchorMode: (v: boolean) => void;
}

const tf = (l: Layer): FrameTransform => ({ x: l.x, y: l.y, rotation: l.rotation, visible: l.visible });

export const useStore = create<State>((set, get) => ({
  assets: {},
  tree: null,
  layers: [],
  frames: [],
  currentFrameId: null,
  selectedId: null,
  anchorMode: false,
  view: { zoom: 3, panX: 40, panY: 40 },
  canvasW: 800,
  canvasH: 600,
  settings: { gridSize: 1, snap: true, showGrid: true, showAnchors: true, outW: 256, outH: 256, originX: 128, originY: 200 },

  importAssets: (assets, tree) =>
    set((s) => {
      const map = { ...s.assets };
      for (const a of assets) map[a.id] = a;
      return { assets: map, tree };
    }),

  addLayer: (assetId, x, y) =>
    set((s) => {
      const asset = s.assets[assetId];
      if (!asset) return {};
      const layer: Layer = {
        id: uid("l"),
        assetId,
        name: asset.name.replace(/\.[^.]+$/, ""),
        parentId: null,
        x,
        y,
        rotation: 0,
        pivotX: Math.round(asset.width / 2),
        pivotY: Math.round(asset.height / 2),
        z: s.layers.length,
        visible: true,
      };
      // 保证至少有一帧
      let frames = s.frames;
      let currentFrameId = s.currentFrameId;
      if (frames.length === 0) {
        currentFrameId = uid("f");
        frames = [{ id: currentFrameId, name: "帧 1", transforms: {} }];
      }
      // 新部件在所有帧里都出现（同一初始位置）
      const t = tf(layer);
      frames = frames.map((f) => ({ ...f, transforms: { ...f.transforms, [layer.id]: { ...t } } }));
      return { layers: [...s.layers, layer], frames, currentFrameId, selectedId: layer.id };
    }),

  addLayerCentered: (assetId) => {
    const s = get();
    const cx = (s.canvasW / 2 - s.view.panX) / s.view.zoom;
    const cy = (s.canvasH / 2 - s.view.panY) / s.view.zoom;
    s.addLayer(assetId, Math.round(cx), Math.round(cy));
  },

  setCanvasSize: (w, h) => set({ canvasW: w, canvasH: h }),

  selectLayer: (id) => set({ selectedId: id }),

  patchLayer: (id, patch) =>
    set((s) => {
      const layers = s.layers.map((l) => (l.id === id ? { ...l, ...patch } : l));
      let frames = s.frames;
      // 变换类字段写回当前帧（真正按帧编辑）
      const hasTf = TF_KEYS.some((k) => k in patch);
      if (hasTf && s.currentFrameId) {
        const layer = layers.find((l) => l.id === id)!;
        frames = s.frames.map((f) =>
          f.id === s.currentFrameId ? { ...f, transforms: { ...f.transforms, [id]: tf(layer) } } : f
        );
      }
      return { layers, frames };
    }),

  deleteLayer: (id) =>
    set((s) => ({
      layers: s.layers.filter((l) => l.id !== id).map((l) => (l.parentId === id ? { ...l, parentId: null } : l)),
      frames: s.frames.map((f) => {
        const t = { ...f.transforms };
        delete t[id];
        return { ...f, transforms: t };
      }),
      selectedId: s.selectedId === id ? null : s.selectedId,
    })),

  moveZ: (id, dir) =>
    set((s) => {
      const sorted = [...s.layers].sort((a, b) => a.z - b.z);
      const i = sorted.findIndex((l) => l.id === id);
      const j = i + dir;
      if (i < 0 || j < 0 || j >= sorted.length) return {};
      [sorted[i], sorted[j]] = [sorted[j], sorted[i]];
      sorted.forEach((l, idx) => (l.z = idx));
      return { layers: [...sorted] };
    }),

  setParent: (id, parentId) =>
    set((s) => {
      if (id === parentId) return {};
      const byId = new Map(s.layers.map((l) => [l.id, l]));
      let cur = parentId ? byId.get(parentId) : undefined;
      while (cur) {
        if (cur.id === id) return {};
        cur = cur.parentId ? byId.get(cur.parentId) : undefined;
      }
      return { layers: s.layers.map((l) => (l.id === id ? { ...l, parentId } : l)) };
    }),

  selectFrame: (id) =>
    set((s) => {
      const frame = s.frames.find((f) => f.id === id);
      if (!frame) return {};
      const layers = s.layers.map((l) => {
        const t = frame.transforms[l.id];
        return t ? { ...l, x: t.x, y: t.y, rotation: t.rotation, visible: t.visible } : l;
      });
      return { layers, currentFrameId: id };
    }),

  deleteFrame: (id) =>
    set((s) => {
      const frames = s.frames.filter((f) => f.id !== id);
      let currentFrameId = s.currentFrameId;
      if (s.currentFrameId === id) currentFrameId = frames[0]?.id ?? null;
      return { frames, currentFrameId };
    }),

  duplicateFrame: () => {
    const s = get();
    const cur = s.frames.find((f) => f.id === s.currentFrameId);
    const transforms: Record<string, FrameTransform> = cur
      ? JSON.parse(JSON.stringify(cur.transforms))
      : Object.fromEntries(s.layers.map((l) => [l.id, tf(l)]));
    const id = uid("f");
    const i = s.frames.findIndex((f) => f.id === s.currentFrameId);
    const frame: Frame = { id, name: `帧 ${s.frames.length + 1}`, transforms };
    const frames = [...s.frames];
    frames.splice(i < 0 ? s.frames.length : i + 1, 0, frame);
    set({ frames, currentFrameId: id });
  },

  nextFrame: () => {
    const s = get();
    const i = s.frames.findIndex((f) => f.id === s.currentFrameId);
    if (i >= 0 && i < s.frames.length - 1) s.selectFrame(s.frames[i + 1].id);
    else s.duplicateFrame(); // 到末尾：复制当前帧（带着上一帧的部件继续调）
  },

  prevFrame: () => {
    const s = get();
    const i = s.frames.findIndex((f) => f.id === s.currentFrameId);
    if (i > 0) s.selectFrame(s.frames[i - 1].id);
  },

  setView: (v) => set((s) => ({ view: { ...s.view, ...v } })),
  setSettings: (st) => set((s) => ({ settings: { ...s.settings, ...st } })),
  setAnchorMode: (v) => set({ anchorMode: v }),
}));
