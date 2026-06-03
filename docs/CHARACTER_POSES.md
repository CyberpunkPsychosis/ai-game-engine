# 战斗角色「姿势 + 绑骨」生产规格

> 目标：云 AI 出**关键姿势** → Claude 对齐/绑骨/补间成动画 → 接进游戏。
> 你只负责"按规格生成 + 上传"，其余我来。

---

## 0. 推荐工具（无 GPU，云端）
- **Scenario.gg（首选）**：先用几张参考图**训一个你自己的角色模型**，再配 **ControlNet / OpenPose** 按指定姿势出图。一致性最强，有 API、支持透明底/精灵表。
- 备选：Leonardo.ai（可训风格 + 出图）。
- **一致性三件套**（务必都用）：
  1. **训练角色模型**（或 IP-Adapter 锁定参考图）——保证每张都是"同一个角色"。
  2. **ControlNet OpenPose**——用火柴人姿势精确控制每个动作的 pose。
  3. **固定**：底模 / 风格提示词前缀 / 种子 / 画幅 / 角色大小。

---

## 1. 角色设定（贴合苔藓世界）
- **Viir，小林守**：矮个兜帽披风战士，手持一把**发光青绿色光刃（light-nail）**。
- 画风：手绘、生物荧光、顶部青绿冷光勾边（和 Mossy 世界一致），暗部偏冷。
- **侧视、面朝右**（统一！需要左向时我来镜像）。

---

## 2. 输出格式（硬性要求，做错我没法对齐）
- **透明背景 PNG**，**不要**烘焙地面阴影/光晕。
- **统一画幅**：建议 **512×512**，所有姿势同尺寸。
- **角色大小一致**：每张里角色高度占比尽量相同（约画幅的 70–80%）。
- **脚底对齐**：角色**双脚踩在同一条基线**上（建议画幅底部往上约 8%），这样我能按"脚底锚点"对齐，动画不会上下乱跳。
- **同一朝向、同一比例、同一光照方向**。
- 命名：`动作_序号.png`（见下）。

---

## 3. 要生成的姿势清单（关键帧，少而精）
> 空洞骑士每个动作其实就 3–4 帧。先做下面这些就能打。

| 动作 | 文件名 | 张数 | 姿势要点 |
|---|---|---|---|
| 待机 | `idle_1..2` | 2 | 轻微呼吸，重心微沉 |
| 跑 | `run_1..4` | 4 | 接触/腾空/交叉 4 拍 |
| 起跳 | `jump_1` | 1 | 蜷腿向上 |
| 下落 | `fall_1` | 1 | 伸腿、披风上飘 |
| **平砍·蓄力** | `atk1_1` | 1 | 光刃后举、身体后扭 |
| **平砍·挥出** | `atk1_2` | 1 | 光刃水平劈出、前冲、手臂全伸 |
| **平砍·收招** | `atk1_3` | 1 | 收刀、惯性前倾 |
| 上挑 | `up_1..2` | 2 | 光刃上扬挑空 |
| 下劈/踏弹 | `down_1..2` | 2 | 光刃朝下、用于 pogo 弹跳 |
| 冲刺 | `dash_1` | 1 | 前倾拉长、披风后扯 |
| 受击 | `hurt_1` | 1 | 后仰、缩身 |
| 施法 | `cast_1..2` | 2 | 举刃蓄光（接孢爆） |
| 倒下 | `death_1..2` | 2 | 跪下/化光消散 |

（先做 **idle / run / jump / fall / 平砍3张 / 下劈 / 冲刺 / 受击**就能玩出 HK 味，其它后补。）

---

## 4. 提示词模板
**风格前缀（每张都加）：**
```
hand-painted 2D game character, small hooded caped warrior holding a glowing
teal energy blade, bioluminescent rim light, cool dark palette, side view facing
right, full body, centered, feet on bottom baseline, transparent background,
consistent proportions, no ground shadow, game sprite
```
**每个姿势在前缀后追加 pose 描述，例如：**
- `atk1_2`：`mid horizontal slash, blade fully extended forward, body lunging forward, cape trailing back`
- `down_1`：`pointing blade straight down, diving pose, for a downward pogo attack`
- `run_2`：`running mid-stride, airborne frame, legs spread`

**强一致性做法**：每个动作先画一张 **OpenPose 火柴人**控制姿势，配上训练好的角色模型 + 上面前缀，逐张生成。

---

## 5. 你做完后怎么交给我
1. 按 `动作_序号.png` 命名（如 `atk1_2.png`）。
2. 用上传页传到 `incoming/`（一folder 或一批都行）。
3. 回聊天说"姿势传好了"。

## 6. 然后我做什么
- **自动对齐**：按脚底锚点统一位置/尺寸 → `assets/char/viir/`。
- **绑骨 / 补间**：把关键姿势接成动画（平砍 = 蓄力→挥出→收招 + 大月牙斩 + 顿帧/击退/镜头）。
- **接状态机**：idle/run/jump/fall/attack/dash/hurt 自动切换，连进现有连招与敌人系统。
- 出预览给你看，再一起调手感。
