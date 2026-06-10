# runner_girl — 奔跑循环动画 (v2, ML 抠图重制)

从上传视频 `21e0ebe2-run.mp4` 提取的可循环奔跑动作。v2 用 isnet-anime ML 模型重新抠图,
修复了 v1 简单洪水填充的问题(运动模糊帧鞋子缺损、边缘灰白描边、地面阴影闪烁)。
管线脚本: `tools/video2sprites.py`,实践记录: `docs/ai-asset-pipeline.md`。

- **循环**: 20 帧 = 1 个完整跑步循环(左右脚各一步), 24fps 约 0.83s/圈, 首尾无缝
- `frames/run_01.png … run_20.png`: 全分辨率逐帧 (819x1022, RGBA, 软边缘 alpha)
- `run_sheet_10x2_half.png`: 精灵表 10 列 x 2 行, 每帧 409x511
- `animation.json`: 引擎元数据(帧序、fps、sheet 切片参数)
- `run_preview.gif` / `run_preview_transparent.gif`: 1/3 缩放预览

地面软阴影已去除(各帧不一致会闪烁),建议引擎内用 blob shadow。
