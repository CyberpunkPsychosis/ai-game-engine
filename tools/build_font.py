#!/usr/bin/env python3
"""把系统里的 WenQuanYi 正黑子集化成只含项目用到的中文字 → fonts/ui.ttf（几百KB）。
网页版用这个当默认主题字体，免得中文菜单显示成方块。新增中文 UI 文案后重跑一次再提交。
依赖: pip install fonttools；系统字体 /usr/share/fonts/truetype/wqy/wqy-zenhei.ttc。
"""
import glob, os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc"
OUT = os.path.join(ROOT, "fonts", "ui.ttf")

chars = set()
for f in glob.glob(os.path.join(ROOT, "scripts", "**", "*.gd"), recursive=True):
    for ch in open(f, encoding="utf-8").read():
        if "一" <= ch <= "鿿" or "　" <= ch <= "〿" or "＀" <= ch <= "￯":
            chars.add(ch)
txt = "/tmp/_uichars.txt"
open(txt, "w", encoding="utf-8").write("".join(sorted(chars)))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
subprocess.check_call([
    "pyftsubset", SRC, "--font-number=0", "--text-file=" + txt,
    "--unicodes=U+0020-007E,U+00A0-00FF,U+2010-2027,U+3000-303F,U+FF00-FFEF",
    "--output-file=" + OUT, "--drop-tables+=DSIG", "--no-hinting",
])
print("subset %d chars -> %s (%d KB)" % (len(chars), OUT, os.path.getsize(OUT) // 1024))
