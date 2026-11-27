#!/usr/bin/env python3
"""Clear the RISC-V float-ABI bits in ELF64 e_flags (make objects link as soft-float).

The soft-fp TF helpers in the distro libgcc are integer-only code but were
assembled with the hard-float ABI flag, so GNU ld refuses to mix them with
soft-float objects. This rewrites only that flag.
"""
import struct
import sys

FLOAT_ABI_MASK = 0x6  # EF_RISCV_FLOAT_ABI_SOFT/DOUBLE/QUAD

def patch(path: str) -> bool:
    with open(path, "r+b") as f:
        hdr = f.read(64)
        if len(hdr) < 64 or hdr[:4] != b"\x7fELF" or hdr[4] != 2:
            return False
        flags = struct.unpack_from("<I", hdr, 48)[0]
        new = flags & ~FLOAT_ABI_MASK
        if new != flags:
            f.seek(48)
            f.write(struct.pack("<I", new))
            return True
    return False

changed = sum(1 for p in sys.argv[1:] if patch(p))
print(f"patched {changed} object(s)")
