import { useStore } from "../store";
import { exportRig } from "../lib/export";

export default function FramesBar() {
  const frames = useStore((s) => s.frames);
  const currentFrameId = useStore((s) => s.currentFrameId);
  const prevFrame = useStore((s) => s.prevFrame);
  const nextFrame = useStore((s) => s.nextFrame);
  const idx = frames.findIndex((f) => f.id === currentFrameId);

  const doExport = () => {
    const s = useStore.getState();
    exportRig({
      assets: s.assets,
      layers: s.layers,
      frames: s.frames,
      outW: s.settings.outW,
      outH: s.settings.outH,
      originX: s.settings.originX,
      originY: s.settings.originY,
      fps: 12,
    });
  };

  return (
    <div className="flex items-center gap-2 border-t border-line bg-panel px-3 py-2">
      <button onClick={prevFrame} className="rounded-md border border-line px-2 py-1 text-xs hover:bg-claysoft" title="上一帧">◀</button>
      <span className="min-w-16 text-center text-xs font-medium text-muted">{frames.length ? `帧 ${idx + 1} / ${frames.length}` : "无帧"}</span>
      <button onClick={nextFrame} className="rounded-md border border-line px-2 py-1 text-xs hover:bg-claysoft" title="下一帧（到末尾新建一帧，用来给身体每帧标点）">▶</button>
      <span className="hidden text-[11px] text-muted sm:inline">切到每帧，给身体标对应的点</span>
      <button onClick={doExport} className="ml-auto rounded-md bg-clay px-3 py-1.5 text-sm font-semibold text-white hover:bg-clay-600">
        导出 (Godot)
      </button>
    </div>
  );
}
