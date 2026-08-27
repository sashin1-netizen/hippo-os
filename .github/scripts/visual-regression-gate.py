#!/usr/bin/env python3
"""Evidence-driven visual gate for the Android 16 sanctuary screenshot.

This is deliberately a composition/profile gate, not a claim of production art approval.
It rejects the historical failure modes (black frames, flat prototype ground, cyan water,
missing hero subject, missing HUD structure) and scores the emulator frame against the
approved Grasslands Sanctuary layout profile. Physical-phone review remains mandatory.
"""

from __future__ import annotations

import colorsys
import json
import math
import sys
from pathlib import Path
from typing import Dict, Iterable, List, Tuple

from PIL import Image, ImageFilter, ImageStat


def crop_norm(image: Image.Image, region: List[float]) -> Image.Image:
    x1, y1, x2, y2 = region
    return image.crop(
        (
            int(image.width * x1),
            int(image.height * y1),
            int(image.width * x2),
            int(image.height * y2),
        )
    )


def sample_pixels(image: Image.Image, max_width: int = 180) -> Iterable[Tuple[int, int, int]]:
    if image.width > max_width:
        ratio = max_width / float(image.width)
        image = image.resize((max_width, max(1, int(image.height * ratio))))
    return image.convert("RGB").getdata()


def rgb_stats(image: Image.Image) -> Dict[str, float]:
    rgb = image.convert("RGB")
    stat = ImageStat.Stat(rgb)
    gray = rgb.convert("L")
    gray_stat = ImageStat.Stat(gray)
    means = stat.mean
    return {
        "mean_r": float(means[0]),
        "mean_g": float(means[1]),
        "mean_b": float(means[2]),
        "mean_luma": float(gray_stat.mean[0]),
        "stddev": float(max(stat.stddev)),
        "blue_dominance": float(means[2] - max(means[0], means[1])),
    }


def average_saturation(image: Image.Image) -> float:
    values = []
    for r, g, b in sample_pixels(image):
        _, saturation, _ = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
        values.append(saturation)
    return sum(values) / max(1, len(values))


def edge_density(image: Image.Image) -> float:
    gray = image.convert("L")
    if gray.width > 240:
        ratio = 240 / float(gray.width)
        gray = gray.resize((240, max(1, int(gray.height * ratio))))
    edges = gray.filter(ImageFilter.FIND_EDGES)
    pixels = list(edges.getdata())
    if not pixels:
        return 0.0
    return sum(1 for value in pixels if value >= 30) / float(len(pixels))


def fraction(image: Image.Image, predicate) -> float:
    pixels = list(sample_pixels(image))
    if not pixels:
        return 0.0
    return sum(1 for pixel in pixels if predicate(*pixel)) / float(len(pixels))


def natural_color_fraction(image: Image.Image) -> float:
    def natural(r: int, g: int, b: int) -> bool:
        h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
        if not (0.10 <= v <= 0.98 and s >= 0.16):
            return False
        green = 0.16 <= h <= 0.46
        earth = 0.035 <= h <= 0.16
        water = 0.47 <= h <= 0.66
        return green or earth or water

    return fraction(image, natural)


def foreground_fraction(image: Image.Image, sky_luma: float) -> float:
    cutoff = max(45.0, sky_luma - 32.0)

    def foreground(r: int, g: int, b: int) -> bool:
        luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
        mx = max(r, g, b) / 255.0
        mn = min(r, g, b) / 255.0
        saturation = 0.0 if mx <= 0.0 else (mx - mn) / mx
        return 18.0 <= luma <= cutoff and saturation <= 0.72

    return fraction(image, foreground)


