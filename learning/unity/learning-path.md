# 🔵 Unity 学习线

## Unity vs Godot,先帮你想清楚再学
| 维度 | Unity | Godot |
|---|---|---|
| 价格 | 个人版免费,有营收门槛/授权条款 | 完全免费开源,无任何条款 |
| 资料/教程 | **极多**(全网最多),招聘需求大 | 较多,增长快 |
| 上手难度 | 中(功能多,菜单复杂) | 低(轻量,直观) |
| 语言 | C#(强类型,工程化好) | GDScript(像 Python,易上手) |
| 体积/启动 | 大(装好几个 G) | 小(几百 M,秒开) |
| AI MCP | **官方+社区 MCP 成熟**,AI 能直接操作编辑器 | 也有社区方案,但不如 Unity 成熟 |
| 你的现状 | 要从零起 | **已有项目,沉没成本最低** |

> **建议**:如果只是想"尽快独立做出游戏"——主攻 Godot。
> 如果看重"资料最多 / 将来想用 Unity MCP 让 AI 直接操控编辑器 / 偏向就业"——主攻 Unity。
> **别两个同时猛攻**,先把一个学到能独立做出小游戏。

## 安装(自己电脑上)
1. 下 [Unity Hub](https://unity.com/download) —— 它是管理 Unity 版本/项目的入口。
2. 在 Hub 里装一个 **LTS 长期支持版**(比如 Unity 6 LTS),装的时候勾上
   **WebGL / Windows Build Support** 等你需要的平台。
3. 注册免费 Unity 账号(个人版免费)。
4. New Project → 选 **2D (URP)** 模板,开整。

## 学习资源(按顺序)
1. **Code Monkey · Unity 2D 完整免费课 2025**(首选,5.5 小时做完整游戏,带工程文件):
   [Class Central 收录页](https://www.classcentral.com/course/youtube-learn-unity-2d-beginner-free-complete-course-unity-tutorial-2025-474791)
   / 直接搜 YouTube "Code Monkey Learn Unity 2D"。
2. **Unity Learn 官方平台**(免费,项目化):
   [Beginning 2D Game Development](https://learn.unity.com/course/beginning-2d-game-development)
   · [2D Beginner: Adventure Game](https://learn.unity.com/course/2d-beginner-adventure-game)
3. **课程精选榜单**(挑适合自己的):
   [Class Central · 2026 最佳 Unity 课程](https://www.classcentral.com/report/best-unity-courses/)

## C# 基础(Unity 用 C#,值得补一点)
- 不用先学完 C# 再学 Unity,**边做边补**即可。
- 需要系统补时:微软官方 [C# 入门](https://learn.microsoft.com/dotnet/csharp/) 免费。

## 里程碑
- [ ] 装好 Unity Hub + 一个 LTS 版本,建出第一个 2D 工程
- [ ] 跟 Code Monkey 课做出一个能玩的完整小游戏
- [ ] 看懂 Scene / GameObject / Component / Prefab 这几个核心概念
- [ ] (进阶)按 [`setup-unity-mcp.md`](./setup-unity-mcp.md) 搭通 Unity MCP,
      让 AI 帮你直接在编辑器里操作
