#!/usr/bin/env python3
"""
Deterministic pixel-art post-processing pipeline for Kaizo Trap (Godot 4).
Converts AI-generated high-res pixel art concepts into crisp, grid-aligned,
palette-quantized sprites, tilesets, and Godot SpriteFrames (.tres) resources.
"""

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image


# Locked 16-bit Kaizo Trap canonical master palette (sampled from reference frames)
PALETTES = {
    "master": [
        (13, 12, 20),     # Deep CRT black / thick cartoon outline
        (28, 34, 62),     # Dark navy (manual headers / shadows)
        (56, 62, 86),     # Dark slate / factory steel shadow
        (100, 106, 126),  # Metallic shell / steel mid
        (170, 178, 198),  # Light steel / manual grey
        (246, 248, 255),  # Pure white / laser core / manual paper
        # Kai (exact canon: orange-red ponytail, lavender bow & dress, warm cream skin)
        (250, 212, 168),  # Skin light
        (218, 166, 120),  # Skin shadow
        (232, 86, 42),    # Kai bright orange-red hair
        (168, 46, 28),    # Kai hair shadow
        (208, 160, 255),  # Kai lavender dress / bow light
        (148, 96, 218),   # Kai lavender dress / bow shadow
        (242, 182, 214),  # Kai pinkish-lavender shoes
        # Zo (canon: reddish-brown spiky hair, sky-blue tee, grey-blue pants)
        (74, 184, 255),   # Zo sky-blue shirt / bright overworld sky
        (38, 126, 204),   # Sky / water mid blue
        (176, 78, 56),    # Zo reddish-brown hair
        # Kaizo Trap iconic blocks, hazards & biomes
        (255, 212, 28),   # Golden-yellow Bagua Kaizo block
        (206, 138, 18),   # Kaizo block / manual orange shadow
        (246, 134, 54),   # Manual accent orange / shell core glow / Y door
        (142, 204, 24),   # Overworld bright lime grass
        (76, 148, 28),    # Overworld dark grass
        (166, 102, 54),   # Dirt / coconut light
        (104, 58, 32),    # Dirt / coconut dark
        (164, 232, 255),  # Electric spike / Ice highlight / N door
        (74, 168, 224),   # Ice mid
        (246, 72, 48),    # Lava / Danger red-orange
        (194, 24, 52),    # Crimson blood splat / Boss red eyes
        (164, 62, 232),   # Glitch violet
        (68, 236, 168),   # ZhugeDOS phosphor green
        (24, 112, 78),    # ZhugeDOS dark green
        (255, 72, 184),   # Glitch hot pink
        (228, 214, 72),   # Warning hazard stripe yellow
    ]
}


def clean_alpha(img: Image.Image, alpha_threshold: int = 128) -> Image.Image:
    """Harden semi-transparent fringes into crisp pixel-art binary alpha."""
    rgba = np.array(img.convert("RGBA"))
    alpha = rgba[:, :, 3]
    rgba[alpha < alpha_threshold] = [0, 0, 0, 0]
    rgba[alpha >= alpha_threshold, 3] = 255
    return Image.fromarray(rgba)


def trim_and_pad_cell(
    cell: Image.Image,
    target_w: int,
    target_h: int,
    align_bottom: bool = True,
    pad: int = 1,
) -> Image.Image:
    """Crop opaque bounding box of a single sprite frame, scale cleanly into target cell."""
    cell = clean_alpha(cell, alpha_threshold=96)
    bbox = cell.getbbox()
    canvas = Image.new("RGBA", (target_w, target_h), (0, 0, 0, 0))
    if not bbox:
        return canvas

    cropped = cell.crop(bbox)
    max_w = max(1, target_w - pad * 2)
    max_h = max(1, target_h - pad * 2)
    scale = min(max_w / cropped.width, max_h / cropped.height)
    new_w = max(1, int(round(cropped.width * scale)))
    new_h = max(1, int(round(cropped.height * scale)))

    # Box downsampling followed by alpha hardening + palette quantization keeps silhouettes crisp
    resized = cropped.resize((new_w, new_h), Image.Resampling.BOX)
    resized = clean_alpha(resized, alpha_threshold=110)

    x = (target_w - new_w) // 2
    y = (target_h - new_h - pad) if align_bottom else (target_h - new_h) // 2
    canvas.paste(resized, (x, y), resized)
    return canvas


