import { useStore } from "../store";

export default function Inspector() {
  const layers = useStore((s) => s.layers);
  const selectedId = useStore((s) => s.selectedId);
  const patchLayer = useStore((s) => s.patchLayer);
  const placeMode = useStore((s) => s.placeMode);
  const setPlaceMode = useStore((s) => s.setPlaceMode);
  const updatePoint = useStore((s) => s.updatePoint);
  const removePoint = useStore((s) => s.removePoint);
  const setParent = useStore((s) => s.setParent);

  const l = layers.find((q) => q.id === selectedId);
  if (!l) return <div className="px-3 py-4 text-sm text-muted">点一下画布上的部件来编辑。</div>;

  const others = layers.filter((q) => q.id !== l.id);
  const adding = placeMode?.layerId === l.id && placeMode.target === "addpoint";

  const rotateBy = (deg: number) => {
    let r = Math.round(l.rotation / 45) * 45 + deg;
    while (r > 180) r -= 360;
    while (r <= -180) r += 360;
    patchLayer(l.id, { rotation: r });
  };

  return (
    <div className="space-y-3 px-3 py-3">
      <label className="flex items-center gap-2 text-sm">
        <span className="w-14 shrink-0 text-muted">名称</span>
        <input value={l.name} onChange={(e) => patchLayer(l.id, { name: e.target.value })} className="w-full rounded-md border border-line bg-surface px-2 py-1" />
      </label>

      <label className="flex items-center gap-2 text-sm">
        <span className="w-14 shrink-0 text-muted">父级</span>
        <select value={l.parentId ?? ""} onChange={(e) => setParent(l.id, e.target.value || null)} className="w-full rounded-md border border-line bg-surface px-2 py-1">
          <option value="">（无）</option>
          {others.map((o) => (
            <option key={o.id} value={o.id}>{o.name}</option>
          ))}
        </select>
      </label>

      <label className="flex items-center gap-2 text-sm">
        <span className="w-14 shrink-0 text-muted">精灵表</span>
        <input
          type="number"
          min={1}
          value={l.sheetFrames}
          onChange={(e) => patchLayer(l.id, { sheetFrames: Math.max(1, parseInt(e.target.value) || 1) })}
          className="w-20 rounded-md border border-line bg-surface px-2 py-1"
        />
        <span className="text-[11px] text-muted">横向帧数（身体填 4，普通件填 1）</span>
      </label>

      <div className="space-y-1.5">
        <label className="flex items-center gap-2 text-sm">
          <span className="w-14 shrink-0 text-muted">旋转</span>
          <input type="range" min={-180} max={180} step={1} value={l.rotation} onChange={(e) => patchLayer(l.id, { rotation: parseFloat(e.target.value) })} className="w-full accent-clay" />
          <span className="w-10 text-right text-xs text-muted">{Math.round(l.rotation)}°</span>
        </label>
        <div className="flex gap-1.5 pl-16">
          <button onClick={() => rotateBy(-45)} className="flex-1 rounded-md border border-line px-2 py-1 text-xs hover:bg-claysoft">↺ −45°</button>
          <button onClick={() => rotateBy(45)} className="flex-1 rounded-md border border-line px-2 py-1 text-xs hover:bg-claysoft">↻ +45°</button>
          <button onClick={() => patchLayer(l.id, { rotation: 0 })} className="rounded-md border border-line px-2 py-1 text-xs hover:bg-claysoft">0°</button>
        </div>
      </div>

      {/* 标记点：肩、枪口等。放大后在画布上点像素即可 */}
      <div className="space-y-1.5 border-t border-line pt-3">
        <div className="text-xs font-semibold tracking-wide text-muted">标记点（肩 / 枪口…）</div>
        <button
          onClick={() => setPlaceMode(adding ? null : { layerId: l.id, target: "addpoint" })}
          className={`w-full rounded-md px-2 py-1.5 text-sm font-medium ${adding ? "bg-clay text-white" : "border border-line hover:bg-claysoft"}`}
        >
          {adding ? "点画布像素加点…（点这关闭）" : "+ 加标记点（点画布像素）"}
        </button>
        {l.points.map((p) => (
          <div key={p.id} className="flex items-center gap-1">
            <input value={p.name} onChange={(e) => updatePoint(l.id, p.id, { name: e.target.value })} className="w-24 rounded-md border border-line bg-surface px-2 py-1 text-sm" />
            <span className="text-[11px] text-muted">{p.x},{p.y}</span>
            <button onClick={() => removePoint(l.id, p.id)} className="ml-auto rounded-md px-2 py-1 text-xs text-muted hover:text-clay">删除</button>
          </div>
        ))}
        {l.points.length > 0 && <p className="text-[11px] text-muted">圆点可直接在画布上拖动微调。</p>}
      </div>
    </div>
  );
}
