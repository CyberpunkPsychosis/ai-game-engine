import { useStore } from "../store";

export default function LayersPanel() {
  const layers = useStore((s) => s.layers);
  const selectedId = useStore((s) => s.selectedId);
  const selectLayer = useStore((s) => s.selectLayer);
  const patchLayer = useStore((s) => s.patchLayer);
  const deleteLayer = useStore((s) => s.deleteLayer);
  const moveZ = useStore((s) => s.moveZ);
  const assets = useStore((s) => s.assets);

  const sorted = [...layers].sort((a, b) => b.z - a.z); // 顶层在上

  return (
    <div className="flex h-full flex-col">
      <div className="border-b border-line px-3 py-2 text-xs font-semibold tracking-wide text-muted">
        图层 ({layers.length})
      </div>
      <div className="no-scrollbar flex-1 overflow-y-auto py-1">
        {sorted.length === 0 && <div className="px-3 py-4 text-sm text-muted">从左侧把部件拖/点到画布。</div>}
        {sorted.map((l) => {
          const a = assets[l.assetId];
          const sel = l.id === selectedId;
          return (
            <div
              key={l.id}
              onClick={() => selectLayer(l.id)}
              className={`mx-1 flex items-center gap-2 rounded-md px-2 py-1 ${sel ? "bg-claysoft ring-1 ring-clay" : "hover:bg-claysoft"}`}
            >
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  patchLayer(l.id, { visible: !l.visible });
                }}
                className="w-5 text-center text-xs"
                title="显示/隐藏"
              >
                {l.visible ? "◉" : "○"}
              </button>
              {a && <img src={a.url} className="h-5 w-5 object-contain" style={{ imageRendering: "pixelated" }} />}
              <span className="truncate text-sm">{l.name}</span>
              <div className="ml-auto flex items-center gap-0.5 text-xs text-muted">
                <button onClick={(e) => { e.stopPropagation(); moveZ(l.id, 1); }} className="px-1 hover:text-ink" title="上移">▲</button>
                <button onClick={(e) => { e.stopPropagation(); moveZ(l.id, -1); }} className="px-1 hover:text-ink" title="下移">▼</button>
                <button onClick={(e) => { e.stopPropagation(); deleteLayer(l.id); }} className="px-1 hover:text-clay" title="删除">✕</button>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
