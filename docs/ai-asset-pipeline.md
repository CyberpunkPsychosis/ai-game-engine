# AI 生成游戏素材动画 — 管线最佳实践

基于 runner_girl 奔跑动画的实战记录 + 2026 年业界调研。可复用脚本见 `tools/video2sprites.py`。

## 总体流程

```
角色概念图(AI image gen, 锁定风格/调色板)
  → AI 视频生成动作片段(4-6s, 纯色背景, 原地动作)
  → 自动检测循环周期, 截取一个完整 cycle
  → ML 抠图(逐帧) + alpha 后处理
  → 统一裁剪对齐 → 精灵表/逐帧 PNG + 元数据
  → 引擎内试播 + 人工 QA(必不可少)
```

## 1. 生成阶段:让后处理少踩坑

- **纯白或纯色背景**、角色居中、**原地**做动作(跑步机式),后面对齐就是免费的。
- 片段长度 4-6 秒,保证至少 4-6 个完整循环可供挑选首尾衔接最好的一段。
- 锁定角色一致性:同一概念图驱动视频生成;批量生产时业界普遍用 5-15 张参考图
  训练角色 LoRA/custom model,保证比例、配色、风格跨动作一致。

## 2. 循环检测:别靠肉眼数帧

- 帧间自相关:对每个候选周期 k,算所有 `|frame[i] - frame[i+k]|` 的均值,最小者即周期。
- **坑:半周期陷阱**。跑步/走路左右脚近似镜像,k=半周期的分数也很低
  (本素材 k=10 与 k=20 都是低分,真周期是 20)。分数接近时取大的 k。
- 起始帧选 `|frame[s] - frame[s+k]|` 最小的 s,循环无缝。

## 3. 抠图:简单方法的坑 vs ML 模型

### 实测踩过的坑(简单阈值/洪水填充)

| 问题 | 原因 |
|---|---|
| 运动模糊帧肢体被吃掉(鞋只剩碎片) | cv2.floodFill 默认**浮动范围**,沿模糊渐变一路爬进前景;就算用 `FLOODFILL_FIXED_RANGE`,半透明模糊区也无法用二值决策正确表达 |
| 暗背景下灰白描边(halo) | 软反走样边缘被二值化,背景色混进边缘像素;1px 腐蚀+模糊治标不治本 |
| 地面软阴影残留碎块 | 阴影到背景是渐变,任何阈值都会切在半路 |

**结论:AI 生成视频普遍带软边缘+运动模糊,二值抠图必翻车,直接上 ML matting。**

### 模型选型(2026)

| 模型 | 适用 | 备注 |
|---|---|---|
| **rembg isnet-anime** | 动漫/卡通角色 | 本管线采用;锐利线条+平涂色优化,20 帧 CPU 约 30s |
| BiRefNet | 写实/复杂边缘(发丝、毛发) | 边缘保真度最高,较慢;rembg 简单方法会丢约 40% 细发丝 |
| SAM2/3 | 多目标、需要交互指定 | 点/框提示式,适合"画面里有多个东西只要其中一个" |
| RVM / MatAnyone | 真人视频 | 循环网络利用时序信息防闪烁,但**只针对真人**,动漫无效 |

### alpha 后处理(必做)

1. **alpha 曲线重映射**:isnet 输出的"实心"区域 alpha 普遍只有 170~250,
   引擎里角色会整体半透明。`a' = clip((a-30)/(210-30))`,实心拉满、边缘软过渡保留。
2. **地面阴影去闪烁**:saliency 模型只在阴影和脚接触时把它当前景,
   触地帧有阴影、腾空帧没有 → 循环播放疯狂闪烁。要么全删要么全留;全删做法:
   采样阴影像素的 HSV 分布做色相键控(本素材阴影 H165-168 与正红色鞋 H176+ 完全分离),
   再删灰褐描边残留 + 完全位于地面区的孤立连通域。引擎里用 blob shadow 替代。
3. **QA 方法**:把结果合成到**暗背景和亮背景各看一遍**(白底看不出白边,黑底看不出黑边),
   放大 200-400% 重点检查发丝、披风、运动模糊最重的过渡帧。

## 4. 装配与交付

- 所有帧用**全循环并集 bbox** 统一裁剪 → 画布一致、锚点天然对齐。
- 交付四件套:全分辨率逐帧 PNG(源)、精灵表(引擎用,可半分辨率)、
  `animation.json`(fps/帧序/sheet 切片参数)、GIF 预览(评审用)。
