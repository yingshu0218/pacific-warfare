#!/usr/bin/env python3
"""Stream compact evidence; retain slow, hidden and warmup frames separately."""
import argparse
import json
import math
import statistics
from collections import Counter
from pathlib import Path


def rows(path):
    if not path.exists():
        return
    with path.open() as stream:
        for line in stream:
            if line.strip():
                yield json.loads(line)


def distribution(values):
    if not values:
        return None
    data = sorted(values)
    def quantile(fraction):
        point = (len(data) - 1) * fraction
        index = int(point)
        return data[index] + (data[min(index + 1, len(data) - 1)] - data[index]) * (point - index)
    return {"frames": len(data), "p50_ms": quantile(.5), "p95_ms": quantile(.95), "p99_ms": quantile(.99),
            "max_ms": data[-1], "mean_ms": statistics.mean(data),
            "over_33_3ms_ratio": sum(v > 33.3 for v in data) / len(data), "over_50ms_ratio": sum(v > 50 for v in data) / len(data)}


def summary(folder):
    report = json.loads((folder / "run.json").read_text())
    phases = {p["name"]: p for p in report["phases"]}
    samples = {name: {"all": [], "visible": [], "hidden_frames": 0, "unfocused_frames": 0, "invalid_frames": 0} for name in phases}
    heap = []
    for batch in rows(folder / "frames.ndjson"):
        if batch.get("js_heap_bytes"):
            heap.append(batch["js_heap_bytes"])
        for frame in batch["frames"]:
            phase = phases.get(frame["phase"])
            if not phase or not phase["browser_start_ms"] <= frame["at"] <= phase["browser_end_ms"]:
                continue
            value = samples[frame["phase"]]
            if not isinstance(frame["ms"], (int, float)) or not math.isfinite(frame["ms"]) or frame["ms"] <= 0:
                value["invalid_frames"] += 1
                continue
            value["all"].append(frame["ms"])
            if frame["visible"] == "visible":
                value["visible"].append(frame["ms"])
            else:
                value["hidden_frames"] += 1
            value["unfocused_frames"] += not frame["focused"]
    for name, values in samples.items():
        values["all"] = distribution(values["all"])
        values["visible"] = distribution(values["visible"])
        values["visual_30fps_target_met"] = bool(values["all"] and values["all"]["p95_ms"] <= 33.3 and not values["hidden_frames"] and not values["invalid_frames"])
    metric_peaks = {}
    wasm = []
    for value in rows(folder / "metrics.ndjson"):
        wasm.extend(value.get("wasm_bytes", []))
        for key in ["projectiles", "projectile_peak", "mounts", "node_count", "draw_calls", "fragments"]:
            actual = value["game"].get(key)
            if isinstance(actual, (int, float)):
                metric_peaks[key] = max(actual, metric_peaks.get(key, actual))
    memory = {}
    for value in rows(folder / "memory.ndjson"):
        types = {p["id"]: p["type"] for p in value["processes"]}
        for process in value["memory"]:
            if process["physical_footprint_bytes"] is None:
                continue
            item = memory.setdefault(str(process["pid"]), {"type": types.get(process["pid"]), "scope": value["scope"], "samples": 0})
            item["samples"] += 1
            for name in ["resident_bytes", "physical_footprint_bytes"]:
                before = item.get(name, [process[name], process[name]])
                item[name] = [min(before[0], process[name]), max(before[1], process[name])]
    audio = {name: {"samples": 0, "rms_max_after_300ms": 0., "peak": 0.} for name in phases if phases[name].get("sound_pause")}
    for batch in rows(folder / "audio.ndjson"):
        for value in batch["samples"]:
            name = value["phase"]
            if name not in audio:
                continue
            phase = phases[name]
            if phase["browser_start_ms"] + 300 <= value["at"] <= phase["browser_end_ms"]:
                audio[name]["samples"] += 1
                audio[name]["rms_max_after_300ms"] = max(audio[name]["rms_max_after_300ms"], value["rms"])
                audio[name]["peak"] = max(audio[name]["peak"], value["peak"])
    for value in audio.values():
        value["silent"] = bool(value["samples"] and value["rms_max_after_300ms"] == 0)
    events = Counter()
    for value in rows(folder / "events.ndjson"):
        events[value["event"]["kind"]] += 1
    return {"status": report["status"], "mode": report["mode"], "source": str(folder),
            "identity": report.get("identity"), "hardware": report.get("hardware"), "contract_sha256": report["contract_sha256"],
            "phases": [{**phase, "frames": samples[name]} for name, phase in phases.items()], "metric_peaks": metric_peaks,
            "wasm_bytes": [min(wasm), max(wasm)] if wasm else None,
            "wasm_note": "Unavailable on ordinary page without Godot/WASM observation hooks" if report["mode"] == "plain" else "Retained linear capacity; not process physical memory",
            "js_heap_bytes": [min(heap), max(heap)] if heap else None, "owned_process_memory": memory,
            "sound_pause": audio, "selected_event_counts": dict(events), "cleanup": report["cleanup"],
            "measurement_note": "All finite positive frame times inside explicit intervals retained, including slow/hidden frames. Plain rAF has no game state. Probe-enabled CPU and frame times are reported separately, never all attributed to normal gameplay."}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = summary(args.run_dir)
    if args.output:
        args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(result, ensure_ascii=False))
