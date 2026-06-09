# 重开须知 · RESTART（仓库清理记录）

记录**当前保留了什么、删了什么、踩过的坑**。被删的游戏都在 git 历史里，`git log` 能找回。

## 历次清理

### 2026-06 · 收敛到单一游戏「刹那 TimeStop」
做过 3 个游戏，**只留第 3 个**，前两个删除（仍在 git 历史）：
1. ~~横版弹反动作（类 Sekiro）~~ —— 已删（`scenes/`、`scripts/` 根下角色脚本、`art/` 角色、`assets/packs|tilesets`）
2. ~~土豆兄弟 / Survivor（俯视角幸存者）~~ —— 已删（`scripts/survivor`、`scenes/survivor`、`assets/survivor`）
3. **刹那 TimeStop（时间定格横版）** ← 保留，当前唯一在做。见 `docs/TIMESTOP.md`

## 仓库现在保留的
- **游戏本体** `timestop/`（纯代码驱动：game/player/enemy/bullet/fx + postprocess.gdshader + main.tscn）
- **公用框架** `scripts/autoload/`：`GameManager`(暂停) `SceneManager`(切场景) `AudioManager`(SFX/音乐)
  `Juice`(顿帧/震屏) `DevTools`(实时调参) `FX`(闪白/序列帧/火花/音效钩子)
- `scripts/sprite_sheet.gd`：精灵表→SpriteFrames 切片器（**FX 依赖，勿删**）
- `shaders/flash.gdshader`、`art/fx/`、`assets/sfx/`：**FX 依赖资源，勿删**
- `fonts/zpix.ttf`：像素中文字体
- **工具** `tools/`：`sprite-keyer`(手机网页:选帧/抠图/对齐/导横条,当前主力) `enemy-designer` `composer` `tilemap` `sprite-rigger`
- **构建/配置**：`.github/workflows/build.yml`(CI 导出网页版到 Pages)、`export_presets.cfg`、`project.godot`、`.mcp.json`
- **文档** `docs/`：`TIMESTOP.md`(当前游戏) `SPRITE_PIPELINE.md`(选帧/抠图/对齐) `CLOUD_WORKFLOW.md`(出素材流程) `AI_TOOLS.md` `ASSET_SOURCING.md` `LUDO_MCP.md` `LEARN_GODOT.md` 本文件

## 删除后必做（经验）
- 删脚本可能连累**保留的 autoload**（如 `FX` 用 `SpriteSheet`）→ 删完**务必 headless 自测**：
  ```bash
  GODOT=/tmp/godot_bin/Godot_v4.5-stable_linux.x86_64
  "$GODOT" --headless --import && "$GODOT" --headless --path . --quit-after 180 2>&1 \
    | grep -iE "SCRIPT ERROR|Parse Error|Failed to load"
  ```
- 删/恢复脚本后类名缓存会过期 → 先 `--import` 刷新全局 class 注册再跑。

## 通用结论（仍然有效）
- **引擎/手感不是瓶颈**：移动/连招/顿帧/震屏/命中特效/敌人/后处理都验证能做好。
- **难点在 AI 出素材的一致性**：一致性 > 帧数 > 画质。锁角色（训模型/参考图/调色板/固定种子）、统一格式。
  注：游戏原生模型（Retro Diffusion / Scenario 训练）效果远好于通用模型，但需 Scenario **Pro** 套餐。
- **"华丽"主要来自系统+运动+Juice+特效**，不是堆动画帧。
- **音效是最便宜的手感放大器**：`assets/sfx/<name>.wav` 丢进去即响（`FX.sfx("hit")`）。
