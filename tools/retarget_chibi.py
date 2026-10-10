"""Builds assets/models/heroes/chibi_*.glb from a Tripo export.

  python tools/fix_tripo_glb.py chibi_boy_rigged_full.glb boy_src.glb
  pip install bpy==4.2.0  (Blender as a Python module, Python 3.11)
  python tools/retarget_chibi.py -- boy_src.glb assets/models/characters/Knight.glb chibi_boy.glb 16000 "$(cat tools/chibi_clips.txt)"

Welds and decimates the mesh, keeps one 1024 colour texture, retargets the
KayKit clips onto the chibi rig (world-space, arm chain lowered a little),
adds handslot.l/.r bones like KayKit and exports a GLB.
"""
import bpy, sys, time, math
from mathutils import Matrix, Vector, Quaternion
argv = sys.argv[sys.argv.index('--') + 1:]
SRC, KAY, DST, TRIS = argv[0], argv[1], argv[2], int(argv[3])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 24
bpy.ops.import_scene.gltf(filepath=SRC)
chibi = [o for o in bpy.context.scene.objects if o.type == 'ARMATURE'][0]
body = max([o for o in bpy.context.scene.objects if o.type == 'MESH'], key=lambda o: len(o.data.polygons))
for o in list(bpy.context.scene.objects):
    if o not in (chibi, body):
        bpy.data.objects.remove(o, do_unlink=True)
own_actions = list(bpy.data.actions)

# --- lighter mesh -------------------------------------------------------
bpy.context.view_layer.objects.active = body
# Tripo splits vertices along UV seams: weld them so decimation leaves no cracks.
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.remove_doubles(threshold=0.0002)
bpy.ops.object.mode_set(mode='OBJECT')
print('welded verts', len(body.data.vertices))
dec = body.modifiers.new('dec', 'DECIMATE')
dec.ratio = TRIS / len(body.data.polygons)
while body.modifiers.find('dec') > 0:
    bpy.ops.object.modifier_move_up(modifier='dec')
bpy.ops.object.modifier_apply(modifier='dec')
print('tris', len(body.data.polygons))

# Vertex colour R = how much of the vertex may be recoloured as outfit: head,
# hair, face and hands stay 0 (the shader also leaves skin-coloured texels alone).
KEEP_SKIN = ('Head', 'Neck', 'Jaw', 'LeftHand', 'RightHand')
KEEP_PREFIX = ('Hair', 'Eye', 'Brow', 'Mouth', 'LeftThumb', 'LeftIndex', 'LeftMiddle', 'LeftRing', 'LeftLittle',
    'RightThumb', 'RightIndex', 'RightMiddle', 'RightRing', 'RightLittle')
names = {g.index: g.name for g in body.vertex_groups}
attr = body.data.color_attributes.new('Col', 'FLOAT_COLOR', 'POINT')
for v in body.data.vertices:
    keep = sum(g.weight for g in v.groups if names[g.group] in KEEP_SKIN or names[g.group].startswith(KEEP_PREFIX))
    total = sum(g.weight for g in v.groups) or 1.0
    r = max(0.0, min(1.0, 1.0 - keep / total))
    attr.data[v.index].color = (r, r, r, 1.0)
body.data.color_attributes.active_color = attr

# --- one 1024 colour texture, no normal / metal-rough maps ---------------
mat = body.data.materials[0]
nt = mat.node_tree
bsdf = [n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'][0]
base_img = None
for link in list(nt.links):
    if link.to_node == bsdf and link.to_socket.name == 'Base Color':
        base_img = link.from_node.image
for name in ('Normal', 'Metallic', 'Roughness'):
    for link in list(bsdf.inputs[name].links):
        nt.links.remove(link)
mat.use_backface_culling = False
bsdf.inputs['Metallic'].default_value = 0.0
bsdf.inputs['Roughness'].default_value = 0.85
for n in list(nt.nodes):
    if n.type == 'TEX_IMAGE' and n.image != base_img:
        nt.nodes.remove(n)
    elif n.type in ('NORMAL_MAP', 'SEPARATE_COLOR', 'SEPRGB'):
        nt.nodes.remove(n)
base_img.scale(1024, 1024)

# --- KayKit rig with all clips ------------------------------------------
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=KAY)
kay = [o for o in bpy.data.objects if o not in before and o.type == 'ARMATURE'][0]
for o in list(bpy.data.objects):
    if o not in before and o != kay:
        bpy.data.objects.remove(o, do_unlink=True)
