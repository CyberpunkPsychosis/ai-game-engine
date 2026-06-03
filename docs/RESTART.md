# 重开须知 · RESTART

阶段性验证结束后清场了。本文件记录**保留了什么、怎么快速重开、踩过的坑**。
（被删的游戏内容都在 git 历史里，`git log` 能找回。）

## 仓库现在保留的（框架 + 工具，不含具体游戏）
- **Godot 框架** `scripts/`
  - `autoload/`：`GameManager`(暂停) `SceneManager`(切场景) `AudioManager`(SFX/音乐)
    `Juice`(顿帧/震屏) `DevTools` `FX`(受击闪白/屏幕闪/溶解/音效钩子)
  - `components/`：`health` `hitbox` `hurtbox`
  - `state_machine/`：`state` `state_machine`
  - `shaders/flash.gdshader`：受击闪白着色器（FX 用）
- **工具** `tools/`
  - `uploader/`：手机上传页（把素材推进仓库 `incoming/`）
  - `composer/`：自由摆放式关卡编辑器（拖摆零件、景深视差、导出 scene.json）
  - `tilemap/`：瓦片地图编辑器（规整 tileset 刷格子、3 层 BG/主层(碰撞)/前景、导出 tilemap.json）
    · 单指画/擦、双指平移缩放；运行时待接成 Godot TileMapLayer（重开做新游戏时补）
  - `sprite-rigger/`：给角色立绘绑骨/标锚点
  - `char_intake/intake.py`：把"姿势_序号.png"按脚底锚点对齐入库
- **构建**：`.github/workflows/build.yml`（CI 导出网页版到 GitHub Pages）、`export_presets.cfg`
- **配置**：`project.godot`（输入映射 move/jump/attack/dash/special/move_down 已留）、`.mcp.json`(Ludo 本地用)
- **文档** `docs/`：`CHARACTER_POSES.md`(出姿势规格) `LUDO_MCP.md` `LEVEL_DESIGN.md` 本文件
- 主场景：空占位 `scenes/start.tscn`

## 重开一个新游戏的最短路径
1. **拿素材**：本地用 Ludo/画/买 → 传到 `incoming/`（上传页或 git）。
2. **入库**
   - 角色姿势：`python3 tools/char_intake/intake.py incoming/<folder> <name>` → `assets/char/<name>/`
   - 图集/序列帧：参考历史里的切片/打包脚本（`git log` 找 `slice`/`pack`）。
3. **角色控制器**：复用历史里的 `cyber.gd`/`hero.gd` 模式（CharacterBody2D + 状态机 +
   读 `anim.json` 建 SpriteFrames + 走/跑/跳/攻击 + FX/Juice）。
4. **关卡**：用 `composer` 编辑器拖出 `scene.json`（图层/视差/碰撞矩形/标记），
   或手写。运行时读 `scene.json` 生成世界（历史里的 `game.gd` 是范例）。
5. **主场景**：把 `project.godot` 的 `run/main_scene` 指向你的游戏场景。

## 素材规格（经验值，省额度）
| 动作 | 帧数 | 备注 |
|---|---|---|
| 跑 run | 6–8 | AI 帧越多越抖，少而准 |
| 待机 idle | 2–4 | |
| 跳/落 | 各 1–2 | |
| 攻击 attack | 3–5 | 蓄力→挥出→收招，命中只在中间帧 |
| 受击/死亡 | 2–3 / 4–6 | |

**格式**：透明底 PNG、统一画幅、**侧视朝右**、角色大小一致、**双脚踩同一基线**、
不烘焙地面阴影、命名 `动作_序号.png`。一张图一个姿势分开出。

## 踩过的坑 / 结论
- **引擎/手感不是瓶颈**：走跳冲刺、连招、挑空、果冻、顿帧、震屏、命中特效、敌人、
  视差、编辑器、运行时——都验证能做好。**给到素材就能接好。**
- **难点在 AI 出素材的一致性**：要"慢慢调"，逐动作生成、锁角色（训模型/参考图/固定种子）、
  统一格式。一致性 > 帧数。
- **画风要统一**：像素角色配手绘世界会违和；同一画风/或统一后处理。
- **"华丽"主要来自系统+运动+Juice+特效**，不是堆动画帧（空洞骑士也没几帧）。
- **音效是最便宜的手感放大器**：`assets/sfx/<name>.wav` 丢进去即响（hit/slash/dash/jump…）。

## 想做好"好玩"的关卡
见 `docs/LEVEL_DESIGN.md`（关卡设计入门 + 学习资源）。
