# 瓦片/地图生产管线 —— 用户手动操作手册(2026-06)

> 姊妹篇:角色管线见 `CHAR_PIPELINE_3D.md`。**要做哪些瓦片、按什么世界观/色板**,清单在 `TILE_ASSETS.md`(本文讲"怎么做",那篇讲"做什么")。
> 好消息:**瓦片是 AI 最擅长的素材类型**(规整、可平铺、不挑帧间一致性)——这是实测后唯一仍推荐 AI 生成的方向。
> **分工**:本文步骤=用户手动操作;成品交 Claude → 接 Godot(TileMap/房间皮肤)。

## 30 秒概念课

- **tile(瓦片)**:固定尺寸小方块(我们用 **32×32**),拼出地图。
- **无缝(seamless)**:瓦片左右/上下首尾相接不露缝——瓦片的命根子。
- **autotile(自动拼接)**:一套"边/角/中心/过渡"瓦片,引擎按邻接关系自动选块。
  常见格式:**Wang / 3×3(blob)/ dual-grid 15 块**。Godot 的 Terrain Set 吃这套。
- **先后顺序**:先要"能踩的主地形"(地面块+顶面草/苔条),再要装饰。一张主地形就能让游戏脱离色块。

## 路线 A:AI 生成(推荐起步)

| 工具 | 用法 | 要点 |
|---|---|---|
| **RetroDiffusion**(retrodiffusion.ai) | 选 tile 模式:`tileset`(整套自动拼接)/`single_tile`(单张无缝)/`tile_object`(瓦片对齐物件)/`scene_object`(大场景物) | 像素瓦片专模,实测推荐;**喂色板**锁风格(`docs/style/palette.png`);各模式对应用途见 `TILE_ASSETS.md` |
| **[PixelLab 瓦片工具](https://www.pixellab.ai/docs/tools/create-tileset)** | 文字或贴图 → 生成整套 tileset,可导出 **Wang / dual-grid 15 / 3×3** 格式 | 直接出引擎友好的 autotile 排布,省拼装功夫 |
| 通用生图(混元 TokenHub 等) | 提示词写明 `seamless tileable texture, 32x32 pixel art, top-down/side view` | 出**单张无缝纹理**还行,整套 autotile 别指望;产物交给路线 C 的 Tilesetter 切 |

**提示词要点**(实测有效):写明 `seamless / tileable`、视角(横版写 `side view platformer tile`)、尺寸、`limited palette`、贴主题词(我们的:青冷石、霜苔、神社、凝晶)。

## 路线 B:现成包(零成本保底)

- **itch.io** 搜:`tileset 32x32 platformer`、`dark fantasy tileset`、`japanese shrine tileset`;筛 free + 商用授权
- **Kenney.nl**:CC0 全套,风格干净(偏几何,适合原型期)
- 铁律同角色:**认准同一作者成套**,别东拼西凑;下载后丢 `incoming/` 给 Claude

## 路线 C:半自动组装(自画/AI 纹理 → 整套 autotile)

**[Tilesetter](https://www.tilesetter.org/)**(神器,买断制):喂一张**基础纹理**(自画的或 AI 出的单张无缝图)→ 自动生成整套边/角/过渡瓦片 → **直接导出 Godot 格式**。还自带地图编辑器。
自学像素画后这是你的主力:画一块 32×32 的"中心纹理",其余几十块它替你长出来。

## 无缝检验(交付前必做)

把瓦片 **2×2 平铺**看一眼:接缝处有没有亮线/断纹/重复感过强的图案。
(AI 出的"伪无缝"很常见,平铺一下立刻现形;不过关就让工具重roll或手修边缘几列像素。)

## 色板纪律

所有瓦片过同一色板(`docs/style/palette.png`,世界观:**世界是冷的、你是暖的、冻结是亮蓝的**,详见 `WORLD.md`)。
AI 出图后可让 Claude 用脚本做色板量化对齐,不用手修。

## 交付规格(给 Claude 时对照)

- **PNG 网格图**:瓦片间**无间距无边距**(margin/spacing = 0),整张尺寸是 32 的整倍数
- 附一句:瓦片尺寸、哪块是"中心填充"、哪些是"顶面/边/角"(或直接说用的 PixelLab/Tilesetter 哪种导出格式)
- 放 `incoming/tiles/<主题名>/` 推上来,或直接发
- **最快见效的第一单**:`A1 主地形`两件套——①地面填充块(可平铺)②顶面条(草/苔,盖在地面块上沿)。
  game.gd 里有现成挂点(`_tile_ground`/`_tile_top`,现注释停用),这两张一到,房间立刻从色块换成真地形,十分钟接入
- 之后再上整套 autotile,Claude 搭 Godot TileMap/Terrain Set 接管房间地形

## 优先级(对照 TILE_ASSETS.md)

1. **A1 主地形**(地面+顶面)★ 一张换肤全场
2. A4 背景近景墙(单张无缝,压暗一档)
3. A3 悬空平台条
4. A5 远景视差剪影、装饰物件(鸟居/灯笼/凝晶)…按清单走

## 踩坑备忘

- 横版的"地面"要两层:**内部填充**(暗、密)+**顶面条**(亮、有草/苔)——只出一块会糊成一片
- 装饰物件(灯笼/鸟居)要**透明底独立图**,别烤进瓦片里(要摆放自由度)
- 瓦片接缝在游戏里会被镜头放大检视,32×32 内部纹理别太强对比,否则平铺出"格子感"
