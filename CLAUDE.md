# CLAUDE.md — 新会话先读这个

> 这是 **AI Game Engine**（Godot 4.5，2D 横版动作游戏，对话驱动开发）。
> 用户从手机/网页跟你聊天来推进。**当前正在做"怪物行动编排"这条线**，详见
> 👉 **`docs/HANDOFF.md`（重要：新会话务必先读）**。其余背景见 `README.md`、`docs/`。

## 现在在做什么（一句话）
做了一个网页版**「怪物导演」画布工具**（`tools/enemy-designer/index.html`），用户在画布上**摆怪 + 画移动路线/弹道**，把"嘴说不清的怪物行动路线"画出来，点「复制给AI」把带坐标的行动路线发给你，你照着在 Godot 里实现怪。**分阶段做**：用户画一段 → 你实现 → 用户试玩用游戏内 `⚙调参` 面板（DevTools）微调 → 画下一段。

## 关键约定
- **开发分支**：`claude/game-engine-claude-chat-mbKeN`（在这上面提交/推送，不要推别的分支）。
- 这个工具**只补"行动路线"**，不负责定所有数值/机制；数值你来定，用户试玩再调。
- 怪的实现要带 `tunables()`（见 `scripts/enemy.gd`），这样用户能在游戏里实时拖滑块调手感。
- 工具是纯前端单文件 HTML，改完 `node --check` 验证脚本即可；CI 会部署到 GitHub Pages。

## 工具链速查
- `tools/enemy-designer/` 怪物导演（画布摆位+路线+弹道）← 当前主线
- `tools/sprite-forge/` **AI 出动作序列帧**：一张参考图→整表一次生成(GPT Image 2/Gemini)→抠绿切帧脚底对齐（密钥走环境变量 `SCENARIO_AUTH_B64`）
- `tools/composer/` 关卡编辑器 · `tools/tilemap/` 瓦片地图 · `tools/sprite-rigger/` 绑骨
- `scripts/autoload/dev_tools.gd` 游戏内实时调参（F1 调参 / F3 透视；手机左上角按钮）
- `scripts/enemy.gd` 敌人基类（多招组合 + AI 选招 + `tunables()`）
