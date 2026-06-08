# 刹那 TimeStop — 时间定格 2D 横版动作

对话驱动开发的 2D 横版动作游戏。引擎：**Godot 4.5**。
一句话：**实时快打 + 随手冻结单体 + 绝境全场定格翻盘。**

> 新会话/接手请先读 **`CLAUDE.md`** 和 **`docs/TIMESTOP.md`**。

## 核心机制
- **冻结时间**（共用一条能量条）：
  - 轻档 **冻单体**（K / 瞄准）：冻住一个敌人或子弹 ~2.6s，花 18 能量。
  - 重档 **全场定格**（L）：攒满 100 能量放，全场凝固 ~3s，绝境翻盘。
- **能量靠进攻攒**：命中 +8、击杀 +28（逼你压上）。
- **闪避 DASH**（C）：0.22s 冲刺 + 全程无敌帧（穿怪穿弹），带拖影。
- **敌人三型**：冲锋 / 远程弹幕 / 治疗。波次导演自动刷新。
- 技术亮点：统一时间系统（冻结/定格/顿帧同一套底层）、全屏后处理 shader（GL/Web 安全）、打击感三件套。

## 操作
- **电脑**：A/D 移动 · 空格 跳 · J 砍 · K 冻单体(瞄鼠标) · L 全场定格 · C 闪避 · R 重开
- **手机（横屏）**：左下虚拟摇杆 + 右下 `HIT/JUMP/FRZ/DASH/STOP`

## 试玩
- **网页版**：CI 自动部署到 GitHub Pages（根地址），浏览器直接玩。
- **本地**：装 Godot 4.5 → `godot --path .`（或编辑器打开按 ▶️）。

## 工程结构
```
project.godot          引擎配置 + 输入映射（main_scene → timestop/main.tscn）
timestop/              游戏本体（game/player/enemy/bullet/fx + postprocess.gdshader）
scripts/autoload/      公用框架（暂停/切场景/音频/震屏/调参/特效）
shaders/ art/fx/ assets/sfx/   FX 依赖资源
fonts/zpix.ttf         像素中文字体
tools/                 网页辅助工具（AI 出素材 / 编辑器）
docs/                  文档（TIMESTOP 当前游戏 + AI 出素材工作流）
.github/workflows/     CI：导出网页版部署到 Pages
```

> 美术暂用色块占位（先验证机制）。历史上做过另两个游戏（横版弹反、土豆兄弟），已废弃，详见 `docs/RESTART.md`。
