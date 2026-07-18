#!/usr/bin/env python3
"""Wipe AI-drawn third-party logos; keep diagram text as word marks.

Does not paste brand artwork or sticker badges. Erases logo pixels and draws
simple generic line icons. Product names already appear as text in the figure.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

DIAGRAMS = Path(__file__).resolve().parent


def load_rgba(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def font(size: int) -> ImageFont.ImageFont:
    try:
        return ImageFont.truetype(
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", size
        )
    except OSError:
        return ImageFont.load_default()


def cover_rect(
    canvas: Image.Image,
    box: tuple[int, int, int, int],
    fill: tuple[int, int, int, int],
    radius: int = 2,
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


def plain_text(
    canvas: Image.Image,
    cx: int,
    cy: int,
    text: str,
    *,
    fill: tuple[int, int, int, int] = (20, 40, 70, 255),
    size: int = 16,
) -> None:
    d = ImageDraw.Draw(canvas)
    d.text((cx, cy), text, fill=fill, font=font(size), anchor="mm")


def generic_git_icon(canvas: Image.Image, cx: int, cy: int, scale: int = 26) -> None:
    d = ImageDraw.Draw(canvas)
    ink = (20, 40, 70, 255)
    d.line((cx, cy - scale, cx, cy + scale), fill=ink, width=3)
    d.line((cx, cy, cx + scale, cy - scale // 2), fill=ink, width=3)
    for px, py in ((cx, cy - scale), (cx, cy + scale), (cx + scale, cy - scale // 2)):
        d.ellipse((px - 5, py - 5, px + 5, py + 5), fill=ink)


def generic_blocks_icon(canvas: Image.Image, cx: int, cy: int, scale: int = 20) -> None:
    d = ImageDraw.Draw(canvas)
    ink = (20, 40, 70, 255)
    s = scale
    for box in (
        (cx - s, cy - s // 3, cx, cy + s // 2),
        (cx, cy - s // 3, cx + s, cy + s // 2),
        (cx - s // 2, cy - s, cx + s // 2, cy - s // 6),
    ):
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


def generic_doc_icon(canvas: Image.Image, cx: int, cy: int, scale: int = 20) -> None:
    d = ImageDraw.Draw(canvas)
    ink = (70, 50, 100, 255)
    d.rounded_rectangle(
        (cx - scale // 2, cy - scale, cx + scale // 2, cy + scale),
        radius=3,
        outline=ink,
        width=2,
    )
    for y in (cy - scale // 2, cy, cy + scale // 2):
        d.line((cx - scale // 3, y, cx + scale // 3, y), fill=ink, width=2)


def generic_cloud_lock(canvas: Image.Image, cx: int, cy: int, scale: int = 24) -> None:
    d = ImageDraw.Draw(canvas)
    ink = (40, 100, 70, 255)
    d.ellipse(
        (cx - scale, cy - scale // 2, cx + scale // 3, cy + scale // 2),
        outline=ink,
        width=2,
    )
    d.ellipse(
        (cx - scale // 3, cy - scale // 2, cx + scale, cy + scale // 2),
        outline=ink,
        width=2,
    )
    d.rounded_rectangle((cx - 8, cy, cx + 8, cy + 14), radius=2, outline=ink, width=2)


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
    plate = (254, 254, 255, 255)
    plate_tf = (251, 251, 251, 255)

    # B1 Invertocat → git branch (caption already says GitHub)
    cover_rect(canvas, (40, 850, 190, 985), plate)
    generic_git_icon(canvas, 115, 915, 24)

    # B3 Terraform mark/cube → generic blocks (caption already says Terraform)
    cover_rect(canvas, (435, 695, 545, 815), plate_tf)
    generic_blocks_icon(canvas, 490, 755, 20)

    # C AWS service redraws → generic icons (labels already in diagram)
    cover_rect(canvas, (50, 1065, 150, 1165), plate)
    generic_cloud_lock(canvas, 100, 1115, 22)

    cover_ellipse(canvas, 720, 1145, 100, plate)
    generic_flow_icon(canvas, 720, 1145, 20)

    cover_rect(canvas, (820, 1075, 960, 1215), plate)
    generic_bucket_icon(canvas, 890, 1135, 24)
    plain_text(canvas, 890, 1188, "S3", size=15, fill=(30, 90, 50, 255))

    # Security Tooling: wipe AI purple squares only; keep existing labels if possible
    cover_rect(canvas, (730, 1270, 840, 1360), plate)
    generic_doc_icon(canvas, 785, 1315, 18)
    cover_rect(canvas, (850, 1270, 960, 1360), plate)
    generic_doc_icon(canvas, 905, 1315, 18)

    canvas.convert("RGB").save(dst, "PNG", optimize=True)
    print(f"wrote {dst}")


def composite_network(src: Path, dst: Path) -> None:
    canvas = load_rgba(src)
    bg = (249, 249, 252, 255)
    navy = (15, 35, 70, 255)

    # AI AWS smile → plain text word mark only
    cover_rect(canvas, (12, 14, 148, 122), bg, radius=8)
    plain_text(canvas, 80, 68, "AWS", size=28, fill=navy)

    cover_rect(canvas, (90, 140, 200, 250), bg)
    generic_cloud_lock(canvas, 145, 195, 26)

    cover_ellipse(canvas, 1103, 397, 120, bg)
    generic_flow_icon(canvas, 1103, 397, 24)

    cover_rect(canvas, (1265, 310, 1425, 470), bg)
    generic_bucket_icon(canvas, 1345, 380, 30)
    plain_text(canvas, 1345, 445, "S3", size=18, fill=(30, 90, 50, 255))

    # Security tooling — wipe full AI purple icon row
    cover_rect(canvas, (1055, 645, 1415, 800), bg)
    generic_doc_icon(canvas, 1155, 710, 22)
    plain_text(canvas, 1155, 760, "CloudTrail", size=14, fill=(90, 40, 80, 255))
    generic_doc_icon(canvas, 1345, 710, 22)
    plain_text(canvas, 1345, 760, "Config", size=14, fill=(90, 40, 80, 255))

    canvas.convert("RGB").save(dst, "PNG", optimize=True)
    print(f"wrote {dst}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source-dir", type=Path, required=True)
    args = ap.parse_args()
    src = args.source_dir
    composite_lab(src / "aws-landing-zone-lab.png", DIAGRAMS / "aws-landing-zone-lab.png")
    composite_network(
        src / "aws-landing-zone-network.png", DIAGRAMS / "aws-landing-zone-network.png"
    )


if __name__ == "__main__":
    main()
