import type { Layer } from "./types";

// 计算某图层的世界变换矩阵（沿父链累乘：translate -> rotate）
export function worldMatrix(layer: Layer, layers: Layer[]): DOMMatrix {
  const byId = new Map(layers.map((l) => [l.id, l]));
  const chain: Layer[] = [];
  const seen = new Set<string>();
  let cur: Layer | undefined = layer;
  while (cur && !seen.has(cur.id)) {
    chain.unshift(cur);
    seen.add(cur.id);
    cur = cur.parentId ? byId.get(cur.parentId) : undefined;
  }
  let m = new DOMMatrix();
  for (const l of chain) {
    m = m.translate(l.x, l.y).rotate(l.rotation);
  }
  return m;
}

// 父链的世界矩阵（不含自身），用于把屏幕位移换算成该图层的局部位移
export function parentWorldMatrix(layer: Layer, layers: Layer[]): DOMMatrix {
  if (!layer.parentId) return new DOMMatrix();
  const parent = layers.find((l) => l.id === layer.parentId);
  if (!parent) return new DOMMatrix();
  return worldMatrix(parent, layers);
}

// 拓扑排序：父在子之前（避免渲染/计算顺序问题）
export function ordered(layers: Layer[]): Layer[] {
  return [...layers].sort((a, b) => a.z - b.z);
}
