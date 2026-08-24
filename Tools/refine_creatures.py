#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC_DIR = ROOT / "godot" / "model_specs"
MODEL_DIR = ROOT / "godot" / "assets" / "models"
CLI = Path("/tmp/anyCreature/engine/cli.js")

TARGETS = {
    "hippo": (SPEC_DIR / "hippo.json", MODEL_DIR / "mochi_pygmy_hippo.glb"),
    "pig": (SPEC_DIR / "pig.json", MODEL_DIR / "truffle_pig.glb"),
    "shar_pei": (SPEC_DIR / "shar_pei.json", MODEL_DIR / "bao_shar_pei.glb"),
}


def refine_geometry(spec):
    spec["smooth_angle"] = max(float(spec.get("smooth_angle", 68)), 82)
    shading = spec.setdefault("shading", {})
    noise = shading.setdefault("noise", {})
    noise["amount"] = min(float(noise.get("amount", 0.16)), 0.085)
    noise["size"] = min(float(noise.get("size", 0.014)), 0.010)

    for volume in spec.get("volumes", []):
        chain = str(volume.get("chain", ""))
        if chain == "body":
            volume["sides"] = max(int(volume.get("sides", 20)), 32)
            volume["ring_step"] = min(float(volume.get("ring_step", 0.055)), 0.040)
        elif chain == "head":
            volume["sides"] = max(int(volume.get("sides", 18)), 30)
            volume["ring_step"] = min(float(volume.get("ring_step", 0.065)), 0.040)
        elif chain in ("LFront", "LBack"):
            volume["sides"] = max(int(volume.get("sides", 12)), 18)
            volume["ring_step"] = min(float(volume.get("ring_step", 0.045)), 0.035)
        elif chain == "tail":
            volume["sides"] = max(int(volume.get("sides", 12)), 18)


def add_species_motion(species, spec):
    animations = spec.setdefault("animations", {})
    idle = animations.get("idle", {})
    idle_tracks = idle.setdefault("tracks", {})
    idle_tracks.setdefault("HeadRoot", {})["ry"] = [[0, -1.5], [0.28, 1.2], [0.62, -0.6], [1, -1.5]]
    idle_tracks.setdefault("Neck2", {})["ry"] = [[0, 0.8], [0.5, -0.8], [1, 0.8]]

    if species == "hippo":
        animations["sniff"] = {
            "duration": 2.6,
            "loop": True,
            "tracks": {
                "NeckB": {"rx": [[0, 0], [0.35, -4], [0.72, 2.5], [1, 0]]},
                "HeadRoot": {"ry": [[0, -5], [0.38, 4], [0.7, -2], [1, -5]]},
                "Skull": {"rx": [[0, 1], [0.5, -2], [1, 1]]},
                "Nose": {"rx": [[0, 0], [0.5, 2.2], [1, 0]]},
            },
        }
        animations["wallow"] = {
            "duration": 2.2,
            "loop": True,
            "tracks": {
                "Hips": {"rz": [[0, -2.2], [0.5, 2.2], [1, -2.2]]},
                "NeckB": {"rx": [[0, 5], [0.5, 10], [1, 5]]},
                "Tail1": {"ry": [[0, -6], [0.5, 6], [1, -6]]},
            },
        }
    elif species == "pig":
        animations["root"] = {
            "duration": 1.45,
            "loop": True,
            "tracks": {
                "NeckB": {"rx": [[0, 10], [0.30, 27], [0.62, 16], [1, 10]]},
                "HeadRoot": {"rx": [[0, 7], [0.30, 20], [0.62, 11], [1, 7]], "ry": [[0, -3], [0.5, 3], [1, -3]]},
                "Nose": {"rx": [[0, 0], [0.35, 6], [0.7, -3], [1, 0]]},
                "Hips": {"ty": [[0, 0], [0.5, 0.009], [1, 0]]},
            },
        }
        animations["sniff"] = {
            "duration": 1.9,
            "loop": True,
            "tracks": {
                "HeadRoot": {"ry": [[0, -7], [0.32, 5], [0.65, -2], [1, -7]]},
                "Skull": {"rx": [[0, 0], [0.5, 3], [1, 0]]},
                "Nose": {"rx": [[0, -1], [0.5, 2.5], [1, -1]]},
            },
        }
    elif species == "shar_pei":
        animations["observe"] = {
            "duration": 3.4,
            "loop": True,
            "tracks": {
                "NeckB": {"ry": [[0, -7], [0.28, -2], [0.58, 7], [0.82, 2], [1, -7]]},
                "HeadRoot": {"ry": [[0, -4], [0.4, 4], [0.72, 1], [1, -4]], "rx": [[0, -1], [0.55, 2], [1, -1]]},
                "Skull": {"rx": [[0, 1], [0.5, -1.5], [1, 1]]},
            },
        }
        animations["sniff"] = {
            "duration": 1.8,
            "loop": True,
            "tracks": {
                "NeckB": {"rx": [[0, 0], [0.42, 8], [0.72, 3], [1, 0]]},
                "HeadRoot": {"ry": [[0, -3], [0.5, 3], [1, -3]]},
                "Nose": {"rx": [[0, 0], [0.5, 2], [1, 0]]},
            },
        }


def main():
    if not CLI.exists():
        print("anyCreature compiler not present; model refinement skipped")
        return
    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    for species, (source, output) in TARGETS.items():
        spec = json.loads(source.read_text())
        refine_geometry(spec)
        add_species_motion(species, spec)
        temp = Path("/tmp") / f"hippo_os_{species}_refined.json"
        temp.write_text(json.dumps(spec, separators=(",", ":")))
        subprocess.run(["node", str(CLI), str(temp), str(output)], check=True)
        if not output.exists() or output.stat().st_size < 100_000:
            raise RuntimeError(f"refined model output invalid: {output}")
        print("refined", species, output, output.stat().st_size)


if __name__ == "__main__":
    main()
