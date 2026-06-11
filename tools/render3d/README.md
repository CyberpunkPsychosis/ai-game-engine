# 3D→序列帧管线(死亡细胞式)

1. **建模**: 概念图 → Tripo/Meshy 图生3D(免费额度) → 导出 FBX/GLB
2. **绑骨+动作**(浏览器手动, Mixamo 无 API): mixamo.com 上传模型自动绑骨 →
   挑动作 → 下载设置: **FBX Binary / With Skin / 30fps / 不勾 keyframe reduction**
3. **渲染**(云端可跑):
   ```bash
   /tmp/blender_bin/blender -b -P tools/render3d/render_sprites.py -- 模型.fbx /tmp/out 12 90
   ```
   出带透明通道的 PNG 序列(正交侧视, 无需抠图, 循环精确)
4. **像素化入库**: 走现有锁色板管线切 80x80 条 → `art/timestop/hero/`

优点: 动作=Mixamo库里挑不是抽; 一致性绝对; alpha/循环天生完美。
已知限制: 裙摆类布料会僵(Mixamo 无布料骨); 渲染风格偏"死亡细胞 3D 感"。
