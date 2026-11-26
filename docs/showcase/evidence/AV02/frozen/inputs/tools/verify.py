#!/usr/bin/env python3
"""Bounded, serialized local validation. No shell, no global process cleanup."""
from __future__ import annotations

import argparse
import contextlib
import datetime as dt
import fcntl
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
RUN_ROOT = ROOT / ".local" / "validation"
LOCK_PATH = RUN_ROOT / "godot-render.lock"
GODOT = Path("/Applications/Godot.app/Contents/MacOS/Godot")
VERSION = "4.7.2.stable.official.ed1daf0bf"
WRAPPER_STARTED_UTC = dt.datetime.now(dt.timezone.utc).isoformat()
DIAGNOSTIC = re.compile(r"(?:^|\n)\s*(?:SCRIPT ERROR|ERROR|USER ERROR|FATAL ERROR):", re.I)


class LockTimeout(Exception):
    pass


def prepare_run_root():
    RUN_ROOT.mkdir(parents=True, exist_ok=True)
    # Recreate on fresh checkouts; this ignored file must exist before any import.
    marker = RUN_ROOT.parent / ".gdignore"
    if not marker.exists():
        marker.touch()


def process_identity(pid: int) -> str:
    """PID plus kernel start time; metadata is inspectable, flock is authoritative."""
    try:
        result = subprocess.run(["/bin/ps", "-p", str(pid), "-o", "lstart=,command="],
                                capture_output=True, text=True, timeout=2)
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        pass
    # Restricted hosts can deny ps. The kernel-held flock still proves ownership;
    # PID, invocation and launch timestamp remain available for independent audit.
    return f"pid={pid} started_utc={WRAPPER_STARTED_UTC} argv={sys.argv!r} (ps unavailable)"


