# 素材搜集指南（**当前主线**：买/找现成包）

> ✅ **这就是当前主线（2026-06 二次验证后）**：AI 出"角色精灵/动画"已确认是瓶颈（单图能用、帧间一致做不到，详见 `AI_TOOLS.md` 末尾「实测结论」），所以**角色素材走现成包 / 自己画**。
> 当前主角已换成 itch.io 的 **Mattz Art 免费武士包**（4 动作 idle/run/attack/hurt），就是这条路的落地。
> 找成品包时怎么搜、挑什么、授权怎么看，都在本文。
> ⚠️ 我断网,无法核对各站现状/链接;以下站点与作者均为业内常用,自行搜索访问。

## 0. 铁律
- **一致性第一**:优先找**同一作者的成套包**(角色+敌人+环境同风格),或 AI 训风格;别拼凑杂风。
- **必须带攻击/前摇帧**(弹反命根子):看预览有没有 idle/run/**attack/wind-up**/take-hit/death。
- **侧视 + 统一尺寸**(横版)。
- **能商用**(Steam 要上架):逐个看 license。

## 1. 去哪找(免费 + 付费)
| 站点 | 特点 |
|---|---|
| **itch.io** ⭐ | 像素素材大本营,海量免费+便宜,质量高。**首选。** |
| **CraftPix.net** | 免费+付费像素包,游戏就绪、成套 |
| **GameDev Market / Unity Asset Store** | 付费、游戏就绪、成套 |
| **OpenGameArt.org** | 全免费(CC),质量参差 |
| **Kenney.nl** | 免费,偏几何/UI/tileset,**适合灰盒原型**,非像素角色 |
| **Humble Bundle** | 偶尔有超值素材包 |

## 2. 推荐作者(同风格成套,省一致性功夫)
- **LuizMelo** ⭐(你用过的 Martial Hero 就是他)——一系列**同风格**角色(Martial Hero 1/2/3、Wizard、Huntress、Evil Wizard…),**全带 idle/run/jump/attack/take-hit/death、侧视**。
  → **可以一个人当主角、其它当敌人/Boss,直接一套风格统一!非常适合垂直切片起步。**
- **chierit** —— 动画精良的**Boss/敌人**包(带攻击/前摇),弹反敌人好用。
- **ansimuz** —— 成套**环境 + 角色**(Gothic/Warped/Sci-fi…),氛围统一。
- 其它:Penzilla、rvros、Pixel Frog、Szadi art、Brullov、0x72、Creative Kind 等。

## 3. 搜索关键词(英文更好搜)
- 主角/角色:`pixel art samurai/knight/warrior sprite sheet attack idle run`、`2D side scroller character animated`、`pixel hero attack death animation`
- 敌人/Boss:`pixel enemy pack animated attack`、`pixel art boss sprite sheet`、`2D enemy side view telegraph`
- 地形:`pixel tileset platformer`、`2D side-scroller tileset cave/castle/forest`
- 特效:`pixel slash effect`、`hit spark pixel vfx`、`pixel impact effect pack`
- UI:`pixel UI pack`、`pixel health bar`

## 4. 挑选清单(看预览时逐条对)
- [ ] **风格能和主角统一**?(成套最好)
- [ ] 有 **idle/run + 至少一个攻击 + 前摇(wind-up)+ 受击 + 死亡**?(弹反必须有攻击/前摇)
- [ ] **侧视朝右**、角色大小/画幅一致、脚底基本对齐?
- [ ] **license 能商用**?(免费商用/署名/付费),记下来源作者。
- [ ] 不是**扒别人成品游戏**的素材(侵权,Steam 会出事)。

## 5. 垂直切片"购物清单"(先只收这些 ⭐)
对应 `CAST.md` 的切片:
- **主角**:1 个带 idle/run/jump/闪避/攻击/**受击**/死亡 的角色(攻击帧用来做你的轻攻击;弹反/处决特效引擎加)。
- **敌人 ×2**:① 慢刀型(有明显前摇+挥砍)② 重击型(有蓄力大动作)——**前摇越夸张越好**。
- **Boss ×1**:带多段攻击的角色(可用 chierit 的 boss 包 / LuizMelo 的某角色充当)。
- **1 套 tileset**(一个生态区,规整瓦片,配 `tools/tilemap`)。
- (可选)特效/UI 包;大多特效引擎能做,先不急。
> **别一次收全套 8 个敌人 5 个 Boss**——先够切片,验证好玩了再扩。

## 6. 收完怎么交给我(引擎侧)
1. 下载解压 → 放进仓库 `incoming/`(上传页或 `git push`)。
2. 回会话说:"`incoming/xxx` 是主角/敌人/tileset,做进去"。
3. 我:切片入库 → 接角色控制器 / 敌人 AI / tileset 接关卡。
4. **每个角色记下作者/授权**,我建一个 `CREDITS.md`(Steam 上架要署名)。

## 7. 一致性兜底方案(找不到统一风格时)
- 用 **AI 训一个风格模型**,把找到的"定调那张"当参考,**把缺的角色补成同风格**(见 `CLOUD_WORKFLOW.md`)。
- 或后期**约一位像素美术**统一重绘关键角色(Steam 体量值得)。
- 灰盒阶段根本不需要美术——可以**先拿任意素材/方块把玩法做好**,美术后置。

## 8. 起步建议
**先去 itch.io 翻 LuizMelo 全家桶** → 选一个当主角、两三个当敌人/Boss,**一套风格直接齐活**,丢进 `incoming/`,我们就能搭出**有真攻击帧的弹反垂直切片**。
