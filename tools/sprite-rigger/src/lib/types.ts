export interface Asset {
  id: string;
  name: string;
  path: string; // zip 内完整路径
  url: string; // object URL（运行时，刷新后重建）
  width: number;
  height: number;
  blob?: Blob; // 原始二进制（用于持久化，不序列化进工程 JSON）
}

export interface Layer {
  id: string;
  assetId: string;
  name: string;
  parentId: string | null;
  // 当前姿势的变换（live）
  x: number;
  y: number;
  rotation: number; // 角度
  // 结构
  pivotX: number; // 锚点（资源局部像素）
  pivotY: number;
  z: number;
  visible: boolean;
}

export interface FrameTransform {
  x: number;
  y: number;
  rotation: number;
  visible: boolean;
}

export interface Frame {
  id: string;
  name: string;
  transforms: Record<string, FrameTransform>; // layerId -> 该帧变换快照
}

export interface TreeNode {
  name: string;
  path: string;
  isDir: boolean;
  assetId?: string;
  children: TreeNode[];
}
