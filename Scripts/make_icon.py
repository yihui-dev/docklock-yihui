#!/usr/bin/env python3
"""Renders the DockLock app icon (all macOS sizes) into the asset catalog. Needs Pillow."""
import json
import os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "App", "Resources", "Assets.xcassets", "AppIcon.appiconset")
S = 1024


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def rounded_mask(size, box, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius=radius, fill=255)
    return mask


def render():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    # Squircle-ish background with a vertical gradient (macOS icon grid: 824px body, 100px margin).
    body = (100, 100, 924, 924)
    grad = Image.new("RGBA", (S, S))
    top, bottom = (40, 92, 222), (18, 36, 104)
    for y in range(S):
        t = max(0.0, min(1.0, (y - body[1]) / (body[3] - body[1])))
        ImageDraw.Draw(grad).line([(0, y), (S, y)], fill=lerp(top, bottom, t) + (255,))
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((100, 118, 924, 942), radius=185, fill=(0, 0, 0, 110))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(18)))
    img.paste(grad, (0, 0), rounded_mask((S, S), body, 185))

    # Two monitors: a dim one on the left (drawn on an overlay so it blends), the bright "locked" one on the right.
    overlay = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    o = ImageDraw.Draw(overlay)
    o.rounded_rectangle((170, 300, 480, 520), radius=22, fill=(255, 255, 255, 45), outline=(255, 255, 255, 140), width=8)
    o.rounded_rectangle((230, 470, 420, 500), radius=10, fill=(255, 255, 255, 90))
    img.alpha_composite(overlay)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((300, 230, 860, 640), radius=34, fill=(245, 248, 255, 255))
    d.rounded_rectangle((326, 256, 834, 614), radius=20, fill=(29, 56, 150, 255))
    # Stand.
    d.polygon([(545, 640), (615, 640), (640, 720), (520, 720)], fill=(225, 232, 250, 255))
    d.rounded_rectangle((470, 712, 690, 740), radius=12, fill=(225, 232, 250, 255))

    # The Dock on the bright monitor, with app tiles.
    d.rounded_rectangle((400, 540, 760, 598), radius=18, fill=(228, 234, 252, 255))
    colors = [(255, 94, 87), (255, 189, 46), (40, 201, 64), (10, 132, 255), (191, 90, 242)]
    for i, c in enumerate(colors):
        x = 418 + i * 68
        d.rounded_rectangle((x, 552, x + 52, 590), radius=11, fill=c + (255,))

    # Padlock badge.
    cx, cy = 760, 300
    d.ellipse((cx - 118, cy - 118, cx + 118, cy + 118), fill=(255, 196, 38, 255), outline=(255, 255, 255, 255), width=12)
    d.rounded_rectangle((cx - 62, cy - 18, cx + 62, cy + 70), radius=16, fill=(58, 44, 8, 255))
    d.arc((cx - 44, cy - 84, cx + 44, cy + 4), start=180, end=360, fill=(58, 44, 8, 255), width=20)
    d.line((cx - 44, cy - 40, cx - 44, cy - 14), fill=(58, 44, 8, 255), width=20)
    d.line((cx + 44, cy - 40, cx + 44, cy - 14), fill=(58, 44, 8, 255), width=20)
    d.ellipse((cx - 12, cy + 8, cx + 12, cy + 32), fill=(255, 196, 38, 255))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    base = render()
    images = []
    for size in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            px = size * scale
            name = f"icon_{size}x{size}{'@2x' if scale == 2 else ''}.png"
            base.resize((px, px), Image.LANCZOS).save(os.path.join(OUT, name))
            images.append({"idiom": "mac", "size": f"{size}x{size}", "scale": f"{scale}x", "filename": name})
    with open(os.path.join(OUT, "Contents.json"), "w") as f:
        json.dump({"images": images, "info": {"author": "xcode", "version": 1}}, f, indent=2)
        f.write("\n")
    base.save(os.path.join(ROOT, "docs", "icon.png"))


if __name__ == "__main__":
    main()
