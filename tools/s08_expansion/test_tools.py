#!/usr/bin/env python3
"""Synthetic file/contract tests only. No Godot, export, HTTP or Chrome."""
import copy
import hashlib
import json
import struct
import tempfile
import unittest
from pathlib import Path

from audit_pack import audit, pack_entries
from contract import FEATURES, GROUPS, sha, validate
from summarize import summary

HERE = Path(__file__).resolve().parent
TEMPLATE = json.loads((HERE / "contract.template.json").read_text())


def ready_shape():
    config = copy.deepcopy(TEMPLATE)
    config["status"] = "released_for_s08"
    config["target"].update(entry="res://showcase/fixture.tscn", title_contains="SYNTHETIC")
    config["admission"].update(record="release.json", record_sha256="0" * 64, runtime_manifest="runtime.json", runtime_manifest_sha256="0" * 64)
    config["package"].update(manifest_sha256="0" * 64, pck_sha256="0" * 64, stage="stage", required_resources=["scripts/probe.gd"])
    config["probe"].update({"protocol":"receive-events-v1", "serialization":"compact-state-and-event-deltas", "global":"FixtureProbe", "metrics_global":"FixtureMetrics", "source_paths":["scripts/probe.gd"]})
    config["runtime"]["playwright_module"] = "/synthetic/never-imported.mjs"
    config["bindings"]["ended"] = "ended"
    config["bindings"]["sound"] = "sound_enabled"
    config["cases"] = [{"key": group, "group": group, "features": sorted(FEATURES),
                         "steps": [{"action": "menu", "menu": "segment", "label": "SYNTHETIC " + group}]} for group in sorted(GROUPS)]
    return config


def pck(path, files):
    records = []
    offset = 0
    for name, data in files.items():
        encoded = name.encode() + b"\0"
        records.append(struct.pack("<I", len(encoded)) + encoded + struct.pack("<QQ16sI", offset, len(data), hashlib.md5(data).digest(), 0))
        offset += len(data)
    directory = struct.pack("<I", len(records)) + b"".join(records)
    header = struct.pack("<6I2Q", 0x43504447, 4, 4, 7, 2, 0, 40 + len(directory), 40)
    path.write_bytes(header + directory + b"".join(files.values()))


