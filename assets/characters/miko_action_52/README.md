# miko_action_52 — 时停巫女·动作版奔跑(死亡细胞风实验)

对标参考: 42x49px/19色/动作向跑姿。管线(共 112 CU):
1. 刹那 LoRA 出"侧面疾跑姿态"概念图(22 CU) — action_1/2.png
2. Seedance i2v 原地疾跑 5s 视频(90 CU, cameraFixed, 概念图为首帧) — source_video.mp4
3. 本地零成本: 17帧循环检测 → isnet-anime 抠图 → alpha重映射 → 均匀取8帧
   → INTER_AREA 缩到 52px → 联合 k-means 锁19色 → 硬边 → 脚底对齐帧底

- `run_strip_8x52.png`: 8帧 x 52x52, 建议 10-12fps + speed_scale 跟随移速
- 风格说明: Seedance 输出会"去像素化"成高清动画风, 最终像素质感由
  降采样+锁色板步骤决定 — 即风格可控, 同一段视频可出任意目标分辨率/色数。
- 注意: 动作版体型(写实比例)与 miko_shrine_maiden_48(Q版RPG比例)不一致,
  上岗需配套重做 idle 等其余动作, 不能混用。