class ValidationLock:
    def __init__(self, owner: str, timeout: float):
        self.owner, self.timeout = owner, timeout
        self.handle = None
        self.token = uuid.uuid4().hex

    def __enter__(self):
        prepare_run_root()
        # Never unlink this inode: waiters must all lock the same kernel object.
        self.handle = LOCK_PATH.open("a+", encoding="utf-8")
        deadline = time.monotonic() + self.timeout
        try:
            while True:
                try:
                    fcntl.flock(self.handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    break
                except BlockingIOError:
                    if time.monotonic() >= deadline:
                        self.handle.seek(0)
                        raise LockTimeout(self.handle.read().strip())
                    time.sleep(min(0.05, max(0, deadline - time.monotonic())))
            self.metadata = {
                "status": "held", "owner": self.owner, "pid": os.getpid(),
                "process_identity": process_identity(os.getpid()), "token": self.token,
                "acquired_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
                "project": str(ROOT),
            }
            self._write()
            return self
        except BaseException:
            self.handle.close()
            raise

    def _write(self):
        self.handle.seek(0)
        self.handle.truncate()
        self.handle.write(json.dumps(self.metadata, ensure_ascii=False, indent=2) + "\n")
        self.handle.flush()
        os.fsync(self.handle.fileno())

    def __exit__(self, *_):
        try:
            self.metadata.update(status="released", released_utc=dt.datetime.now(dt.timezone.utc).isoformat())
            self._write()
        finally:
            fcntl.flock(self.handle, fcntl.LOCK_UN)
            self.handle.close()


def group_exists(pgid: int) -> bool:
    try:
        os.killpg(pgid, 0)
        return True
    except ProcessLookupError:
        return False


def cleanup_group(process: subprocess.Popen) -> bool:
    """Only signal the new session/process group created by this invocation."""
    pgid = process.pid
    for sig, grace in ((signal.SIGTERM, 0.5), (signal.SIGKILL, 1.5)):
        process.poll()  # reap the direct child, including normal exits
        if not group_exists(pgid):
            return True
        with contextlib.suppress(ProcessLookupError):
            os.killpg(pgid, sig)
        until = time.monotonic() + grace
        while time.monotonic() < until:
            process.poll()
            if not group_exists(pgid):
                return True
            time.sleep(0.025)
    with contextlib.suppress(subprocess.TimeoutExpired):
        process.wait(timeout=0.2)
    return not group_exists(pgid)


def run_child(command: list[str], cwd: Path, timeout: float, output_path: Path) -> dict:
    started = time.monotonic()
    process = None
    timed_out = False
    interrupted = False
    clean = True
    cleanup_error = ""
    launch_error = ""
    try:
        # A file avoids pipe deadlocks when descendants inherit stdout/stderr.
        with output_path.open("wb") as output:
            process = subprocess.Popen(command, cwd=cwd, stdout=output, stderr=subprocess.STDOUT,
                                       start_new_session=True)
            try:
                process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                timed_out = True
            except KeyboardInterrupt:
                interrupted = True
    except OSError as exc:
        launch_error = str(exc)
    finally:
        if process is not None:
            try:
                clean = cleanup_group(process)
            except OSError as exc:
                # Retain ownership and exit evidence even when the host denies
                # process-group inspection/signalling. A failed cleanup is fatal.
                clean = False
                cleanup_error = f"{type(exc).__name__}: {exc}"
                process.poll()
    output = output_path.read_text(errors="replace") if output_path.exists() else ""
    # Strip ANSI styling before checking Godot diagnostics.
    diagnostic = bool(DIAGNOSTIC.search(re.sub(r"\x1b\[[0-9;]*m", "", output)))
    return {
        "command": command, "cwd": str(cwd), "pid": process.pid if process else None,
        "process_group": process.pid if process else None,
        "returncode": process.returncode if process else None, "timed_out": timed_out,
        "interrupted": interrupted, "diagnostic_error": diagnostic, "launch_error": launch_error,
        "cleanup_ok": clean, "cleanup_error": cleanup_error,
        "duration_s": round(time.monotonic() - started, 4),
        "output": str(output_path),
        "passed": bool(process is not None and process.returncode == 0 and not timed_out
                       and not interrupted and not diagnostic and clean and not launch_error),
    }


def positive_float(value: str) -> float:
    number = float(value)
    if not 0 < number < float("inf"):
        raise argparse.ArgumentTypeError("must be finite and positive")
    return number


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--owner", required=True, help="chat/task name; visible in lock and logs")
    parser.add_argument("--timeout", type=positive_float, default=60.0, help="seconds per subprocess")
    parser.add_argument("--lock-timeout", type=positive_float, default=15.0)
    parser.add_argument("--project", type=Path, default=ROOT, help="explicit Godot project root")
    parser.add_argument("--godot", type=Path, default=GODOT)
    sub = parser.add_subparsers(dest="action", required=True)
    sub.add_parser("version")
    sub.add_parser("import")
    test = sub.add_parser("test")
    test.add_argument("scripts", nargs="+", help="res:// script paths, run sequentially")
    custom = sub.add_parser("godot", help="bounded raw Godot args (headless added by default)")
    custom.add_argument("--render", action="store_true", help="explicit opt-in to native rendering")
    custom.add_argument("args", nargs=argparse.REMAINDER)
    custom = sub.add_parser("exec", help="other validation process, under the same render lock")
    custom.add_argument("args", nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)
    project = args.project.resolve()
    if not (project / "project.godot").is_file():
        parser.error("--project must contain project.godot")
    run_id = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%S") + "-" + uuid.uuid4().hex[:8]
    run_dir = RUN_ROOT / "runs" / run_id
    prepare_run_root()
    run_dir.mkdir(parents=True)
    report = {"run_id": run_id, "owner": args.owner, "action": args.action, "project": str(project),
              "lock": str(LOCK_PATH), "wrapper_pid": os.getpid(), "checks": [], "passed": False}
    code = 1
    try:
        with ValidationLock(args.owner, args.lock_timeout) as lock:
            report["lock_identity"] = lock.metadata.copy()
            if args.action == "exec":
                command = args.args[1:] if args.args[:1] == ["--"] else args.args
                if not command:
                    parser.error("exec requires a command after --")
                commands = [command]
            else:
                version = run_child([str(args.godot), "--version"], project, args.timeout, run_dir / "00-version.log")
                version["expected_version"] = VERSION
                version["version_matches"] = Path(version["output"]).read_text(errors="replace").strip() == VERSION
                version["passed"] = version["passed"] and version["version_matches"]
                report["checks"].append(version)
                if not version["passed"]:
                    raise RuntimeError("Godot version check failed")
                base = [str(args.godot), "--headless", "--path", str(project)]
                if args.action == "version":
                    commands = []
                elif args.action == "import":
                    commands = [base + ["--editor", "--import", "--quit"]]
                elif args.action == "test":
                    commands = [base + ["--script", script] for script in args.scripts]
                else:
                    extra = args.args[1:] if args.args[:1] == ["--"] else args.args
                    if args.render:
                        base.remove("--headless")
                    commands = [base + extra]
            for index, command in enumerate(commands, start=1):
                result = run_child(command, project, args.timeout, run_dir / f"{index:02d}-output.log")
                report["checks"].append(result)
                if not result["passed"]:
                    break
            report["passed"] = bool(report["checks"]) and all(c["passed"] for c in report["checks"])
            code = 0 if report["passed"] else 1
    except LockTimeout as exc:
        report["error"] = "lock_timeout"
        report["lock_owner"] = str(exc)
        code = 2
    except (RuntimeError, OSError) as exc:
        report["error"] = str(exc)
    except KeyboardInterrupt:
        report["error"] = "interrupted"
        code = 130
    finally:
        report["exit_code"] = code
        (run_dir / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
        print(json.dumps({"passed": report["passed"], "exit_code": code,
                          "report": str(run_dir / "report.json")}, ensure_ascii=False))
    return code


if __name__ == "__main__":
    # SIGTERM follows the same Python finally cleanup path as Ctrl-C.
    signal.signal(signal.SIGTERM, lambda *_: (_ for _ in ()).throw(KeyboardInterrupt()))
    sys.exit(main())
