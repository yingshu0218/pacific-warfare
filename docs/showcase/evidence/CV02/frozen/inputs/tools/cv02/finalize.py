#!/usr/bin/env python3
"""Freeze CV02's exact tested sources, reports and output/reference hashes."""
from pathlib import Path
import datetime as dt
import hashlib
import json
import shutil

ROOT=Path(__file__).resolve().parents[2]
EV=ROOT/"docs/showcase/evidence/CV02"
STAGE=ROOT/".local/cv02-web-project"

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    build=json.loads((EV/"build_manifest.json").read_text())
    target=EV/"frozen/inputs"
    target.mkdir(parents=True,exist_ok=True)
    (target.parent/".gdignore").touch()
    source_hashes={}
    for name,expected in build["source_sha256"].items():
        path=STAGE/name
        assert sha(path)==expected,"Staged source mismatch: "+name
        assert sha(ROOT/name)==expected,"Live input changed after validation: "+name
        copy=target/name;copy.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(path,copy)
        source_hashes[name]=sha(copy)
    extras=[ROOT/"tools/verify.py",ROOT/"AGENTS.md",ROOT/"docs/carrier-deck-contracts.md",
            ROOT/"naval/shokaku_1941_08_23/inspection/test_shokaku.gd"]+list((ROOT/"tools/cv02").glob("*.py"))+list((ROOT/"tools/cv02").glob("*.mjs"))
    for path in extras:
        name=str(path.relative_to(ROOT));copy=target/name;copy.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(path,copy)
        source_hashes[name]=sha(copy)
    records=[]
    for path in sorted((ROOT/".local/validation/runs").glob("*/report.json")):
        report=json.loads(path.read_text())
        if report.get("owner")!="CV02": continue
        directory=EV/"validation"/report["run_id"];directory.mkdir(parents=True,exist_ok=True)
        for log in path.parent.iterdir():
            if log.is_file():shutil.copy2(log,directory/log.name)
        records.append({"run_id":report["run_id"],"action":report["action"],"passed":report["passed"],
                        "exit_code":report["exit_code"],"report":str((directory/"report.json").relative_to(ROOT)),
                        "cleanup_ok":all(c["cleanup_ok"] for c in report["checks"])})
    source_text=json.dumps(source_hashes,sort_keys=True,separators=(",",":"))
    reference=ROOT/"docs/references/ships/shokaku_1941_08_23"
    reference_hashes={str(p.relative_to(ROOT)):sha(p) for p in reference.rglob("*") if p.is_file() and p.suffix!=".import"}
    # The manifest excludes itself and the frozen copies already listed above.
    evidence_hashes={str(p.relative_to(ROOT)):sha(p) for p in EV.rglob("*")
                     if p.is_file() and p.suffix!=".import" and "frozen" not in p.relative_to(EV).parts
                     and p.name!="delivery_manifest.json"}
    tests=json.loads((EV/"mechanisms.json").read_text())
    chrome=json.loads((EV/"chrome/run.json").read_text())
    cleanup=json.loads((EV/"process-audit.json").read_text())
    assert tests["passed"] and chrome["passed"] and cleanup["all_previous_CV02_groups_gone"]
    assert all(row["cleanup_ok"] for row in records)
    manifest={"task":"CV02","frozen_utc":dt.datetime.now(dt.timezone.utc).isoformat(),"engine":build["engine"],
        "status":"Implemented; headless/native/Chrome checks complete. Coordinator owns final admission and live registration.",
        "source_file_count":len(source_hashes),"source_sha256":source_hashes,
        "source_manifest_sha256":hashlib.sha256(source_text.encode()).hexdigest(),
        "references_sha256":reference_hashes,"evidence_sha256":evidence_hashes,
        "web_output_sha256":build["output_sha256"],"validation_runs":records,
        "headless_check_count":len(tests["checks"]),"chrome_check_count":len(chrome["checks"]),"chrome_cadence":chrome["cadence"],
        "ordinary_showcase_modified":False,"runtime_data_registered":False,
        "native_evidence":"native-r4 full set + native-depth two corrected port views; Chrome full set uses exact frozen final source",
        "known_limits":["Source gaps/hidden shapes and exact historical station precision retained in modeling-brief",
            "Dedicated-AA game six triples differs from historical twelve",
            "Nine wire stations are functional reconstruction, not verified historical count",
            "Unchanged old A6M parked attitude/gear limitations; D4Y is dimensions only",
            "Pure model/static bearing only; no OPS01/AA combat/bombing/full-fleet performance claim"],
        "cleanup":"All owned validation child groups exited; Chrome, temporary HTTP server and profile removed; no user windows closed"}
    (EV/"delivery_manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({"sources":len(source_hashes),"source_manifest_sha256":manifest["source_manifest_sha256"],
                      "headless_checks":len(tests["checks"]),"chrome_checks":len(chrome["checks"]),
                      "validation_runs":len(records),"manifest":str(EV/"delivery_manifest.json")},ensure_ascii=False))

if __name__=="__main__":main()
