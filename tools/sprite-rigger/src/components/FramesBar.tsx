import { useStore } from "../store";
import { exportRig } from "../lib/export";

export default function FramesBar() {
  const frames = useStore((s) => s.frames);
  const currentFrameId = useStore((s) => s.currentFrameId);
  const captureFrame = useStore((s) => s.captureFrame);
  const selectFrame = useStore((s) => s.selectFrame);
  const deleteFrame = useStore((s) => s.deleteFrame);

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
      <span className="text-xs font-semibold tracking-wide text-muted">帧序列</span>
      <button
        onClick={captureFrame}
        className="rounded-md border border-line px-2 py-1 text-xs hover:bg-claysoft"
        title="把当前姿势保存为一帧"
      >
        + 捕获帧
      </button>
      <div className="no-scrollbar flex flex-1 items-center gap-1 overflow-x-auto">
        {frames.map((f, i) => (
          <div
            key={f.id}
            onClick={() => selectFrame(f.id)}
            className={`flex shrink-0 cursor-pointer items-center gap-1 rounded-md px-2 py-1 text-xs ${
              currentFrameId === f.id ? "bg-clay text-white" : "border border-line hover:bg-claysoft"
            }`}
          >
            <span>{i + 1}</span>
            <button
              onClick={(e) => {
                e.stopPropagation();
                deleteFrame(f.id);
              }}
              className="opacity-70 hover:opacity-100"
            >
              ✕
            </button>
          </div>
        ))}
        {frames.length === 0 && <span className="text-xs text-muted">未捕获帧时，导出当前姿势为单帧。</span>}
      </div>
      <button
        onClick={doExport}
        className="rounded-md bg-clay px-3 py-1 text-xs font-semibold text-white hover:bg-clay-600"
      >
        导出 (Godot)
      </button>
    </div>
  );
}
