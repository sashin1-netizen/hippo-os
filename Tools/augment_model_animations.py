#!/usr/bin/env python3
"""Single deterministic Hippo OS creature-production refinement pass.

The checked-in JSON files are stable anatomy sources. This step raises mesh density,
reduces synthetic surface noise, adds subtle idle motion and injects species-specific
behaviour clips before the strict anyCreature compiler builds the runtime GLBs.
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC_DIR = ROOT / "godot" / "model_specs"


def keyframes(*pairs):
    return [[float(t), float(v)] for t, v in pairs]


EXTRA_ANIMATIONS = {
    "hippo.json": {
        "sniff": {
            "duration": 2.2,
            "loop": True,
            "tracks": {
                "NeckB": {"rx": keyframes((0, -2.0), (0.28, 6.0), (0.58, 1.5), (0.82, 5.0), (1, -2.0))},
                "HeadRoot": {"rx": keyframes((0, 0.0), (0.30, 5.0), (0.60, 2.0), (1, 0.0))},
                "Skull": {"ry": keyframes((0, -3.0), (0.35, 4.0), (0.68, -4.0), (1, -3.0))},
                "Hips": {"ty": keyframes((0, 0.0), (0.5, -0.006), (1, 0.0))},
            },
        },
        "wallow": {
            "duration": 3.4,
            "loop": True,
            "tracks": {
                "Hips": {
                    "ty": keyframes((0, -0.015), (0.25, -0.050), (0.55, -0.025), (0.82, -0.055), (1, -0.015)),
                    "ry": keyframes((0, -2.0), (0.35, 4.0), (0.70, -4.0), (1, -2.0)),
                },
                "NeckB": {
                    "rx": keyframes((0, 5.0), (0.35, 11.0), (0.68, 6.0), (1, 5.0)),
                    "ry": keyframes((0, -3.0), (0.5, 3.0), (1, -3.0)),
                },
                "Skull": {"rx": keyframes((0, 2.0), (0.5, 6.0), (1, 2.0))},
                "Tail1": {"ry": keyframes((0, 5.0), (0.5, -5.0), (1, 5.0))},
            },
        },
    },
    "pig.json": {
        "root": {
            "duration": 1.65,
            "loop": True,
            "tracks": {
                "NeckB": {"rx": keyframes((0, 8.0), (0.22, 23.0), (0.48, 15.0), (0.72, 25.0), (1, 8.0))},
                "HeadRoot": {"rx": keyframes((0, 3.0), (0.28, 15.0), (0.60, 8.0), (1, 3.0))},
                "Skull": {"ry": keyframes((0, -6.0), (0.25, 7.0), (0.50, -8.0), (0.75, 6.0), (1, -6.0))},
                "Hips": {"ty": keyframes((0, 0.0), (0.5, -0.010), (1, 0.0))},
                "Tail1": {"ry": keyframes((0, 10.0), (0.5, -10.0), (1, 10.0))},
            },
        },
        "sniff": {
            "duration": 1.9,
            "loop": True,
            "tracks": {
                "NeckB": {"rx": keyframes((0, 1.0), (0.35, 8.0), (0.72, 3.0), (1, 1.0))},
                "HeadRoot": {"rx": keyframes((0, 0.0), (0.4, 5.0), (1, 0.0))},
                "Skull": {"ry": keyframes((0, -5.0), (0.5, 5.0), (1, -5.0))},
                "Muzzle": {"rx": keyframes((0, 0.0), (0.5, 2.5), (1, 0.0))},
            },
        },
    },
    "shar_pei.json": {
        "observe": {
            "duration": 3.0,
            "loop": True,
            "tracks": {
                "NeckB": {
                    "ry": keyframes((0, -8.0), (0.30, 2.0), (0.58, 10.0), (0.82, 1.0), (1, -8.0)),
                    "rx": keyframes((0, -1.0), (0.5, 2.0), (1, -1.0)),
                },
                "HeadRoot": {"ry": keyframes((0, -5.0), (0.5, 7.0), (1, -5.0))},
                "Skull": {"rx": keyframes((0, 1.0), (0.45, -1.5), (1, 1.0))},
                "Tail1": {"ry": keyframes((0, 4.0), (0.5, -4.0), (1, 4.0))},
            },
        },
        "sniff": {
            "duration": 2.0,
            "loop": True,
            "tracks": {
                "NeckB": {"rx": keyframes((0, 1.0), (0.30, 9.0), (0.64, 4.0), (1, 1.0))},
                "HeadRoot": {"rx": keyframes((0, 0.0), (0.35, 6.0), (1, 0.0))},
                "Skull": {"ry": keyframes((0, -4.0), (0.5, 4.0), (1, -4.0))},
                "Muzzle": {"rx": keyframes((0, 0.0), (0.5, 2.0), (1, 0.0))},
            },
        },
    },
}


def refine_geometry(data: dict) -> None:
    data["smooth_angle"] = max(float(data.get("smooth_angle", 68)), 82.0)
    shading = data.setdefault("shading", {})
    noise = shading.setdefault("noise", {})
    noise["amount"] = min(float(noise.get("amount", 0.16)), 0.085)
    noise["size"] = min(float(noise.get("size", 0.014)), 0.010)

    for volume in data.get("volumes", []):
        chain = str(volume.get("chain", ""))
        current_sides = int(volume.get("sides", 12))
        if chain == "body":
            volume["sides"] = max(current_sides, 32)
            volume["ring_step"] = min(float(volume.get("ring_step", 0.055)), 0.040)
        elif chain == "head":
            volume["sides"] = max(current_sides, 30)
            volume["ring_step"] = min(float(volume.get("ring_step", 0.065)), 0.040)
        elif chain in ("LFront", "LBack"):
            volume["sides"] = max(current_sides, 18)
            volume["ring_step"] = min(float(volume.get("ring_step", 0.045)), 0.035)
        elif chain == "tail":
            volume["sides"] = max(current_sides, 18)
            volume["ring_step"] = min(float(volume.get("ring_step", 0.055)), 0.045)


def add_idle_micro_motion(data: dict) -> None:
    animations = data.setdefault("animations", {})
    idle = animations.setdefault("idle", {"duration": 2.4, "loop": True, "tracks": {}})
    tracks = idle.setdefault("tracks", {})
    tracks.setdefault("HeadRoot", {})["ry"] = keyframes((0, -1.5), (0.28, 1.2), (0.62, -0.6), (1, -1.5))
    tracks.setdefault("Neck2", {})["ry"] = keyframes((0, 0.8), (0.5, -0.8), (1, 0.8))


def augment(path: Path, additions: dict) -> None:
    data = json.loads(path.read_text(encoding="utf-8"))
    refine_geometry(data)
    add_idle_micro_motion(data)
    animations = data.setdefault("animations", {})
    animations.update(additions)
    path.write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")
    missing = [name for name in additions if name not in animations]
    if missing:
        raise RuntimeError(f"Failed to add animations to {path.name}: {missing}")
    total_sides = sum(int(volume.get("sides", 0)) for volume in data.get("volumes", []))
    print(
        f"{path.name}: animations={','.join(animations.keys())} "
        f"smooth_angle={data.get('smooth_angle')} volume_side_budget={total_sides}"
    )


def main() -> None:
    for filename, additions in EXTRA_ANIMATIONS.items():
        path = SPEC_DIR / filename
        if not path.is_file():
            raise FileNotFoundError(path)
        augment(path, additions)


if __name__ == "__main__":
    main()
