# 刹那 TimeStop · 进度与说明（TIMESTOP）

> 用户当前主力在做的**新游戏**：一个**时间定格**的 2D 横版动作游戏（Godot 4.5）。
> 与之前的弹反/survivor 游戏**完全无关**，是另起炉灶的新方向。
> 试玩部署在**根地址** https://cyberpunkpsychosis.github.io/ai-game-engine/
> 美术暂用色块占位（先验证机制好不好玩，美术以后再做）。

## 一句话定位
**"实时快打 + 随手冻结搞事 + 绝境全场定格翻盘"** 的横版动作游戏。
**目标体量:空洞骑士级的可探索横版(metroidvania)**——分阶段做,先竖切片再铺量(路线图见文末)。

## 核心机制（已与用户敲定）
- **统一的"冻结时间"，分大小两档，共用一条能量条**：
  - **轻档·冻单体**（FRZ / 键 K / 右键瞄准）：冻住一个敌人或子弹 ~2.6s，花 18 能量。被冻物视觉变蓝。
  - **重档·全场定格**（STOP / 键 L）：攒满 100 能量放，全场凝固 ~3s，绝境翻盘。
- **能量靠"进攻"攒**（用户选的"莽"路线）：命中 +8、击杀 +28。→ 逼玩家主动压上。
  - 自带张力：攒能量要打，救命的全场定格也要花能量 → 打得越猛越有底气。
- **闪避 DASH**（DASH / 键 C）：0.22s 冲刺 + **全程无敌帧**（可穿怪穿弹）、0.75s 冷却、带拖影。
- **敌人三型**：冲锋 charger / 远程弹幕 shooter / 治疗 healer。**charger 已改成可躲避的扑影**:
  逼近(慢, 能甩开)→ **预警蓄力(闪红框)** → 直线扑杀(锁方向、冲过头, 只这下碰到才伤人)→ 露破绽硬直(可反击)。
  shooter 保持中距开火不贴脸、healer 边奶边躲。(后续用 enemy-designer 给每种怪重做机制。)

## 技术架构（刻意展示技术力，非普通写法）
- **统一时间系统**（`game.gd: scale_for()`）：每个实体每帧 `sdt = delta * scale_for(自身frozen_t)`。
  `scale_for` = 0(命中顿帧) / 0(单体冻结) / `world_scale`(全场定格时平滑 lerp→0)。
  → 冻单体 / 全场定格 / 命中顿帧 / **(未来)慢镜处决** 全是**同一套底层**，玩家恒用真实 delta（时停时只敌人凝固）。
- **全屏后处理 shader**（`postprocess.gdshader`）：定格时画面去色冷蓝 + 暗角加深 + 边缘冷霜脉动 + 扫描线 + 白闪；不读屏幕纹理，**GL Compatibility / Web 安全**。
- **CanvasModulate** 全场冷调；`world_scale` 平滑刹停/恢复（时间"渐渐凝固"而非硬切）。
- **打击感**：命中顿帧(hitstop)、trauma 式震屏、击退、被打方块倾斜、火花。
- **全屏触摸面板**统一接管触摸（见下"已知坑"）。
- **房间 / 碰撞 / 摄像机**（阶段1,2026-06 加）：从单屏竞技场升级为**可滚动房间**。
  - `game.gd: _build_room()` 代码内建测试房间(2880×1080):主地面+断坑、阶梯悬空平台、左右墙、出口区。
  - `game.gd: collide_move(pos,half,motion)` —— AABB 对静态 `solids` 的**轴分离碰撞**,玩家/敌人共用(取代旧的单一 `GROUND` 判定)。
  - `Camera2D` 跟随玩家(`position_smoothing` + `limit_*` 夹房间边),**震屏改走 `cam.offset`**(原来是 `world.position`)。
  - 渲染:`_draw()` 在 world 坐标铺房间背景/网格/`solids` 色块/出口/悬停粒子,随相机滚动;HUD/后处理在 CanvasLayer 仍屏幕固定。
  - 掉出房间:玩家→受伤回 `_spawn`;敌人/子弹→移除。
  - ⏳ 阶段2:`_build_room` 换成解析 composer 导出的 `scenes/*.json`(world/markers + solids 约定)。

## 文件结构（`timestop/`，纯代码驱动）
| 文件 | 作用 |
|---|---|
| `main.tscn` | 主场景：仅一个 Node2D + `game.gd`（`project.godot` 的 main_scene 指向它）|
| `game.gd` | 主循环 / 时间系统 / **房间&碰撞&摄像机** / 战斗结算 / 导演刷怪 / HUD / 触摸 / 后处理&震屏 |
| `player.gd` (TSPlayer) | 玩家：移动/跳/攻击/闪避，恒实时；走 `game.collide_move` 碰地形 + 踏被冻物 |
| `enemy.gd` (TSEnemy) | 三型敌人 AI，用 sdt 受时间系统控制；走 `game.collide_move` 碰地形 |
| `bullet.gd` (TSBullet) | 子弹，受时间系统控制 |
| `fx.gd` (TSSpark) | 命中火花 |
| `room_loader.gd` (RoomLoader) | 读 `res://scenes/<id>.json` → Dictionary(房间数据)|
| `postprocess.gdshader` | 全屏定格后处理 |
| `../scenes/*.json` | 房间数据;现有 room_a(中枢)/ room_b(竖向)/ room_c(横向), 连成 `room_c⟵room_a⟶room_b` |

