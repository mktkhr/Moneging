#!/usr/bin/env python3
"""Draws the two fictional receipts of acceptance/fixtures/receipts/.

Usage: python3 draw_receipts.py <receipts-directory>

Needs Pillow and the macOS Hiragino Sans font. The layout is fixed, so the
same script always draws the same picture.
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

FONT_PATH = "/System/Library/Fonts/ヒラギノ角ゴシック W4.ttc"
BOLD_PATH = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"
WIDTH = 420
MARGIN = 36
LINE_HEIGHT = 46
FONT_SIZE = 28

# Each line: (kind, left text, right text). kinds: center, big, row, blank, rule
SEVEN_ELEVEN = [
    ("big", "セブン-イレブン", ""),
    ("center", "新宿三丁目店", ""),
    ("center", "TEL 03-0000-0000", ""),
    ("blank", "", ""),
    ("row", "2026/02/14(土) 12:34", ""),
    ("row", "レジ0012", "責:03"),
    ("rule", "", ""),
    ("row", "おにぎり", "¥380"),
    ("row", "弁当", "¥800"),
    ("rule", "", ""),
    ("row", "小計", "¥1,180"),
    ("bold", "合計", "¥1,180"),
    ("row", "(内消費税等 8%", "¥87)"),
    ("blank", "", ""),
    ("row", "お預り", "¥2,000"),
    ("row", "お釣り", "¥820"),
    ("blank", "", ""),
    ("center", "ありがとうございました", ""),
]

CORNER_DELI = [
    ("big", "コーナーデリ", ""),
    ("center", "本店", ""),
    ("center", "TEL 03-0000-0001", ""),
    ("blank", "", ""),
    ("row", "2026/02/13(金) 18:20", ""),
    ("row", "伝票 0457", ""),
    ("rule", "", ""),
    ("row", "唐揚げ弁当", "¥680"),
    ("row", "+ LARGE RICE", "¥150"),
    ("row", "緑茶", "¥150"),
    ("rule", "", ""),
    ("bold", "合計", "¥980"),
    ("row", "(内消費税等 8%", "¥72)"),
    ("blank", "", ""),
    ("row", "お預り", "¥1,000"),
    ("row", "お釣り", "¥20"),
    ("blank", "", ""),
    ("center", "またのご来店を", ""),
]


def draw(lines: list, path: Path) -> None:
    font = ImageFont.truetype(FONT_PATH, FONT_SIZE, index=0)
    bold = ImageFont.truetype(BOLD_PATH, FONT_SIZE, index=0)
    big = ImageFont.truetype(BOLD_PATH, FONT_SIZE + 10, index=0)
    height = MARGIN * 2 + LINE_HEIGHT * len(lines)
    image = Image.new("L", (WIDTH, height), 255)
    pen = ImageDraw.Draw(image)
    y = MARGIN
    for kind, left, right in lines:
        if kind == "rule":
            pen.line((MARGIN, y + LINE_HEIGHT // 2, WIDTH - MARGIN, y + LINE_HEIGHT // 2), fill=0, width=2)
        elif kind in ("center", "big"):
            face = big if kind == "big" else font
            span = pen.textlength(left, font=face)
            pen.text(((WIDTH - span) / 2, y), left, font=face, fill=0)
        elif kind in ("row", "bold"):
            face = bold if kind == "bold" else font
            pen.text((MARGIN, y), left, font=face, fill=0)
            if right:
                span = pen.textlength(right, font=face)
                pen.text((WIDTH - MARGIN - span, y), right, font=face, fill=0)
        y += LINE_HEIGHT
    image.save(path, "JPEG", quality=70, optimize=True)


def main() -> None:
    target = Path(sys.argv[1])
    target.mkdir(parents=True, exist_ok=True)
    draw(SEVEN_ELEVEN, target / "seven-eleven.jpg")
    draw(CORNER_DELI, target / "corner-deli.jpg")


main()
