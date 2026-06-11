# Blender headless 渲染: FBX 动画 → 透明底 PNG 序列帧(正交侧视)
# 用法: blender -b -P render_sprites.py -- <model.fbx> <out_dir> [frames=12] [azimuth=90]
import bpy, sys, math, os

argv = sys.argv[sys.argv.index("--")+1:]
FBX, OUT = argv[0], argv[1]
N_FRAMES = int(argv[2]) if len(argv) > 2 else 12
AZIMUTH = float(argv[3]) if len(argv) > 3 else 90.0   # 90=侧视(朝右)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=FBX)

# 动画帧范围(取第一个 action)
acts = bpy.data.actions
if acts:
    f0, f1 = acts[0].frame_range
    bpy.context.scene.frame_start = int(f0)
    bpy.context.scene.frame_end = int(f1)

# 模型包围盒 → 相机正交尺度
import mathutils
mins = mathutils.Vector((1e9,)*3); maxs = mathutils.Vector((-1e9,)*3)
for ob in bpy.context.scene.objects:
    if ob.type == 'MESH':
        for v in ob.bound_box:
            w = ob.matrix_world @ mathutils.Vector(v)
            mins = mathutils.Vector(map(min, mins, w)); maxs = mathutils.Vector(map(max, maxs, w))
center = (mins + maxs) / 2
size = max(maxs.z - mins.z, maxs.x - mins.x, maxs.y - mins.y)

# 正交相机: 方位角环绕(90°=+X 侧视)
cam_data = bpy.data.cameras.new("cam"); cam_data.type = 'ORTHO'
cam_data.ortho_scale = size * 1.3
cam = bpy.data.objects.new("cam", cam_data)
bpy.context.scene.collection.objects.link(cam)
a = math.radians(AZIMUTH)
dist = size * 3
cam.location = (center.x + dist*math.sin(a), center.y - dist*math.cos(a), center.z)
cam.rotation_euler = (math.radians(90), 0, a)
bpy.context.scene.camera = cam

# Workbench 平面渲染(快, 纯色, 适合后续像素化) + 透明底
sc = bpy.context.scene
sc.render.engine = 'BLENDER_WORKBENCH'
sc.display.shading.light = 'FLAT'
sc.display.shading.color_type = 'TEXTURE'
sc.render.film_transparent = True
sc.render.resolution_x = 512; sc.render.resolution_y = 512
sc.render.image_settings.file_format = 'PNG'
sc.render.image_settings.color_mode = 'RGBA'

os.makedirs(OUT, exist_ok=True)
f0, f1 = sc.frame_start, sc.frame_end
for i in range(N_FRAMES):
    fr = f0 + (f1 - f0) * i / max(1, N_FRAMES)   # 均匀采样(末帧=首帧, 循环不取重)
    sc.frame_set(int(round(fr)))
    sc.render.filepath = os.path.join(OUT, f"f{i:02d}.png")
    bpy.ops.render.render(write_still=True)
print("RENDER_DONE", N_FRAMES, "frames ->", OUT)