## 操作
- **电脑**：A/D 移动 · 空格 跳 · J 砍 · K 冻单体(瞄鼠标) · L 全场定格 · C 闪避 · R 重开
- **手机**（横屏！游戏是 1280×720 横版）：左下**圆形摇杆** + 右下**错落弧形大圆键** `砍/跳/闪/冻/定`
  (`touch_ui.gd` 画;点按高亮、能量不足变暗;输入仍走 `game.touch_panel` 统一圆形命中)

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
- ✅ **踏被冻物**（凝固之物即立足之地）：冻住的敌人/子弹变实体平台，可落脚+再起跳；
  全场定格时整个战场都能踩（`player.gd: _stand_on_frozen()`，只认 frozen_t>0 / freeze_t>0，顿帧不算）。
- ✅ **残响表现**（敌人=死前一瞬的残响）：活动时卡帧式抽搐 + 1–2px 错位残影；冻住瞬间彻底钉死（`enemy.gd` `_jit`）。
- ✅ **凝界悬停粒子**：半空挂着不落的冷白雨丝/尘，定格时更亮更蓝（`game.gd: _gen_motes()` / 背景 `_draw`）。
- ✅ **阶段1 可探索地基**：单屏竞技场→可滚动房间(跟随相机 + AABB 平台碰撞 + 竖向地形 + 断坑 + 高台)。
- 美术：AI 出图路线暂搁置（需人工修太多），后续走现成素材；当前仍色块占位。
- 部署：Godot Web 导出到根地址（`build.yml` 走 project.godot 主场景）

## 路线图（空洞骑士级 = 分阶段, 先竖切片再铺量）
| 阶段 | 内容 | 状态 |
|---|---|---|
| 0 现状 | 单屏波次格斗 + 时停三件套 + 踏被冻物 | ✅ |
| **1 地基** | 单屏→可滚动房间:跟随相机 + 实体平台碰撞 + 竖向地形;时停/踏被冻物在大地形里玩 | ✅ |
| **2 房间互联** | JSON 关卡(`scenes/*.json`)+ 出口换房(淡入淡出)+ 存档长椅 | ✅ |
| 3 能力 gating | 二段跳/冲刺位移/「冻物当跳台」做成解谜钥匙, 锁区→解锁(metroidvania 核心) | ⏳ |
| 4 内容铺量 | 多房间地图 + 用 enemy-designer 出怪 + Boss(悬龙) + NPC/lore | ⏳ |
| 5 美术 | 色块→现成素材(最后一步) | ⏳ |

## 房间数据格式（`scenes/<id>.json`, 由 `room_loader.gd` 读, `game.gd` 应用）
```json
{ "world": {"width":2880,"height":1080}, "groundY":1000,
  "solids": [[x,y,w,h], ...],          // 实体地形(碰撞)
  "spawn": {"x":180,"y":956},
  "doors": {"east":{"x":2720,"y":956}}, // 从相邻房间进来时的落点(按 exit.entry 命名)
  "exits": [{"x":2810,"y":836,"w":60,"h":180,"to":"room_b","entry":"west"}],
  "benches": [{"x":300,"y":1000}],      // 存档点:站上回血回能 + 设重生
  "enemies": [{"kind":"charger","x":900,"y":950}] }
```
- `game.gd: load_room(id, entry)` → `_apply_room()`:清旧怪/弹、建 solids、落位玩家(门/spawn)、刷怪、更新相机边界、铺粒子。
- 出口:玩家进出口区且非过场 → `_go_to_room()` 淡出→换房→淡入;`_exit_lock` 防进门瞬间反复触发。
- 死亡/掉坑:`_restart()` 回最近长椅所在房间满血;`endless=false` → 房间清完不再刷波。
- ⏳ **对接 composer**:它导出 world/markers, 只需补一层 `solids`(或把 tile 实例标 solid)、markers→spawn/enemy/exit 映射即可直接喂这个加载器。

## 下一步（阶段3 入口）
- 能力 gating:二段跳 / 冲刺位移(已有 DASH)/「冻物当跳台」做成解谜钥匙,锁区→解锁。
- 用 composer 真画几个房间导出 `scenes/*.json`(补 solids 约定),铺成连通地图。
- 给 player/enemy 加 `tunables()` 接游戏内 ⚙调参(F1)。