def metric_score(checks: List[Tuple[str, bool]], weight: float, report: Dict[str, object]) -> float:
    passed = sum(1 for _, ok in checks if ok)
    for name, ok in checks:
        report[name] = bool(ok)
    return weight * (passed / float(max(1, len(checks))))


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: visual-regression-gate.py SCREENSHOT PROFILE [OUTPUT_JSON]", file=sys.stderr)
        return 2

    image_path = Path(sys.argv[1])
    profile_path = Path(sys.argv[2])
    output_path = Path(sys.argv[3]) if len(sys.argv) >= 4 else None

    image = Image.open(image_path).convert("RGB")
    profile = json.loads(profile_path.read_text(encoding="utf-8"))
    report: Dict[str, object] = {
        "reference_id": profile["reference_id"],
        "image": str(image_path),
        "width": image.width,
        "height": image.height,
    }

    aspect = image.width / float(max(1, image.height))
    portrait = profile["portrait"]
    aspect_ok = portrait["min_aspect_ratio"] <= aspect <= portrait["max_aspect_ratio"]
    report["aspect_ratio"] = aspect
    report["portrait_aspect_ok"] = aspect_ok
    if not aspect_ok:
        report["score"] = 0.0
        report["passed"] = False
        if output_path:
            output_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(json.dumps(report, indent=2))
        return 1

    total = 0.0

    sky_cfg = profile["sky"]
    sky = crop_norm(image, sky_cfg["region"])
    sky_stats = rgb_stats(sky)
    sky_sat = average_saturation(sky)
    report["sky"] = {**sky_stats, "saturation": sky_sat}
    total += metric_score(
        [
            ("sky_luma_ok", sky_stats["mean_luma"] >= sky_cfg["minimum_mean_luma"]),
            ("sky_blue_ok", sky_stats["blue_dominance"] >= sky_cfg["minimum_blue_dominance"]),
            ("sky_saturation_ok", sky_sat >= sky_cfg["minimum_saturation"]),
        ],
        sky_cfg["weight"],
        report,
    )

    world_cfg = profile["world"]
    world = crop_norm(image, world_cfg["region"])
    world_stats = rgb_stats(world)
    world_black = fraction(world, lambda r, g, b: r <= 8 and g <= 8 and b <= 8)
    world_natural = natural_color_fraction(world)
    world_edges = edge_density(world)
    report["world"] = {
        **world_stats,
        "black_fraction": world_black,
        "natural_color_fraction": world_natural,
        "edge_density": world_edges,
    }
    total += metric_score(
        [
            ("world_detail_ok", world_stats["stddev"] >= world_cfg["minimum_stddev"]),
            ("world_not_black_ok", world_black <= world_cfg["maximum_black_fraction"]),
            ("world_natural_palette_ok", world_natural >= world_cfg["minimum_natural_color_fraction"]),
            ("world_depth_edges_ok", world_edges >= world_cfg["minimum_edge_density"]),
        ],
        world_cfg["weight"],
        report,
    )

    hero_cfg = profile["hero"]
    hero = crop_norm(image, hero_cfg["region"])
    hero_stats = rgb_stats(hero)
    hero_edges = edge_density(hero)
    hero_foreground = foreground_fraction(hero, sky_stats["mean_luma"])
    report["hero"] = {
        **hero_stats,
        "edge_density": hero_edges,
        "foreground_fraction": hero_foreground,
    }
    total += metric_score(
        [
            ("hero_detail_ok", hero_stats["stddev"] >= hero_cfg["minimum_stddev"]),
            ("hero_edges_ok", hero_edges >= hero_cfg["minimum_edge_density"]),
            (
                "hero_occupancy_ok",
                hero_cfg["minimum_foreground_fraction"]
                <= hero_foreground
                <= hero_cfg["maximum_foreground_fraction"],
            ),
        ],
        hero_cfg["weight"],
        report,
    )

    hud_cfg = profile["hud"]
    hud_regions = {
        "top_left": crop_norm(image, hud_cfg["top_left_region"]),
        "right_rail": crop_norm(image, hud_cfg["right_rail_region"]),
        "bottom": crop_norm(image, hud_cfg["bottom_region"]),
    }
    hud_stddevs = {name: rgb_stats(region)["stddev"] for name, region in hud_regions.items()}
    report["hud"] = hud_stddevs
    total += metric_score(
        [
            ("hud_top_left_ok", hud_stddevs["top_left"] >= hud_cfg["minimum_region_stddev"]),
            ("hud_right_rail_ok", hud_stddevs["right_rail"] >= hud_cfg["minimum_region_stddev"]),
            ("hud_bottom_ok", hud_stddevs["bottom"] >= hud_cfg["minimum_region_stddev"]),
        ],
        hud_cfg["weight"],
        report,
    )

    reject_cfg = profile["prototype_rejection"]
    near_black = fraction(image, lambda r, g, b: r <= 8 and g <= 8 and b <= 8)
    near_white = fraction(image, lambda r, g, b: r >= 238 and g >= 238 and b >= 238)
    flat_green = fraction(
        image,
        lambda r, g, b: g > 85 and g > r * 1.28 and g > b * 1.18 and abs(g - max(r, b)) > 25,
    )
    flat_cyan = fraction(
        image,
        lambda r, g, b: g > 95 and b > 105 and r < 105 and abs(g - b) < 70,
    )
    report["prototype_rejection"] = {
        "near_black_fraction": near_black,
        "near_white_fraction": near_white,
        "flat_green_fraction": flat_green,
        "flat_cyan_fraction": flat_cyan,
    }
    total += metric_score(
        [
            ("not_mostly_black", near_black <= reject_cfg["maximum_near_black_fraction"]),
            ("not_dialog_white", near_white <= reject_cfg["maximum_near_white_fraction"]),
            ("not_flat_green_prototype", flat_green <= reject_cfg["maximum_flat_green_fraction"]),
            ("not_cyan_prototype_water", flat_cyan <= reject_cfg["maximum_flat_cyan_fraction"]),
        ],
        reject_cfg["weight"],
        report,
    )

    score = round(total, 2)
    minimum = float(profile["minimum_score"])
    passed = score >= minimum
    report["score"] = score
    report["minimum_score"] = minimum
    report["passed"] = passed

    if output_path:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(json.dumps(report, indent=2), encoding="utf-8")

    print(json.dumps(report, indent=2))
    if not passed:
        print(f"visual regression FAIL: score {score:.2f} < {minimum:.2f}", file=sys.stderr)
        return 1
    print(f"visual regression PASS: score {score:.2f} >= {minimum:.2f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
