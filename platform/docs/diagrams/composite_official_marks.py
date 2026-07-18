#!/usr/bin/env python3
"""Composite unmodified official brand marks onto portfolio PNGs.

Replaces AI-redrawn third-party logos with files from platform/docs/brand/.
Does not recolor, outline, or otherwise alter mark artwork — only scales
uniformly and pastes.

Usage:
  python composite_official_marks.py [--source-dir DIR]
If --source-dir is set, read Image2 PNGs from that directory (idempotent).
Otherwise overwrite diagrams in place (one-shot on current PNGs).
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]  # platform/
BRAND = ROOT / "docs" / "brand"
DIAGRAMS = Path(__file__).resolve().parent


def load_rgba(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def sample_bg(canvas: Image.Image, x: int, y: int) -> tuple[int, int, int, int]:
    px = canvas.getpixel((max(0, x), max(0, y)))
    if len(px) == 3:
        return (px[0], px[1], px[2], 255)
    return px


def cover_ellipse(
    canvas: Image.Image, cx: int, cy: int, diameter: int, fill: tuple[int, int, int, int]
) -> None:
    d = ImageDraw.Draw(canvas)
    r = diameter // 2
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=fill)


def cover_rect(
    canvas: Image.Image,
    box: tuple[int, int, int, int],
    fill: tuple[int, int, int, int],
    radius: int = 4,
) -> None:
    d = ImageDraw.Draw(canvas)
    d.rounded_rectangle(box, radius=radius, fill=fill)


def paste_mark(
    canvas: Image.Image,
    mark: Image.Image,
    cx: int,
    cy: int,
    size: int,
    *,
    knock_white: bool = False,
) -> None:
    m = mark.copy()
    m.thumbnail((size, size), Image.Resampling.LANCZOS)
    if knock_white:
        px = m.load()
        w, h = m.size
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if r > 245 and g > 245 and b > 245:
                    px[x, y] = (r, g, b, 0)
    x0 = cx - m.size[0] // 2
    y0 = cy - m.size[1] // 2
    canvas.alpha_composite(m, (x0, y0))


def paste_aws_icon(
    canvas: Image.Image,
    mark: Image.Image,
    cx: int,
    cy: int,
    size: int,
    *,
    cover_box: tuple[int, int, int, int] | None = None,
    cover_fill: tuple[int, int, int, int] | None = None,
    precover: bool = True,
) -> None:
    """Paste an AWS Architecture / Resource icon. Honors alpha if present."""
    m = mark.convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)
    x0 = cx - size // 2
    y0 = cy - size // 2
    fill = cover_fill or (255, 255, 255, 255)
    if precover:
        box = cover_box or (x0, y0, x0 + size, y0 + size)
        cover_rect(canvas, box, fill, radius=4)
    canvas.alpha_composite(m, (x0, y0))


def draw_aws_wordmark(
    canvas: Image.Image, box: tuple[int, int, int, int], bg: tuple[int, int, int, int]
) -> None:
    cover_rect(canvas, box, bg, radius=10)
    d = ImageDraw.Draw(canvas)
    x0, y0, x1, y1 = box
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    try:
        font = ImageFont.truetype(
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 36
        )
    except OSError:
        font = ImageFont.load_default()
    d.text((cx, cy), "AWS", fill=(255, 255, 255, 255), font=font, anchor="mm")


def composite_lab(src: Path, dst: Path) -> None:
    canvas = load_rgba(src)
    white = (255, 255, 255, 255)

    gh = load_rgba(BRAND / "github-mark-black.png")
    tf = load_rgba(BRAND / "terraform-mark.png")
    vpc = load_rgba(BRAND / "aws" / "vpc.png")
    s3 = load_rgba(BRAND / "aws" / "s3.png")
    flow = load_rgba(BRAND / "aws" / "flow-logs.png")
    trail = load_rgba(BRAND / "aws" / "cloudtrail.png")
    config = load_rgba(BRAND / "aws" / "config.png")

    # B1: AI Invertocat under "Push code" (keep caption text above)
    cover_ellipse(canvas, 109, 932, 100, white)
    paste_mark(canvas, gh, 109, 932, 84)

    # B3: AI cube stand-in → official Terraform mark (keep step numeral + labels)
    cover_rect(canvas, (435, 700, 545, 805), white, radius=4)
    paste_mark(canvas, tf, 490, 752, 82)

    # C: AWS Architecture Icons (unmodified)
    paste_aws_icon(canvas, vpc, 100, 1115, 64, cover_box=(70, 1085, 130, 1145))
    # Flow Logs circular AI mark → official VPC Flow Logs resource icon
    cover_ellipse(canvas, 720, 1145, 112, white)
    paste_aws_icon(canvas, flow, 720, 1145, 64, precover=False)
    # Log Archive S3 line-art bucket
    paste_aws_icon(canvas, s3, 895, 1126, 72, cover_box=(850, 1080, 940, 1172))
    # Security Tooling: cover AI purple squares only (not labels below)
    paste_aws_icon(
        canvas, trail, 780, 1305, 72, cover_box=(720, 1260, 840, 1355)
    )
    paste_aws_icon(
        canvas, config, 900, 1305, 72, cover_box=(840, 1260, 960, 1355)
    )

    canvas.convert("RGB").save(dst, "PNG", optimize=True)
    print(f"wrote {dst}")


def composite_network(src: Path, dst: Path) -> None:
    canvas = load_rgba(src)
    navy = (15, 35, 70, 255)

    vpc = load_rgba(BRAND / "aws" / "vpc.png")
    s3 = load_rgba(BRAND / "aws" / "s3.png")
    flow = load_rgba(BRAND / "aws" / "flow-logs.png")
    trail = load_rgba(BRAND / "aws" / "cloudtrail.png")
    config = load_rgba(BRAND / "aws" / "config.png")

    # AI-redrawn AWS smile → plain text wordmark (no corporate smile recreation)
    draw_aws_wordmark(canvas, (16, 18, 142, 119), navy)

    paste_aws_icon(canvas, vpc, 145, 195, 72, cover_box=(100, 150, 190, 240))

    # Flow Logs
    cover_ellipse(canvas, 1103, 397, 120, (255, 255, 255, 255))
    paste_aws_icon(canvas, flow, 1103, 397, 72, precover=False)

    # Log Archive S3
    paste_aws_icon(
        canvas, s3, 1344, 397, 96, cover_box=(1280, 330, 1410, 470)
    )

    # Security Tooling — cover AI purple squares only (not labels)
    paste_aws_icon(
        canvas, trail, 1153, 710, 96, cover_box=(1055, 645, 1250, 790)
    )
    paste_aws_icon(
        canvas, config, 1343, 710, 96, cover_box=(1285, 645, 1415, 790)
    )

    canvas.convert("RGB").save(dst, "PNG", optimize=True)
    print(f"wrote {dst}")


def composite_architecture(src: Path, dst: Path) -> None:
    canvas = load_rgba(src)
    px = canvas.getpixel((40, 40))
    if px[2] > px[0] + 20 and px[0] < 50:
        draw_aws_wordmark(canvas, (16, 18, 142, 119), (15, 35, 70, 255))
        canvas.convert("RGB").save(dst, "PNG", optimize=True)
        print(f"wrote {dst} (aws wordmark)")
    else:
        print(f"skip {dst.name}: no navy smile at (40,40)={px}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--source-dir",
        type=Path,
        default=None,
        help="Directory with pristine Image2 PNGs (lab/network/architecture).",
    )
    args = ap.parse_args()
    src_dir = args.source_dir or DIAGRAMS

    composite_lab(
        src_dir / "aws-landing-zone-lab.png",
        DIAGRAMS / "aws-landing-zone-lab.png",
    )
    composite_network(
        src_dir / "aws-landing-zone-network.png",
        DIAGRAMS / "aws-landing-zone-network.png",
    )
    arch_src = src_dir / "aws-landing-zone-architecture.png"
    if arch_src.exists():
        composite_architecture(arch_src, DIAGRAMS / "aws-landing-zone-architecture.png")


if __name__ == "__main__":
    main()