kay_actions = [a for a in bpy.data.actions if a not in own_actions]

kb = kay.data.bones
cb = chibi.data.bones
PAIRS = []  # (kay bone, chibi bone, kay dir end, chibi dir end)
for side, S in (('l', 'Left'), ('r', 'Right')):
    PAIRS += [
        ('upperarm.' + side, S + 'UpperArm', 'lowerarm.' + side, S + 'LowerArm'),
        ('lowerarm.' + side, S + 'LowerArm', 'hand.' + side, S + 'Hand'),
        ('hand.' + side, S + 'Hand', 'TAIL', S + 'Middle1'),
        ('upperleg.' + side, S + 'UpperLeg', 'lowerleg.' + side, S + 'LowerLeg'),
        ('lowerleg.' + side, S + 'LowerLeg', 'foot.' + side, S + 'Foot'),
        ('foot.' + side, S + 'Foot', 'toes.' + side, S + 'Toes'),
        ('toes.' + side, S + 'Toes', 'TAIL', 'TAIL'),
    ]
PAIRS = [('hips', 'Hips', 'spine', 'Spine'), ('spine', 'Spine', 'chest', 'Chest'),
         ('chest', 'Chest', 'head', 'Neck'), ('head', 'Head', 'UP', 'UP')] + PAIRS

def rest_dir(bones, name, end):
    b = bones[name]
    if end == 'UP':
        return Vector((0, 0, 1))
    if end == 'TAIL':
        return (b.tail_local - b.head_local).normalized()
    return (bones[end].head_local - b.head_local).normalized()

ARM_DROP = 18.0
MAPPED = {}
for k, c, ke, ce in PAIRS:
    if k not in kb or c not in cb:
        print('skip', k, c)
        continue
    dk, dc = rest_dir(kb, k, ke), rest_dir(cb, c, ce)
    # KayKit's T-pose arms are horizontal; the chibi's short arms look stiff that
    # high, so its whole arm chain hangs ARM_DROP degrees lower in every pose.
    if 'arm.' in k or k.startswith('hand.'):
        drop = math.radians(ARM_DROP) * (1.0 if k.endswith('.l') else -1.0)
        dk = Matrix.Rotation(drop, 3, 'Y') @ dk
    swing = dc.rotation_difference(dk).to_matrix()
    Rc = cb[c].matrix_local.to_3x3()
    Rk = kb[k].matrix_local.to_3x3()
    MAPPED[c] = (k, Rk.inverted(), swing @ Rc)

hip_scale = cb['Hips'].head_local.z / kb['hips'].head_local.z
arm_scale = (cb['LeftHand'].head_local - cb['LeftLowerArm'].head_local).length / \
    (kb['hand.l'].head_local - kb['lowerarm.l'].head_local).length
print('hip scale %.3f arm scale %.3f' % (hip_scale, arm_scale))

# --- weapon slots: same grip as the KayKit hands ---------------------------
bpy.context.view_layer.objects.active = chibi
bpy.ops.object.mode_set(mode='EDIT')
eb = chibi.data.edit_bones
for side, S in (('r', 'Right'), ('l', 'Left')):
    hand_c = cb[S + 'Hand']
    k_hand, k_slot = kb['hand.' + side], kb['handslot.' + side]
    Mc = MAPPED[S + 'Hand'][2]
    Rc = hand_c.matrix_local.to_3x3()
    rot = Rc @ Mc.inverted() @ k_slot.matrix_local.to_3x3()
    pos = hand_c.head_local + Rc @ Mc.inverted() @ ((k_slot.head_local - k_hand.head_local) * arm_scale)
    nb = eb.new('handslot.' + side)
    nb.length = 0.03
    nb.matrix = Matrix.Translation(pos) @ rot.to_4x4()
    nb.parent = eb[S + 'Hand']
bpy.ops.object.mode_set(mode='OBJECT')
cb = chibi.data.bones

