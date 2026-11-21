"""Turns a dense, static chibi sculpt into a rigged hero body that plays every
chibi clip.  See tools/import_chibi.md for the whole pipeline.

Stage 1 (needs Blender as a Python module):
  python -m venv /opt/bpy5 && /opt/bpy5/bin/pip install bpy==5.3.0 numpy
  /opt/bpy5/bin/python tools/import_chibi.py decimate SRC.glb CACHE.npz 16000

  Welds the scan's UV-seam vertices, decimates to the triangle budget, keeps the
  base colour map only (1024 px JPEG) and stores mesh + texture in CACHE.npz.

Stage 2 (numpy + Blender's BVH tree for the nearest-surface queries):
  /opt/bpy5/bin/python tools/import_chibi.py rig CACHE.npz tools/chibi_models.json NAME OUT.glb

  Puts the mesh in the chibi's space (+Z front, feet on y=0), fits the chibi
  skeleton (chibi_boy or chibi_girl, by the spec's base) to the spec's landmarks,
  poses the base chibi's own skinned body into that fit, copies the skin weights
  from its nearest surface and writes a glb with the skeleton and the skinned
  mesh only.  The game borrows the base chibi's clips at run time
  (HeroVisual._chibi_clips), so each body is ~1 MB instead of ~7.
"""
import sys, json, math, struct, time
import numpy as np


def stage_decimate(src, out, tris):
    import bpy
    t = time.time()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    ob = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]
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
    me = ob.data
    me.calc_loop_triangles()
    print('decimated to', len(me.loop_triangles), 'tris in %.0fs' % (time.time() - t))
    nv = len(me.vertices)
    co = np.empty(nv * 3, np.float32); me.vertices.foreach_get('co', co); co = co.reshape(-1, 3)
    nloops = len(me.loops)
    lv = np.empty(nloops, np.int32); me.loops.foreach_get('vertex_index', lv)
    uv = np.empty(nloops * 2, np.float32); me.uv_layers.active.data.foreach_get('uv', uv); uv = uv.reshape(-1, 2)
    nt = len(me.loop_triangles)
    tl = np.empty(nt * 3, np.int32); me.loop_triangles.foreach_get('loops', tl); tl = tl.reshape(-1, 3)
    # One output vertex per (mesh vertex, uv) pair.
    key = np.column_stack([lv.astype(np.float64), np.round(uv[:, 0] * 8192), np.round(uv[:, 1] * 8192)])
    uniq, first, inv = np.unique(key, axis=0, return_index=True, return_inverse=True)
    inv = inv.reshape(-1)
    # Blender is Z-up: back to glTF's Y-up.
    pos = co[lv[first]][:, [0, 2, 1]] * np.array([1.0, 1.0, -1.0], np.float32)
    tex = uv[first] * np.array([1.0, -1.0], np.float32) + np.array([0.0, 1.0], np.float32)  # glTF v runs down
    faces = inv[tl]
    # Base colour map, 1024 px JPEG.
    mat = me.materials[0]
    img = None
    bsdf = [n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'][0]
    for link in mat.node_tree.links:
        if link.to_node == bsdf and link.to_socket.name == 'Base Color':
            img = link.from_node.image
    img.scale(1024, 1024)
    scene = bpy.context.scene
    scene.render.image_settings.file_format = 'JPEG'
    scene.render.image_settings.quality = 88
    jpg = out + '.jpg'
    img.save_render(jpg, scene=scene)
    np.savez_compressed(out, yup=1, pos=pos, uv=tex, faces=faces.astype(np.int32), jpg=np.frombuffer(open(jpg, 'rb').read(), np.uint8))
    print('wrote', out, len(pos), 'verts', len(faces), 'tris')


if __name__ == '__main__':
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    if argv[0] == 'decimate':
        stage_decimate(argv[1], argv[2], int(argv[3]))
    elif argv[0] == 'rig':
        import chibi_rig  # noqa: placed next to this file
        chibi_rig.main(argv[1:])
