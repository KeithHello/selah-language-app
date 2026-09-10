"""Derive RGBA runtime poses from the preserved, plain-background V4 designs.

Uses the existing Pillow/NumPy environment. Outputs go to output/plush-alpha
for visual review before being copied to assets/sprites. All poses share one
crop and scale so their original body proportions and animation framing stay
consistent. No generated replacement artwork or external API is involved.
"""

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[2]
DESIGNS = ROOT / "design-system/selah/mascot"
OUTPUT = ROOT / "output/plush-alpha"


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def filled_mask(mask):
    # Flood only the outside; enclosed pale fabric remains fully opaque.
    small = mask.resize((mask.width // 4, mask.height // 4), Image.Resampling.NEAREST)
    outside = small.copy()
    ImageDraw.floodfill(outside, (0, 0), 128)
    holes = Image.fromarray(np.where(np.asarray(outside) == 0, 255, 0).astype("uint8"))
    holes = holes.resize(mask.size, Image.Resampling.NEAREST)
    return Image.fromarray(np.maximum(np.asarray(mask), np.asarray(holes)))


def connected_body(mask):
    # Discard detached floor specks while keeping the original detailed edge.
    small = mask.resize((mask.width // 4, mask.height // 4), Image.Resampling.NEAREST)
    ys, xs = np.where(np.asarray(small) > 0)
    center = np.argmin((xs - np.median(xs)) ** 2 + (ys - np.median(ys)) ** 2)
    ImageDraw.floodfill(small, (int(xs[center]), int(ys[center])), 128)
    connected = Image.fromarray(np.where(np.asarray(small) == 128, 255, 0).astype("uint8"))
    return connected.resize(mask.size, Image.Resampling.NEAREST).filter(ImageFilter.MaxFilter(5))


def cutout(source):
    rgb = np.asarray(source.convert("RGB"), dtype=np.float32)
    height, width, _ = rgb.shape
    strip = max(8, width // 25)
    sides = np.stack(
        (np.median(rgb[:, :strip], axis=1), np.median(rgb[:, -strip:], axis=1)),
        axis=1,
    )
    sides = np.asarray(
        Image.fromarray(sides.astype("uint8")).filter(ImageFilter.GaussianBlur(8)),
        dtype=np.float32,
    )
    x = np.linspace(0, 1, width)[None, :, None]
    background = sides[:, :1] * (1 - x) + sides[:, 1:] * x
    distance = np.max(np.abs(background - rgb), axis=2)

    # Horizontal fabric detail separates feet from the smooth floor shadow.
    # An isotropic high-pass also detects the shadow's horizontal light edge.
    texture = np.zeros((height, width))
    texture[:, 2:-2] = np.max(
        np.abs(rgb[:, :-4] + rgb[:, 4:] - 2 * rgb[:, 2:-2]), axis=2
    )
    density = np.asarray(
        Image.fromarray((texture > 4).astype("uint8") * 255).filter(ImageFilter.BoxBlur(4)),
        dtype=float,
    ) / 255
    lower = np.broadcast_to(np.arange(height)[:, None] > height * .70, (height, width))
    solid = distance >= 38
    solid[lower] &= density[lower] > .35
    core = Image.fromarray(np.where(solid, 255, 0).astype("uint8"))
    lower_top = int(height * .70) - 16
    lower_core = core.crop((0, lower_top, width, height))
    lower_core = lower_core.filter(ImageFilter.MaxFilter(15)).filter(ImageFilter.MinFilter(15))
    lower_core = lower_core.filter(ImageFilter.MinFilter(15)).filter(ImageFilter.MaxFilter(15))
    core.paste(lower_core, (0, lower_top))
    core = core.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(5))
    core = filled_mask(core)
    # Remove detached specks and very thin remnants of the studio floor.
    core = core.filter(ImageFilter.MinFilter(5)).filter(ImageFilter.MaxFilter(5))
    connected = np.asarray(connected_body(core)) > 0
    core = Image.fromarray(np.where(lower & ~connected, 0, np.asarray(core)).astype("uint8"))
    band = np.asarray(core.filter(ImageFilter.MaxFilter(11))) > 0
    alpha = np.clip((distance - 8) / 30, 0, 1)
    alpha[~band] = 0
    alpha[np.asarray(core) > 0] = 1
    alpha[alpha < 1 / 255] = 0

    # Remove the baked-in warm matte only in partially covered edge pixels.
    # Fully opaque character pixels are preserved exactly at source resolution.
    foreground = np.clip(
        (rgb - background * (1 - alpha[:, :, None]))
        / np.maximum(alpha[:, :, None], 1 / 255),
        0,
        255,
    )
    foreground[alpha == 0] = 0

    # Keep only the textured lower silhouette, with a short antialiased edge.
    coverage = np.asarray(core.filter(ImageFilter.GaussianBlur(.8)), dtype=float) / 255
    floor_weight = np.where(lower, 1 - coverage, 0)
    shadow = np.clip((distance - 8) / np.maximum(background.max(axis=2) - 24, 1), 0, .65)
    subject = alpha * (1 - floor_weight)
    shadow *= floor_weight
    combined = subject + shadow * (1 - subject)
    foreground = (foreground * subject[:, :, None] + 24 * (shadow * (1 - subject))[:, :, None]) / np.maximum(combined[:, :, None], 1 / 255)
    alpha = combined
    foreground[alpha == 0] = 0
    rgba = np.dstack((foreground, alpha * 255)).round().astype("uint8")
    return Image.fromarray(rgba)


def review_sheet(poses, background, destination):
    cell_w, cell_h = 168, 198
    sheet = Image.new("RGB", (cell_w * 10, cell_h * 5), background)
    draw = ImageDraw.Draw(sheet)
    ink = "#E9E9E9" if background == "#29372F" else "#524D46"
    for i, (_, pose, _) in enumerate(poses):
        x, y = (i % 10) * cell_w, (i // 10) * cell_h
        small = pose.resize((160, 160), Image.Resampling.LANCZOS)
        sheet.paste(small, (x + 4, y + 4), small)
        draw.text((x + 10, y + 173), f"S{i // 10 + 1} / A{i % 10 + 1:02}", fill=ink)
    sheet.save(destination)


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    poses = []
    for stage in range(1, 6):
        for action in range(1, 11):
            source = DESIGNS / f"seed-c-s{stage}-a{action:02}-v4.png"
            with Image.open(source) as image:
                if image.size != (1254, 1254) or image.mode != "RGB":
                    raise ValueError(f"Unexpected source format: {source.name}")
                pose = cutout(image)
            poses.append((f"PlushV4S{stage}A{action:02}.png", pose, source))
        print(f"Matted stage {stage}/5", flush=True)

    bounds = [pose.getchannel("A").getbbox() for _, pose, _ in poses]
    left = min(b[0] for b in bounds)
    top = min(b[1] for b in bounds)
    right = max(b[2] for b in bounds)
    bottom = max(b[3] for b in bounds)
    side = max(right - left, bottom - top) + 48
    x = round((left + right - side) / 2)
    y = round((top + bottom - side) / 2)
    crop = (x, y, x + side, y + side)
    entries = []
    published = []
    for name, pose, source in poses:
        pose = pose.crop(crop).resize((768, 768), Image.Resampling.LANCZOS)
        destination = OUTPUT / name
        pose.save(destination, optimize=True)
        alpha = np.asarray(pose.getchannel("A"))
        if not (np.any(alpha == 0) and np.any(alpha == 255) and np.any((alpha > 0) & (alpha < 255))):
            raise ValueError(f"Missing transparency or solid subject: {name}")
        if any(np.any(edge) for edge in (alpha[0], alpha[-1], alpha[:, 0], alpha[:, -1])):
            raise ValueError(f"Clipped silhouette: {name}")
        entries.append({
            "file": name,
            "source": source.name,
            "sourceSha256": sha256(source),
            "sha256": sha256(destination),
            "mode": "RGBA",
            "width": 768,
            "height": 768,
            "transparentPixels": int(np.count_nonzero(alpha == 0)),
            "partialPixels": int(np.count_nonzero((alpha > 0) & (alpha < 255))),
            "opaquePixels": int(np.count_nonzero(alpha == 255)),
        })
        published.append((name, pose, source))

    (OUTPUT / "manifest.json").write_text(json.dumps({
        "sourceVersion": "C V4, preserved RGB design masters",
        "method": "local background matte, solid interior, edge decontamination",
        "sharedSourceCrop": crop,
        "assets": entries,
    }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    review_sheet(published, "#FBF8F4", OUTPUT / "review-warm.png")
    review_sheet(published, "#29372F", OUTPUT / "review-dark.png")
    print(json.dumps({
        "assets": len(entries), "crop": crop,
        "bytes": sum((OUTPUT / e["file"]).stat().st_size for e in entries),
        "output": str(OUTPUT),
    }))


if __name__ == "__main__":
    main()
