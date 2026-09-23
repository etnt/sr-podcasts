"""Generate the podcastshortcut app icon.

Draws a "headphones + play button" glyph (the classic podcast-player motif)
on a violet-indigo diagonal gradient. Renders everything at 4x and
downsamples with LANCZOS for crisp anti-aliased edges.

Outputs (all 1024x1024) into assets/icon/:
  app_icon.png            full-bleed square master icon
  adaptive_background.png gradient-only background for Android adaptive icons
  adaptive_foreground.png glyph on transparent, scaled into the safe zone
  adaptive_monochrome.png single-color glyph for Android 13 themed icons
  preview.png             legibility check at 48/96/192 px on light and dark
"""

import math
import os

from PIL import Image, ImageDraw

OUT = "/Users/ttornkvi/git/my-podcasts/assets/icon"
S = 4                      # supersample factor
W = 1024 * S               # working canvas size
CX = W / 2

# Gradient endpoints (violet -> deep indigo), diagonal top-left -> bottom-right
C1 = (124, 58, 237)        # #7C3AED
C2 = (55, 48, 163)         # #3730A3


def diagonal_gradient(size, c1, c2):
    """Smooth diagonal gradient built small then upscaled (gradients don't need detail)."""
    small = Image.new("RGB", (64, 64))
    px = small.load()
    for y in range(64):
        for x in range(64):
            t = (x + y) / 126.0
            px[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(c1, c2))
    return small.resize((size, size), Image.BICUBIC)


def draw_glyph(size, color):
    """Draw the headphones+play glyph centered in a square canvas of `size`.

    Glyph bounding design (relative to size): occupies roughly the middle 52%.
    """
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # All coordinates below are in a 1024-unit design space, scaled to `size`.
    k = size / 1024.0

    def p(x, y):
        return (x * k, y * k)

    stroke = round(52 * k)

    # Headband: top half of a circle centered at (512, 560), radius 250.
    r = 250 * k
    cy, cx = 560 * k, 512 * k
    d.arc([cx - r, cy - r, cx + r, cy + r], start=180, end=360,
          fill=color, width=stroke)

    # Round the arc's open ends with small caps.
    cap_r = stroke / 2
    for ex in (cx - r, cx + r):
        d.ellipse([ex - cap_r, cy - cap_r, ex + cap_r, cy + cap_r], fill=color)

    # Ear cups: rounded rectangles under the arc ends.
    cup_w, cup_h, corner = 110 * k, 190 * k, 55 * k
    for ex in (cx - r, cx + r):
        d.rounded_rectangle(
            [ex - cup_w / 2, cy - 50 * k, ex + cup_w / 2, cy - 50 * k + cup_h],
            radius=corner, fill=color)

    # Play triangle, centered in the headband opening.
    tri = [(448, 572), (448, 728), (586, 650)]
    d.polygon([p(x, y) for x, y in tri], fill=color)

    return img


def main():
    os.makedirs(OUT, exist_ok=True)

    # ---- glyph at 4x, then downsampled once ----
    glyph = draw_glyph(W, (255, 255, 255, 255))

    # ---- master icon: gradient + glyph, full bleed ----
    master = diagonal_gradient(W, C1, C2).convert("RGBA")
    master.alpha_composite(glyph)
    master = master.resize((1024, 1024), Image.LANCZOS)
    master.save(os.path.join(OUT, "app_icon.png"))

    # ---- adaptive background: gradient only ----
    diagonal_gradient(1024, C1, C2).save(
        os.path.join(OUT, "adaptive_background.png"))

    # ---- adaptive foreground: full-bleed glyph. flutter_launcher_icons
    # wraps this in a 16% inset, shrinking it to 68% of the layer, so scale
    # the glyph to 88% here: 0.88 * 0.68 ~= 60% of the tile, just inside the
    # 66% safe zone.
    safe = 0.88
    glyph_small = glyph.resize((round(1024 * safe),) * 2, Image.LANCZOS)
    fg = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    off = (1024 - glyph_small.width) // 2
    fg.alpha_composite(glyph_small, (off, off))
    fg.save(os.path.join(OUT, "adaptive_foreground.png"))

    # ---- monochrome (Android 13 themed icons): pure-white glyph ----
    mono_glyph = draw_glyph(W, (255, 255, 255, 255)).resize(
        (round(1024 * safe),) * 2, Image.LANCZOS)
    mono = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    mono.alpha_composite(mono_glyph, (off, off))
    mono.save(os.path.join(OUT, "adaptive_monochrome.png"))

    # ---- legibility preview ----
    cells = 5
    cell = 240
    pv = Image.new("RGB", (cells * cell, 2 * cell), (250, 250, 250))
    dark = Image.new("RGB", (cells * cell, cell), (18, 18, 22))
    pv.paste(dark, (0, cell))
    for row, bg_top in enumerate((0, cell)):
        for i, px in enumerate((48, 72, 96, 144, 192)):
            ic = master.resize((px, px), Image.LANCZOS)
            x = i * cell + (cell - px) // 2
            y = bg_top + (cell - px) // 2
            # drop shadow so the shape reads against both backgrounds
            sh = Image.new("RGBA", (px + 20, px + 20), (0, 0, 0, 0))
            ImageDraw.Draw(sh).rounded_rectangle(
                [10, 10, px + 10, px + 10], radius=px // 5, fill=(0, 0, 0, 90))
            sh = sh.resize((px + 20, px + 20))
            pv.paste(Image.new("RGB", sh.size, (0, 0, 0)), (x - 10, y - 10),
                     sh)
            pv.paste(ic, (x, y))
    pv.save(os.path.join(OUT, "preview.png"))
    print("wrote:", sorted(os.listdir(OUT)))


if __name__ == "__main__":
    main()
