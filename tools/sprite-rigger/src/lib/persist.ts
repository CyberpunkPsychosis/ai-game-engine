import type { Asset, Layer, Frame, TreeNode } from "./types";
import { idbGet, idbPut, idbClear } from "./db";

type AssetMeta = Omit<Asset, "url" | "blob">;

interface Snapshot {
  v: number;
  layers: Layer[];
  frames: Frame[];
  tree: TreeNode | null;
  currentFrameId: string | null;
  selectedId: string | null;
  settings: unknown;
  view: unknown;
  assets: AssetMeta[];
}

export interface Loaded {
  assets: Record<string, Asset>;
  tree: TreeNode | null;
  layers: Layer[];
  frames: Frame[];
  currentFrameId: string | null;
  selectedId: string | null;
  settings: any;
  view: any;
}

export async function saveBlob(id: string, blob: Blob): Promise<void> {
  await idbPut("blobs", id, blob);
}

export async function saveSnapshot(s: {
  assets: Record<string, Asset>;
  layers: Layer[];
  frames: Frame[];
  tree: TreeNode | null;
  currentFrameId: string | null;
  selectedId: string | null;
  settings: unknown;
  view: unknown;
}): Promise<void> {
  const assets: AssetMeta[] = Object.values(s.assets).map(({ id, name, path, width, height }) => ({
    id,
    name,
    path,
    width,
    height,
  }));
  const snap: Snapshot = {
    v: 1,
    layers: s.layers,
    frames: s.frames,
    tree: s.tree,
    currentFrameId: s.currentFrameId,
    selectedId: s.selectedId,
    settings: s.settings,
    view: s.view,
    assets,
  };
  await idbPut("meta", "project", snap);
}

export async function loadSnapshot(): Promise<Loaded | null> {
  const snap = await idbGet<Snapshot>("meta", "project");
  if (!snap) return null;
  const assets: Record<string, Asset> = {};
  for (const m of snap.assets) {
    const blob = await idbGet<Blob>("blobs", m.id);
    if (blob) {
      assets[m.id] = { ...m, blob, url: URL.createObjectURL(blob) };
    }
  }
  return {
    assets,
    tree: snap.tree,
    layers: snap.layers.map((l) => ({
      ...l,
      points: (l as any).points ?? [],
      sheetFrames: (l as any).sheetFrames ?? 1,
      locked: (l as any).locked ?? false,
    })),
    frames: snap.frames.map((f) => ({ ...f, points: (f as any).points ?? {} })),
    currentFrameId: snap.currentFrameId,
    selectedId: snap.selectedId,
    settings: snap.settings,
    view: snap.view,
  };
}

export async function clearAll(): Promise<void> {
  await idbClear("meta");
  await idbClear("blobs");
}
