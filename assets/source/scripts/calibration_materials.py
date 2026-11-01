"""Калибровка материалов: три куба с материалами библиотеки -> .glb без картинок.

В Godot MaterialLibrary.apply подменяет их на assets/materials/<группа>/<имя>.tres.
Запуск в Blender: exec(open(путь, encoding="utf-8").read())
"""
import os

import bpy

exec(open("G:/Годот/endless-zavod/assets/source/scripts/blender_lib.py", encoding="utf-8").read())

OUT = PROJECT + "/assets/models/_calibration/calib_materials.glb"
BLEND = PROJECT + "/assets/source/blend/calibration_materials.blend"
PREFIX = "calibmat_"

for obj in [o for o in bpy.data.objects if o.name.startswith(PREFIX)]:
    bpy.data.objects.remove(obj, do_unlink=True)

bpy.ops.object.select_all(action="DESELECT")
made = []
for i, sid in enumerate(("concrete_042a", "painted_metal_004", "rubber_004")):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(i * 1.5, 0.0, 0.5))
    obj = bpy.context.active_object
    obj.name = PREFIX + sid
    obj.scale = (1.0, 1.0, 1.0)
    assign(obj, sid)
    obj.select_set(True)
    made.append(obj)

# Добавление примитива снимает выделение с предыдущих, а экспорт идёт только по выделенному.
for obj in made:
    obj.select_set(True)

os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=OUT, export_format="GLB", use_selection=True, export_yup=True, export_apply=True,
    export_image_format="NONE", export_materials="EXPORT", export_cameras=False, export_lights=False,
)
bpy.ops.wm.save_as_mainfile(filepath=BLEND)
print("exported", OUT, [o.name for o in made])
