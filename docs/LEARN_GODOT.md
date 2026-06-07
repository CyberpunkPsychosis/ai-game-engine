# 学 Godot · 每日私教课程（LEARN_GODOT）

> 用户在系统学 Godot（边做自己这个 2D 动作游戏边学）。**Claude 当私教，一天一课。**
> 节奏：用户**白天在公司读文档**（下面每课的"📖读"）→ **回家/网页版编辑器动手验证**（"🛠️做"）。
> 用户同时在学画画，所以每天动手任务**控制在 15–30 分钟**，别贪多。

## 怎么上课
- 用户每天来说一句「**上课**」或「今天学啥」，Claude 就讲**下一课**：先讲清概念，再给当天「📖读」链接 + 「🛠️做」的小任务，答疑。
- 每上完一课，把下面对应行的 `[ ]` 改成 `[x]`，并更新「当前进度」。
- 原则：**能让用户自己在编辑器里做的，就别替他写**（「教我」模式）。卡住了再点拨。
- 一切尽量落到**用户自己的项目**（`scripts/player.gd`、`scripts/enemy.gd`、关卡）上，不做一次性 demo。

## 当前进度
> 👉 **下一课：第 1 课（节点与场景）**

---

## 第一周 · 地基（节点 / 场景 / 脚本 / 信号）
目标：理解 Godot 的"世界观"——一切都是节点，场景是节点的组合。

- [ ] **D1 节点与场景树**　📖 [Nodes and scenes](https://docs.godotengine.org/en/stable/getting_started/step_by_step/nodes_and_scenes.html)　🛠️ 新建场景，放一个 `Sprite2D`，随便拖张图，运行看到它。
- [ ] **D2 第一个脚本 · _ready/_process**　📖 [Creating your first script](https://docs.godotengine.org/en/stable/getting_started/step_by_step/scripting_first_script.html)　🛠️ 给节点挂脚本，让它每帧旋转/移动一点。
- [ ] **D3 输入 Input**　📖 [Input examples](https://docs.godotengine.org/en/stable/tutorials/inputs/input_examples.html)　🛠️ 按方向键让方块左右移动。
- [ ] **D4 信号 Signals**　📖 [Signals](https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html)　🛠️ 用编辑器连一个按钮的 `pressed` 信号到脚本；再用代码连一次。
- [ ] **D5 场景实例化 Instancing**　📖 [Creating instances](https://docs.godotengine.org/en/stable/getting_started/step_by_step/instancing.html)　🛠️ 把"方块"存成场景，在另一个场景里复制出 3 个。
- [ ] **D6 复盘 + 串起来**　🛠️ 做一个"方块能左右走"的小场景，自己从头搭一遍（不看上面的步骤）。
- [ ] **D7 读真实代码**　跟 Claude 一起读 `scripts/player.gd` 开头，把这周学的概念对到项目里。

## 第二周 · 2D 动作核心
目标：能让一个角色走、跳、打（先用色块）。

- [ ] **D8 CharacterBody2D + move_and_slide**　📖 [Using CharacterBody2D](https://docs.godotengine.org/en/stable/tutorials/physics/using_character_body_2d.html)
- [ ] **D9 重力 + 跳跃**　🛠️ 加重力、空格起跳。
- [ ] **D10 可变跳 / 土狼时间 / 跳跃缓冲**　跟 Claude 读 `player.gd` 里这部分手感代码，看官方做法对比。
- [ ] **D11 碰撞层与掩码 Collision layers/masks**　📖 [Physics introduction](https://docs.godotengine.org/en/stable/tutorials/physics/physics_introduction.html)
- [ ] **D12 Area2D 做命中判定**　对照项目 `scripts/components/hitbox.gd`、`hurtbox.gd`。
- [ ] **D13 动画 AnimatedSprite2D / AnimationPlayer**　📖 [2D sprite animation](https://docs.godotengine.org/en/stable/tutorials/2d/2d_sprite_animation.html)
- [ ] **D14 整合**　色块角色：走 + 跳 + 挥一下（攻击框出现）。

## 第三周 · 世界与内容
- [ ] **D15 TileMap 关卡**　📖 [Using TileMaps](https://docs.godotengine.org/en/stable/tutorials/2d/using_tilemaps.html)　← 用户将来"自己接管关卡"的关键
- [ ] **D16 相机 Camera2D**（跟随角色）
- [ ] **D17 音效 AudioStreamPlayer**　📖 [Audio streams](https://docs.godotengine.org/en/stable/tutorials/audio/audio_streams.html)
- [ ] **D18 UI 与 CanvasLayer**（血条）
- [ ] **D19 场景切换**（对照 `autoload/scene_manager.gd`）
- [ ] **D20 状态机思想**（对照 `scripts/state_machine/`）
- [ ] **D21 整合 + 复盘**

## 第四周 · 接管自己的项目
- [ ] **D22–24 读懂 `player.gd` / `enemy.gd` 全貌**
- [ ] **D25–26 自己用 TileMap 摆一小关**（用户主导，Claude 接逻辑）
- [ ] **D27 自己给一只怪加一个行为**（「教我」模式，Claude 只点拨）
- [ ] **D28 复盘：哪些自己做更快、哪些交给 AI** → 定下长期分工

## 备注
- 网页版编辑器：[editor.godotengine.org](https://editor.godotengine.org/)（电脑 Chrome/Edge；公司网可能拦 SharedArrayBuffer，拦了就回家用装好的 Godot 验证）。
- 装正式版：[godotengine.org/download](https://godotengine.org/download)（免费、单文件、不用安装，下载即用）。
