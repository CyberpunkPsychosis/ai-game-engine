import { useState } from "react";
import Toolbar from "./components/Toolbar";
import ProjectTree from "./components/ProjectTree";
import CanvasStage from "./components/CanvasStage";
import LayersPanel from "./components/LayersPanel";
import Inspector from "./components/Inspector";
import FramesBar from "./components/FramesBar";
import { useStore } from "./store";

function CanvasSettings() {
  const settings = useStore((s) => s.settings);
  const setSettings = useStore((s) => s.setSettings);
  const num = (label: string, key: "outW" | "outH" | "originX" | "originY" | "gridSize") => (
    <label className="flex items-center gap-2 text-sm">
      <span className="w-14 shrink-0 text-muted">{label}</span>
      <input
        type="number"
        value={settings[key]}
        onChange={(e) => setSettings({ [key]: parseInt(e.target.value) || 0 } as any)}
        className="w-full rounded-md border border-line bg-surface px-2 py-1"
      />
    </label>
  );
  return (
    <div className="space-y-2 border-t border-line px-3 py-3">
      <div className="text-xs font-semibold tracking-wide text-muted">画布 / 输出</div>
      <div className="grid grid-cols-2 gap-2">
        {num("宽", "outW")}
        {num("高", "outH")}
        {num("原点X", "originX")}
        {num("原点Y", "originY")}
        {num("网格", "gridSize")}
      </div>
      <p className="text-[11px] leading-relaxed text-muted">
        原点 = 角色根锚点，导出时作为 (0,0)。把身体根锚点对到这里，Godot 里坐标就对齐。
      </p>
    </div>
  );
}

export default function App() {
  const [leftOpen, setLeftOpen] = useState(false);
  const [rightOpen, setRightOpen] = useState(false);

  return (
    <div className="flex h-full flex-col">
      <Toolbar onLeft={() => setLeftOpen(true)} onRight={() => setRightOpen(true)} />

      <div className="relative flex min-h-0 flex-1">
        {/* 左：项目树 */}
        <aside className="hidden w-64 shrink-0 border-r border-line bg-panel md:block">
          <ProjectTree />
        </aside>

        {/* 中：画布 */}
        <main className="flex min-w-0 flex-1 flex-col">
          <div className="min-h-0 flex-1">
            <CanvasStage />
          </div>
          <FramesBar />
        </main>

        {/* 右：图层 + 属性 + 设置 */}
        <aside className="hidden w-80 shrink-0 flex-col overflow-y-auto border-l border-line bg-panel lg:flex">
          <LayersPanel />
          <div className="border-t border-line">
            <div className="px-3 py-2 text-xs font-semibold tracking-wide text-muted">属性</div>
            <Inspector />
          </div>
          <CanvasSettings />
        </aside>

        {/* 手机端：左抽屉 */}
        {leftOpen && (
          <div className="absolute inset-0 z-20 flex md:hidden">
            <div className="w-72 bg-panel shadow-xl">
              <ProjectTree />
            </div>
            <div className="flex-1 bg-black/20" onClick={() => setLeftOpen(false)} />
          </div>
        )}

        {/* 手机端：右抽屉 */}
        {rightOpen && (
          <div className="absolute inset-0 z-20 flex md:hidden">
            <div className="flex-1 bg-black/20" onClick={() => setRightOpen(false)} />
            <div className="w-80 max-w-[85%] overflow-y-auto bg-panel shadow-xl">
              <LayersPanel />
              <div className="border-t border-line">
                <div className="px-3 py-2 text-xs font-semibold tracking-wide text-muted">属性</div>
                <Inspector />
              </div>
              <CanvasSettings />
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