- 帧率:24fps/20 帧是"流畅动画"风;要更"游戏感"可隔帧取 10 帧按 12fps 播。
- 记录素材来源与许可(AI 生成也要留 prompt/模型/源视频备查)。

## 5. 工具生态速览(2026 调研)

- 一条龙 SaaS:Scenario、PixelLab、Ludo.ai、AutoSprite 等都是
  "图生视频→自动切帧→自动抠图→打包 sheet" 的封装,原理同上;
  自建管线(本仓库方案)胜在阈值可控、可批量、免费。
- 精修:Aseprite / Piskel,AI 出 20 个变体 → 人挑 → 像素编辑器修细节、统一调色板,
  是 2026 年独立游戏的主流组合;**生成的 sheet 不经人工 QA 不要直接进版本**。

## 参考来源

- [BiRefNet vs rembg vs U2Net 生产环境对比](https://dev.to/om_prakash_3311f8a4576605/birefnet-vs-rembg-vs-u2net-which-background-removal-model-actually-works-in-production-4830)
- [rembg(含 isnet-anime 模型)](https://github.com/danielgatis/rembg)
- [BiRefNet 评测](https://ice-ice-bear.github.io/posts/2026-04-15-birefnet/)
- [Robust Video Matting(真人视频时序一致抠图)](https://github.com/PeterL1n/RobustVideoMatting)
- [MatAnyone: Stable Video Matting](https://arxiv.org/html/2501.14677v1)
- [Cloudflare: 背景去除模型评测](https://blog.cloudflare.com/background-removal/)
- [Seeles: AI Sprite Sheet 实战工作流](https://www.seeles.ai/resources/blogs/how-we-create-ai-sprite-sheets)
- [Scenario: AI Sprite Generator 三种工作流](https://www.scenario.com/blog/ai-sprite-generator)
- [Gamelabs: AI 精灵表透明背景生成](https://gamelabstudio.co/blog/how-to-ai-spritesheet-transparency)
- [Sprite-AI: 2026 像素画生成器评测](https://www.sprite-ai.art/blog/best-pixel-art-generators-2026)

## 6. 视频模型抽卡实战补遗(闪避翻滚 4 抽记录)

**现象**: 视频模型(Seedance)对"人体倒转"有强烈先验抗拒。无论怎么用动作词措辞
(combat roll / shoulder roll / somersault / 详细解剖学描述), 贴地语境下都会被
"安全化"为下蹲前扑——角色埋头团身后腿永远不过头顶。空中语境(高跳)倒愿意翻转。

**破法: 物体运动隐喻**。把"她翻滚"改写成"她蜷成球, 球像轮子一样向前滚一整圈"
(curls into a tight ball ... rolls forward like a wheel turning one full revolution),
一发命中完整的背着地+腿过顶旋转。模型愿意滚一个球, 不愿意滚一个人。

**监工 SOP**: 每抽必须放大逐帧检查关键姿态(旋转类动作=找"倒立帧"), 缩略图会骗人;
不合格直接毙, 不要试图用烂底料做后处理补救(残影/特效救不了姿势)。
残影建议程序化合成(前N帧剪影偏移+主题色半透明), 比让模型烤进视频干净可控。

## 7. 出画问题(运动信封) — 长刀斩事故复盘

**现象**: 大幅度动作视频里角色/武器超出画框被裁(长刀斩 121 帧中顶部 13 帧、
左 21、右 22 帧触边; 跳跃视频顶部出画同病)。入库帧若触边, 衣袖/刀尖即带着
隐性缺损(小尺寸下不易察觉)。

**根因**: 不是 API 参数错 — 是**隐性参数**: 参考图构图与动作运动信封不匹配。
实测参考图角色占画面 91% 高、顶部余量仅 5%; 举刀过头需要约半身位头顶空间。
cameraFixed=true(管线必需, 保对齐)使模型无法拉远补偿。

**预防三件套**:
1. 生成前估"运动信封": 举武器过头/跳跃/大跨步类动作, 参考图角色应 ≤60% 画面高,
   四周余量 ≥20%。现成概念图不必重画 — **垫大画布**(贴到更大的纯色背景中央)
   再喂 i2v, 零成本; Seedance 沿用首帧构图, 角色自动变小余量变大。
2. 生成后 QC 增加**触边检测**(自动化): 对每帧做背景差分, 统计画框四边行列的
   前景像素数, >阈值即触边帧, 选帧时禁用。
3. cameraFixed 永远保持 true, 余量只能在源头给。

**遗留**: 现行 attack strip 的 f60/89/96 带侧边裁切(已知缺陷, 80px 下不可见);
下次重做攻击时用垫大画布方案根治。
