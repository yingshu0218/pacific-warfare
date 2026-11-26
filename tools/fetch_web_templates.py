"""Fetch only web template ZIP members from the official same-version TPZ."""
import io, struct, urllib.request, zipfile, zlib
from pathlib import Path
URL = 'https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'

def fetch(start, end):
    req = urllib.request.Request(URL, headers={'Range': f'bytes={start}-{end}'})
    with urllib.request.urlopen(req, timeout=60) as response:
        if response.status != 206:
            raise RuntimeError('Server did not honor byte range')
        return response.read()

size = 1281349702
tail = fetch(size-65536, size-1)
pos = tail.rfind(b'PK\x05\x06')
fields = struct.unpack_from('<4s4H2IH', tail, pos)
central_size, central_offset = fields[5:7]
central = fetch(central_offset, central_offset+central_size-1)
# Build a small synthetic archive containing the central directory only.
eocd = bytearray(tail[pos:])
struct.pack_into('<I', eocd, 16, 0)
archive = zipfile.ZipFile(io.BytesIO(central+eocd))
out = Path.home()/'Library/Application Support/Godot/export_templates/4.7.2.stable'
out.mkdir(parents=True, exist_ok=True)
for member in archive.infolist():
    name = Path(member.filename).name
    if name not in ('web_nothreads_release.zip','web_nothreads_debug.zip','version.txt'):
        continue
    print('Fetching', name, member.compress_size, flush=True)
    header = fetch(member.header_offset, member.header_offset+29)
    name_len, extra_len = struct.unpack_from('<HH',header,26)
    start = member.header_offset+30+name_len+extra_len
    compressed = fetch(start,start+member.compress_size-1)
    data = zlib.decompress(compressed,-15) if member.compress_type == 8 else compressed
    assert len(data) == member.file_size
    assert zlib.crc32(data) == member.CRC
    (out/name).write_bytes(data)
    print('Installed', out/name, flush=True)
