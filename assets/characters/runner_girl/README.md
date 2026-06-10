# runner_girl — 奔跑循环动画

从上传视频 `21e0ebe2-run.mp4` 提取的可循环奔跑动作，已去除白色背景（含地面软阴影），透明 PNG。

- **循环**：20 帧 = 1 个完整跑步循环（左右脚各一步），24fps 播放约 0.83s/圈，首尾无缝衔接
- `frames/run_01.png … run_20.png`：全分辨率逐帧（821x1026，RGBA）
- `run_sheet_10x2_half.png`：精灵表，10 列 x 2 行，半分辨率（每帧 410x513）
- `animation.json`：引擎用元数据（帧序、fps、sheet 切片参数）
- `run_preview.gif` / `run_preview_transparent.gif`：1/3 缩放预览

所有帧使用统一画布裁剪，角色对齐一致，可直接按固定锚点播放。
