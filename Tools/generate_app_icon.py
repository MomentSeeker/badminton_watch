#!/usr/bin/env python3
from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ICONSET = ROOT / "KineticVelocityWatch" / "Assets.xcassets" / "AppIcon.appiconset"
SOURCE_ICON = ROOT / "Tools" / "app_icon_source.png"

LIME = (194, 245, 0, 255)
LOAD = (232, 255, 46, 255)
CYAN = (0, 242, 255, 255)
TEXT = (232, 228, 224, 255)
SURFACE = (18, 20, 15, 255)
BLACK = (7, 8, 7, 255)


def draw_rotated_round_rect(
    image: Image.Image,
    center: tuple[float, float],
    size: tuple[float, float],
    radius: float,
    fill: tuple[int, int, int, int],
    angle: float,
    outline: tuple[int, int, int, int] | None = None,
    width: int = 1,
) -> None:
    scale = 2
    layer_size = (int(size[0] * scale + width * 8), int(size[1] * scale + width * 8))
    layer = Image.new("RGBA", layer_size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    inset = width * 3
    rect = (inset, inset, layer_size[0] - inset, layer_size[1] - inset)
    draw.rounded_rectangle(rect, radius=radius * scale, fill=fill, outline=outline, width=width * scale)
    layer = layer.resize((layer_size[0] // scale, layer_size[1] // scale), Image.Resampling.LANCZOS)
    layer = layer.rotate(angle, expand=True, resample=Image.Resampling.BICUBIC)
    x = int(center[0] - layer.size[0] / 2)
    y = int(center[1] - layer.size[1] / 2)
    image.alpha_composite(layer, (x, y))


def draw_shuttlecock(image: Image.Image, size: int, compact: bool = False) -> None:
    cx = size * 0.50
    cy = size * (0.48 if compact else 0.46)
    feather_w = size * (0.075 if compact else 0.068)
    feather_h = size * (0.40 if compact else 0.46)
    offset_y = -size * (0.13 if compact else 0.15)

    glow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    for i, angle in enumerate([-34, -17, 0, 17, 34]):
        color = LOAD if i % 2 == 0 else CYAN
        draw_rotated_round_rect(
            glow,
            (cx, cy + offset_y),
            (feather_w * 1.12, feather_h * 1.03),
            feather_w / 2,
            color[:3] + (120,),
            angle,
        )
    glow = glow.filter(ImageFilter.GaussianBlur(size * 0.035))
    image.alpha_composite(glow)

    for i, angle in enumerate([-34, -17, 0, 17, 34]):
        color = LOAD if i % 2 == 0 else CYAN
        alpha = 248 if i == 2 else 220
        draw_rotated_round_rect(
            image,
            (cx, cy + offset_y),
            (feather_w, feather_h),
            feather_w / 2,
            color[:3] + (alpha,),
            angle,
        )

    base_w = size * (0.42 if compact else 0.39)
    base_h = size * (0.19 if compact else 0.18)
    draw_rotated_round_rect(
        image,
        (cx, cy + size * 0.27),
        (base_w, base_h),
        size * 0.032,
        TEXT,
        -10,
        outline=LIME[:3] + (190,),
        width=max(2, int(size * 0.012)),
    )

    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(shadow)
    draw.ellipse(
        (
            cx - size * 0.22,
            cy + size * 0.34,
            cx + size * 0.22,
            cy + size * 0.43,
        ),
        fill=(0, 0, 0, 90),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(size * 0.03))
    image.alpha_composite(shadow)


def make_master(size: int = 1024) -> Image.Image:
    if SOURCE_ICON.exists():
        with Image.open(SOURCE_ICON) as source:
            image = source.convert("RGB")
            crop_size = min(image.size)
            left = (image.width - crop_size) // 2
            top = (image.height - crop_size) // 2
            image = image.crop((left, top, left + crop_size, top + crop_size))
            return image.resize((size, size), Image.Resampling.LANCZOS)

    image = Image.new("RGBA", (size, size), BLACK)
    draw = ImageDraw.Draw(image)

    for y in range(size):
        t = y / max(size - 1, 1)
        r = int(7 + 12 * (1 - t))
        g = int(8 + 17 * (1 - t))
        b = int(7 + 4 * (1 - t))
        draw.line([(0, y), (size, y)], fill=(r, g, b, 255))

    grid = Image.new("RGBA", image.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(grid)
    step = size // 5
    for pos in range(step, size, step):
        gd.line([(pos, 0), (pos, size)], fill=LIME[:3] + (22,), width=max(1, size // 190))
        gd.line([(0, pos), (size, pos)], fill=LIME[:3] + (20,), width=max(1, size // 190))

    points = []
    for x in range(-size // 10, size + size // 10, 8):
        t = x / size
        y = size * (0.73 - 0.34 * math.sin((t + 0.08) * math.pi * 0.78))
        points.append((x, y))
    gd.line(points, fill=LIME[:3] + (42,), width=max(3, size // 86), joint="curve")
    grid = grid.filter(ImageFilter.GaussianBlur(size * 0.001))
    image.alpha_composite(grid)

    halo = Image.new("RGBA", image.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(halo)
    hd.ellipse(
        (size * 0.11, size * 0.07, size * 0.89, size * 0.91),
        fill=LIME[:3] + (34,),
    )
    halo = halo.filter(ImageFilter.GaussianBlur(size * 0.12))
    image.alpha_composite(halo)

    draw_shuttlecock(image, size)

    vignette = Image.new("RGBA", image.size, (0, 0, 0, 0))
    vd = ImageDraw.Draw(vignette)
    vd.rounded_rectangle(
        (size * 0.025, size * 0.025, size * 0.975, size * 0.975),
        radius=size * 0.22,
        outline=(255, 255, 255, 23),
        width=max(2, size // 96),
    )
    image.alpha_composite(vignette)
    return image.convert("RGB")


def icon_entries() -> list[dict[str, str]]:
    return [
        {"idiom": "watch", "role": "notificationCenter", "subtype": "38mm", "size": "24x24", "scale": "2x", "filename": "AppIcon-24x24@2x.png"},
        {"idiom": "watch", "role": "notificationCenter", "subtype": "42mm", "size": "27.5x27.5", "scale": "2x", "filename": "AppIcon-27.5x27.5@2x.png"},
        {"idiom": "watch", "role": "companionSettings", "size": "29x29", "scale": "2x", "filename": "AppIcon-29x29@2x.png"},
        {"idiom": "watch", "role": "companionSettings", "size": "29x29", "scale": "3x", "filename": "AppIcon-29x29@3x.png"},
        {"idiom": "watch", "role": "appLauncher", "subtype": "38mm", "size": "40x40", "scale": "2x", "filename": "AppIcon-40x40@2x.png"},
        {"idiom": "watch", "role": "appLauncher", "subtype": "40mm", "size": "44x44", "scale": "2x", "filename": "AppIcon-44x44@2x.png"},
        {"idiom": "watch", "role": "quickLook", "subtype": "38mm", "size": "86x86", "scale": "2x", "filename": "AppIcon-86x86@2x.png"},
        {"idiom": "watch", "role": "quickLook", "subtype": "42mm", "size": "98x98", "scale": "2x", "filename": "AppIcon-98x98@2x.png"},
        {"idiom": "watch", "role": "quickLook", "subtype": "44mm", "size": "108x108", "scale": "2x", "filename": "AppIcon-108x108@2x.png"},
        {"idiom": "watch-marketing", "size": "1024x1024", "scale": "1x", "filename": "AppIcon-1024x1024.png"},
    ]


def pixel_size(entry: dict[str, str]) -> int:
    base = float(entry["size"].split("x", 1)[0])
    scale = int(entry["scale"].replace("x", ""))
    return int(round(base * scale))


def main() -> None:
    ICONSET.mkdir(parents=True, exist_ok=True)
    master = make_master()

    for entry in icon_entries():
        px = pixel_size(entry)
        icon = master.resize((px, px), Image.Resampling.LANCZOS)
        icon.save(ICONSET / entry["filename"])

    contents = {
        "images": icon_entries(),
        "info": {"author": "xcode", "version": 1},
    }
    (ICONSET / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


if __name__ == "__main__":
    main()
