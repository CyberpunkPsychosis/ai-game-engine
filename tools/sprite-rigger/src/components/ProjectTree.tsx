import { useRef, useState } from "react";
import { useStore } from "../store";
import type { TreeNode } from "../lib/types";
import { parseZip, parseFiles } from "../lib/zip";

function NodeRow({ node, depth, onPick }: { node: TreeNode; depth: number; onPick?: () => void }) {
  const [open, setOpen] = useState(true);
  const assets = useStore((s) => s.assets);
  const addLayerCentered = useStore((s) => s.addLayerCentered);
  const pad = depth * 12 + 8;

  if (node.isDir) {
    return (
      <div>
        <button
          onClick={() => setOpen(!open)}
          className="flex w-full items-center gap-1 py-1 pr-2 text-left text-sm text-muted hover:text-ink"
          style={{ paddingLeft: pad }}
        >
          <span className="w-3 text-xs">{open ? "▾" : "▸"}</span>
          <span className="truncate font-medium">{node.name}</span>
        </button>
        {open && node.children.map((c) => <NodeRow key={c.path} node={c} depth={depth + 1} onPick={onPick} />)}
      </div>
    );
  }

  const asset = node.assetId ? assets[node.assetId] : undefined;
  return (
    <div
      draggable
      onDragStart={(e) => e.dataTransfer.setData("text/assetId", node.assetId ?? "")}
      onClick={() => {
        if (node.assetId) {
          addLayerCentered(node.assetId);
          onPick?.();
        }
      }}
      className="flex cursor-pointer items-center gap-2 rounded-md py-1 pr-2 hover:bg-claysoft"
      style={{ paddingLeft: pad }}
      title="点击添加到画布中央（手机端推荐），桌面也可拖到画布"
    >
      {asset && (
        <img
          src={asset.url}
          className="h-6 w-6 shrink-0 object-contain"
          style={{ imageRendering: "pixelated" }}
        />
      )}
      <span className="truncate text-sm">{node.name}</span>
      {asset && (
        <span className="ml-auto shrink-0 text-[10px] text-muted">
          {asset.width}×{asset.height}
        </span>
      )}
    </div>
  );
}

export default function ProjectTree({ onPick }: { onPick?: () => void } = {}) {
  const tree = useStore((s) => s.tree);
  const importAssets = useStore((s) => s.importAssets);
  const [loading, setLoading] = useState(false);
  const zipRef = useRef<HTMLInputElement>(null);
  const imgRef = useRef<HTMLInputElement>(null);

  const onZip = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0];
    if (!f) return;
    setLoading(true);
    try {
      const r = await parseZip(f);
      importAssets(r.assets, r.tree);
    } finally {
      setLoading(false);
      e.target.value = "";
    }
  };
  const onImgs = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const fs = e.target.files;
    if (!fs?.length) return;
    setLoading(true);
    try {
      const r = await parseFiles(fs);
      importAssets(r.assets, r.tree);
    } finally {
      setLoading(false);
      e.target.value = "";
    }
  };

  return (
    <div className="flex h-full flex-col">
      <div className="flex items-center gap-2 border-b border-line px-3 py-2">
        <span className="text-xs font-semibold tracking-wide text-muted">项目素材</span>
        <div className="ml-auto flex gap-1">
          <button
            onClick={() => zipRef.current?.click()}
            className="rounded-md bg-clay px-2 py-1 text-xs font-medium text-white hover:bg-clay-600"
          >
            上传 zip
          </button>
          <button
            onClick={() => imgRef.current?.click()}
            className="rounded-md border border-line px-2 py-1 text-xs hover:bg-claysoft"
          >
            图片
          </button>
        </div>
        <input ref={zipRef} type="file" accept=".zip" className="hidden" onChange={onZip} />
        <input ref={imgRef} type="file" accept="image/*" multiple className="hidden" onChange={onImgs} />
      </div>
      <div className="no-scrollbar flex-1 overflow-y-auto py-1">
        {loading && <div className="px-3 py-4 text-sm text-muted">解析中…</div>}
        {!loading && !tree && (
          <div className="px-3 py-6 text-sm leading-relaxed text-muted">
            上传素材压缩包开始。
            <br />
            支持 PNG/WebP，自动按目录解析。
          </div>
        )}
        {!loading && tree && tree.children.map((c) => <NodeRow key={c.path} node={c} depth={0} onPick={onPick} />)}
      </div>
    </div>
  );
}
