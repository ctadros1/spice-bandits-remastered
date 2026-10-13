#!/usr/bin/env python3
"""Read-only trace extraction with PC-relative literal/pointer annotations."""
import argparse
import hashlib
import json
import re
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("terms", nargs="+")
    args = parser.parse_args()
    binary = (ROOT / "original/game-files/ipa-1.14/Payload/Tower.app/Tower").read_bytes()
    sections = json.loads((ROOT / "original/analysis/sections.json").read_text())
    functions = json.loads((ROOT / "original/analysis/functions.json").read_text())
    named = {f["address"]: f["demangled"] for f in json.loads((ROOT / "original/analysis/game-functions.json").read_text())}
    lines = (ROOT / "original/source-code/recovered/Tower-full-disassembly.armv7.txt").read_text().splitlines()
    instructions = {}
    for line in lines:
        match = re.match(r"\s*([0-9a-f]+):", line)
        if match:
            instructions[int(match[1], 16)] = line

    def offset(address):
        for section in sections:
            if section["offset"] and section["addr"] <= address < section["addr"]+section["size"]:
                return address-section["addr"]+section["offset"]
        return None

    def word(address):
        i = offset(address)
        return struct.unpack_from("<I", binary, i)[0] if i is not None else None

    def description(address):
        i = offset(address)
        if i is None:
            return ""
        s = next((s for s in sections if s["addr"] <= address < s["addr"]+s["size"]), {})
        if s.get("section") in ("__cstring", "__objc_methname", "__objc_classname"):
            return repr(binary[i:i+500].split(b"\0")[0].decode("utf-8", "replace"))
        pointer = word(address)
        if s.get("section") in ("__objc_selrefs", "__nl_symbol_ptr", "__la_symbol_ptr"):
            return "pointer " + hex(pointer) + " " + description(pointer)
        if s.get("section") == "__cfstring":
            return "CFString " + description(word(address+8))
        return s.get("section", "") + " " + hex(address)

    output = ROOT / "docs/mechanics/traces"
    output.mkdir(parents=True, exist_ok=True)
    for f in functions:
        name = named.get(f["address"], f["name"])
        if not any(term in name for term in args.terms):
            continue
        registers = {}
        result = [name, hex(f["address"]), "Executable SHA256 " + hashlib.sha256(binary).hexdigest()]
        for address in sorted(instructions):
            if not f["address"] <= address < f["address"]+f["size"]:
                continue
            line = instructions[address]
            match = re.search(r"\bmov([wt])\s+(r\d+), #(0x[0-9a-f]+)", line)
            if match:
                kind, reg, value = match.groups()
                value = int(value, 16)
                registers[reg] = value if kind == "w" else (registers.get(reg, 0) & 65535) | (value << 16)
            match = re.search(r"\badd\s+(r\d+), pc", line)
            if match and match[1] in registers:
                registers[match[1]] += address+4
                line += " ; " + description(registers[match[1]])
            match = re.search(r"\bvldr\s+(s\d+|d\d+), \[pc, #(0x[0-9a-f]+|\d+)\]", line)
            if match:
                reg, delta = match.groups()
                i = offset(((address+4) & ~3)+int(delta, 0))
                if i is not None:
                    value = struct.unpack_from("<f" if reg.startswith("s") else "<d", binary, i)[0]
                    line += " ; literal " + repr(value)
            result.append(line)
        file = output / (re.sub(r"[^A-Za-z0-9_-]", "_", name)[:170] + ".txt")
        file.write_text("\n".join(result)+"\n")
        print(name, "->", file.relative_to(ROOT))


if __name__ == "__main__":
    main()
