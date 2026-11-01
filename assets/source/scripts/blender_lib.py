"""Помощник Blender: материалы библиотеки проекта.

Материал в Blender называется так же, как набор в assets/textures/lib (например painted_metal_004).
При экспорте .glb картинки не вшиваются (export_image_format='NONE'), а в Godot материал с этим
именем подменяется файлом из assets/materials (класс MaterialLibrary). Здесь материал нужен только
чтобы модель выглядела правильно во вьюпорте Blender. Фильтр Closest повторяет Nearest в игре.

Использование в Blender:
    exec(open("G:/Годот/endless-zavod/assets/source/scripts/blender_lib.py", encoding="utf-8").read())
    mat = ensure_material("concrete_042a")
"""
import json
import os

import bpy

PROJECT = "G:/Годот/endless-zavod"
LIB = PROJECT + "/assets/textures/lib/"
MANIFEST = PROJECT + "/assets/source/scripts/lib_manifest.json"

_items = None


def manifest() -> dict:
    global _items
    if _items is None:
        with open(MANIFEST, encoding="utf-8") as f:
            _items = {item["id"]: item for item in json.load(f)}
    return _items


def _image(path: str, color: bool) -> bpy.types.Image:
    img = bpy.data.images.load(path, check_existing=True)
    img.colorspace_settings.name = "sRGB" if color else "Non-Color"
    return img


def _tex_node(nodes, path: str, color: bool, x: float, y: float):
    node = nodes.new("ShaderNodeTexImage")
    node.image = _image(path, color)
    node.interpolation = "Closest"
    node.location = (x, y)
    return node


def ensure_material(sid: str) -> bpy.types.Material:
    """Материал библиотеки по id набора; создаётся один раз и переиспользуется."""
    existing = bpy.data.materials.get(sid)
    if existing is not None:
        return existing
    entry = manifest().get(sid)
    if entry is None:
        raise KeyError("нет набора в библиотеке: " + sid)
    base = LIB + entry["group"] + "/"
    maps = entry["maps"]

    mat = bpy.data.materials.new(sid)
    try:
        mat.use_nodes = True
    except Exception:
        pass
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")

    color = _tex_node(nodes, base + maps["c"], True, -700, 300)
    links.new(color.outputs["Color"], bsdf.inputs["Base Color"])
    if "r" in maps:
        rough = _tex_node(nodes, base + maps["r"], False, -700, 0)
        links.new(rough.outputs["Color"], bsdf.inputs["Roughness"])
    if "m" in maps:
        metal = _tex_node(nodes, base + maps["m"], False, -700, -300)
        links.new(metal.outputs["Color"], bsdf.inputs["Metallic"])
    if "n" in maps:
        normal_tex = _tex_node(nodes, base + maps["n"], False, -1000, -600)
        normal = nodes.new("ShaderNodeNormalMap")
        normal.location = (-700, -600)
        links.new(normal_tex.outputs["Color"], normal.inputs["Color"])
        links.new(normal.outputs["Normal"], bsdf.inputs["Normal"])

    avg = entry.get("avg_color", [0.5, 0.5, 0.5])
    mat.diffuse_color = (*avg, 1.0)
    return mat


def assign(obj: bpy.types.Object, sid: str) -> None:
    """Единственный материал на объект (заменяет прежние)."""
    obj.data.materials.clear()
    obj.data.materials.append(ensure_material(sid))
