#!/usr/bin/env python3
"""Compose the README presentation image from the real app screenshots."""

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
IMAGES = ROOT / "docs" / "images"
OUTPUT = IMAGES / "new-file-creation-2-presentation.png"
ICON = ROOT / "NewFileCreation2App" / "Design" / "AppIcon.icns"
FONT_PATH = Path("/System/Library/Fonts/SFNS.ttf")

WIDTH = 2560
HEIGHT = 1440

COLORS = {
    "text": (248, 250, 252, 255),
    "secondary": (177, 190, 211, 255),
    "muted": (122, 139, 166, 255),
    "accent": (86, 148, 255, 255),
    "cyan": (34, 211, 238, 255),
    "purple": (139, 92, 246, 255),
    "chip": (255, 255, 255, 24),
    "chip_border": (255, 255, 255, 42),
}


def font(size: int, weight: str = "Regular") -> ImageFont.FreeTypeFont:
    face = ImageFont.truetype(str(FONT_PATH), size)
    try:
        face.set_variation_by_name(weight)
    except (OSError, ValueError):
        pass
    return face


def horizontal_gradient(size: tuple[int, int], start: tuple[int, int, int],
                        end: tuple[int, int, int]) -> Image.Image:
    width, height = size
    gradient = Image.new("RGBA", (width, height))
    pixels = gradient.load()
    for y in range(height):
        for x in range(width):
            t = (x / max(width - 1, 1) * 0.65) + (y / max(height - 1, 1) * 0.35)
            pixels[x, y] = (
                round(start[0] + (end[0] - start[0]) * t),
                round(start[1] + (end[1] - start[1]) * t),
                round(start[2] + (end[2] - start[2]) * t),
                255,
            )
    return gradient


def add_glow(canvas: Image.Image, center: tuple[int, int], radius: int,
             color: tuple[int, int, int], opacity: int) -> None:
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.ellipse(
        [center[0] - radius, center[1] - radius,
         center[0] + radius, center[1] + radius],
        fill=(*color, opacity),
    )
    layer = layer.filter(ImageFilter.GaussianBlur(radius // 2))
    canvas.alpha_composite(layer)


def add_dot_grid(canvas: Image.Image, step: int = 56) -> None:
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for x in range(0, canvas.width, step):
        for y in range(0, canvas.height, step):
            draw.ellipse([x, y, x + 2, y + 2], fill=(255, 255, 255, 16))
    canvas.alpha_composite(layer)


def rounded_snapshot(path: Path, target_width: int, radius: int) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    height = round(image.height * target_width / image.width)
    image = image.resize((target_width, height), Image.LANCZOS)
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, image.width - 1, image.height - 1], radius=radius, fill=255
    )
    image.putalpha(mask)
    return image


def add_shadow(canvas: Image.Image, image: Image.Image, position: tuple[int, int],
               blur: int = 34, opacity: int = 150, offset: tuple[int, int] = (0, 22)) -> None:
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    alpha = image.getchannel("A")
    tint = Image.new("RGBA", image.size, (0, 0, 0, opacity))
    shadow.paste(tint, (position[0] + offset[0], position[1] + offset[1]), alpha)
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(shadow)
    canvas.alpha_composite(image, position)


def add_border(canvas: Image.Image, image: Image.Image, position: tuple[int, int],
               radius: int, color: tuple[int, int, int, int]) -> None:
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.rounded_rectangle(
        [position[0], position[1],
         position[0] + image.width - 1, position[1] + image.height - 1],
        radius=radius,
        outline=color,
        width=2,
    )
    canvas.alpha_composite(layer)


def draw_pill(draw: ImageDraw.ImageDraw, text: str, face: ImageFont.FreeTypeFont,
              x: int, y: int, padding_x: int = 26, padding_y: int = 15) -> int:
    bounds = draw.textbbox((0, 0), text, font=face)
    width = bounds[2] - bounds[0] + padding_x * 2
    height = bounds[3] - bounds[1] + padding_y * 2
    draw.rounded_rectangle(
        [x, y, x + width, y + height],
        radius=height // 2,
        fill=COLORS["chip"],
        outline=COLORS["chip_border"],
        width=2,
    )
    draw.text((x + padding_x, y + padding_y - bounds[1]), text,
              font=face, fill=COLORS["secondary"])
    return width


