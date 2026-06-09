# CLAUDE.md — 新会话先读这个

> 这是 **AI Game Engine**（Godot 4.5，对话驱动开发）。用户从手机/网页跟你聊天来推进。
> **当前唯一在做的游戏：「刹那 TimeStop」时间定格 2D 横版动作。**
> 👉 接手前必读 **`docs/TIMESTOP.md`**（设计/架构/操作/踩坑/状态/下一步全在里面）。

## 现在在做什么（一句话）
**「刹那 TimeStop」**：实时快打 + 随手冻结单体 + 绝境全场定格翻盘的横版动作游戏。
纯代码驱动，美术暂用色块占位（先验证机制好不好玩）。试玩部署在根地址
https://cyberpunkpsychosis.github.io/ai-game-engine/

## 关键约定
- **开发分支**：`claude/game-engine-claude-chat-mbKeN`（只在这上面提交/推送）。
- **美术方案（2026-06 定）**：**目前用现成素材去做**。AI 生成"角色精灵/动画"已完整验证→是**瓶颈**(出图能用但帧间一致性/抠图/影子都得人工修，性价比低)，**暂搁置**；用户在自学美术，做游戏是长期过程，以后 AI 成熟了再说。当前主角仍**色块占位**。
  - AI 角色动画流程(踩坑后跑通、留作将来参考)：RD Plus 抽卡定角色 → Flux Kontext 去影子+改姿势 → Seedance **首帧=尾帧(`lastFrameImage`)** 直接生成无缝循环(`aspectRatio:adaptive` 别用 1:1 否则丢配件) → **洪水填充抠白底**(保留内部白，别用阈值/rembg) → 统一画框+去漂移抽帧 → `build_from_strips` 切帧。播放速度是 fps 参数、随时可调。
  - **瓦片/tileset 反而适合 AI**(规整、可平铺)：可试 `model_retrodiffusion-tile` 等专用瓦片模型。
- 改完 GDScript **务必本地 headless 自测再 push**（CI"绿"≠能跑，解析错误只在运行时炸→黑屏）：
  ```bash
  GODOT=/tmp/godot_bin/Godot_v4.5-stable_linux.x86_64   # 没有就下 4.5-stable linux.x86_64
  "$GODOT" --headless --path . --quit-after 180 2>&1 | grep -iE "SCRIPT ERROR|Parse Error|Failed to load"
  ```
- 类型推断坑：`var x := 无类型实例.方法()` 返回 Variant 会解析失败 → 用显式类型 `var x: float = ...`。
- 触屏：项目 `emulate_mouse_from_touch=false`，Button 默认收不到触摸 → 用全屏 Control 的 `gui_input` 接 `InputEventScreenTouch`（见 `game.gd`）。
- 中文字体 `fonts/zpix.ttf`（像素中文）已入库；Web 导出若中文方块，确认字体嵌入或暂用英文。

## 仓库结构
- `timestop/` ← **游戏本体**（game/player/enemy/bullet/fx + postprocess.gdshader，main.tscn）
- `scripts/autoload/` 公用框架：GameManager(暂停)·SceneManager(切场景)·AudioManager·Juice(震屏)·FX(火花/序列帧)·DevTools(实时调参)
- `scripts/sprite_sheet.gd` 精灵表→SpriteFrames 切片器（FX 用）
- `shaders/flash.gdshader`·`art/fx/`·`assets/sfx/` FX 依赖资源（勿删）
- `fonts/` 字体 · `tools/` 网页辅助工具（出素材/编辑器，非游戏）
- `docs/TIMESTOP.md` 当前游戏文档 · `docs/AI_TOOLS.md`/`ASSET_SOURCING.md`/`CLOUD_WORKFLOW.md`/`LUDO_MCP.md` AI 出素材工作流

> 历史上还做过另两个游戏（横版弹反、土豆兄弟 survivor），**已废弃删除**，在 git 历史里可找回。详见 `docs/RESTART.md`。

## 工具链速查（`tools/`，纯前端，CI 部署到 GitHub Pages）
- `tools/sprite-forge/` **AI 出动作序列帧**：参考图→整表生成→抠绿切帧（密钥走环境变量 `SCENARIO_AUTH_B64`）
- `tools/enemy-designer/` 怪物路线画布 · `tools/composer/` 关卡 · `tools/tilemap/` 瓦片 · `tools/sprite-rigger/` 绑骨
- `scripts/autoload/dev_tools.gd` 游戏内实时调参（F1 调参 / F3 透视；手机左上角按钮）
