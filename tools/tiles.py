#!/usr/bin/env python3
"""Read and patch TileMapLayer cells inside a .tscn without the editor.

    from tools.tiles import Scene
    sc = Scene("world/game_level_2.tscn")
    sc.get("Cliffs", 76, 5)            -> (source, ax, ay) or None
    sc.set("Cliffs", 76, 5, 0, 12, 0)  # source 0, atlas (12,0)
    sc.clear("Scatter", 73, 1)
    sc.save()

Godot's tile_map_data is base64 of: uint16 format, then 12 bytes per cell —
int16 x, y, source_id, atlas_x, atlas_y, alternative — little-endian.
The Godot editor must not have the scene open while this writes it.
"""
import base64, re, struct, sys


class Scene:
    def __init__(self, path):
        self.path = path
        self.text = open(path).read()
        self.layers = {}
        for m in re.finditer(r'\[node name="([^"]+)" type="TileMapLayer"[^\]]*\]\n(.*?)(?=\n\[node |\Z)', self.text, re.S):
            name, body = m.group(1), m.group(2)
            d = re.search(r'tile_map_data = PackedByteArray\("([^"]*)"\)', body)
            if not d:
                continue
            raw = base64.b64decode(d.group(1))
            fmt, = struct.unpack_from("<H", raw, 0)
            cells = {}
            for off in range(2, len(raw), 12):
                x, y, src, ax, ay, alt = struct.unpack_from("<hhhhhh", raw, off)
                cells[(x, y)] = (src, ax, ay, alt)
            self.layers[name] = {"fmt": fmt, "cells": cells, "b64": d.group(1)}

    def get(self, layer, x, y):
        c = self.layers[layer]["cells"].get((x, y))
        return c[:3] if c else None

    def set(self, layer, x, y, src, ax, ay, alt=0):
        self.layers[layer]["cells"][(x, y)] = (src, ax, ay, alt)

    def clear(self, layer, x, y):
        self.layers[layer]["cells"].pop((x, y), None)

    def encode(self, layer):
        L = self.layers[layer]
        out = bytearray(struct.pack("<H", L["fmt"]))
        for (x, y), (src, ax, ay, alt) in sorted(L["cells"].items(), key=lambda kv: (kv[0][1], kv[0][0])):
            out += struct.pack("<hhhhhh", x, y, src, ax, ay, alt)
        return base64.b64encode(bytes(out)).decode()

    def save(self):
        for name, L in self.layers.items():
            new = self.encode(name)
            if new != L["b64"]:
                self.text = self.text.replace(L["b64"], new, 1)
                L["b64"] = new
        open(self.path, "w").write(self.text)


if __name__ == "__main__":
    sc = Scene(sys.argv[1])
    for n, L in sc.layers.items():
        print(n, len(L["cells"]), "cells")