class PreparationTests(unittest.TestCase):
    def test_template_cannot_launch(self):
        with self.assertRaisesRegex(ValueError, "Waiting for coordinator"):
            validate(TEMPLATE)

    def test_final_shape_and_no_guessed_index(self):
        config = ready_shape()
        validate(config)
        config["cases"][0]["steps"][0] = {"action": "menu", "menu": "segment", "index": 24}
        with self.assertRaisesRegex(ValueError, "never a guessed index"):
            validate(config)

    def test_coverage_and_history_gate(self):
        for mutate in [lambda c: c["cases"].pop(), lambda c: c["probe"].update(serialization="full-history")]:
            config = ready_shape()
            mutate(config)
            with self.assertRaises(ValueError):
                validate(config)

    def test_pack_digest_and_path(self):
        with tempfile.TemporaryDirectory(prefix="s08x-files-") as folder:
            file = Path(folder) / "fixture.pck"
            pck(file, {"data/test.json": b'{"synthetic":true}'})
            self.assertEqual(len(pack_entries(file)), 1)
            original = file.read_bytes()
            file.write_bytes(original[:-1] + b"X")
            with self.assertRaisesRegex(ValueError, "Corrupt PCK"):
                pack_entries(file)
            pck(file, {"../escape": b"test"})
            with self.assertRaisesRegex(ValueError, "Unsafe PCK"):
                pack_entries(file)

    def fixture(self, root):
        config = ready_shape()
        runtime_files = {"scripts/probe.gd": b"extends RefCounted\n", "showcase/fixture.tscn": b"[gd_scene format=3]\n",
                         "data/units/fixture.json": b'{"id":"fixture","model_scene":"res://showcase/fixture.tscn"}',
                         "aircraft/fixture/data/interfaces.json": b'{"synthetic":true}'}
        stage = root / "stage"
        for name, data in runtime_files.items():
            for parent in [root, stage]:
                file = parent / name
                file.parent.mkdir(parents=True, exist_ok=True)
                file.write_bytes(data)
        (root / "project.godot").write_text('run/main_scene="res://scenes/main.tscn"\n')
        (stage / "project.godot").write_text('run/main_scene="res://showcase/fixture.tscn"\nrenderer/rendering_method="gl_compatibility"\n')
        (stage / "export_presets.cfg").write_text("SYNTHETIC\n")
        (stage / "shell.html").write_text("SYNTHETIC\n")
        (root / "release.json").write_text('{"synthetic_test_only":true}')
        runtime = {"files": list(runtime_files), "entries": {"expanded": "res://showcase/fixture.tscn", "all": "res://showcase/all_units.tscn"}}
        (root / "runtime.json").write_text(json.dumps(runtime))
        package = root / "build/first-playable"
        package.mkdir(parents=True)
        (package / "index.html").write_text("SYNTHETIC ordinary shell")
        files = {**runtime_files, "project.binary": b"res://showcase/fixture.tscn"}
        pck(package / "index.pck", files)
        manifest = {"engine": config["engine"], "entry": config["target"]["entry"], "root_sources": {n: sha(root / n) for n in runtime_files},
                    "sources": {n: sha(stage / n) for n in [*runtime_files, "project.godot", "export_presets.cfg", "shell.html"]},
                    "admission_manifest_sha256": sha(root / "runtime.json"), "outputs": {n: {"bytes": (package / n).stat().st_size, "sha256": sha(package / n)} for n in ["index.html", "index.pck"]}}
        (package / "build_manifest.json").write_text(json.dumps(manifest))
        config["admission"].update(record_sha256=sha(root / "release.json"), runtime_manifest_sha256=sha(root / "runtime.json"))
        config["package"].update(manifest_sha256=sha(package / "build_manifest.json"), pck_sha256=sha(package / "index.pck"))
        file = root / "contract.json"
        file.write_text(json.dumps(config))
        return file, files

    def test_synthetic_ordinary_audit(self):
        with tempfile.TemporaryDirectory(prefix="s08x-audit-") as folder:
            root = Path(folder)
            file, _ = self.fixture(root)
            result = audit(file, root)
            self.assertEqual(result["root_sources"], 4)
            self.assertEqual(len(result["models"]), 1)
            self.assertFalse(result["Chrome_started"])
            (root / "aircraft/fixture/data/interfaces.json").write_text("changed")
            with self.assertRaisesRegex(ValueError, "Root source drift"):
                audit(file, root)

    def test_html_and_output_tampering(self):
        with tempfile.TemporaryDirectory(prefix="s08x-drift-") as folder:
            root = Path(folder)
            file, _ = self.fixture(root)
            (root / "build/first-playable/index.html").write_text('<script src="measure.js"></script>')
            with self.assertRaisesRegex(ValueError, "Output drift"):
                audit(file, root)

    def test_raw_interfaces_omitted_by_export_are_rejected(self):
        with tempfile.TemporaryDirectory(prefix="s08x-raw-json-") as folder:
            root = Path(folder)
            file, files = self.fixture(root)
            del files["aircraft/fixture/data/interfaces.json"]
            package = root / "build/first-playable"
            pck(package / "index.pck", files)
            manifest_file = package / "build_manifest.json"
            manifest = json.loads(manifest_file.read_text())
            manifest["outputs"]["index.pck"] = {"bytes":(package / "index.pck").stat().st_size, "sha256":sha(package / "index.pck")}
            manifest_file.write_text(json.dumps(manifest))
            config = json.loads(file.read_text())
            config["package"].update(manifest_sha256=sha(manifest_file), pck_sha256=sha(package / "index.pck"))
            file.write_text(json.dumps(config))
            with self.assertRaisesRegex(ValueError, "Missing admitted runtime resource"):
                audit(file, root)

    def test_untracked_export_file_is_rejected(self):
        with tempfile.TemporaryDirectory(prefix="s08x-untracked-") as folder:
            root = Path(folder)
            file, _ = self.fixture(root)
            (root / "build/first-playable/candidate-only.js").write_text("SYNTHETIC")
            with self.assertRaisesRegex(ValueError, "Untracked file"):
                audit(file, root)

    def test_summary_retains_slow_and_hidden_frames(self):
        with tempfile.TemporaryDirectory(prefix="s08x-summary-") as folder:
            root = Path(folder)
            (root / "run.json").write_text(json.dumps({"status":"SYNTHETIC", "mode":"plain", "contract_sha256":"0" * 64, "cleanup":{}, "phases":[{"name":"plain_1x", "browser_start_ms":0, "browser_end_ms":1000}]}))
            frames = [{"phase":"plain_1x", "at":i, "ms":ms, "visible":visible, "focused":True} for i, ms, visible in [(1,16,"visible"),(2,240,"visible"),(3,70,"hidden")]]
            (root / "frames.ndjson").write_text(json.dumps({"frames":frames}) + "\n")
            result = summary(root)
            self.assertEqual(result["phases"][0]["frames"]["all"]["max_ms"], 240)
            self.assertEqual(result["phases"][0]["frames"]["hidden_frames"], 1)
            self.assertFalse(result["phases"][0]["frames"]["visual_30fps_target_met"])
            self.assertIsNone(result["wasm_bytes"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
