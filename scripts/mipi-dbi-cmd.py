#!/usr/bin/env python3
"""Compile a panel-mipi-dbi command text file into the firmware binary format
expected by drivers/gpu/drm/tiny/panel-mipi-dbi.c (file format version 1).

usage: mipi-dbi-cmd.py <input.txt> <output.bin>
"""
import sys

MAGIC = b"MIPI DBI" + bytes(7)
VERSION = 1


def compile_cmds(text: str) -> bytes:
    out = bytearray(MAGIC + bytes([VERSION]))
    for lineno, raw in enumerate(text.splitlines(), 1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        tok = line.split()
        if tok[0] == "delay":
            ms = int(tok[1], 0)
            if not 0 <= ms <= 255:
                sys.exit(f"line {lineno}: delay must be 0..255 ms")
            out += bytes([0x00, 0x01, ms])
            continue
        vals = [int(t, 0) for t in tok]
        if any(v < 0 or v > 0xFF for v in vals):
            sys.exit(f"line {lineno}: values must be bytes")
        cmd, params = vals[0], vals[1:]
        out += bytes([cmd, len(params), *params])
    return bytes(out)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    with open(sys.argv[1]) as f:
        data = compile_cmds(f.read())
    with open(sys.argv[2], "wb") as f:
        f.write(data)
