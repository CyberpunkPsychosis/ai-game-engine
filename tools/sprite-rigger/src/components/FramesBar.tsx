import { useEffect, useState } from "react";
import { useStore } from "../store";
import { exportRig } from "../lib/export";

export default function FramesBar() {
  const frames = useStore((s) => s.frames);
  const currentFrameId = useStore((s) => s.currentFrameId);
  const selectFrame = useStore((s) => s.selectFrame);
  const deleteFrame = useStore((s) => s.deleteFrame);
  const duplicateFrame = useStore((s) => s.duplicateFrame);
  const nextFrame = useStore((s) => s.nextFrame);
  const prevFrame = useStore((s) => s.prevFrame);

  const idx = frames.findIndex((f) => f.id === currentFrameId);

  const [playing, setPlaying] = useState(false);
  const [fps, setFps] = useState(8);
  useEffect(() => {
    if (!playing || frames.length < 2) return;
    const t = setInterval(() => {
      const s = useStore.getState();
      const i = s.frames.findIndex((f) => f.id === s.currentFrameId);
      const next = s.frames[(i + 1) % s.frames.length];
      if (next) s.selectFrame(next.id);
    }, 1000 / fps);
    return () => clearInterval(t);
  }, [playing, fps, frames.length]);

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
      <div className="flex items-center gap-1">
        <button onClick={prevFrame} className="rounded-md border border-line px-2 py-1 text-xs hover:bg-claysoft" title="上一帧">◀</button>
        <span className="min-w-14 text-center text-xs font-medium text-muted">
          {frames.length ? `帧 ${idx + 1} / ${frames.length}` : "无帧"}
        </span>
        <button onClick={nextFrame} className="rounded-md border border-line px-2 py-1 text-xs hover:bg-claysoft" title="下一帧（到末尾会复制当前帧）">▶</button>
        <button onClick={duplicateFrame} className="ml-1 rounded-md border border-line px-2 py-1 text-xs hover:bg-claysoft" title="复制当前帧为新帧">⧉ 复制</button>
        <button
          onClick={() => setPlaying((p) => !p)}
          className={`ml-1 rounded-md px-2 py-1 text-xs ${playing ? "bg-clay text-white" : "border border-line hover:bg-claysoft"}`}
          title="预览播放（循环）"
        >
          {playing ? "⏸ 停" : "⏵ 播放"}
        </button>
        <input
          type="number"
          min={1}
          max={30}
          value={fps}
          onChange={(e) => setFps(Math.min(30, Math.max(1, parseInt(e.target.value) || 8)))}
          className="w-12 rounded-md border border-line bg-surface px-1 py-1 text-center text-xs"
          title="帧率 fps"
        />
      </div>

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
            {frames.length > 1 && (
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  deleteFrame(f.id);
                }}
                className="opacity-70 hover:opacity-100"
              >
                ✕
              </button>
            )}
          </div>
        ))}
      </div>

      <button onClick={doExport} className="rounded-md bg-clay px-3 py-1 text-xs font-semibold text-white hover:bg-clay-600">
        导出 (Godot)
      </button>
    </div>
  );
}
