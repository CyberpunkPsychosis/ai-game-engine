# 刹那 TimeStop · 进度与说明（TIMESTOP）

> 用户当前主力在做的**新游戏**：一个**时间定格**的 2D 横版动作游戏（Godot 4.5）。
> 与之前的弹反/survivor 游戏**完全无关**，是另起炉灶的新方向。
> 试玩部署在**根地址** https://cyberpunkpsychosis.github.io/ai-game-engine/
> 美术暂用色块占位（先验证机制好不好玩，美术以后再做）。

## 一句话定位
**"实时快打 + 随手冻结搞事 + 绝境全场定格翻盘"** 的横版动作游戏。

## 核心机制（已与用户敲定）
- **统一的"冻结时间"，分大小两档，共用一条能量条**：
  - **轻档·冻单体**（FRZ / 键 K / 右键瞄准）：冻住一个敌人或子弹 ~2.6s，花 18 能量。被冻物视觉变蓝。
  - **重档·全场定格**（STOP / 键 L）：攒满 100 能量放，全场凝固 ~3s，绝境翻盘。
- **能量靠"进攻"攒**（用户选的"莽"路线）：命中 +8、击杀 +28。→ 逼玩家主动压上。
  - 自带张力：攒能量要打，救命的全场定格也要花能量 → 打得越猛越有底气。
- **闪避 DASH**（DASH / 键 C）：0.22s 冲刺 + **全程无敌帧**（可穿怪穿弹）、0.75s 冷却、带拖影。
- **敌人三型**：冲锋 charger / 远程弹幕 shooter / 治疗 healer（逼你别磨蹭）。波次导演自动刷新。

## 技术架构（刻意展示技术力，非普通写法）
- **统一时间系统**（`game.gd: scale_for()`）：每个实体每帧 `sdt = delta * scale_for(自身frozen_t)`。
  `scale_for` = 0(命中顿帧) / 0(单体冻结) / `world_scale`(全场定格时平滑 lerp→0)。
  → 冻单体 / 全场定格 / 命中顿帧 / **(未来)慢镜处决** 全是**同一套底层**，玩家恒用真实 delta（时停时只敌人凝固）。
- **全屏后处理 shader**（`postprocess.gdshader`）：定格时画面去色冷蓝 + 暗角加深 + 边缘冷霜脉动 + 扫描线 + 白闪；不读屏幕纹理，**GL Compatibility / Web 安全**。
- **CanvasModulate** 全场冷调；`world_scale` 平滑刹停/恢复（时间"渐渐凝固"而非硬切）。
- **打击感**：命中顿帧(hitstop)、trauma 式震屏、击退、被打方块倾斜、火花。
- **全屏触摸面板**统一接管触摸（见下"已知坑"）。

## 文件结构（`timestop/`，纯代码驱动）
| 文件 | 作用 |
|---|---|
| `main.tscn` | 主场景：仅一个 Node2D + `game.gd`（`project.godot` 的 main_scene 指向它）|
| `game.gd` | 主循环 / 时间系统 / 战斗结算 / 导演刷怪 / HUD / 触摸 / 后处理&震屏 |
| `player.gd` (TSPlayer) | 玩家：移动/跳/攻击/闪避，恒实时 |
| `enemy.gd` (TSEnemy) | 三型敌人 AI，用 sdt 受时间系统控制 |
| `bullet.gd` (TSBullet) | 子弹，受时间系统控制 |
| `fx.gd` (TSSpark) | 命中火花 |
| `postprocess.gdshader` | 全屏定格后处理 |

## 操作
- **电脑**：A/D 移动 · 空格 跳 · J 砍 · K 冻单体(瞄鼠标) · L 全场定格 · C 闪避 · R 重开
- **手机**（横屏！游戏是 1280×720 横版）：左下虚拟摇杆 + 右下 `HIT/JUMP/FRZ/DASH/STOP`

## 数值（在 `game.gd` 顶部常量 / 各脚本，方便调手感）
- 能量：`ENERGY_MAX=100` `SINGLE_COST=18` `SINGLE_DUR=2.6` `FULL_DUR=3.0`，初始 50，命中+8/击杀+28
- 玩家：速度 320、跳 -640、重力 1700（`player.gd`）；闪避 720 速/0.22s/0.75cd/0.30 无敌
- 子弹：弹速 240、远程开火间隔 2.8s、仅 dist<620 才射

## ⚠️ 踩过的坑 / 重要经验
1. **CI"绿"≠脚本能跑**：导出会照样打包，GDScript 解析错误只在**运行时**炸 → 黑屏。
   **务必本地 Godot headless 自测**（见下）。
2. **类型推断坑**：`var x := 无类型实例.方法()` 若返回 Variant 会**解析失败**→整脚本加载不了。用显式类型 `var x: float = ...`。
3. **触屏按钮点不动的真因**：项目 `emulate_mouse_from_touch=false`，Godot **Button 默认只认鼠标事件**，触摸收不到 → 按钮失效。
   解法：全屏 `Control` 用 `gui_input` 直接处理 `InputEventScreenTouch`，手动命中矩形（`game.gd` 的 `_on_touch`）。
4. **中文乱码**：Web 导出未嵌入 zpix 字体 → 中文变方块。当前 UI 暂用**英文/数字**规避；字体管线确认后再换回中文。
5. 旧工程的 autoload（FX layer80 / SceneManager layer128 全屏 ColorRect）都是 `MOUSE_FILTER_IGNORE`，不挡输入。

## 本地自测命令（沙箱已下载 Godot 4.5 到 /tmp）
```bash
GODOT=/tmp/Godot_v4.5-stable_linux.x86_64   # 没有就从 godot-builds releases 下 4.5-stable linux.x86_64
"$GODOT" --headless --path . --quit-after 180 2>&1 | grep -iE "SCRIPT ERROR|Parse Error|Failed to load"
# 无输出 = 脚本解析/运行无错。改完 GDScript 一律先跑这个再 push。
```

## 当前状态（截至本次整理）
- ✅ 核心循环可玩（移动/跳/砍/冻/全场定格/闪避/三型敌人/波次/能量/HUD/后处理/震屏）
- ✅ 黑屏(解析错误)已修；本地 headless 无错
- ✅ 触屏改全屏面板方案（待用户手机确认）
- ✅ 弹幕已减量
- 部署：Godot Web 导出到根地址（`build.yml` 走 project.godot 主场景）

## 下一步候选
- 用户确认手机触屏可用后，打磨手感数值
- "冻住敌人/子弹当踏板"的涌现玩法做明显（站上去）
- 给 player/enemy 加 `tunables()` 接入游戏内 ⚙调参（实时拖滑块调手感）
- Boss / 更多敌人花样；美术（色块→精灵）
