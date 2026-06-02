# AI Game Engine — 2D 横版动作游戏

用对话驱动开发的 2D 横版像素动作游戏（目标平台：PC，键鼠 + 手柄）。
引擎：**Godot 4.5**（开源）。最终产品是 **Steam 原生 PC 版**；网页版仅作快速试玩预览。

## 当前进度
- ✅ 工程骨架 + 角色控制器（移动 / 跳跃，色块占位，美术待定）
- ✅ 手感系统：可变跳跃高度、土狼时间、跳跃缓冲、上升/下落分离重力
- ✅ 键盘（WASD + 方向键）+ 手柄输入
- ✅ 自动交付管线：网页版（GitHub Pages）+ Windows exe（CI 工件）
- ⬜ 近战战斗 + 受击反馈 + 敌人（下一步）

## 操作
| 动作 | 键盘 | 手柄 |
|------|------|------|
| 移动 | A/D 或 ←/→ | 左摇杆 / 十字键 |
| 跳跃 | 空格 / W / ↑ | A |
| 攻击 | J / 鼠标左键 | X |

## 两种试玩方式（都不需要本地安装 Godot）
1. **网页版（日常快速看效果）**：CI 自动部署到 GitHub Pages，浏览器点链接即玩。
2. **Windows exe（调真手感 / 即上架版本）**：在 Actions 运行页下载 `AIGameEngine-Windows` 工件，解压双击运行。

> 启用网页链接：仓库 Settings → Pages → Source 选 **GitHub Actions**（一次性设置）。

## 手感调参
所有手感参数都在 `scripts/player.gd` 顶部、并暴露在 Godot Inspector：
最大速度、加速度、摩擦、跳跃初速、上升/下落重力、跳跃截断、土狼时间、跳跃缓冲等。

## 工程结构
```
project.godot          引擎配置 + 输入映射
icon.svg               图标
scenes/main.tscn       测试关卡（地面/墙/三层平台）
scenes/player.tscn     角色（CharacterBody2D + 相机）
scripts/player.gd      角色控制器（手感参数都在这）
export_presets.cfg     Web + Windows 导出预设
.github/workflows/     CI：自动导出并部署
```

## 本地运行（可选，仅当你想自己跑）
装 Godot 4.5 后：`godot --path .`（或编辑器里打开按 ▶️）。
