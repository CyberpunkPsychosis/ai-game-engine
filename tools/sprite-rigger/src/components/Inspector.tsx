import { useStore } from "../store";

function Field({ label, value, onChange, step = 1 }: { label: string; value: number; onChange: (v: number) => void; step?: number }) {
  return (
    <label className="flex items-center gap-2 text-sm">
      <span className="w-14 shrink-0 text-muted">{label}</span>
      <input
        type="number"
        step={step}
        value={Number.isFinite(value) ? Math.round(value * 100) / 100 : 0}
        onChange={(e) => onChange(parseFloat(e.target.value) || 0)}
        className="w-full rounded-md border border-line bg-surface px-2 py-1"
      />
    </label>
  );
}

export default function Inspector() {
  const layers = useStore((s) => s.layers);
  const selectedId = useStore((s) => s.selectedId);
  const patchLayer = useStore((s) => s.patchLayer);
  const setAnchorMode = useStore((s) => s.setAnchorMode);
  const anchorMode = useStore((s) => s.anchorMode);

  const l = layers.find((q) => q.id === selectedId);
  if (!l) {
    return <div className="px-3 py-4 text-sm text-muted">选中一个图层来编辑属性。</div>;
  }

  const others = layers.filter((q) => q.id !== l.id);

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
        <input
          value={l.name}
          onChange={(e) => patchLayer(l.id, { name: e.target.value })}
          className="w-full rounded-md border border-line bg-surface px-2 py-1"
        />
      </label>

      <div className="grid grid-cols-2 gap-2">
        <Field label="X" value={l.x} onChange={(v) => patchLayer(l.id, { x: v })} />
        <Field label="Y" value={l.y} onChange={(v) => patchLayer(l.id, { y: v })} />
      </div>

      <div className="space-y-1.5">
        <label className="flex items-center gap-2 text-sm">
          <span className="w-14 shrink-0 text-muted">旋转</span>
          <input
            type="range"
            min={-180}
            max={180}
            step={1}
            value={l.rotation}
            onChange={(e) => patchLayer(l.id, { rotation: parseFloat(e.target.value) })}
            className="w-full accent-clay"
          />
          <span className="w-10 text-right text-xs text-muted">{Math.round(l.rotation)}°</span>
        </label>
        <div className="flex gap-1.5 pl-16">
          <button onClick={() => rotateBy(-45)} className="flex-1 rounded-md border border-line px-2 py-1 text-xs hover:bg-claysoft" title="逆时针 45°">↺ −45°</button>
          <button onClick={() => rotateBy(45)} className="flex-1 rounded-md border border-line px-2 py-1 text-xs hover:bg-claysoft" title="顺时针 45°">↻ +45°</button>
          <button onClick={() => patchLayer(l.id, { rotation: 0 })} className="rounded-md border border-line px-2 py-1 text-xs hover:bg-claysoft" title="归零">0°</button>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-2">
        <Field label="锚X" value={l.pivotX} onChange={(v) => patchLayer(l.id, { pivotX: v })} />
        <Field label="锚Y" value={l.pivotY} onChange={(v) => patchLayer(l.id, { pivotY: v })} />
      </div>

      <button
        onClick={() => setAnchorMode(!anchorMode)}
        className={`w-full rounded-md px-2 py-1.5 text-sm font-medium ${anchorMode ? "bg-clay text-white" : "border border-line hover:bg-claysoft"}`}
      >
        {anchorMode ? "锚点模式：点画布设锚点（再次点关闭）" : "设置锚点（点画布拾取）"}
      </button>

      <label className="flex items-center gap-2 text-sm">
        <span className="w-14 shrink-0 text-muted">父级</span>
        <select
          value={l.parentId ?? ""}
          onChange={(e) => useStore.getState().setParent(l.id, e.target.value || null)}
          className="w-full rounded-md border border-line bg-surface px-2 py-1"
        >
          <option value="">（无）</option>
          {others.map((o) => (
            <option key={o.id} value={o.id}>
              {o.name}
            </option>
          ))}
        </select>
      </label>
    </div>
  );
}
