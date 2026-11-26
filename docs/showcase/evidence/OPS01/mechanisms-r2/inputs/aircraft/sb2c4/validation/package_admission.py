#!/usr/bin/env python3
"""Freeze SB2C native evidence; run through tools/verify.py exec."""
from pathlib import Path
import datetime as dt
import difflib
import hashlib
import json
import os
import shutil

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = ROOT / "docs/showcase/evidence/SB2C-admission"
LOCK = ROOT / ".local/validation/godot-render.lock"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    lock = json.loads(LOCK.read_text())
    if lock.get("owner") != "SB2C-admission" or lock.get("status") != "held":
        raise SystemExit("Run through tools/verify.py --owner SB2C-admission exec.")
    before = json.loads((EVIDENCE / "sources-before.json").read_text())
    interface = json.loads((EVIDENCE / "interfaces.json").read_text())
    paths = [
        "aircraft/sb2c4/sb2c4.gd", "aircraft/sb2c4/showcase.gd",
        "aircraft/sb2c4/sb2c4.tscn", "aircraft/sb2c4/showcase.tscn",
        "aircraft/sb2c4/validation/test_sb2c4_admission.gd",
        "aircraft/sb2c4/validation/package_admission.py",
        "aircraft/scripts/aircraft_builder.gd",
        "scripts/showcase/sb2c_flight_adapter.gd", "project.godot",
    ]
    hashes = {p: digest(ROOT / p) for p in paths}
    expected = {
        "model_source_sha256": hashes["aircraft/sb2c4/sb2c4.gd"],
        "showcase_source_sha256": hashes["aircraft/sb2c4/showcase.gd"],
        "shared_builder_sha256": hashes["aircraft/scripts/aircraft_builder.gd"],
    }
    captures = []
    for path in sorted((EVIDENCE / "final").glob("*.png")):
        metadata_path = Path(str(path) + ".json")
        metadata = json.loads(metadata_path.read_text())
        for key, value in expected.items():
            if metadata[key] != value:
                raise SystemExit(f"Stale capture: {path.name} {key}")
        captures.append({"file": str(path.relative_to(EVIDENCE)), "sha256": digest(path),
                         "metadata": str(metadata_path.relative_to(EVIDENCE)),
                         "metadata_sha256": digest(metadata_path),
                         "view": metadata["view"], "mode": metadata["mode"], "pose": metadata["pose"]})
    if len(captures) != 14 or interface["model_source_sha256"] != expected["model_source_sha256"] or interface["failures"]:
        raise SystemExit("Final captures/test do not match the frozen model.")
    if interface["shared_builder_sha256"] != expected["shared_builder_sha256"]:
        raise SystemExit("Shared dependency changed after the final contract check.")
    side_before = json.loads((EVIDENCE / "baseline/reference-side-flight.png.json").read_text())
    side_after = json.loads((EVIDENCE / "final/side-flight.png.json").read_text())
    camera_keys = ["camera_position_m", "camera_rotation_rad", "camera_projection", "camera_size_m"]
    same_side_camera = all(side_before[k] == side_after[k] for k in camera_keys)
    if not same_side_camera:
        raise SystemExit("Before/after side camera drifted.")
    index = []
    live_groups = []
    for report_path in sorted((ROOT / ".local/validation/runs").glob("*/report.json")):
        report = json.loads(report_path.read_text())
        if report.get("owner") != "SB2C-admission" or report["run_id"] < "20261110T183132":
            continue
        dest = EVIDENCE / "logs" / report["run_id"]
        dest.mkdir(parents=True, exist_ok=True)
        shutil.copy2(report_path, dest / "report.json")
        for log in report_path.parent.glob("*.log"):
            shutil.copy2(log, dest / log.name)
        checks = []
        for check in report.get("checks", []):
            item = {k: check.get(k) for k in ["command", "returncode", "timed_out", "diagnostic_error", "cleanup_ok", "duration_s", "passed", "process_group"]}
            checks.append(item)
            pgid = check.get("process_group")
            if pgid:
                try:
                    os.killpg(pgid, 0)
                except ProcessLookupError:
                    pass
                else:
                    live_groups.append({"run_id": report["run_id"], "process_group": pgid})
        index.append({"run_id": report["run_id"], "action": report["action"], "passed": report["passed"],
                      "exit_code": report["exit_code"], "error": report.get("error", ""),
                      "report": str((dest / "report.json").relative_to(EVIDENCE)), "checks": checks})
    if live_groups:
        raise SystemExit("An owned validation process group is still alive: " + repr(live_groups))
    (EVIDENCE / "verification-index.json").write_text(json.dumps(index, ensure_ascii=False, indent=2) + "\n")
    cleanup = {
        "checked_utc": dt.datetime.now(dt.timezone.utc).isoformat(), "owned_child_process_groups_remaining": live_groups,
        "all_recorded_child_cleanup_ok": all(c.get("cleanup_ok") is not False for r in index for c in r["checks"]),
        "created_browser_tabs": 0, "created_http_services": 0,
        "scope": "SB2C-admission only; unrelated user/DM01 processes were not signalled",
        "lock": "held by this bounded packaging invocation; verify.py releases it on return",
    }
    (EVIDENCE / "cleanup.json").write_text(json.dumps(cleanup, ensure_ascii=False, indent=2) + "\n")
    restore = Path(before["restore"])
    changes = []
    for name in ["aircraft/sb2c4/sb2c4.gd", "aircraft/sb2c4/showcase.gd"]:
        changes.extend(difflib.unified_diff((restore / name).read_text().splitlines(True),
                                          (ROOT / name).read_text().splitlines(True),
                                          fromfile="before/" + name, tofile="after/" + name))
    (EVIDENCE / "source-changes.diff").write_text("".join(changes))
    original_refs = ["extra_09.jpg", "extra_10.jpg", "05.jpg", "extra_11.jpg",
                     "wright-state-sb2c4-side-preview.jpg", "target/sb2c4-outer-form-candidate-v04.png"]
    refs = {name: digest(ROOT / "docs/references/bombers/sb2c" / name) for name in original_refs}
    manifest = {
        "date_cn": "2026-11-11", "generated_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "status": "native_checks_complete_pending_coordinator_final_admission",
        "source_hashes": hashes, "reference_hashes": refs, "captures": captures,
        "same_before_after_side_camera": same_side_camera,
        "same_before_after_side_shared_builder": side_before["shared_builder_sha256"] == side_after["shared_builder_sha256"],
        "restore": before["restore"], "baseline_manifest": "sources-before.json",
        "interface": "interfaces.json", "verification": "verification-index.json", "cleanup": "cleanup.json",
    }
    (EVIDENCE / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    (EVIDENCE / "comparison.md").write_text("""# SB2C 原始资料与同模型对照

2026-11-11。原始照片、AI 风格图、Godot 画面分别保存。以下模型截图均来自本轮冻结源码；相机参数与哈希在各 PNG 的同名 .json 中。照片没有作形体修补或 AI 处理。

## 飞行侧轮廓

| 实机原始公开预览 R04 | Godot 最终飞行形态 |
| --- | --- |
| ![Wright State SB2C-4 原始预览](../../../references/bombers/sb2c/wright-state-sb2c4-side-preview.jpg) | ![最终侧视](final/side-flight.png) |

R04 的馆藏身份为 SB2C-4、左侧飞行照，公开预览仅 400×327（机体有效宽约 277 px）。只能核大形、后腹收束、风挡位置与尾轮大致站位，不能据此声称精确厂图坐标；不将它当作历史涂装模板。最终模型为收轮飞行检查，原图尾轮可见，两者状态差异保留。

## 同机位的修改前后

| 本轮最初模型，同向飞行侧视 | 最终模型，同一相机与飞行姿态 |
| --- | --- |
| ![准入前](baseline/reference-side-flight.png) | ![冻结后](final/side-flight.png) |

这一对相机位置、旋转、投影、尺寸相同；共享 builder 哈希也由打包脚本核对。机身长宽没有整体缩放。主要差异是连续圆鼻、加深中机身、向上收束的后腹、尾端与垂尾关系，以及后倾风挡。r1 只作中间反例留档，不作为最终交付。

## 斜前与斜后完整对照

| 原始成品模型照片 | Godot 简化模型，接近方向的停放视图 |
| --- | --- |
| ![R01 斜前](../../../references/bombers/sb2c/extra_09.jpg) | ![斜前](final/reference-front-parked.png) |
| ![R02 斜后](../../../references/bombers/sb2c/extra_10.jpg) | ![斜后](final/reference-rear-parked.png) |

R01/R02 是同一作者的 1/48 成品相册，原照片有透视及打开的减速板。模型使用透视相机并采用简化停放姿态、闭合面板。方向和占幅已校，但摄影内参未知，不作逐像素测绘或历史独立来源的双重证明。

## 安装与正常观察距离

| 主要承载局部原图 R05 | Godot 必要支撑 |
| --- | --- |
| ![后座枪架原图](../../../references/bombers/sb2c/extra_11.jpg) | ![简化环轨支撑](final/gunner-support.png) |

枪架只保留环轨、短支撑和双枪外形；原图能支持环轨/围框与枪座的关系，无法证明内部全机构。枪身整体静态上仰 24°，避免穿入垂尾，尚未接火控。小孔与内部机械不制作。

![正常观战距离](final/observer-distance-flight.png)

以上为真实 Godot 原生画面，非 AI 图。AI v04 仅作曲面/纯色/简化程度目标，见原参考目录，不能作为历史形状或本轮运行证据。

正前和俯视截图只证明本模型的对称、比例和连接；本轮仍未取得可量取的同子型实机正前/严格正投影顶视原图。尾轮和支杆坐标、罩体截面与枪架精确尺寸仍属于照片估计。
""")
    print(json.dumps({"captures": len(captures), "wrapper_runs": len(index), "model_sha256": expected["model_source_sha256"],
                      "live_owned_groups": live_groups, "same_side_camera": same_side_camera,
                      "same_side_builder": manifest["same_before_after_side_shared_builder"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