def quantize_palette(img: Image.Image, palette_name: str = "master") -> Image.Image:
    """Snap all opaque pixels to nearest color in locked palette without dithering."""
    rgba = np.array(img.convert("RGBA"))
    mask = rgba[:, :, 3] > 0
    if not np.any(mask):
        return img

    pal = np.array(PALETTES[palette_name], dtype=np.int32)
    pixels = rgba[mask][:, :3].astype(np.int32)
    # Weighted Euclidean distance (perceptual RGB weights)
    diff = pixels[:, None, :] - pal[None, :, :]
    weights = np.array([2, 4, 3], dtype=np.int32)
    dist = np.sum((diff * diff) * weights, axis=2)
    nearest = np.argmin(dist, axis=1)
    rgba[mask, :3] = pal[nearest].astype(np.uint8)
    rgba[mask, 3] = 255
    return Image.fromarray(rgba)


def process_grid_sheet(
    src: Path,
    dst: Path,
    cols: int,
    rows: int,
    cell_w: int,
    cell_h: int,
    align_bottom: bool = True,
    quantize: bool = True,
    pad: int = 1,
    direct_tile: bool = False,
) -> Path:
    """Split a generated cols x rows sheet and re-pack to exact pixel dimensions."""
    img = Image.open(src).convert("RGBA")
    src_cw = img.width / cols
    src_ch = img.height / rows

    out = Image.new("RGBA", (cols * cell_w, rows * cell_h), (0, 0, 0, 0))
    for r in range(rows):
        for c in range(cols):
            box = (
                int(round(c * src_cw)),
                int(round(r * src_ch)),
                int(round((c + 1) * src_cw)),
                int(round((r + 1) * src_ch)),
            )
            tile = img.crop(box)
            if direct_tile:
                tile = tile.resize((cell_w, cell_h), Image.Resampling.BOX)
                tile = clean_alpha(tile, alpha_threshold=110)
            else:
                tile = trim_and_pad_cell(tile, cell_w, cell_h, align_bottom=align_bottom, pad=pad)
            if quantize:
                tile = quantize_palette(tile)
            out.paste(tile, (c * cell_w, r * cell_h))

    dst.parent.mkdir(parents=True, exist_ok=True)
    out.save(dst)
    print(f"[PIXEL] {src.name} -> {dst} ({out.width}x{out.height}, {cols}x{rows} of {cell_w}x{cell_h})")
    return dst


def process_single(
    src: Path,
    dst: Path,
    width: int,
    height: int,
    quantize: bool = True,
    keep_alpha: bool = True,
) -> Path:
    """Downsample a single sprite/background/manual image cleanly."""
    img = Image.open(src).convert("RGBA")
    resized = img.resize((width, height), Image.Resampling.BOX)
    if keep_alpha:
        resized = clean_alpha(resized, alpha_threshold=110)
    else:
        arr = np.array(resized)
        arr[:, :, 3] = 255
        resized = Image.fromarray(arr, mode="RGBA")
    if quantize:
        resized = quantize_palette(resized)
    dst.parent.mkdir(parents=True, exist_ok=True)
    resized.save(dst)
    print(f"[PIXEL] {src.name} -> {dst} ({width}x{height})")
    return dst


