# 学 Godot · 私教课程（LEARN_GODOT）

> 用户边做自己这个 2D 动作游戏边学 Godot。**Claude 当私教，一课一课讲。**
> 节奏：用户**白天公司读文档/我讲** → **回家或网页版编辑器动手验证**。同时在学画画。
>
> **【方向已定 · 2026-06】用户选择：只学"我要自己亲手做"的部分。**
> 系统逻辑（战斗/AI/状态机/手感算法）→ **交给 Claude 写，用户看懂原理即可，不专门学手写。**
> 用户亲手做的（关卡/动画/摆位/调参/音效）→ **重点学扎实**，因为手做比口述给 AI 快。

## 怎么上课
- 用户说「**上课**」/「下一课」，Claude 讲下一课：概念 + 「📖读」+ 「🛠️做」小任务 + 答疑。
- 文档太复杂时，用户会说"简化"，Claude 给"照着点 + 最少代码"的极简版。
- 上完一课把 `[ ]` 改 `[x]`，更新「当前进度」。
- 「教我」模式：能让用户自己在编辑器里做的就别替他写，卡住再点拨。尽量落到用户真实项目上。

## 当前进度
> 👉 **下一阶段第 1 课：动画（把图接进游戏）**　[D6 实操、地基复习待用户随时后补]

---

## ✅ 第一阶段 · 地基（已完成 D1–D10）
> 给了用户"读代码 + 跟 AI 沟通"的能力。**不用再深挖，够用。**
- [x] D1 节点与场景树
- [x] D2 第一个脚本 `_ready`/`_process`
- [x] D3 输入 Input（含向量 / lerp 平滑跟随）
- [x] D4 信号 Signals
- [x] D5 场景实例化 `preload`→`instantiate`→`add_child`
- [ ] D6 复盘自己串一遍（用户跳过，后补）
- [x] D7 读真实 `player.gd`
- [x] D8 CharacterBody2D + move_and_slide
- [x] D9 重力 + 跳跃
- [x] D10 跳跃手感三件套（可变跳/土狼时间/跳跃缓冲）— **看懂即可，已交给 Actor2D**

---

## 🎯 第二阶段 · 只学"用户亲手做"的（当前重点）
目标：用户能**自己摆关卡、把画的图接进游戏、摆怪调手感**，不依赖 AI 做这些视觉/空间活。

- [ ] **L1 动画 · 把图接进游戏**　📖 [2D sprite animation](https://docs.godotengine.org/en/stable/tutorials/2d/2d_sprite_animation.html)
  　🛠️ 用 `AnimatedSprite2D` 把几张图做成"待机/走"动画，按移动切换。← 直接挂钩用户学画画
- [ ] **L2 TileMap · 自己刷一张关卡**　📖 [Using TileMaps](https://docs.godotengine.org/en/stable/tutorials/2d/using_tilemaps.html)
  　🛠️ 导入一套 tileset，刷出地面/平台，加碰撞，角色能站上去。← 用户要接管的"关卡"
- [ ] **L3 相机跟随**　🛠️ `Camera2D` 跟着角色走（可配合学过的 lerp 做平滑跟随）。
- [ ] **L4 把怪摆进关卡 + ⚙调参**　🛠️ 用项目现成的 enemy 实例摆进关卡，进游戏用 F1/⚙ 拖滑块调手感（不写战斗系统）。
- [ ] **L5 音效 · 最便宜的手感放大器**　📖 [Audio streams](https://docs.godotengine.org/en/stable/tutorials/audio/audio_streams.html)
  　🛠️ 丢个 `.wav` 进 `assets/sfx/`，攻击/跳跃时播放，立刻"有肉感"。
- [ ] **L6 自己拼一小关 / 接手项目关卡**　🛠️ 用户主导摆关卡，Claude 接逻辑。从"教程"正式进入"你的游戏"。

## 🤝 交给 AI 的（用户不用学手写，遇到再让 Claude 讲原理）
战斗结算 / 弹反格挡 / 敌人 AI 选招 / 状态机 / 受击特效系统 / 数值平衡。
→ 对应项目文件：`scripts/actor_2d.gd`、`scripts/enemy.gd`、`scripts/components/`、`scripts/state_machine/`、`scripts/autoload/fx.gd`。

## 备注
- 网页版编辑器：[editor.godotengine.org](https://editor.godotengine.org/)（用户已能打开）。
- 装正式版：[godotengine.org/download](https://godotengine.org/download)。
- 免费素材：[Kenney](https://kenney.nl/)（CC0，做 tileset/动画练习直接用）。
- AI 出动作帧的新工具：`tools/sprite-forge/`（参考图→整表生成→切帧），动画素材以后从这来。