def build_icon(size: int) -> Image.Image:
    with tempfile.TemporaryDirectory(prefix="nfc-presentation-") as directory:
        converted = Path(directory) / "app-icon.png"
        subprocess.run(
            ["sips", "-s", "format", "png", str(ICON), "--out", str(converted)],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        image = Image.open(converted).convert("RGBA").resize((size, size), Image.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1],
                                           radius=round(size * 0.22), fill=255)
    image.putalpha(mask)
    return image


def main() -> int:
    icon_path = IMAGES / "new-file-creation-2-library.png"
    quick_path = IMAGES / "new-file-creation-2-quick-panel.png"
    widget_path = IMAGES / "new-file-creation-2-widget.png"
    for path in (icon_path, quick_path, widget_path, ICON):
        if not path.exists():
            print(f"Missing presentation source: {path}", file=sys.stderr)
            return 1

    canvas = horizontal_gradient((WIDTH, HEIGHT), (8, 13, 28), (18, 28, 54))
    add_glow(canvas, (2050, 120), 620, (34, 98, 214), 56)
    add_glow(canvas, (760, 1180), 520, (114, 62, 210), 42)
    add_glow(canvas, (2250, 1260), 430, (16, 148, 172), 32)
    add_dot_grid(canvas)

    draw = ImageDraw.Draw(canvas, "RGBA")

    # Left column: brand and concise positioning.
    icon = build_icon(176)
    add_shadow(canvas, icon, (128, 250), blur=28, opacity=120, offset=(0, 16))
    draw = ImageDraw.Draw(canvas, "RGBA")

    draw.text((352, 270), "NATIVE macOS UTILITY",
              font=font(25, "Semibold"), fill=COLORS["accent"])
    draw.text((352, 314), "Built with AppKit",
              font=font(31, "Medium"), fill=COLORS["muted"])

    title_face = font(94, "Bold")
    draw.text((126, 472), "New File", font=title_face, fill=COLORS["text"])
    draw.text((126, 582), "Creation 2", font=title_face, fill=COLORS["text"])

    subtitle_face = font(33, "Regular")
    subtitle = ("Create files from templates in Finder,\n"
                "from the menu bar, from the library,\n"
                "or with the nfc command.")
    draw.multiline_text((130, 730), subtitle, font=subtitle_face,
                        fill=COLORS["secondary"], spacing=12)

    pill_face = font(25, "Medium")
    x = 130
    y = 872
    first_row = ["Menu bar", "Finder", "Template library"]
    second_row = ["CLI", "Widgets", "28 languages"]
    for label in first_row:
        width = draw_pill(draw, label, pill_face, x, y)
        x += width + 16
    x = 130
    y += 76
    for label in second_row:
        width = draw_pill(draw, label, pill_face, x, y)
        x += width + 16

    draw.text((132, 1120), "Local-first", font=font(28, "Semibold"), fill=COLORS["text"])
    draw.text((132, 1166), "No network requests  •  No analytics  •  MIT license",
              font=font(25, "Regular"), fill=COLORS["muted"])

    # Right stage: the library is the hero, with the quick panel and widget
    # floating over its lower corners for depth.
    library = rounded_snapshot(icon_path, 1540, 34)
    library_pos = (930, 116)
    add_shadow(canvas, library, library_pos, blur=48, opacity=190, offset=(0, 30))
    add_border(canvas, library, library_pos, 34, (255, 255, 255, 34))

    quick = rounded_snapshot(quick_path, 486, 30)
    quick_pos = (846, 842)
    add_shadow(canvas, quick, quick_pos, blur=34, opacity=170, offset=(0, 22))
    add_border(canvas, quick, quick_pos, 30, (255, 255, 255, 34))

    widget = rounded_snapshot(widget_path, 560, 30)
    widget_pos = (1888, 1008)
    add_shadow(canvas, widget, widget_pos, blur=34, opacity=150, offset=(0, 20))
    add_border(canvas, widget, widget_pos, 30, (255, 255, 255, 40))

    # A small caption for the floating widget keeps the composition readable.
    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.text((850, 1300), "Menu bar quick panel", font=font(24, "Medium"),
              fill=COLORS["muted"])
    draw.text((1904, 1300), "WidgetKit widget", font=font(24, "Medium"),
              fill=COLORS["muted"])

    canvas.convert("RGB").save(OUTPUT, "PNG", optimize=True)
    print(f"Wrote {OUTPUT} ({OUTPUT.stat().st_size // 1024} KB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