order = []
def walk(b):
    order.append(b)
    for ch in b.children:
        walk(ch)
for b in cb:
    if b.parent is None:
        walk(b)
REL = {b.name: (b.parent.matrix_local.inverted() @ b.matrix_local) if b.parent else b.matrix_local.copy() for b in order}

def bake(act, name):
    kay.animation_data_create()
    kay.animation_data.action = act
    f0, f1 = int(math.floor(act.frame_range[0])), int(math.ceil(act.frame_range[1]))
    frames = list(range(f0, f1 + 1))
    rots = {b.name: [] for b in order if b.name in MAPPED}
    hips_loc = []
    k_hips_rest = kb['hips'].head_local
    for f in frames:
        bpy.context.scene.frame_set(f)
        kp = kay.pose.bones
        world = {}
        for b in order:
            parent_w = world[b.parent.name] if b.parent else Matrix.Identity(4)
            rest_w = parent_w @ REL[b.name]
            if b.name in MAPPED:
                k, Rk_inv, Mc = MAPPED[b.name]
                rot = kp[k].matrix.to_3x3() @ Rk_inv @ Mc
                if b.parent is None:
                    pos = b.head_local + (kp[k].matrix.translation - k_hips_rest) * hip_scale
                else:
                    pos = rest_w.translation
                w = Matrix.Translation(pos) @ rot.to_4x4()
                basis = REL[b.name].inverted() @ parent_w.inverted() @ w
                q = basis.to_quaternion()
                prev = rots[b.name][-1] if rots[b.name] else None
                if prev is not None and prev.dot(q) < 0:
                    q.negate()
                rots[b.name].append(q)
                if b.parent is None:
                    hips_loc.append(basis.translation.copy())
                world[b.name] = w
            else:
                world[b.name] = rest_w
    new = bpy.data.actions.new(name)
    for bone, qs in rots.items():
        for i in range(4):
            fc = new.fcurves.new('pose.bones["%s"].rotation_quaternion' % bone, index=i, action_group=bone)
            fc.keyframe_points.add(len(frames))
            co = []
            for f, q in zip(frames, qs):
                co += [f - f0, q[i]]
            fc.keyframe_points.foreach_set('co', co)
            fc.update()
    for i in range(3):
        fc = new.fcurves.new('pose.bones["Hips"].location', index=i, action_group='Hips')
        fc.keyframe_points.add(len(frames))
        co = []
        for f, l in zip(frames, hips_loc):
            co += [f - f0, l[i]]
        fc.keyframe_points.foreach_set('co', co)
        fc.update()
    new.use_fake_user = True
    return new

t = time.time()
made = []
KEEP = set(argv[4].split(',')) if len(argv) > 4 else None
for act in kay_actions:
    name = act.name[:-4] if act.name.endswith('_Rig') else act.name
    if KEEP is None or name in KEEP:
        made.append(bake(act, name))
print('baked', len(made), 'clips in %.1fs' % (time.time() - t))
for a in own_actions:
    a.name = 'Chibi_' + a.name.split('_')[0]
for a in kay_actions:
    bpy.data.actions.remove(a)
bpy.data.objects.remove(kay, do_unlink=True)

# Every clip becomes its own NLA track so the exporter writes them all.
chibi.animation_data_create()
chibi.animation_data.action = None
# The importer left one NLA track per original clip ("Idle", "Walk"...): drop them.
for tr in list(chibi.animation_data.nla_tracks):
    chibi.animation_data.nla_tracks.remove(tr)
for a in made + own_actions:
    tr = chibi.animation_data.nla_tracks.new()
    tr.name = a.name
    tr.strips.new(a.name, 0, a)
    tr.mute = True

for o in bpy.context.scene.objects:
    o.select_set(o in (chibi, body))
bpy.ops.export_scene.gltf(filepath=DST, export_format='GLB', use_selection=True,
    export_animations=True, export_animation_mode='NLA_TRACKS', export_force_sampling=True,
    export_optimize_animation_size=False, export_image_format='JPEG', export_jpeg_quality=82,
    export_morph=False, export_vertex_color='ACTIVE', export_skins=True, export_all_influences=False, export_def_bones=False)
print('exported', DST)
