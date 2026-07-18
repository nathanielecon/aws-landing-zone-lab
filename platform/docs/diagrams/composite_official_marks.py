#!/usr/bin/env python3
"""Replace AI-redrawn third-party logos with generic icons + plain word marks.

Does NOT paste GitHub / Terraform / Jenkins / AWS brand artwork.
Loads pristine Image2 PNGs from --source-dir (required for clean wipes).
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

DIAGRAMS = Path(__file__).resolve().parent


def load_rgba(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def font(size: int, bold: bool = True) -> ImageFont.ImageFont:
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
        if bold
        else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"
        if bold
        else "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def cover_rect(
    canvas: Image.Image,
    box: tuple[int, int, int, int],
    fill: tuple[int, int, int, int],
    radius: int = 6,
) -> None:
    ImageDraw.Draw(canvas).rounded_rectangle(box, radius=radius, fill=fill)


def cover_ellipse(
    canvas: Image.Image,
    cx: int,
    cy: int,
    diameter: int,
    fill: tuple[int, int, int, int],
) -> None:
    r = diameter // 2
    ImageDraw.Draw(canvas).ellipse((cx - r, cy - r, cx + r, cy + r), fill=fill)


def word_badge(
    canvas: Image.Image,
    cx: int,
    cy: int,
    text: str,
    *,
    fill: tuple[int, int, int, int] = (15, 35, 70, 255),
    fg: tuple[int, int, int, int] = (255, 255, 255, 255),
    pad_x: int = 14,
    pad_y: int = 8,
    size: int = 18,
) -> None:
    d = ImageDraw.Draw(canvas)
    f = font(size)
    bbox = d.textbbox((0, 0), text, font=f)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x0 = cx - tw // 2 - pad_x
    y0 = cy - th // 2 - pad_y
    x1 = cx + tw // 2 + pad_x
    y1 = cy + th // 2 + pad_y
    d.rounded_rectangle((x0, y0, x1, y1), radius=8, fill=fill)
    d.text((cx, cy), text, fill=fg, font=f, anchor="mm")


def generic_git_icon(canvas: Image.Image, cx: int, cy: int, scale: int = 28) -> None:
    """Simple branch nodes — not Invertocat."""
    d = ImageDraw.Draw(canvas)
    ink = (20, 40, 70, 255)
    # vertical stem + branch
    d.line((cx, cy - scale, cx, cy + scale), fill=ink, width=3)
    d.line((cx, cy, cx + scale, cy - scale // 2), fill=ink, width=3)
    for px, py in ((cx, cy - scale), (cx, cy + scale), (cx + scale, cy - scale // 2)):
        d.ellipse((px - 5, py - 5, px + 5, py + 5), fill=ink)


def generic_blocks_icon(canvas: Image.Image, cx: int, cy: int, scale: int = 22) -> None:
    """Three cubes — generic IaC, not Terraform mark."""
    d = ImageDraw.Draw(canvas)
    ink = (20, 40, 70, 255)
    s = scale
    # isometric-ish squares as outlines
    boxes = [
        (cx - s, cy - s // 3, cx, cy + s // 2),
        (cx, cy - s // 3, cx + s, cy + s // 2),
        (cx - s // 2, cy - s, cx + s // 2, cy - s // 6),
    ]
    for box in boxes:
        d.rectangle(box, outline=ink, width=2)


def generic_bucket_icon(canvas: Image.Image, cx: int, cy: int, scale: int = 26) -> None:
    d = ImageDraw.Draw(canvas)
    ink = (30, 90, 50, 255)
    d.arc((cx - scale, cy - scale // 2, cx + scale, cy + scale), 0, 180, fill=ink, width=3)
    d.line((cx - scale, cy, cx - scale + 4, cy + scale // 2), fill=ink, width=3)
    d.line((cx + scale, cy, cx + scale - 4, cy + scale // 2), fill=ink, width=3)
    d.arc(
        (cx - scale + 4, cy + scale // 3, cx + scale - 4, cy + scale),
        0,
        180,
        fill=ink,
        width=3,
    )


def generic_doc_icon(canvas: Image.Image, cx: int, cy: int, scale: int = 22) -> None:
    d = ImageDraw.Draw(canvas)
    ink = (80, 40, 120, 255)
    d.rounded_rectangle(
        (cx - scale // 2, cy - scale, cx + scale // 2, cy + scale),
        radius=3,
        outline=ink,
        width=2,
    )
    for i, y in enumerate((cy - scale // 2, cy, cy + scale // 2)):
        d.line((cx - scale // 3, y, cx + scale // 3, y), fill=ink, width=2)


def generic_cloud_lock(canvas: Image.Image, cx: int, cy: int, scale: int = 24) -> None:
    d = ImageDraw.Draw(canvas)
    ink = (40, 100, 70, 255)
    d.ellipse((cx - scale, cy - scale // 2, cx + scale // 3, cy + scale // 2), outline=ink, width=2)
    d.ellipse((cx - scale // 3, cy - scale // 2, cx + scale, cy + scale // 2), outline=ink, width=2)
    d.rounded_rectangle(
        (cx - 8, cy, cx + 8, cy + 14),
        radius=2,
        outline=ink,
        width=2,
    )


def generic_flow_icon(canvas: Image.Image, cx: int, cy: int, scale: int = 22) -> None:
    d = ImageDraw.Draw(canvas)
    ink = (90, 50, 140, 255)
    d.ellipse((cx - scale, cy - scale, cx + scale, cy + scale), outline=ink, width=2)
    d.line((cx - scale // 2, cy, cx + scale // 2, cy), fill=ink, width=2)
    d.polygon(
        [(cx + scale // 2, cy), (cx + scale // 4, cy - 6), (cx + scale // 4, cy + 6)],
        fill=ink,
    )


def composite_lab(src: Path, dst: Path) -> None:
    canvas = load_rgba(src)
    white = (255, 255, 255, 255)

    # B1: wipe AI Invertocat completely → generic git + "GitHub"
    plate = (254, 254, 255, 255)
    cover_rect(canvas, (40, 850, 190, 985), plate, radius=2)
    generic_git_icon(canvas, 115, 905, 22)
    word_badge(canvas, 115, 950, "GitHub", size=15, pad_x=10, pad_y=5)

    # B3: wipe AI Terraform / cube logo area → generic blocks + "Terraform"
    plate_tf = (251, 251, 251, 255)
    cover_rect(canvas, (435, 695, 545, 815), plate_tf, radius=2)
    generic_blocks_icon(canvas, 490, 735, 20)
    word_badge(canvas, 490, 785, "Terraform", size=14, pad_x=10, pad_y=5, fill=(70, 40, 110, 255))

    # C: wipe AI AWS service marks → generic icons + word labels
    # VPC header icon
    cover_rect(canvas, (50, 1065, 150, 1165), white, radius=4)
    generic_cloud_lock(canvas, 100, 1115, 22)
    # Flow Logs
    cover_ellipse(canvas, 720, 1145, 100, white)
    generic_flow_icon(canvas, 720, 1145, 20)
    # S3
    cover_rect(canvas, (820, 1075, 960, 1215), white, radius=6)
    generic_bucket_icon(canvas, 890, 1125, 24)
    word_badge(canvas, 890, 1185, "S3", size=14, pad_x=10, pad_y=4, fill=(40, 100, 50, 255))
    # Security Tooling icons
    cover_rect(canvas, (720, 1260, 970, 1365), white, radius=4)
    generic_doc_icon(canvas, 780, 1305, 18)
    word_badge(canvas, 780, 1345, "CloudTrail", size=11, pad_x=8, pad_y=3, fill=(140, 40, 90, 255))
    generic_doc_icon(canvas, 900, 1305, 18)
    word_badge(canvas, 900, 1345, "Config", size=11, pad_x=8, pad_y=3, fill=(140, 40, 90, 255))

    canvas.convert("RGB").save(dst, "PNG", optimize=True)
    print(f"wrote {dst}")


def composite_network(src: Path, dst: Path) -> None:
    canvas = load_rgba(src)
    white = (255, 255, 255, 255)
    navy = (15, 35, 70, 255)

    # AI AWS smile → plain word mark only
    cover_rect(canvas, (10, 12, 150, 125), white, radius=8)
    word_badge(canvas, 80, 68, "AWS", fill=navy, size=22, pad_x=18, pad_y=12)

    # VPC icon
    cover_rect(canvas, (90, 140, 200, 250), white, radius=4)
    generic_cloud_lock(canvas, 145, 195, 26)

    # Flow Logs
    cover_ellipse(canvas, 1103, 397, 120, white)
    generic_flow_icon(canvas, 1103, 397, 24)

    # S3
    cover_rect(canvas, (1265, 310, 1425, 480), white, radius=6)
    generic_bucket_icon(canvas, 1345, 380, 30)
    word_badge(canvas, 1345, 445, "S3", size=16, pad_x=12, pad_y=5, fill=(40, 100, 50, 255))

    # Security Tooling — wipe AI purple squares
    cover_rect(canvas, (1050, 640, 1420, 800), white, radius=4)
    generic_doc_icon(canvas, 1155, 700, 22)
    word_badge(canvas, 1155, 755, "CloudTrail", size=13, pad_x=9, pad_y=4, fill=(140, 40, 90, 255))
    generic_doc_icon(canvas, 1345, 700, 22)
    word_badge(canvas, 1345, 755, "Config", size=13, pad_x=9, pad_y=4, fill=(140, 40, 90, 255))

    canvas.convert("RGB").save(dst, "PNG", optimize=True)
    print(f"wrote {dst}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--source-dir",
        type=Path,
        required=True,
        help="Directory with pristine Image2 PNGs (required).",
    )
    args = ap.parse_args()
    src = args.source_dir

    composite_lab(src / "aws-landing-zone-lab.png", DIAGRAMS / "aws-landing-zone-lab.png")
    composite_network(
        src / "aws-landing-zone-network.png", DIAGRAMS / "aws-landing-zone-network.png"
    )


if __name__ == "__main__":
    main()
