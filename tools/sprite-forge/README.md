# Sprite Forge —— 一张参考图 → 一整套一致的动作序列帧

把"嘴说不清、AI 逐帧又乱漂"的怪物动画，用 **2026 主流验证过的「整表一次生成」法**稳定做出来。

## 它解决什么

逐帧 / 文字驱动的 AI 动画会 **"漂"**：每帧角色都变样（脸、比例、武器都跳）。
本工具改用 **一次性整表生成**：让一个多模态模型（GPT Image 2 / Gemini 3.1）**一次输出
一整张排好网格的精灵表**——因为所有帧来自单次生成，**帧间天然一致**。动作再交给确定性
后期（抠绿幕 + 按网格切帧 + 脚底对齐），稳。

## 配方（工具自动跑完这四步）

1. 参考角色图 → 上传 Scenario
2. GPT Image 2 / Gemini 3.1：一次出「绿幕 `#00FF00` + N 帧网格」精灵表
3. 抠绿 → 按网格切帧 → 脚底对齐
4. 产出：透明底单帧 + 引擎就绪等格精灵表 + 预览 GIF + `frames.json`

## 准备

```bash
pip install Pillow numpy
# 鉴权只读环境变量，绝不写进仓库：
export SCENARIO_AUTH_B64=<apikey:secret 的 base64>
# 或分开给：
export SCENARIO_API_KEY=api_xxx
export SCENARIO_API_SECRET=xxx
```

## 用法

```bash
# 1) 先估成本（不扣费）
python3 tools/sprite-forge/sprite_forge.py \
    --ref incoming/monster.png --desc "a red horned demon brute holding an axe" \
    --action "melee axe attack" --frames 6 --dry-run

# 2) 正式出图
python3 tools/sprite-forge/sprite_forge.py \
    --ref incoming/monster.png --desc "a red horned demon brute holding an axe" \
    --action "melee axe attack" --frames 6 --name demon_attack \
    --model gpt-image-2 --out out/demon_attack

# 3) 只对已有整表重新切帧（不花钱，调切帧参数用）
python3 tools/sprite-forge/sprite_forge.py \
    --process-only sheet.png --cols 3 --rows 2 --name demon_attack --out out/demon_attack
```

## 常用参数

| 参数 | 说明 |
|---|---|
| `--ref` | 参考角色图（**透明底 / 侧视朝右**效果最好） |
| `--desc` | 角色描述，**英文更准** |
| `--action` | 动作：`"melee axe attack"` / `"walk cycle"` / `"hurt reaction"` / `"death"` |
| `--frames` | 帧数（默认 6）。网格按帧数推断：4→2×2，6→3×2，9→3×3，12→4×3… |
| `--cols/--rows` | 手动指定网格 |
| `--beats` | 逐帧动作描述，分号分隔（更可控）：`"idle;wind-up;peak;strike;follow;recover"` |
| `--model` | `gpt-image-2`（默认，质感强）或 `gemini`（便宜） |
| `--quality` | 仅 GPT：`high/medium/low/auto` |
| `--name` `--out` | 输出前缀 / 目录 |

## 成本（CU，会扣 Scenario 额度）

| 模型 | 一张整表（1536×1024） |
|---|---|
| GPT Image 2（high） | ~48 CU |
| **Gemini 3.1** | **~13 CU**（批量推荐） |

`--dry-run` 永远先估价不扣费。

## 产出

```
out/demon_attack/
  demon_attack_sheet.png     # 引擎就绪：等格横排精灵表（透明底）
  frames/demon_attack_0..N.png  # 单帧（脚底对齐、透明底）
  demon_attack.gif           # 循环预览
  demon_attack_preview.png   # 接触表（棋盘底）
  frames.json                # 帧数/单帧尺寸/锚点/fps，供 Godot 加载器切片
```

`frames.json` 的 `anchor: bottom-center` 与 `tools/char_intake` 的脚底锚点约定一致，
可直接接角色/敌人加载器。

## 出好图的提示

- **一致性 > 帧数 > 画质**：先锁住"同一只怪"，再谈细节。
- 参考图用**干净的侧视单帧**最稳（朝右、透明底、脚底对齐）。
- 想更顺滑：`--frames 9`（3×3）或事后补间；想更"厚重"：6 帧关键姿势即可。
- 角色一致性不够时，可先用 Scenario 训一个角色模型再来出表（见 `docs/AI_TOOLS.md`）。
- GPT/Gemini 出不了透明底，所以走绿幕；本工具已自动抠绿+去绿溢。
