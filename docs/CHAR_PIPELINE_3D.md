# 角色 3D 中转管线 —— 用户手动操作手册(2026-06 定稿)

> **这是素材生产的主路线**:3D 中转 = 帧间一致性物理保证(同一个模型渲出来的帧不会漂移),
> 动作库复用 = 一个动作全角色通用。已实测验证(见 `AI_TOOLS.md` 实测结论、`incoming/guardian/`)。
> **分工**:本文档全部步骤=**用户手动操作**;最后把成品(精灵 sheet 或带动画 FBX)交给 Claude 入库接 Godot。

## 总流程图

```
【角色系统】                        【动作系统】
角色设计(立绘/捏人)                 Mixamo 动作库(免费几千个)
   ↓                                Cascadeur AI 生成动作(大招/特殊技)
生成 3D 角色                        DeepMotion 视频转动作(自拍→动作)
   ↓                                Rokoko 动捕(预算高再说)
统一 Humanoid 骨架                      ↓
   ↓                                统一成 Humanoid 动画
【角色库】 ←——— Blender Retarget ———→ 【动作库】
                    ↓
            角色 × 动作 自由组合
                    ↓
            固定镜头批量渲染(横版侧视)
                    ↓
            像素化处理
                    ↓
            Sprite Sheet ——→ 交给 Claude → Godot 接入
```

---

## 第一步:角色库

目标:女剑士 / 枪手 / 僵尸 / Boss / NPC……全部做成统一格式。

| 工具 | 适合 | 要点 |
|---|---|---|
| **VRoid Studio** ⭐推荐 | 日系/二次元/动漫风 | 免费;捏人(发型/眼睛/衣服/身材);导出 VRM;十几分钟一个角色 |
| **Meshy** | 写实/赛博朋克/欧美风 | 立绘 → Image to 3D → 自动 Rig → 导 FBX;几乎不用建模;二次元稳定性不如 VRoid |
| **腾讯混元 TokenHub** | 图生 3D(已实测✅) | `hy-3d-3.1` 质量好、日漫质感能带进 3D;你有额度;产出参考 `incoming/guardian/` |

**⚠️ 踩坑经验(实测)**:
- 喂 3D 的图必须 **T-pose / A-pose 正面图**(先用图生图把立绘转 T-pose)。
- **武器不要拿在手里**!绑骨算法明确要求"模型不含武器/坐骑/翅膀等"。收鞘背在背后勉强可以,
  最稳是**空手建模,武器单独做小模型挂手骨**(还能换武器)。
- 避免松散衣物、复杂发型(绑骨会乱)。

## 第二步:统一骨架(最重要)

所有角色都统一成 **Humanoid** 骨架(Head/Spine/UpperArm/LowerArm/UpperLeg/LowerLeg/Foot...),
动作才能跨角色共用。

**工具:Mixamo(免费)** — 上传角色 FBX → 自动识别关节(下巴/手腕/肘/膝/脚踝,拖几个点)→
几十秒出 Rigged.fbx。以后所有角色都过这一道。

> VRoid 导出的 VRM 要先转 FBX(Blender 装 VRM 插件导入再导出 FBX)。

## 第三步:建立动作库(系统的灵魂)

以后做游戏 = 不断往动作库加动作。

| 来源 | 适合 | 说明 |
|---|---|---|
| **Mixamo** | 基础动作 | Idle/Walk/Run/Jump/Roll/Hit/Death/Climb/Shoot/Sword Slash……几千个免费,够大部分游戏 |
| **Cascadeur** ⭐⭐⭐⭐⭐ | 特殊技能(居合斩/旋风斩/空中连击/Boss大招) | ①文字 AI 生成("A swordswoman performs a spinning slash")②手动摆关键 Pose,AI 补中间帧;自动修重心/惯性/平衡/落地;导出 FBX |
| **DeepMotion** | 视频转动作 | 自己录视频(拿扫把挥一下)→ 上传 MP4 → 动捕 → FBX。"自拍→游戏动作" |
| **Rokoko** | 专业动捕 | 格斗/武术/Boss演出;预算高再考虑 |

## 第四步:Retarget(动作重定向)

一个动作 → 所有角色通用:`SpinSlash.fbx`(女剑士的)retarget 后变成枪手/僵尸/Boss 的旋风斩,
不用重做动画。

**工具:Blender**
- **Auto-Rig Pro**(收费,业内好用)
- 或 Blender 自带 Retarget(免费,新版已经不错)

原理:动作骨架A → 映射 → 角色骨架B。

## 第五步:渲染成 2D(横版侧视)

固定正交镜头从侧面拍(角色朝→),Blender 批量输出 `run_001.png ... run_008.png`、
`attack_001.png ... attack_012.png`。

> 💡 **这步可以甩给 Claude**:渲染脚本已经趟通(相机跟踪骨盆=原地跑、灯光跟随、透明底、
> 自动找循环、拼横条,脚本在会话里随用随有)。你给**带动画的 FBX/GLB**,Claude 出 sheet。
> 想自己渲也行,注意:透明背景、正交相机、每个动作存独立序列。

## 第六步:像素化(像素风才需要)

```
Blender 渲染 512×512
  ↓ 缩小
64×64(Nearest Neighbor)
  ↓ 放大显示
游戏内 NEAREST 整数倍
  ↓ 限制调色板
32色 / 16色 → 像素 Sprite
```

> 💡 这步 Claude 也能代劳(PIL 脚本:缩放+色板量化)。

---

## 交付规格(给 Claude 时对照)

- 放进 `incoming/<角色名>/`(git push)或直接发文件
- **最省事**:带动画的 FBX/GLB(第四步产物),后面 Claude 全包
- **自己渲完**:透明底 PNG 横条,侧视**朝右**,每帧等宽等高,脚底同基线,一动作一条;
  附一句:动作名、帧宽×高、帧数、期望 fps(详见 `SPRITE_PIPELINE.md`)
- Godot 侧接入:`SpriteSheet.build_from_strips` → `player.set_sprite_frames`,十分钟的事

## 与游戏的对应关系(首发优先级)

1. 主角:Idle / Run / Jump / Fall / Attack(轻砍)/ Roll / Hit / Death
2. 之后:冻结特写、处决、爬墙(对应 player.gd 已有但停用的状态)
3. 敌人:每种 Idle / Move / Attack / Hit / Death 五件套
