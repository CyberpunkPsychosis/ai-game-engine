import { create } from "zustand";
import type { Asset, Layer, Frame, TreeNode } from "./lib/types";
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
  originX: number; // 角色根锚点（输出画布坐标），导出时作为 (0,0)
  originY: number;
}

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

  importAssets: (assets: Asset[], tree: TreeNode) => void;
  addLayer: (assetId: string, x: number, y: number) => void;
  selectLayer: (id: string | null) => void;
  patchLayer: (id: string, patch: Partial<Layer>) => void;
  deleteLayer: (id: string) => void;
  moveZ: (id: string, dir: number) => void;
  setParent: (id: string, parentId: string | null) => void;

  captureFrame: () => void;
  selectFrame: (id: string) => void;
  deleteFrame: (id: string) => void;
  renameFrame: (id: string, name: string) => void;

  setView: (v: Partial<View>) => void;
  setSettings: (s: Partial<Settings>) => void;
  setAnchorMode: (v: boolean) => void;
}

export const useStore = create<State>((set, get) => ({
  assets: {},
  tree: null,
  layers: [],
  frames: [],
  currentFrameId: null,
  selectedId: null,
  anchorMode: false,
  view: { zoom: 3, panX: 0, panY: 0 },
  settings: {
    gridSize: 1,
    snap: true,
    showGrid: true,
    showAnchors: true,
    outW: 256,
    outH: 256,
    originX: 128,
    originY: 200,
  },

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
      return { layers: [...s.layers, layer], selectedId: layer.id };
    }),

  selectLayer: (id) => set({ selectedId: id }),

  patchLayer: (id, patch) =>
    set((s) => ({
      layers: s.layers.map((l) => (l.id === id ? { ...l, ...patch } : l)),
    })),

  deleteLayer: (id) =>
    set((s) => ({
      layers: s.layers
        .filter((l) => l.id !== id)
        .map((l) => (l.parentId === id ? { ...l, parentId: null } : l)),
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
      // 防环：parentId 不能是 id 的后代
      const byId = new Map(s.layers.map((l) => [l.id, l]));
      let cur = parentId ? byId.get(parentId) : undefined;
      while (cur) {
        if (cur.id === id) return {};
        cur = cur.parentId ? byId.get(cur.parentId) : undefined;
      }
      return { layers: s.layers.map((l) => (l.id === id ? { ...l, parentId } : l)) };
    }),

  captureFrame: () =>
    set((s) => {
      const transforms: Frame["transforms"] = {};
      for (const l of s.layers)
        transforms[l.id] = { x: l.x, y: l.y, rotation: l.rotation, visible: l.visible };
      const frame: Frame = { id: uid("f"), name: `帧 ${s.frames.length + 1}`, transforms };
      return { frames: [...s.frames, frame], currentFrameId: frame.id };
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
    set((s) => ({
      frames: s.frames.filter((f) => f.id !== id),
      currentFrameId: s.currentFrameId === id ? null : s.currentFrameId,
    })),

  renameFrame: (id, name) =>
    set((s) => ({ frames: s.frames.map((f) => (f.id === id ? { ...f, name } : f)) })),

  setView: (v) => set((s) => ({ view: { ...s.view, ...v } })),
  setSettings: (st) => set((s) => ({ settings: { ...s.settings, ...st } })),
  setAnchorMode: (v) => set({ anchorMode: v }),
}));
