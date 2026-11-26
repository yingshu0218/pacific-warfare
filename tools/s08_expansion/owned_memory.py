#!/usr/bin/env python3
"""macOS memory lookup restricted to caller-supplied isolated Chrome CDP PIDs."""
import ctypes
import json
import sys


def main():
    class Usage(ctypes.Structure):
        _fields_ = [("uuid", ctypes.c_uint8 * 16)] + [(name, ctypes.c_uint64) for name in [
            "user", "system", "pkg", "interrupt", "pageins", "wired", "resident", "footprint", "start", "exit",
            "child_user", "child_system", "child_pkg", "child_interrupt", "child_pageins", "child_elapsed", "disk_read", "disk_write"]]
    library = ctypes.CDLL("/usr/lib/libproc.dylib", use_errno=True)
    rows = []
    for value in sys.argv[1:]:
        pid = int(value)
        if pid <= 0:
            raise ValueError("Explicit positive CDP PID required")
        usage = Usage()
        code = library.proc_pid_rusage(pid, 2, ctypes.byref(usage))
        rows.append({"pid": pid, "resident_bytes": usage.resident if code == 0 else None,
                     "physical_footprint_bytes": usage.footprint if code == 0 else None,
                     "errno": ctypes.get_errno() if code else 0})
    print(json.dumps(rows))


if __name__ == "__main__":
    main()
