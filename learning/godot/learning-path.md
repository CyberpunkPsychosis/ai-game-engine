# 🟢 Godot 学习线

> 你**已经有一个 Godot 项目**了(`claude/game-engine-claude-chat-mbKeN` 分支),
> 这是最大优势:不用从零,直接拿现成项目当练手沙盒,最快见效。

## 为什么 Godot 适合你
- **完全免费、开源**,无授权/订阅烦恼,体积小、启动快。
- **对新手和 AI 都友好**:GDScript 像 Python,好读好改,AI 帮你写也清晰。
- 你已有验证过手感的项目,**沉没成本最低**。

## 安装(5 分钟)
1. 去 [godot官网下载](https://godotengine.org/download) —— 选 **Godot 4.x Standard 版**
   (不用 .NET/C# 版,你的项目是 GDScript)。
2. 解压即用,无需安装。打开后 **Import** 你 clone 下来的项目里的 `project.godot`。

## 学习资源(按顺序)
1. **官方入门**(最权威,先做这个):
   [Godot 官方文档 · Your first 2D game](https://docs.godotengine.org/en/stable/getting_started/first_2d_game/index.html)
   —— 手把手做一个完整 2D 躲子弹小游戏,2–3 小时,**强烈建议照着敲一遍**。
2. **GDQuest**(质量最高的 Godot 教程团队,很多免费):
   [GDQuest 官网](https://www.gdquest.com/) / 他们的 YouTube 频道。
3. **官方 step-by-step 脚本教程**:
   [GDScript 基础](https://docs.godotengine.org/en/stable/getting_started/step_by_step/scripting_first_script.html)

## 怎么用你现有项目练手(关键)
你的项目里有现成的好东西可以"拆开学":
- `scripts/enemy.gd` —— 敌人基类,看 AI 怎么选招、`tunables()` 怎么暴露可调参数。
- `scripts/state_machine/` —— 状态机,游戏角色逻辑的核心模式,值得吃透。
- `scripts/touch_controls.gd` —— 输入处理。
- 游戏内按 **F1 调参 / F3 透视**(`scripts/autoload/dev_tools.gd`),边玩边改数值找手感。

**练手建议**:
- [ ] 先跑起来,玩一玩,按 F1 乱拖滑块看数值怎么影响手感。
- [ ] 试着改 `enemy.gd` 里一个数值(比如移速),保存,再玩,感受改动。
- [ ] 用你之前做的"怪物导演"网页工具画一段路线,自己动手在 Godot 里实现这只怪
      (实现不了的部分再让 AI 帮——但**先自己试**)。

## 里程碑
- [ ] 独立跑完官方 2D 教程
- [ ] 读懂自己项目里的 `enemy.gd` 大致逻辑
- [ ] 独立改出一个能看出区别的改动并玩到
- [ ] 独立实现一只简单的怪(走过来打你)
