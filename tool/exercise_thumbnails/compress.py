"""Turns the rendered thumbnail PNGs into the WebP files the app ships.

    flutter test tool/exercise_thumbnails/render_test.dart --no-pub
    python tool/exercise_thumbnails/compress.py

Needs Pillow. Reads build/thumbs_png/thumb_<id>.png, writes
assets/exercises/thumb_<id>.webp (lossy, quality 86: about 10 KB each).
"""
import glob
import os

from PIL import Image

root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
src = os.path.join(root, "build", "thumbs_png")
dst = os.path.join(root, "assets", "exercises")
total = 0
files = sorted(glob.glob(os.path.join(src, "thumb_*.png")))
for f in files:
    out = os.path.join(dst, os.path.basename(f)[:-4] + ".webp")
    Image.open(f).convert("RGB").save(out, "WEBP", quality=86, method=6)
    total += os.path.getsize(out)
print(len(files), "thumbnails,", total // 1024, "KB")
