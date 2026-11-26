#!/usr/bin/env python3
"""Read memory only for explicit PIDs supplied by the owned Chrome CDP session."""
import ctypes,json,sys
class Usage(ctypes.Structure):
    _fields_=[('uuid',ctypes.c_uint8*16)]+[(name,ctypes.c_uint64) for name in ['user','system','pkg','interrupt','pageins','wired','resident','footprint','start','exit','child_user','child_sys','child_pkg','child_interrupt','child_pageins','child_elapsed','disk_read','disk_write']]
lib=ctypes.CDLL('/usr/lib/libproc.dylib',use_errno=True)
rows=[]
for value in sys.argv[1:]:
    pid=int(value);u=Usage();code=lib.proc_pid_rusage(pid,2,ctypes.byref(u))
    rows.append({'pid':pid,'resident_bytes':u.resident if code==0 else None,'physical_footprint_bytes':u.footprint if code==0 else None,'errno':ctypes.get_errno() if code else 0})
print(json.dumps(rows))
