# 搭建 Unity MCP — 让 AI(Claude)直接操作 Unity 编辑器

> **Unity MCP 是什么**:一个 MCP 服务器,在你的 Unity 编辑器和 AI 助手(Claude Code / Cursor 等)
> 之间架一座桥。装好后,AI 能**直接帮你建场景、摆物体、改组件、写 C# 脚本、跑测试、出包**,
> 而不只是给你贴代码让你手动粘。

> ⚠️ **必须在你自己的电脑上做**(要有图形界面的 Unity 编辑器)。云端无界面环境跑不了 Unity。
> 本文件是给你照着做的指南,不是已经跑起来的东西。

## 前置条件
- 已装好 **Unity Hub + 一个 Unity 编辑器版本**(见 `learning-path.md`)。
- 已装好 **Claude Code**(或 Cursor / 你用的 AI 客户端)。
- 一个 Unity 项目(随便建个 2D 工程练手即可)。

## 选哪个 Unity MCP?
2026 年有几个成熟方案,都免费:

| 方案 | 特点 | 链接 |
|---|---|---|
| **官方 Unity MCP** | Unity 6 起内置,Pro/企业版自带;最省心 | [官方文档](https://docs.unity3d.com/Packages/com.unity.ai.assistant@2.0/manual/unity-mcp-overview.html) |
| **CoplayDev/unity-mcp** | 社区最活跃,文档全,对接 Claude 友好 | [GitHub](https://github.com/CoplayDev/unity-mcp) |
| **IvanMurzak/Unity-MCP** | 明确支持 Claude Code,有 CLI 一键装,一行把任意 C# 方法变工具 | [GitHub](https://github.com/IvanMurzak/Unity-MCP) |
| **AnkleBreaker/unity-mcp-server** | 268 个工具,覆盖 Shader Graph/地形/物理/动画 | [GitHub](https://github.com/AnkleBreaker-Studio/unity-mcp-server) |

**新手推荐**:先用 **CoplayDev** 或 **IvanMurzak**(社区方案,免费、文档清楚)。

## 通用安装步骤(以社区方案为例)
> 具体命令以对应 GitHub 仓库 README 为准(版本会更新),这里讲思路:

1. **在 Unity 里装 MCP 包**
   Unity 编辑器 → `Window > Package Manager` → 左上 `+` → `Add package from git URL`
   → 粘贴对应仓库 README 给的 git URL。装完菜单里会多出一个 MCP/AI 相关入口。

2. **启动 MCP 桥接**
   按该仓库说明在 Unity 里打开 MCP 窗口/启用 Server。Unity 一开,它会自动开一个本地通道
   (Windows 命名管道 / macOS·Linux Unix socket),等 AI 客户端来连。

3. **在 Claude Code 里注册这个 MCP 服务器**
   见下方配置示例。配好后 Claude Code 启动时就能连上 Unity。

4. **验证**:在 Claude Code 里说"列出当前 Unity 场景里的物体",能返回 = 通了。

## Claude Code 配置示例
Claude Code 用项目根目录的 `.mcp.json`(或全局配置)注册 MCP 服务器。**确切的 command/args
以你选的仓库 README 为准**,典型形态长这样:

```jsonc
// .mcp.json (放在你的 Unity 项目根目录)
{
  "mcpServers": {
    "unity": {
      "command": "uvx",              // 或 npx / dotnet,看具体方案
      "args": ["unity-mcp-server"],  // 占位:换成该仓库给的实际启动命令
      "env": {}
    }
  }
}
```

或用命令行注册(Claude Code 自带 `claude mcp add`):
```bash
# 形态示意,实参看仓库 README
claude mcp add unity -- <该方案给的启动命令>
# 查看是否注册成功
claude mcp list
```

> 注:有的方案(如 IvanMurzak)提供 **CLI 一键 setup**,会自动帮你写好这些配置——优先用它的 CLI。

## 跑通后能让 AI 做什么(举例)
- "在当前场景建一个 Player,加上 Rigidbody2D 和我的移动脚本"
- "帮我把这 8 张图配成一个 walk 动画 Animator"
- "给场景里所有敌人加上一个掉血组件"
- "导出一个 WebGL 包"

## 重要提醒
- **MCP 是加速器,不是替你学**。先自己会手动操作 Unity,再用 MCP 才知道它做得对不对。
- AI 操作编辑器有时会改错,**养成提交 git / 多存档的习惯**,方便回退。
- 不同方案更新快,**一切以你选的那个仓库最新 README 为准**,本指南只给框架。
