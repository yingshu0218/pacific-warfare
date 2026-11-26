#!/usr/bin/env python3
"""Exercise the real CLI, including diagnostic-only failures and process ownership."""
from __future__ import annotations
import importlib.util
import fcntl
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("verify", ROOT / "tools/verify.py")
VERIFY = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VERIFY)


class VerificationWrapperTests(unittest.TestCase):
    def command(self, source: str, timeout: float = 5, lock_timeout: float = 5):
        return [sys.executable, str(ROOT / "tools/verify.py"), "--owner", "S01-wrapper-test",
                "--timeout", str(timeout), "--lock-timeout", str(lock_timeout),
                "exec", "--", sys.executable, "-u", "-c", source]

    def run_cli(self, source: str, **kwargs):
        result = subprocess.run(self.command(source, **kwargs), capture_output=True, text=True, timeout=15)
        self.assertTrue(result.stdout.strip(), result.stderr)
        summary = json.loads(result.stdout.splitlines()[-1])
        report = json.loads(Path(summary["report"]).read_text())
        self.assertEqual(result.returncode, report["exit_code"])
        return result.returncode, report

    def test_success_and_failure_modes(self):
        code, report = self.run_cli("print('controlled success')")
        self.assertEqual(code, 0)
        self.assertTrue(report["checks"][0]["cleanup_ok"])
        code, report = self.run_cli("raise SystemExit(7)")
        self.assertEqual(code, 1)
        self.assertEqual(report["checks"][0]["returncode"], 7)
        for diagnostic in ("ERROR: controlled zero-exit failure", "SCRIPT ERROR: controlled failure"):
            code, report = self.run_cli(f"print({diagnostic!r})")
            self.assertEqual(code, 1)
            self.assertEqual(report["checks"][0]["returncode"], 0)
            self.assertTrue(report["checks"][0]["diagnostic_error"])

    def test_timeout_and_descendant_cleanup(self):
        with tempfile.TemporaryDirectory(prefix="wrapper-test-", dir=VERIFY.RUN_ROOT) as directory:
            pidfile = Path(directory) / "child.pid"
            source = (
                "import subprocess,sys,time,signal; from pathlib import Path; "
                "child=subprocess.Popen([sys.executable,'-c','import time; time.sleep(30)']); "
                f"Path({str(pidfile)!r}).write_text(str(child.pid)); "
                "signal.signal(signal.SIGTERM,lambda *_: (child.wait(timeout=1),sys.exit(0))); "
                "time.sleep(30)"
            )
            code, report = self.run_cli(source, timeout=0.5)
            self.assertEqual(code, 1)
            check = report["checks"][0]
            self.assertTrue(check["timed_out"])
            self.assertTrue(check["cleanup_ok"])
            self.assertFalse(VERIFY.group_exists(check["process_group"]))
            with self.assertRaises(ProcessLookupError):
                os.kill(int(pidfile.read_text()), 0)

    def test_lock_contention_and_release(self):
        holder = subprocess.Popen(self.command("import time; time.sleep(1.5)"),
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            deadline = time.monotonic() + 5
            metadata = {}
            while time.monotonic() < deadline:
                try:
                    metadata = json.loads(VERIFY.LOCK_PATH.read_text())
                except (FileNotFoundError, json.JSONDecodeError):
                    pass
                if metadata.get("pid") == holder.pid and metadata.get("status") == "held":
                    break
                time.sleep(0.025)
            self.assertEqual(metadata.get("pid"), holder.pid)
            self.assertIn(str(ROOT / "tools/verify.py"), metadata["process_identity"])
            code, report = self.run_cli("raise RuntimeError('must never launch')", lock_timeout=0.1)
            self.assertEqual(code, 2)
            self.assertEqual(report["error"], "lock_timeout")
            self.assertEqual(report["checks"], [])
            stdout, stderr = holder.communicate(timeout=7)
            self.assertEqual(holder.returncode, 0, stdout + stderr)
            code, report = self.run_cli("print('lock reused')")
            self.assertEqual(code, 0)
            self.assertEqual(json.loads(VERIFY.LOCK_PATH.read_text())["status"], "released")
        finally:
            if holder.poll() is None:
                holder.terminate()
            holder.communicate(timeout=7)

    def test_stale_metadata_cannot_block(self):
        # Simulates stale owner text after an abnormal exit, without touching a live lock.
        lock = VERIFY.ValidationLock("S01-stale-fixture", 5).__enter__()
        try:
            lock.metadata.update(pid=99999999, owner="dead-owner", status="held")
            lock._write()
        finally:
            # Model OS release after a crash while retaining stale metadata.
            fcntl.flock(lock.handle, fcntl.LOCK_UN)
            lock.handle.close()
        # Actual locking never depends on either the PID text or file existence.
        code, report = self.run_cli("print('recovered stale metadata')")
        self.assertEqual(code, 0)
        self.assertTrue(report["passed"])

    def test_launch_failure(self):
        with VERIFY.ValidationLock("S01-launch-failure-test", 5):
            result = VERIFY.run_child(["/nonexistent/S01-fixture"], ROOT, 1,
                                      VERIFY.RUN_ROOT / "missing-executable.log")
        self.assertFalse(result["passed"])
        self.assertTrue(result["launch_error"])
        self.assertTrue(result["cleanup_ok"])

    def test_cleanup_permission_failure_retains_child_evidence(self):
        with VERIFY.ValidationLock("S08-cleanup-failure-test", 5):
            with patch.object(VERIFY, "cleanup_group", side_effect=PermissionError(1, "controlled denial")):
                result = VERIFY.run_child([sys.executable, "-c", "print('exited normally')"], ROOT, 2,
                                          VERIFY.RUN_ROOT / "cleanup-denied.log")
        self.assertFalse(result["passed"])
        self.assertFalse(result["cleanup_ok"])
        self.assertIn("PermissionError", result["cleanup_error"])
        self.assertGreater(result["pid"], 0)
        self.assertEqual(result["process_group"], result["pid"])
        self.assertEqual(result["returncode"], 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
