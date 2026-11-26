#!/usr/bin/env python3
"""Read-only audit of CV02 wrapper identities and child process groups."""
import json
import subprocess
import socket
from urllib.parse import urlparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
result = subprocess.run(["/bin/ps","-e","-o","pid=,pgid="],capture_output=True,text=True,check=True,timeout=5)
live = [tuple(map(int,line.split())) for line in result.stdout.splitlines()]
pids = {pid for pid,_ in live}
groups = {pgid for _,pgid in live}
rows = []
for report in sorted((ROOT/".local/validation/runs").glob("*/report.json")):
    data = json.loads(report.read_text())
    if data.get("owner")!="CV02":
        continue
    rows.append({"run_id":data["run_id"],"wrapper_alive":data["wrapper_pid"] in pids,
                 "groups_alive":[c["process_group"] for c in data["checks"] if c.get("process_group") in groups],
                 "cleanup_ok":all(c["cleanup_ok"] for c in data["checks"]),
                 "passed":data["passed"],"report":str(report.relative_to(ROOT))})
chrome_path=ROOT/"docs/showcase/evidence/CV02/chrome/run.json"
chrome={}
if chrome_path.exists():
    browser=json.loads(chrome_path.read_text())
    address=urlparse(browser["url"])
    with socket.socket() as probe:
        probe.settimeout(1)
        port_closed=probe.connect_ex((address.hostname,address.port))!=0
    chrome={"reported_cleanup":browser["cleanup"],"owned_http_port":address.port,"owned_http_port_closed":port_closed,
            "remaining_owned_profiles":[str(p.relative_to(ROOT)) for p in (ROOT/".local").glob("cv02-chrome-*")]}
output = ROOT/"docs/showcase/evidence/CV02/process-audit.json"
output.write_text(json.dumps({"read_only":True,"runs":rows,"chrome":chrome,"all_previous_CV02_groups_gone":all(not r["wrapper_alive"] and not r["groups_alive"] and r["cleanup_ok"] for r in rows)},indent=2)+"\n")
print(json.dumps(rows))
assert all(not r["wrapper_alive"] and not r["groups_alive"] and r["cleanup_ok"] for r in rows)
if chrome:
    assert chrome["owned_http_port_closed"] and not chrome["remaining_owned_profiles"]
