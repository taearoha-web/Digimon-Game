"""Turns a dense, static chibi sculpt into a rigged hero body that plays every
chibi clip (characters/chibi_bodies.gd). Everything at once:

  /opt/bpy5/bin/python tools/import_chibi.py all SRC_DIR CACHE_DIR

  reads SRC_DIR/<src>_d.glb for every model in tools/chibi_models.json (the owner's
  sculpts, meshopt-decoded), keeps the decimated CACHE_DIR/<src>.npz and writes
  assets/models/heroes/<name>.glb.  Then import twice in Godot.

Stage 1 (needs Blender as a Python module):
  python -m venv /opt/bpy5 && /opt/bpy5/bin/pip install bpy==5.3.0 numpy
  /opt/bpy5/bin/python tools/import_chibi.py decimate SRC.glb CACHE.npz 16000

  Welds the scan's UV-seam vertices, decimates to the triangle budget, bakes the
  base colour onto the decimated uvs again (1024 px JPEG) from the nearest
  point of the dense surface, then stores mesh + texture in CACHE.npz.

Stage 2 (numpy + Blender's BVH tree for the nearest-surface queries):
  /opt/bpy5/bin/python tools/import_chibi.py rig CACHE.npz tools/chibi_models.json NAME OUT.glb

  Puts the mesh in the chibi's space (+Z front, feet on y=0), fits the chibi
  skeleton (chibi_boy or chibi_girl, by the spec's base) to the spec's landmarks,
  poses the base chibi's own skinned body into that fit, copies the skin weights
  from its nearest surface and writes a glb with the skeleton and the skinned
  mesh only.  The game borrows the base chibi's clips at run time
  (ChibiBodies.clips), so each body is ~1 MB instead of ~7.
"""
import sys, os, json, math, struct, time
import numpy as np


def _mesh_arrays(me):
    me.calc_loop_triangles()
    co = np.empty(len(me.vertices) * 3, np.float32); me.vertices.foreach_get('co', co)
    lv = np.empty(len(me.loops), np.int32); me.loops.foreach_get('vertex_index', lv)
    uv = np.empty(len(me.loops) * 2, np.float32); me.uv_layers.active.data.foreach_get('uv', uv)
    tl = np.empty(len(me.loop_triangles) * 3, np.int32); me.loop_triangles.foreach_get('loops', tl)
    tp = np.empty(len(me.loop_triangles), np.int32); me.loop_triangles.foreach_get('polygon_index', tp)
    return co.reshape(-1, 3), lv, uv.reshape(-1, 2), tl.reshape(-1, 3), tp


