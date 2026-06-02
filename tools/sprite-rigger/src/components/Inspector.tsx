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
  const placeMode = useStore((s) => s.placeMode);
  const setPlaceMode = useStore((s) => s.setPlaceMode);
  const addPoint = useStore((s) => s.addPoint);
  const updatePoint = useStore((s) => s.updatePoint);
  const removePoint = useStore((s) => s.removePoint);
  const setParent = useStore((s) => s.setParent);
  const attachToPoint = useStore((s) => s.attachToPoint);

  const l = layers.find((q) => q.id === selectedId);
  if (!l) return <div className="px-3 py-4 text-sm text-muted">选中一个图层来编辑属性。</div>;

  const others = layers.filter((q) => q.id !== l.id);
  const parent = l.parentId ? layers.find((q) => q.id === l.parentId) : undefined;

  const rotateBy = (deg: number) => {
    let r = Math.round(l.rotation / 45) * 45 + deg;
    while (r > 180) r -= 360;
    while (r <= -180) r += 360;
    patchLayer(l.id, { rotation: r });
  };

  const pivotPlacing = placeMode?.layerId === l.id && placeMode.target === "pivot";

  return (
    <div className="space-y-3 px-3 py-3">
      <label className="flex items-center gap-2 text-sm">
        <span className="w-14 shrink-0 text-muted">名称</span>
        <input value={l.name} onChange={(e) => patchLayer(l.id, { name: e.target.value })} className="w-full rounded-md border border-line bg-surface px-2 py-1" />
      </label>

      <div className="grid grid-cols-2 gap-2">
        <Field label="X" value={l.x} onChange={(v) => patchLayer(l.id, { x: v })} />
        <Field label="Y" value={l.y} onChange={(v) => patchLayer(l.id, { y: v })} />
      </div>

      <label className="flex items-center gap-2 text-sm">
        <span className="w-14 shrink-0 text-muted">精灵表</span>
        <input
          type="number"
          min={1}
          value={l.sheetFrames}
          onChange={(e) => patchLayer(l.id, { sheetFrames: Math.max(1, parseInt(e.target.value) || 1) })}
          className="w-20 rounded-md border border-line bg-surface px-2 py-1"
        />
        <span className="text-[11px] text-muted">横向帧数（身体动画填 4；单图填 1）</span>
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

      {/* 自身锚点（握把/旋转中心） */}
      <div className="space-y-1.5 border-t border-line pt-3">
        <div className="text-xs font-semibold tracking-wide text-muted">自身锚点（握把 / 旋转中心）</div>
        <div className="grid grid-cols-2 gap-2">
          <Field label="锚X" value={l.pivotX} onChange={(v) => patchLayer(l.id, { pivotX: v })} />
          <Field label="锚Y" value={l.pivotY} onChange={(v) => patchLayer(l.id, { pivotY: v })} />
        </div>
        <button
          onClick={() => setPlaceMode(pivotPlacing ? null : { layerId: l.id, target: "pivot" })}
          className={`w-full rounded-md px-2 py-1.5 text-sm font-medium ${pivotPlacing ? "bg-clay text-white" : "border border-line hover:bg-claysoft"}`}
        >
          {pivotPlacing ? "点画布拾取锚点…（点这关闭）" : "在画布上拾取锚点"}
        </button>
      </div>

      {/* 命名挂点（手、枪口…供别的部件吸附） */}
      <div className="space-y-1.5 border-t border-line pt-3">
        <div className="flex items-center">
          <span className="text-xs font-semibold tracking-wide text-muted">挂点（手 / 枪口…）</span>
          <button onClick={() => addPoint(l.id, "")} className="ml-auto rounded-md border border-line px-2 py-0.5 text-xs hover:bg-claysoft">+ 挂点</button>
        </div>
        <p className="text-[11px] text-muted">加挂点后，直接在画布上用手指拖动橙色圆点定位（比如拖到肩/手）。别的部件可吸附到这里。</p>
        {l.points.map((p) => {
          const placing = placeMode?.layerId === l.id && placeMode.target === p.id;
          return (
            <div key={p.id} className="flex items-center gap-1">
              <input value={p.name} onChange={(e) => updatePoint(l.id, p.id, { name: e.target.value })} className="w-20 rounded-md border border-line bg-surface px-2 py-1 text-sm" />
              <span className="text-[11px] text-muted">{p.x},{p.y}</span>
              <button onClick={() => setPlaceMode(placing ? null : { layerId: l.id, target: p.id })} className={`ml-auto rounded-md px-2 py-1 text-xs ${placing ? "bg-clay text-white" : "border border-line hover:bg-claysoft"}`}>
                {placing ? "点画布…" : "放置"}
              </button>
              <button onClick={() => removePoint(l.id, p.id)} className="rounded-md px-1 py-1 text-xs text-muted hover:text-clay">✕</button>
            </div>
          );
        })}
      </div>

      {/* 挂接到父级 */}
      <div className="space-y-1.5 border-t border-line pt-3">
        <div className="text-xs font-semibold tracking-wide text-muted">挂接到父级</div>
        <label className="flex items-center gap-2 text-sm">
          <span className="w-14 shrink-0 text-muted">父级</span>
          <select value={l.parentId ?? ""} onChange={(e) => setParent(l.id, e.target.value || null)} className="w-full rounded-md border border-line bg-surface px-2 py-1">
            <option value="">（无）</option>
            {others.map((o) => (
              <option key={o.id} value={o.id}>{o.name}</option>
            ))}
          </select>
        </label>
        {parent && parent.points.length > 0 && (
          <div className="space-y-1">
            <p className="text-[11px] text-muted">把本部件的锚点吸附到 {parent.name} 的挂点：</p>
            <div className="flex flex-wrap gap-1">
              {parent.points.map((p) => (
                <button key={p.id} onClick={() => attachToPoint(l.id, parent.id, p.id)} className="rounded-md border border-line px-2 py-1 text-xs hover:bg-claysoft">
                  吸附到「{p.name}」
                </button>
              ))}
            </div>
          </div>
        )}
        {parent && parent.points.length === 0 && <p className="text-[11px] text-muted">父级 {parent.name} 还没有挂点；先选中它加一个挂点。</p>}
      </div>
    </div>
  );
}
