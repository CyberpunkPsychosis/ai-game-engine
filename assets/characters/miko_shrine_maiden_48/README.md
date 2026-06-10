# miko_shrine_maiden_48 — 时停巫女(新主角候选, Scenario API 实验)

世界观: 「刹那/timestop」神社 — 白衣绯袴巫女 + 青色冰霜刀(冷凝界/暖生命双色组)。

## 生成管线(Scenario API, 共 52 CU)
1. 概念图: `POST /v1/generate/custom/model_bfl-flux-2-klein-9b-base`
   - loras: ["model_GH95njeQLz1UGf3HLyZuZDxw"] (刹那风格 LoRA), lorasScale: [1.0]
   - 1024x1024 x2 张, 22 CU → `concept/`
2. 动画: `POST /v1/generate/custom/model_retrodiffusion-animation`
   - style=walking_and_idle (48x48 固定), image=概念图 asset 引用
   - GIF 输出 44 帧 = 4 方向 x (4 帧 idle + 7 帧 walk), 15 CU/次
   - 注意: returnSpritesheet=true 只会打包 16 格行走帧, **idle 只在 GIF 里**

## 文件
- `strips/idle_{south,east,north,west}_strip.png`: 各向 4 帧 idle 横条(48x48/格)
- `strips/walk_{...}_strip.png`: 各向 7 帧行走横条
- `walk_4dir_sheet_4x4.png`: 行走 4x4 网格表(独立生成, 绯袴配色略不同)
- `source_44frames.gif`: 原始 44 帧输出
- 建议播放: idle 4-6fps, walk 8-10fps; 横版用 east/west 条