def stage_decimate(src, out, tris, size=1024):
    import bpy
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    t = time.time()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    ob = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]
    # The dense source stays for the colour re-bake: its triangles, uvs and texture.
    me0 = ob.data.copy()
    co0, lv0, uv0, tl0, _ = _mesh_arrays(me0)
    mat = me0.materials[0]
    bsdf = [n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'][0]
    img = None
    for link in mat.node_tree.links:
        if link.to_node == bsdf and link.to_socket.name == 'Base Color':
            img = link.from_node.image
    tw, th = img.size
    px = np.empty(tw * th * 4, np.float32); img.pixels.foreach_get(px)
    tex0 = px.reshape(th, tw, 4)[:, :, :3]  # row 0 = v 0 (Blender's pixel order)
    tree = BVHTree.FromPolygons([tuple(c) for c in co0], [tuple(lv0[l]) for l in tl0], all_triangles=True)
    print('source', len(tl0), 'tris, texture', tw, 'x', th, 'in %.0fs' % (time.time() - t))
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    # The scans split every vertex on a UV seam: weld so decimation leaves no cracks.
    bpy.ops.mesh.remove_doubles(threshold=0.0002)
    bpy.ops.object.mode_set(mode='OBJECT')
    dec = ob.modifiers.new('dec', 'DECIMATE')
    dec.ratio = tris / len(ob.data.polygons)
    bpy.ops.object.modifier_apply(modifier='dec')
    # Decimation drags the old uvs across their islands (white cracks on the seams):
    # the colour is baked again onto the decimated uvs, every texel from the nearest
    # point of the dense surface, so a triangle that now spans an island gap is filled.
    me = ob.data
    co, lv, uv, tl, _ = _mesh_arrays(me)
    print('decimated to', len(tl), 'tris in %.0fs' % (time.time() - t))
    out_px = np.zeros((size, size, 3), np.float32)
    filled = np.zeros((size, size), bool)
    U = uv * size - 0.5
    P = co[lv]
    for f in tl:
        a, b, c = U[f]
        x0, x1 = int(max(min(a[0], b[0], c[0]) - 1, 0)), int(min(max(a[0], b[0], c[0]) + 2, size))
        y0, y1 = int(max(min(a[1], b[1], c[1]) - 1, 0)), int(min(max(a[1], b[1], c[1]) + 2, size))
        if x0 >= x1 or y0 >= y1:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1, dtype=np.float64), np.arange(y0, y1, dtype=np.float64))
        d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(d) < 1e-12:
            continue
        l0 = ((b[1] - c[1]) * (gx - c[0]) + (c[0] - b[0]) * (gy - c[1])) / d
        l1 = ((c[1] - a[1]) * (gx - c[0]) + (a[0] - c[0]) * (gy - c[1])) / d
        l2 = 1 - l0 - l1
        m = (l0 >= -0.02) & (l1 >= -0.02) & (l2 >= -0.02) & ~filled[y0:y1, x0:x1]
        if not m.any():
            continue
        L = np.clip(np.stack([l0[m], l1[m], l2[m]], 1), 0, 1)
        L /= L.sum(1, keepdims=True)
        pts = L @ P[f]
        ys, xs = np.nonzero(m)
        for k in range(len(pts)):
            loc, _n, fi, _d = tree.find_nearest(Vector(pts[k]))
            tri = tl0[fi]
            pa, pb, pc = co0[lv0[tri]]
            v0, v1, v2 = pb - pa, pc - pa, np.array(loc) - pa
            d00, d01, d11, d20, d21 = v0 @ v0, v0 @ v1, v1 @ v1, v2 @ v0, v2 @ v1
            den = d00 * d11 - d01 * d01
            w1 = (d11 * d20 - d01 * d21) / den if den > 1e-18 else 0.0
            w2 = (d00 * d21 - d01 * d20) / den if den > 1e-18 else 0.0
            suv = (1 - w1 - w2) * uv0[tri[0]] + w1 * uv0[tri[1]] + w2 * uv0[tri[2]]
            sx, sy = suv[0] % 1.0 * tw - 0.5, suv[1] % 1.0 * th - 0.5
            ix, iy = int(np.floor(sx)), int(np.floor(sy))
            fx, fy = sx - ix, sy - iy
            ix0, iy0 = ix % tw, iy % th
            ix1, iy1 = (ix + 1) % tw, (iy + 1) % th
            col = (tex0[iy0, ix0] * (1 - fx) * (1 - fy) + tex0[iy0, ix1] * fx * (1 - fy)
                   + tex0[iy1, ix0] * (1 - fx) * fy + tex0[iy1, ix1] * fx * fy)
            out_px[y0 + ys[k], x0 + xs[k]] = col
        filled[y0:y1, x0:x1] |= m
    # Pad the islands so mipmaps never reach the empty texels.
    for _ in range(12):
        acc = np.zeros_like(out_px); cnt = np.zeros((size, size))
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            acc += np.roll(np.roll(out_px * filled[:, :, None], dy, 0), dx, 1)
            cnt += np.roll(np.roll(filled, dy, 0), dx, 1)
        grow = ~filled & (cnt > 0)
        out_px[grow] = acc[grow] / cnt[grow][:, None]
        filled |= grow
    print('baked in %.0fs' % (time.time() - t))
    bimg = bpy.data.images.new('bake', size, size, alpha=False)
    rgba = np.concatenate([out_px, np.ones((size, size, 1), np.float32)], 2)
    bimg.pixels.foreach_set(rgba.reshape(-1))
    scene = bpy.context.scene
    scene.render.image_settings.file_format = 'JPEG'
    scene.render.image_settings.quality = 88
    jpg = out + '.jpg'
    bimg.save_render(jpg, scene=scene)
    # One output vertex per (mesh vertex, uv) pair.
    key = np.column_stack([lv.astype(np.float64), np.round(uv[:, 0] * 8192), np.round(uv[:, 1] * 8192)])
    _u, first, inv = np.unique(key, axis=0, return_index=True, return_inverse=True)
    inv = inv.reshape(-1)
    # Blender is Z-up: back to glTF's Y-up; glTF's v runs down.
    pos = co[lv[first]][:, [0, 2, 1]] * np.array([1.0, 1.0, -1.0], np.float32)
    texc = uv[first] * np.array([1.0, -1.0], np.float32) + np.array([0.0, 1.0], np.float32)
    faces = inv[tl]
    np.savez_compressed(out, yup=1, pos=pos, uv=texc, faces=faces.astype(np.int32), jpg=np.frombuffer(open(jpg, 'rb').read(), np.uint8))
    print('wrote', out, len(pos), 'verts', len(faces), 'tris')


if __name__ == '__main__':
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    if argv[0] == 'decimate':
        stage_decimate(argv[1], argv[2], int(argv[3]))
    elif argv[0] == 'rig':
        import chibi_rig  # noqa: placed next to this file
        chibi_rig.main(argv[1:])
    elif argv[0] == 'all':
        # all SRC_DIR CACHE_DIR: every model of tools/chibi_models.json, SRC_DIR/<src>_d.glb
        # -> CACHE_DIR/<src>.npz (kept) -> assets/models/heroes/<name>.glb
        import os, chibi_rig
        here = os.path.dirname(os.path.abspath(__file__))
        spec = os.path.join(here, 'chibi_models.json')
        for name, m in json.load(open(spec))['models'].items():
            cache = os.path.join(argv[2], m['src'] + '.npz')
            if not os.path.exists(cache):
                stage_decimate(os.path.join(argv[1], m['src'] + '_d.glb'), cache, int(m.get('tris', 16000)))
            chibi_rig.main([cache, spec, name, os.path.join(here, '..', 'assets', 'models', 'heroes', name + '.glb')])
