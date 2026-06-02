import { useStore } from "../store";
import { exportRig } from "../lib/export";

export default function FramesBar() {
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
      <span className="text-xs text-muted">摆好这一帧、标好点，然后导出发我</span>
      <button onClick={doExport} className="ml-auto rounded-md bg-clay px-3 py-1.5 text-sm font-semibold text-white hover:bg-clay-600">
        导出 (Godot)
      </button>
    </div>
  );
}