def process_smart_grid(
    src: Path,
    dst: Path,
    cols: int,
    rows: int,
    cell_w: int,
    cell_h: int,
    align_bottom: bool = True,
    quantize: bool = True,
    pad: int = 1,
    dilate_px: int = 18,
) -> Path:
    """Detect the exact cols*rows sprite blobs via connected components (no clipped heads!),
    sort into row-major order, and normalize scale across all sprites."""
    import cv2

    img = clean_alpha(Image.open(src).convert("RGBA"), alpha_threshold=90)
    rgba = np.array(img)
    mask = (rgba[:, :, 3] > 0).astype(np.uint8) * 255

    expected = cols * rows
    blobs = []
    # Auto-search dilation radius so adjacent sprites never merge and detached marks stay grouped
    for try_dilate in [dilate_px, 6, 4, 2, 1, 0, 10, 14]:
        if try_dilate > 0:
            kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (try_dilate * 2 + 1, try_dilate * 2 + 1))
            merged = cv2.dilate(mask, kernel, iterations=1)
        else:
            merged = mask
        num_labels, labels, stats, centroids = cv2.connectedComponentsWithStats(merged, connectivity=8)

        cand = []
        for idx in range(1, num_labels):
            area = stats[idx, cv2.CC_STAT_AREA]
            if area < 1500:
                continue
            x, y, w, h = (
                stats[idx, cv2.CC_STAT_LEFT],
                stats[idx, cv2.CC_STAT_TOP],
                stats[idx, cv2.CC_STAT_WIDTH],
                stats[idx, cv2.CC_STAT_HEIGHT],
            )
            sub_mask = mask[y : y + h, x : x + w]
            ys, xs = np.where(sub_mask > 0)
            if len(xs) == 0:
                continue
            x0, x1 = x + int(xs.min()), x + int(xs.max()) + 1
            y0, y1 = y + int(ys.min()), y + int(ys.max()) + 1
            cand.append({
                "box": (x0, y0, x1, y1),
                "cx": (x0 + x1) * 0.5,
                "cy": (y0 + y1) * 0.5,
                "w": x1 - x0,
                "h": y1 - y0,
                "area": (x1 - x0) * (y1 - y0),
            })
        if len(cand) >= expected:
            cand.sort(key=lambda b: b["area"], reverse=True)
            blobs = cand[:expected]
            print(f"[SMART-PIXEL] Matched {expected} clean sprites at dilate={try_dilate}px for {src.name}")
            break

    if len(blobs) != expected:
        print(f"[WARN] Expected {expected} blobs in {src.name}, found {len(blobs)}; falling back to uniform grid.")
        return process_grid_sheet(src, dst, cols, rows, cell_w, cell_h, align_bottom, quantize, pad)

    # Sort into rows by cy, then within each row by cx
    blobs.sort(key=lambda b: b["cy"])
    ordered = []
    for r in range(rows):
        row_blobs = sorted(blobs[r * cols : (r + 1) * cols], key=lambda b: b["cx"])
        ordered.extend(row_blobs)

    # Compute uniform global scale based on median/max sprite dimension so character stays consistent size!
    max_dim = max(max(b["w"], b["h"]) for b in ordered)
    max_target = min(cell_w - pad * 2, cell_h - pad * 2)
    global_scale = max_target / max(1.0, float(max_dim))

    out = Image.new("RGBA", (cols * cell_w, rows * cell_h), (0, 0, 0, 0))
    for i, b in enumerate(ordered):
        r, c = divmod(i, cols)
        cropped = img.crop(b["box"])
        nw = max(1, min(cell_w - pad * 2, int(round(cropped.width * global_scale))))
        nh = max(1, min(cell_h - pad * 2, int(round(cropped.height * global_scale))))
        resized = cropped.resize((nw, nh), Image.Resampling.BOX)
        resized = clean_alpha(resized, alpha_threshold=110)
        if quantize:
            resized = quantize_palette(resized)
        cell = Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0))
        ox = (cell_w - nw) // 2
        oy = (cell_h - nh - pad) if align_bottom else (cell_h - nh) // 2
        cell.paste(resized, (ox, oy), resized)
        out.paste(cell, (c * cell_w, r * cell_h))

    dst.parent.mkdir(parents=True, exist_ok=True)
    out.save(dst)
    print(f"[SMART-PIXEL] {src.name} -> {dst} ({out.width}x{out.height}, {len(ordered)} clean sprites)")
    return dst


def main():
    parser = argparse.ArgumentParser(description="Pixel-art post-processor for Kaizo Trap.")
    sub = parser.add_subparsers(dest="cmd", required=True)

    for name in ("grid", "smart-grid"):
        g = sub.add_parser(name, help="Process a cols x rows sprite/tile sheet.")
        g.add_argument("src", type=Path)
        g.add_argument("dst", type=Path)
        g.add_argument("--cols", type=int, required=True)
        g.add_argument("--rows", type=int, required=True)
        g.add_argument("--cell-w", type=int, required=True)
        g.add_argument("--cell-h", type=int, required=True)
        g.add_argument("--center", action="store_true")
        g.add_argument("--no-quantize", action="store_true")
        g.add_argument("--direct-tile", action="store_true")
        g.add_argument("--pad", type=int, default=1)
        g.add_argument("--dilate", type=int, default=18)

    s = sub.add_parser("single", help="Process a single image.")
    s.add_argument("src", type=Path)
    s.add_argument("dst", type=Path)
    s.add_argument("--width", type=int, required=True)
    s.add_argument("--height", type=int, required=True)
    s.add_argument("--no-quantize", action="store_true")
    s.add_argument("--opaque", action="store_true")

    args = parser.parse_args()
    if args.cmd == "grid":
        process_grid_sheet(
            args.src,
            args.dst,
            args.cols,
            args.rows,
            args.cell_w,
            args.cell_h,
            align_bottom=not args.center,
            quantize=not args.no_quantize,
            pad=args.pad,
            direct_tile=args.direct_tile,
        )
    elif args.cmd == "smart-grid":
        process_smart_grid(
            args.src,
            args.dst,
            args.cols,
            args.rows,
            args.cell_w,
            args.cell_h,
            align_bottom=not args.center,
            quantize=not args.no_quantize,
            pad=args.pad,
            dilate_px=args.dilate,
        )
    elif args.cmd == "single":
        process_single(
            args.src,
            args.dst,
            args.width,
            args.height,
            quantize=not args.no_quantize,
            keep_alpha=not args.opaque,
        )


if __name__ == "__main__":
    main()
