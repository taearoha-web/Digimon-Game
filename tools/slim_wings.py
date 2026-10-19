#!/usr/bin/env python3
"""Slim the wing models (assets/models/wings and star_wings) in place.

The Blender-exported wings ship every triangle with its own three vertices
(76,826 vertices for 26,806 triangles on the warrior's star wings) and up to
27k triangles a pair; in a guild war every fighter wears a pair, so the wings
alone held ~22 MB of GPU vertex buffers on a phone. This reuses the Defender
import pipeline (tools/defender_import.py: merge by material, weld, simplify
with meshoptimizer, crease-angle normals, keep the skin and the clips) with a
triangle budget per pair.

usage: python3 tools/slim_wings.py [--budget-star 6500] [--budget-lv100 4000] [--dry-run]
"""
import os, sys, json, struct, tempfile, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
# defender_import.py runs its import job at module level; load only its definitions.
source = open(os.path.join(HERE, "defender_import.py"), encoding="utf-8").read()
defs = source[:source.index("\nSRC = sys.argv[1]")]
pipeline = {"__name__": "defender_pipeline", "__file__": os.path.join(HERE, "defender_import.py")}
exec(compile(defs, "defender_import.py", "exec"), pipeline)
pipeline["SRC"] = ROOT
pipeline["OUT"] = ROOT


def stats(path):
    raw = open(path, "rb").read()
    jl = struct.unpack_from("<I", raw, 12)[0]
    g = json.loads(raw[20:20 + jl])
    tris = verts = 0
    for m in g["meshes"]:
        for p in m["primitives"]:
            verts += g["accessors"][p["attributes"]["POSITION"]]["count"]
            if "indices" in p:
                tris += g["accessors"][p["indices"]]["count"] // 3
    return verts, tris, len(raw), [a.get("name") for a in g.get("animations", [])]


def main():
    args = sys.argv[1:]
    budget_star = int(args[args.index("--budget-star") + 1]) if "--budget-star" in args else 6500
    budget_lv100 = int(args[args.index("--budget-lv100") + 1]) if "--budget-lv100" in args else 4000
    dry = "--dry-run" in args
    jobs = []
    for folder, budget in (("star_wings", budget_star), ("wings", budget_lv100)):
        d = os.path.join(ROOT, "assets", "models", folder)
        for name in sorted(os.listdir(d)):
            if name.endswith(".glb"):
                jobs.append((os.path.join(d, name), budget))
    print("%-38s %8s %8s %7s -> %8s %8s %7s" % ("file", "verts", "tris", "KB", "verts", "tris", "KB"))
    for path, budget in jobs:
        v0, t0, b0, anims0 = stats(path)
        tmp = tempfile.mkdtemp()
        out = os.path.join(tmp, os.path.basename(path))
        pipeline["build"]([path], out, budget, keep_anims=True)
        v1, t1, b1, anims1 = stats(out)
        assert sorted(a for a in anims1 if a) == sorted(a for a in anims0 if a), "clips lost in " + path
        print("%-38s %8d %8d %7d -> %8d %8d %7d" % (os.path.relpath(path, ROOT), v0, t0, b0 // 1024, v1, t1, b1 // 1024))
        if not dry and (v1 < v0 or t1 < t0):
            shutil.copyfile(out, path)
        shutil.rmtree(tmp)


if __name__ == "__main__":
    main()
