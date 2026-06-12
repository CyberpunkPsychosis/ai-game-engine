# Ludo.ai MCP —— 本地使用说明

仓库根目录已配好 `.mcp.json`（项目级 MCP），接入 Ludo 的远程 HTTP MCP：
`https://mcp.ludo.ai/mcp`，鉴权头 `Authentication: ApiKey <key>`，密钥用环境变量
`LUDO_API_KEY` 注入（**不写死、不提交**）。

> ⚠️ 这个 MCP 只能在**你本地**的 Claude Code / Claude Desktop 用——
> 云端会话(claude.ai/code 这个环境)出站网络是白名单锁死的，连不到 ludo.ai。
> 所以：**本地用 Ludo 出素材 → 推到 `incoming/` → 云端会话负责入库/绑骨/接战斗**。

## 本地怎么用
1. 设置密钥（换成你的真实 key）：
   ```bash
   export LUDO_API_KEY=你的key
   ```
   （或写进本地 `~/.zshrc` / `.env`，别提交到仓库）
2. 在本机用 Claude Code 打开本仓库：
   ```bash
   claude
   ```
   首次会提示批准项目 MCP 服务器 `ludo`，同意即可。
   - 或用 CLI 直接加（等价）：
     `claude mcp add ludo https://mcp.ludo.ai/mcp -t http -H "Authentication: ApiKey $LUDO_API_KEY"`
3. 让本地 Claude 调 Ludo 生成素材（按 `docs/CHARACTER_POSES.md` 的姿势规格/提示词）。
4. 把产出的 PNG 放进 `incoming/`，`git push`（或用上传页）。

## 然后
- 你用 `tools/sprite-keyer` 选帧/抠图/对齐 → 导透明横条（见 `SPRITE_PIPELINE.md`）。
- 发我横条 → 我切帧 `set_sprite_frames` 接进游戏。

## 提示
- **关键角色姿势的一致性**：Ludo 出图也要锁住"同一角色"。能训练/参考锁定就锁定，
  并遵守 `CHARACTER_POSES.md` 的格式（透明底/512×512/侧视朝右/脚底基线/统一大小）。
- 杂项素材(道具/背景/灵感)用 Ludo 很方便；成套角色动画的一致性若不够，
  再考虑 Scenario 的"训练角色模型 + OpenPose 控姿势"。
