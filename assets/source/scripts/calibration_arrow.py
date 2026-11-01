"""Калибровочная стрелка: проверка осей, масштаба и экспорта Blender -> Godot.

Перёд модели в проекте это -Z Godot. После экспорта glTF (+Y Up) Blender (x, y, z) становится
Godot (x, z, -y), поэтому перёд в Blender это +Y. Ожидание в Godot:
  красный нос (перёд)   -> на -Z
  зелёная метка (верх)  -> на +Y
  ширина 0.2 м по X, длина 1.2 м по Z.
Запуск в Blender: exec(open(путь).read())
"""
import bpy

PROJECT = "G:/Годот/endless-zavod"
OUT = PROJECT + "/assets/models/_calibration/calib_arrow.glb"
BLEND = PROJECT + "/assets/source/blend/calibration_arrow.blend"
PREFIX = "calib_"


def clear_old() -> None:
    for obj in [o for o in bpy.data.objects if o.name.startswith(PREFIX)]:
        bpy.data.objects.remove(obj, do_unlink=True)
    for mat in [m for m in bpy.data.materials if m.name.startswith(PREFIX)]:
        bpy.data.materials.remove(mat)


def make_material(name: str, color: tuple) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    try:
        mat.use_nodes = True
    except Exception:
        pass
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    mat.diffuse_color = (*color, 1.0)
    return mat


def finish(obj: bpy.types.Object, name: str, mat: bpy.types.Material) -> None:
    obj.name = name
    obj.data.name = name
    obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)


clear_old()
bpy.ops.object.select_all(action="DESELECT")

body_mat = make_material(PREFIX + "body", (0.55, 0.55, 0.58))
nose_mat = make_material(PREFIX + "nose_red", (0.85, 0.12, 0.1))
top_mat = make_material(PREFIX + "top_green", (0.15, 0.75, 0.2))

# Корпус: 0.2 (X) x 0.9 (Y, длина) x 0.1 (Z, высота), центр в начале координат.
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.0, 0.0))
body = bpy.context.active_object
body.scale = (0.2, 0.9, 0.1)
finish(body, PREFIX + "body", body_mat)

# Нос-конус на +Y (перёд): длина 0.3, основание 0.2 по ширине.
bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.1, radius2=0.0, depth=0.3,
                                location=(0.0, 0.6, 0.0), rotation=(-1.5707963, 0.0, 0.0))
nose = bpy.context.active_object
finish(nose, PREFIX + "nose", nose_mat)

# Метка «верх» на +Z, смещена к хвосту, чтобы не путать с носом.
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, -0.25, 0.1))
top = bpy.context.active_object
top.scale = (0.08, 0.08, 0.1)
finish(top, PREFIX + "top", top_mat)

for obj in (body, nose, top):
    obj.select_set(True)

import os
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=OUT,
    export_format="GLB",
    use_selection=True,
    export_yup=True,
    export_apply=True,
    export_image_format="NONE",
    export_materials="EXPORT",
    export_cameras=False,
    export_lights=False,
)
bpy.ops.wm.save_as_mainfile(filepath=BLEND)
tris = sum(len(o.data.polygons) for o in (body, nose, top))
print("exported", OUT, "polygons(approx)", tris)
