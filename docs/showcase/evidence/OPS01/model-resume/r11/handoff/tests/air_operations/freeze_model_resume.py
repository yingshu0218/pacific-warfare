#!/usr/bin/env python3
"""Freeze the exact admitted OPS model stage and audit its bounded evidence."""
import argparse
import datetime as dt
import hashlib
import json
import math
import os
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def copy_checked(source, target):
    before = digest(source)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    if digest(source) != before or digest(target) != before:
        raise RuntimeError("Changed while freezing: " + str(source))
    return before


def finite(value):
    if isinstance(value, float):
        return math.isfinite(value)
    if isinstance(value, dict):
        return all(finite(x) for x in value.values())
    if isinstance(value, list):
        return all(finite(x) for x in value)
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stage", required=True)
    parser.add_argument("--normal-capture-stage", help="Explicit earlier stage for unaffected, already reviewed normal clips")
    args = parser.parse_args()
    stage = ROOT / ".local/ops01-model" / args.stage
    target = ROOT / "docs/showcase/evidence/OPS01/model-resume" / args.stage
    manifest = json.loads((stage / "input-manifest.json").read_text())
    target.mkdir(parents=True, exist_ok=True)
    (target / ".gdignore").touch()
    sources = {}
    for name, expected in manifest["inputs"].items():
        if any(x in name.lower() for x in ["g4m", "d4y", "au01"]):
            raise RuntimeError("Unadmitted dependency: " + name)
        if digest(stage / name) != expected:
            raise RuntimeError("Executed stage input drift: " + name)
        sources[name] = copy_checked(stage / name, target / "inputs" / name)
    copy_checked(stage / "input-manifest.json", target / "input-manifest.json")

    tests = {}
    for name in ["cycle", "mechanisms", "two-aircraft", "waveoff", "hard-contact", "airframe-first-contact", "model-resume-checks"]:
        source = stage / "docs/showcase/evidence/OPS01" / (name + ".json")
        tests[name] = copy_checked(source, target / "mechanisms" / source.name)
    mechanisms = json.loads((target / "mechanisms/mechanisms.json").read_text())
    geometry = json.loads((target / "mechanisms/model-resume-checks.json").read_text())
    cycle = json.loads((target / "mechanisms/cycle.json").read_text())
    assert mechanisms["failures"] == 0 and geometry["failures"] == 0 and cycle["finished"]

    captures = {}
    recording_sources = {}
    for segment in ["launch", "recovery", "waveoff", "hard_contact"]:
        capture_stage = args.stage if segment == "hard_contact" else (args.normal_capture_stage or args.stage)
        recording_stage = ROOT / ".local/ops01-model" / capture_stage
        recording_manifest = json.loads((recording_stage / "input-manifest.json").read_text())
        assert recording_manifest["S04_manifest_sha256"] == manifest["S04_manifest_sha256"]
        if capture_stage != args.stage and capture_stage not in recording_sources:
            for name, expected in recording_manifest["inputs"].items():
                assert digest(recording_stage / name) == expected
                copy_checked(recording_stage / name, target / "recording-inputs" / capture_stage / name)
            copy_checked(recording_stage / "input-manifest.json", target / "recording-inputs" / capture_stage / "input-manifest.json")
            # Only the wreck follow-up changed after these normal clips. These
            # are the unchanged normal-flight/deck/visual paths and exact model.
            unchanged = ["scripts/air_operations/carrier_operations.gd", "scripts/air_operations/flight_bridge.gd",
                         "scripts/air_operations/configuration_attitude.gd", "scripts/air_operations/deck_motion.gd",
                         "scripts/air_operations/task_bridge.gd", "scripts/air_operations/deck_geometry.gd",
                         "tests/air_operations/inspection.gd", "tests/air_operations/aircraft_visual.gd"]
            unchanged += [r["destination"] for r in manifest["S04_destinations"]]
            assert all(recording_manifest["inputs"][n] == manifest["inputs"][n] for n in unchanged)
            a = json.loads((recording_stage / "scripts/air_operations/model_contact_proxy.json").read_text())
            b = json.loads((stage / "scripts/air_operations/model_contact_proxy.json").read_text())
            assert a["states"] == b["states"]
            recording_sources[capture_stage] = {"input_count": len(recording_manifest["inputs"]),
                                                "unchanged_normal_paths": unchanged,
                                                "mesh_body_hulls_equal": True}
        source = ROOT / ".local/ops01-model-captures" / (capture_stage + "-" + segment)
        data = json.loads((source / "capture.json").read_text())
        assert data["complete"] and data["fps"] == 15 and finite(data)
        frames = sorted(source.glob("frame_*.png"))
        assert frames == [source / ("frame_%05d.png" % n) for n in range(data["frames"])]
        assert len(data["samples"]) == data["frames"]
        errors = {key: max(s["geometry_diagnostics"][key] for s in data["samples"])
                  for key in ["wheel_error_m", "hook_error_m"]}
        assert max(errors.values()) < 0.006
        for a, b in zip(data["samples"], data["samples"][1:]):
            assert abs((b["time_s"] - a["time_s"]) - 1 / 15) < 1e-8
        folder = target / segment
        copy_checked(source / "capture.json", folder / "capture.json")
        chosen = {0, len(frames) - 1, *data["phase_first_frames"].values()}
        if segment == "launch":
            chosen.update([138, 139, 140, 165])
        elif segment == "recovery":
            chosen.update([175, 186, 187, 210, 262])
        elif segment == "waveoff":
            chosen.add(60)
        else:
            lost = next((s["frame"] for s in data["samples"]
                         if not s["units"]["hellcat_1"]["active"]), None)
            if lost is not None:
                chosen.update(range(max(0, lost - 2), min(len(frames), lost + 4)))
                chosen.update([lost + 20, lost + 40, lost + 60, lost + 90])
            stable = next((s["frame"] for s in data["samples"]
                           if s["units"]["hellcat_1"]["module_data"].get("carrier_deck_contact", {}).get("settling_stable")), None)
            assert stable is not None
            chosen.add(stable)
        selected = {frames[n].name: copy_checked(frames[n], folder / frames[n].name)
                    for n in sorted(chosen) if 0 <= n < len(frames)}
        movie = folder / (segment + ".mp4")
        encoding = json.loads(movie.with_suffix(".encoding.json").read_text())
        assert digest(movie) == encoding["output_sha256"]
        assert encoding["input_sha256"] == {p.name: digest(p) for p in frames}
        captures[segment] = {"input_stage": capture_stage, "fps": 15, "frames": len(frames), "duration_s": len(frames) / 15,
                             "start_s": data["start_s"], "render_geometry_maximum_error_m": errors,
                             "selected_frames": selected, "movie_sha256": digest(movie)}

    candidate = json.loads((ROOT / "candidates/s04-carrier-usage/candidate-manifest.json").read_text())
    assert digest(ROOT / "candidates/s04-carrier-usage/candidate-manifest.json") == manifest["S04_manifest_sha256"]
    public = {}
    for name, expected in candidate["public_baseline_sha256"].items():
        public[name] = digest(ROOT / name)
        assert public[name] == expected
    public["new_geometry_helper_absent_in_public_source"] = not (ROOT / "scripts/aircraft_geometry/f6f5_carrier_geometry.gd").exists()
    assert public["new_geometry_helper_absent_in_public_source"]
    assert digest(ROOT / "tools/showcase_runtime.json") == manifest["runtime_whitelist_sha256"]
    baseline = json.loads((ROOT / "docs/air_operations/OPS01/baseline-hashes.json").read_text())
    for name in ["scripts/simulation/aircraft_motion/aircraft_motion.gd", "scripts/behaviors/aircraft/aircraft_tasks.gd", "scripts/simulation/ship_motion/ship_motion.gd"]:
        public[name] = digest(ROOT / name)
        assert public[name] == baseline[name]

    ancillary = {}
    for name in ["tools/verify.py", "tools/showcase_runtime.json", "tests/air_operations/freeze_model_resume.py",
                 "docs/air_operations/OPS01/parameters-and-sources.md", "docs/air_operations/OPS01/integration-hooks.md",
                 "docs/air_operations/OPS01/model-usage-handoff.md", "docs/air-operations-contracts.md",
                 "docs/showcase/deliveries/OPS01.md", "docs/showcase/deliveries/OPS01-model-resume.md",
                 "docs/deliveries/OPS01.md"]:
        ancillary[name] = copy_checked(ROOT / name, target / "handoff" / name)

    runs = []
    groups = set()
    for path in sorted((ROOT / ".local/validation/runs").glob("*/report.json")):
        data = json.loads(path.read_text())
        if data.get("owner") != "OPS01":
            continue
        run = target / "validation-runs" / path.parent.name
        for p in path.parent.iterdir():
            if p.is_file():
                copy_checked(p, run / p.name)
        runs.append({"run_id": data["run_id"], "passed": data["passed"], "action": data["action"],
                     "project": data["project"], "error": data.get("error"),
                     "checks": [{k: c.get(k) for k in ["pid", "process_group", "passed", "cleanup_ok", "timed_out"]}
                                for c in data["checks"]]})
        groups.update(c["process_group"] for c in data["checks"] if c.get("process_group"))
    live = []
    for pgid in sorted(groups):
        try:
            os.killpg(pgid, 0)
        except ProcessLookupError:
            continue
        live.append(pgid)
    assert not live, "Previously registered validation groups still exist"
    evidence = {str(p.relative_to(target)): digest(p) for p in sorted(target.rglob("*"))
                if p.is_file() and p.name != "audit.json" and "inputs" not in p.relative_to(target).parts}
    report = {"created_utc": dt.datetime.now(dt.timezone.utc).isoformat(), "stage": str(stage),
              "source_count": len(sources), "sources": sources, "ancillary": ancillary,
              "runtime_whitelist_sha256": manifest["runtime_whitelist_sha256"],
              "S04_manifest_sha256": manifest["S04_manifest_sha256"], "public_sources": public,
              "checks": {"retained_mechanisms": len(mechanisms["checks"]), "accepted_model_and_composition": geometry["checks"],
                         "failures": 0, "one_cycle_s": cycle["time_s"]},
              "captures": captures, "recording_source_snapshots": recording_sources,
              "evidence": evidence, "validation_runs": runs,
              "registered_process_groups": sorted(groups), "live_registered_groups": live,
              "cleanup_passed": not live, "chrome_tabs_created": 0, "http_services_created": 0,
              "audit_process_group_excluded_until_wrapper_finally": os.getpgrp(),
              "scope": "Independent OPS actual-model phase, zero wind, one Essex, one/two F6F whole waves; no S14/Chrome/production acceptance"}
    (target / "audit.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({k: report[k] for k in ["source_count", "checks", "cleanup_passed", "live_registered_groups"]}))


if __name__ == "__main__":
    main()
