import JSZip from "jszip";
import type { Asset, TreeNode } from "./types";

let counter = 0;
export const uid = (p = "id") =>
  `${p}_${(counter++).toString(36)}_${Math.random().toString(36).slice(2, 6)}`;

const IMG_RE = /\.(png|webp|gif|jpg|jpeg)$/i;

function loadImageSize(url: string): Promise<{ w: number; h: number }> {
  return new Promise((resolve) => {
    const img = new Image();
    img.onload = () => resolve({ w: img.naturalWidth, h: img.naturalHeight });
    img.onerror = () => resolve({ w: 0, h: 0 });
    img.src = url;
  });
}

async function fileToAsset(path: string, blob: Blob): Promise<Asset> {
  const url = URL.createObjectURL(blob);
  const size = await loadImageSize(url);
  const name = path.split("/").pop() ?? path;
  return { id: uid("a"), name, path, url, width: size.w, height: size.h, blob };
}

// 把扁平的资源路径列表组织成目录树
export function buildTree(assets: Asset[], rootName: string): TreeNode {
  const root: TreeNode = { name: rootName, path: "", isDir: true, children: [] };
  const dirMap = new Map<string, TreeNode>([["", root]]);

  const ensureDir = (dirPath: string): TreeNode => {
    if (dirMap.has(dirPath)) return dirMap.get(dirPath)!;
    const parts = dirPath.split("/").filter(Boolean);
    const name = parts[parts.length - 1] ?? dirPath;
    const parentPath = parts.slice(0, -1).join("/");
    const parent = ensureDir(parentPath);
    const node: TreeNode = { name, path: dirPath, isDir: true, children: [] };
    parent.children.push(node);
    dirMap.set(dirPath, node);
    return node;
  };

  for (const a of assets) {
    const parts = a.path.split("/").filter(Boolean);
    const dirPath = parts.slice(0, -1).join("/");
    const dir = ensureDir(dirPath);
    dir.children.push({
      name: a.name,
      path: a.path,
      isDir: false,
      assetId: a.id,
      children: [],
    });
  }

  const sortRec = (n: TreeNode) => {
    n.children.sort((x, y) => {
      if (x.isDir !== y.isDir) return x.isDir ? -1 : 1;
      return x.name.localeCompare(y.name);
    });
    n.children.forEach(sortRec);
  };
  sortRec(root);
  return root;
}

export async function parseZip(file: File): Promise<{ assets: Asset[]; tree: TreeNode }> {
  const zip = await JSZip.loadAsync(file);
  const assets: Asset[] = [];
  const entries = Object.values(zip.files).filter(
    (f) => !f.dir && IMG_RE.test(f.name) && !f.name.startsWith("__MACOSX")
  );
  for (const entry of entries) {
    const blob = await entry.async("blob");
    assets.push(await fileToAsset(entry.name, blob));
  }
  const tree = buildTree(assets, file.name.replace(/\.zip$/i, ""));
  return { assets, tree };
}

export async function parseFiles(files: FileList): Promise<{ assets: Asset[]; tree: TreeNode }> {
  const assets: Asset[] = [];
  for (const f of Array.from(files)) {
    if (IMG_RE.test(f.name)) {
      assets.push(await fileToAsset(f.name, f));
    }
  }
  const tree = buildTree(assets, "uploads");
  return { assets, tree };
}
