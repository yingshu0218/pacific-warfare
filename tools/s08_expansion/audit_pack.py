#!/usr/bin/env python3
"""Read-only audit of a coordinator-bound ordinary expanded PCK. Never builds."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
from pathlib import Path, PurePosixPath

from contract import ROOT, VERSION, load, local_path, relative_name, require, sha


def pack_entries(path):
    entries = {}
    total = path.stat().st_size
    with path.open("rb") as stream:
        header = stream.read(40)
        require(len(header) == 40, "Truncated PCK header")
        magic, version, major, minor, patch, flags, base, directory = struct.unpack("<6I2Q", header)
        require((magic, version, major, minor, patch) == (0x43504447, 4, 4, 7, 2) and flags & ~2 == 0, "Unsupported PCK/version/encryption")
        require(40 <= directory < total and base < total, "PCK offsets outside file")
        stream.seek(directory)
        count = struct.unpack("<I", stream.read(4))[0]
        require(0 < count <= 30000, "Implausible PCK entry count")
        for _ in range(count):
            size = struct.unpack("<I", stream.read(4))[0]
            require(0 < size <= 16384, "Invalid PCK path length")
            name = stream.read(size).rstrip(b"\0").decode("utf-8")
            require(not PurePosixPath(name).is_absolute() and ".." not in PurePosixPath(name).parts and "\\" not in name, "Unsafe PCK path")
            require(name not in entries, "Duplicate PCK path: " + name)
            offset, length, digest, entry_flags = struct.unpack("<QQ16sI", stream.read(36))
            require(entry_flags == 0 and base + offset + length <= total, "Invalid/encrypted PCK payload")
            entries[name] = {"offset": base + offset, "bytes": length, "md5": digest.hex()}
        for name, entry in entries.items():
            stream.seek(entry["offset"])
            digest = hashlib.md5()
            remaining = entry["bytes"]
            while remaining:
                block = stream.read(min(1024 * 1024, remaining))
                require(block, "Truncated PCK payload: " + name)
                remaining -= len(block)
                digest.update(block)
            require(digest.hexdigest() == entry["md5"], "Corrupt PCK payload: " + name)
    return entries


def payload(path, entries, name, limit=16 * 1024 * 1024):
    entry = entries[name]
    require(entry["bytes"] <= limit, "Unreasonably large text payload: " + name)
    with path.open("rb") as stream:
        stream.seek(entry["offset"])
        return stream.read(entry["bytes"])


def audit(contract_path, root=ROOT):
    root = root.resolve()
    config, runtime, manifest = load(contract_path, root)
    require(manifest["engine"] == VERSION, "Build engine version mismatch")
    require(manifest["entry"] == config["target"]["entry"] == runtime["entries"]["expanded"], "Expanded entry mismatch")
    require(runtime["entries"].get("all") == "res://showcase/all_units.tscn", "Old all entry was removed")
    package = local_path(root, config["package"]["directory"])
    require(package == root / "build/first-playable", "Audit the ordinary user package, not a private review export")
    stage = local_path(root, config["package"]["stage"])
    sources = manifest["sources"]
    require(set(manifest["root_sources"]) == set(runtime["files"]), "Build/admission resource sets differ")
    for name, digest in manifest["root_sources"].items():
        relative_name(name)
        require(sha(root / name) == digest, "Root source drift: " + name)
    for name, digest in sources.items():
        relative_name(name)
        require(sha(stage / name) == digest, "Stage source drift: " + name)
    require(manifest["admission_manifest_sha256"] == config["admission"]["runtime_manifest_sha256"], "Build was not made from final admission manifest")
    outputs = {}
    for name, expected in manifest["outputs"].items():
        relative_name(name)
        require("/" not in name, "Nested output requires explicit audit support")
        file = package / name
        actual = {"bytes": file.stat().st_size, "sha256": sha(file)}
        require(actual == expected, "Output drift: " + name)
        outputs[name] = actual
    require({p.name for p in package.iterdir() if p.is_file()} <= set(outputs) | {"build_manifest.json"}, "Untracked file in ordinary export directory")
    require(outputs["index.pck"]["sha256"] == config["package"]["pck_sha256"], "Wrong final PCK")
    html = (package / "index.html").read_text()
    require(not re.search(r"measure\.js|s14_web|window\.(?:S08|S14X)\s*=", html, re.I), "Validation code in ordinary HTML")
    require(not (package / "measure.js").exists(), "Measurement shell leaked into ordinary package")
    project = (root / "project.godot").read_text()
    require('run/main_scene="' + config["target"]["root_main_scene"] + '"' in project, "Root main scene changed")
    stage_project = (stage / "project.godot").read_text()
    require('run/main_scene="' + config["target"]["entry"] + '"' in stage_project, "Stage uses a test scene")
    require('renderer/rendering_method="gl_compatibility"' in stage_project, "Wrong renderer")
    path = package / "index.pck"
    entries = pack_entries(path)
    names = set(entries)
    forbidden = sorted(n for n in names if re.search(r"(^|/)(?:candidates|tests|tools|docs|research|references|evidence|\.local|\.git)(?:/|$)|\.(?:pdf|zip|bak|md)$", n, re.I))
    require(not forbidden, "Unadmitted development payloads: " + repr(forbidden[:8]))
    allowed = set(config["package"]["allowed_generated_payloads"])
    remaps = {}
    for name in sources:
        if name in entries:
            allowed.add(name)
        remap_name = name + ".remap"
        if remap_name in entries:
            allowed.add(remap_name)
            targets = re.findall(rb'path="res://([^"\r\n]+)"', payload(path, entries, remap_name))
            require(targets, "Empty remap: " + remap_name)
            remaps[name] = [t.decode() for t in targets]
            for target in remaps[name]:
                require(target in entries, "Dangling remap: " + target)
                allowed.add(target)
        if name.endswith(".import") and name in entries:
            for target in re.findall(rb'"res://(\.godot/imported/[^"\r\n]+)"', payload(path, entries, name)):
                target = target.decode()
                require(target in entries, "Dangling imported resource: " + target)
                allowed.add(target)
    require(not names - allowed, "Payload outside admitted source graph: " + repr(sorted(names - allowed)[:8]))
    def exists(name):
        return name in names or name in remaps or name + ".import" in names
    for name in sources:
        if name.endswith(".uid") or name in {"project.godot", "export_presets.cfg", "shell.html"}:
            continue
        require(exists(name), "Missing admitted runtime resource: " + name)
        if name.endswith((".json", ".txt")):
            require(name in names and hashlib.sha256(payload(path, entries, name)).hexdigest() == sources[name], "Raw data omitted/changed: " + name)
    for name in config["package"]["required_resources"] + config["probe"]["source_paths"]:
        require(name in sources and exists(name), "Missing final required resource: " + name)
    require(config["target"]["entry"].encode() in payload(path, entries, "project.binary"), "Packed main scene mismatch")
    definitions = []
    for name in sources:
        if name.startswith("data/units/") and "/" not in name[len("data/units/"):] and name.endswith(".json"):
            definition = json.loads(payload(path, entries, name))
            scene = definition.get("model_scene", "").removeprefix("res://")
            require(scene and exists(scene), "Unit model is absent: " + name)
            definitions.append({"id": definition["id"], "scene": scene})
    return {"status": "file_audit_passed_not_browser_tested", "contract_sha256": sha(Path(contract_path)), "engine": VERSION,
            "entry": config["target"]["entry"], "root_sources": len(manifest["root_sources"]), "stage_sources": len(sources),
            "outputs": outputs, "pck_entries": len(entries), "remaps": len(remaps), "models": definitions,
            "all_payload_md5_match": True, "forbidden": forbidden, "Godot_started": False, "Chrome_started": False}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--contract", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        result = audit(args.contract)
    except (ValueError, KeyError, OSError, struct.error) as error:
        print(json.dumps({"status": "not_ready_or_audit_failed", "reason": str(error), "Godot_started": False, "Chrome_started": False}))
        raise SystemExit(2)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(result, ensure_ascii=False))
