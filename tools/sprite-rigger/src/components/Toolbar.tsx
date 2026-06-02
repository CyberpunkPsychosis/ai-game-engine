import { useStore } from "../store";

function Toggle({ on, onClick, children }: { on: boolean; onClick: () => void; children: React.ReactNode }) {
  return (
    <button
      onClick={onClick}
      className={`rounded-md px-2 py-1 text-xs ${on ? "bg-claysoft text-clay-600 ring-1 ring-clay" : "border border-line text-muted hover:bg-claysoft"}`}
    >
      {children}
    </button>
  );
}

export default function Toolbar({ onLeft, onRight }: { onLeft: () => void; onRight: () => void }) {
  const settings = useStore((s) => s.settings);
  const setSettings = useStore((s) => s.setSettings);
  const view = useStore((s) => s.view);
  const setView = useStore((s) => s.setView);

  return (
    <div className="flex items-center gap-2 border-b border-line bg-panel px-3 py-2">
      <button onClick={onLeft} className="rounded-md border border-line px-2 py-1 text-xs md:hidden">素材</button>
      <div className="flex items-center gap-1.5">
        <div className="h-5 w-5 rounded bg-clay" />
        <span className="text-sm font-semibold">Sprite Rigger</span>
        <span className="hidden text-xs text-muted sm:inline">像素拼装 · 锚点对齐</span>
      </div>

      <div className="ml-auto flex items-center gap-1.5">
        <Toggle on={settings.snap} onClick={() => setSettings({ snap: !settings.snap })}>吸附</Toggle>
        <Toggle on={settings.showGrid} onClick={() => setSettings({ showGrid: !settings.showGrid })}>网格</Toggle>
        <Toggle on={settings.showAnchors} onClick={() => setSettings({ showAnchors: !settings.showAnchors })}>锚点</Toggle>
        <div className="hidden items-center gap-0.5 sm:flex">
          <button onClick={() => setView({ zoom: Math.max(0.5, view.zoom / 1.25) })} className="rounded-md border border-line px-2 py-1 text-xs">−</button>
          <span className="w-12 text-center text-xs text-muted">{Math.round(view.zoom * 100)}%</span>
          <button onClick={() => setView({ zoom: Math.min(32, view.zoom * 1.25) })} className="rounded-md border border-line px-2 py-1 text-xs">+</button>
          <button onClick={() => setView({ zoom: 3, panX: 40, panY: 40 })} className="rounded-md border border-line px-2 py-1 text-xs">复位</button>
        </div>
      </div>
      <button onClick={onRight} className="rounded-md border border-line px-2 py-1 text-xs md:hidden">图层</button>
    </div>
  );
}
