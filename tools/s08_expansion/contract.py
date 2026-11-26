"""Read-only final-input binding. Importing this module starts no process."""
from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path, PurePosixPath
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[2]
VERSION = "4.7.2.stable.official.ed1daf0bf"
HEX = re.compile(r"[0-9a-f]{64}\Z")
GROUPS = {"sb2c_bombing", "d4y_bombing", "g4m_bombing", "b25_bombing", "interception_one", "interception_two"}
FEATURES = {"both_commanders", "execution_detail", "sound_pause", "slow_speed", "request_2x", "request_4x", "restart", "active_1x"}


def require(value, message):
    if not value:
        raise ValueError(message)


def sha(path):
    value = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def relative_name(value):
    require(isinstance(value, str) and value, "Missing relative resource path")
    path = PurePosixPath(value)
    require(not path.is_absolute() and ".." not in path.parts and "\\" not in value, "Unsafe resource path: " + value)
    require(str(path) == value and not value.startswith("."), "Noncanonical resource path: " + value)
    return value


def local_path(root, value):
    require(isinstance(value, str) and value, "Missing final-input path")
    path = (root / value).resolve()
    require(path.is_relative_to(root.resolve()), "Final-input path escapes repository")
    return path


def read_bound(root, value, digest, description):
    require(isinstance(digest, str) and HEX.fullmatch(digest), "Missing final SHA256: " + description)
    path = local_path(root, value)
    require(path.is_file() and sha(path) == digest, "Hash mismatch: " + description)
    return json.loads(path.read_text())


def validate(config):
    """Validate binding shape only; no filesystem writes or browser imports."""
    require(config.get("schema") == 1, "Unsupported contract schema")
    require(config.get("status") == "released_for_s08", "Waiting for coordinator's final admission and frozen contract")
    require(config.get("engine") == VERSION, "Engine version differs from repository contract")
    target = config["target"]
    require(target.get("scene") == "expanded" and str(target.get("entry", "")).startswith("res://"), "Missing expanded entry")
    require(target.get("title_contains"), "Missing real final page identity")
    require(target.get("buffer") == [1280, 720], "Explicit performance buffer must be 1280x720")
    url = urlsplit(target["url"])
    require(url.scheme == "http" and url.hostname == "127.0.0.1" and url.port == 8765 and url.path == "/index.html" and not url.query and not url.fragment, "Use the ordinary default localhost URL")
    for block, pairs in [("admission", [("record", "record_sha256"), ("runtime_manifest", "runtime_manifest_sha256")]), ("package", [("manifest", "manifest_sha256")])]:
        for name, digest in pairs:
            require(config[block].get(name) and HEX.fullmatch(config[block].get(digest) or ""), "Unbound input: " + block + "." + name)
    require(HEX.fullmatch(config["package"].get("pck_sha256") or ""), "Missing final PCK hash")
    require(config["package"].get("stage") and config["package"].get("required_resources"), "Missing frozen stage or required runtime resources")
    probe = config["probe"]
    require(probe.get("protocol") in ("receive-events-v1", 2), "Unbound or unsupported probe adapter; confirm final S14 contract")
    require(probe.get("global") and probe.get("metrics_global") and probe["global"] != probe["metrics_global"], "Unbound probe globals")
    require(probe.get("serialization") == "compact-state-and-event-deltas", "Performance contract still repeats complete order/log history")
    require(probe.get("source_paths"), "Missing final probe source provenance")
    runtime = config["runtime"]
    require(runtime.get("chrome") and runtime.get("playwright_module"), "Missing locally available Chrome or Playwright path")
    require(1 <= runtime["max_seconds"] <= 3600 and 10 <= runtime["plain_seconds"] <= 300, "Unbounded browser lifetime")
    require(0 <= runtime["warmup_seconds"] <= 60, "Unbounded warmup")
    require(0 < runtime["max_record_bytes"] <= runtime["max_queued_bytes"] <= runtime["max_evidence_bytes"] <= 512 * 1024 * 1024, "Invalid evidence byte budgets")
    require(0 < runtime["max_wire_bytes"] <= 4 * 1024 * 1024, "Invalid wire budget")
    acceptance = config["acceptance"]
    require(set(acceptance["groups"]) == GROUPS and set(acceptance["required_features"]) >= FEATURES, "Do not remove requested acceptance coverage")
    require(acceptance["minimum_active_wall_s"] >= 600 and acceptance["minimum_restarts"] >= 3, "Long-run/restart requirements cannot be reduced")
    require(acceptance["p95_target_ms"] <= 33.3, "Do not relax performance target")
    require(config["bindings"].get("ended"), "Bind final authoritative end state; do not count ended scenes as active runtime")
    require(config["bindings"].get("sound"), "Bind final sound-enabled state for pause verification")
    cases = config["cases"]
    require(cases and {c.get("group") for c in cases} >= GROUPS, "Bind four attack-task cases (including SB2C abort) and two real interception cases")
    require({v for c in cases for v in c.get("features", [])} >= FEATURES, "Bind controls, command UI and active-run coverage")
    ids = [c.get("key") for c in cases]
    require(all(isinstance(v, str) and re.fullmatch(r"[a-z0-9_]+", v) for v in ids) and len(set(ids)) == len(ids), "Unique evidence case keys required")
    for case in cases:
        require(case.get("steps"), "Missing real menu/input actions for " + case["key"])
        for step in case["steps"]:
            require(step.get("action") in {"menu", "button", "control", "key", "wait", "sample", "pause_check", "screenshot", "checkpoint"}, "Unsupported action; no arbitrary JS evaluation")
            if step["action"] == "menu":
                label = isinstance(step.get("label"), str) and bool(step["label"])
                metadata = "metadata" in step and step["metadata"] is not None
                require(step.get("menu") and label != metadata, "Resolve menus by one final visible label or metadata, never a guessed index")
            if step["action"] == "sample":
                require(0 < step.get("seconds", 0) <= 900, "Bound sample interval")
            if step["action"] == "pause_check":
                require(1 <= step.get("seconds", 0) <= 10, "Bound sound-enabled pause interval")
    return config


def load(path, root=ROOT):
    config = validate(json.loads(Path(path).read_text()))
    read_bound(root, config["admission"]["record"], config["admission"]["record_sha256"], "coordinator admission record")
    runtime = read_bound(root, config["admission"]["runtime_manifest"], config["admission"]["runtime_manifest_sha256"], "runtime admission manifest")
    manifest = read_bound(root, config["package"]["manifest"], config["package"]["manifest_sha256"], "ordinary build manifest")
    return config, runtime, manifest
