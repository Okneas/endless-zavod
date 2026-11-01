"""Собирает рабочую библиотеку текстур для игры из оригиналов PBR 1K.

Оригиналы в assets/textures/pbr не изменяются. Результат (assets/textures/lib/<группа>/):
  <id>_c.jpg  цвет (sRGB), AO подмешан в цвет с силой AO_STRENGTH
  <id>_n.png  нормали OpenGL (Y+), после усреднения нормализованы заново
  <id>_r.jpg  roughness (данные, не цвет)
  <id>_m.jpg  metalness, только если карта не пустая
Манифест с найденными картами и статистикой: assets/source/scripts/lib_manifest.json

Запуск (Blender без окна):
  blender.exe --background --factory-startup --python build_texture_lib.py -- [--only часть_имени] [--size 512] [--force]
"""
import json
import os
import re
import sys

import bpy
import numpy as np

PROJECT = "G:/Годот/endless-zavod"
SRC = PROJECT + "/assets/textures/pbr"
DST = PROJECT + "/assets/textures/lib"
MANIFEST = PROJECT + "/assets/source/scripts/lib_manifest.json"

SIZE = 512
AO_STRENGTH = 0.6        # доля тёмных углов, запекаемая в цвет (0 = не подмешивать)
METAL_MIN = 0.05         # карта metalness с максимумом ниже этого считается пустой
JPEG_QUALITY = 92

AMBIENT = re.compile(
    r"^(?P<base>[A-Za-z]+\d+[A-Z]?)_1K-JPG_(?P<map>Color|NormalGL|Roughness|Metalness|AmbientOcclusion)\.jpg$")
POLYHAVEN = re.compile(
    r"^(?P<base>.+?)_(?P<map>diff|col_01|coll1|nor_gl|rough|metal)_1k\.(?P<ext>jpg|png|exr)$")
MAP_KIND = {
    "Color": "color", "diff": "color", "col_01": "color", "coll1": "color",
    "NormalGL": "normal", "nor_gl": "normal",
    "Roughness": "rough", "rough": "rough",
    "Metalness": "metal", "metal": "metal",
    "AmbientOcclusion": "ao",
}


def snake(base: str) -> str:
    base = re.sub(r"(?<=[a-z])(?=[A-Z])", "_", base)
    base = re.sub(r"(?<=[a-z])(?=\d)", "_", base)
    return base.lower()


def discover() -> list:
    sets = {}
    for group in sorted(os.listdir(SRC)):
        gdir = os.path.join(SRC, group)
        if not os.path.isdir(gdir):
            continue
        for fname in sorted(os.listdir(gdir)):
            m = AMBIENT.match(fname)
            source = "ambientcg"
            if not m:
                m = POLYHAVEN.match(fname)
                source = "polyhaven"
            if not m:
                continue
            key = (group, m.group("base"))
            entry = sets.setdefault(key, {"group": group, "base": m.group("base"), "source": source, "files": {}})
            entry["files"][MAP_KIND[m.group("map")]] = os.path.join(gdir, fname)
    out = []
    for entry in sets.values():
        entry["id"] = snake(entry["base"]) if entry["source"] == "ambientcg" else entry["base"]
        out.append(entry)
    return out


def read_box(path: str, size: int, linear_average: bool = False, normal: bool = False) -> np.ndarray:
    """Читает картинку «как есть» (без цветовых преобразований) и усредняет до size x size.

    Усреднение в правильном пространстве: цвет в линейном, нормали как векторы, данные как есть."""
    img = bpy.data.images.load(path)
    img.colorspace_settings.name = "Non-Color"
    w, h = img.size
    target = size * max(1, round(max(w, h) / size))
    if (w, h) != (target, target):
        img.scale(target, target)
        w, h = target, target
    buf = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    bpy.data.images.remove(img)
    arr = buf.reshape(h, w, 4)[..., :3]
    k = w // size
    if normal:
        vec = arr * 2.0 - 1.0
        if k > 1:
            vec = vec.reshape(size, k, size, k, 3).mean(axis=(1, 3))
        length = np.linalg.norm(vec, axis=-1, keepdims=True)
        vec = vec / np.maximum(length, 1e-6)
        return vec * 0.5 + 0.5
    if linear_average:
        arr = srgb_to_linear(arr)
    if k > 1:
        arr = arr.reshape(size, k, size, k, 3).mean(axis=(1, 3))
    return arr


def srgb_to_linear(c: np.ndarray) -> np.ndarray:
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(c: np.ndarray) -> np.ndarray:
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1.0 / 2.4) - 0.055)


def write(path: str, rgb: np.ndarray, fmt: str) -> None:
    size = rgb.shape[0]
    img = bpy.data.images.new("tmp_out", size, size, alpha=False, float_buffer=False)
    img.colorspace_settings.name = "Non-Color"
    px = np.ones((size, size, 4), dtype=np.float32)
    px[..., :3] = np.clip(rgb, 0.0, 1.0)
    img.pixels.foreach_set(px.ravel())
    img.file_format = fmt
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if fmt == "JPEG":
        img.save(filepath=path, quality=JPEG_QUALITY)
    else:
        img.save(filepath=path)
    bpy.data.images.remove(img)


def gray3(a: np.ndarray) -> np.ndarray:
    return np.repeat(a[..., :1], 3, axis=-1)


def process(entry: dict, size: int, force: bool) -> dict:
    sid, group, files = entry["id"], entry["group"], entry["files"]
    out_dir = os.path.join(DST, group)
    result = {"id": sid, "group": group, "source": entry["source"], "base": entry["base"], "size": size, "maps": {}}
    if "color" not in files:
        result["error"] = "нет карты цвета"
        return result

    path_c = os.path.join(out_dir, sid + "_c.jpg")
    color_lin = read_box(files["color"], size, linear_average=True)
    if "ao" in files and AO_STRENGTH > 0.0:
        ao = read_box(files["ao"], size)[..., :1]
        color_lin = color_lin * (1.0 - AO_STRENGTH + AO_STRENGTH * ao)
        result["ao_baked"] = AO_STRENGTH
    color = linear_to_srgb(color_lin)
    if force or not os.path.exists(path_c):
        write(path_c, color, "JPEG")
    result["maps"]["c"] = os.path.basename(path_c)
    avg_lin = color_lin.reshape(-1, 3).mean(axis=0)
    result["avg_color"] = [round(float(v), 4) for v in linear_to_srgb(avg_lin)]

    if "normal" in files:
        path_n = os.path.join(out_dir, sid + "_n.png")
        if force or not os.path.exists(path_n):
            write(path_n, read_box(files["normal"], size, normal=True), "PNG")
        result["maps"]["n"] = os.path.basename(path_n)

    if "rough" in files:
        path_r = os.path.join(out_dir, sid + "_r.jpg")
        rough = read_box(files["rough"], size)[..., :1]
        if force or not os.path.exists(path_r):
            write(path_r, gray3(rough), "JPEG")
        result["maps"]["r"] = os.path.basename(path_r)
        result["rough_mean"] = round(float(rough.mean()), 3)

    if "metal" in files:
        metal = read_box(files["metal"], size)[..., :1]
        result["metal_max"] = round(float(metal.max()), 3)
        if metal.max() >= METAL_MIN:
            path_m = os.path.join(out_dir, sid + "_m.jpg")
            if force or not os.path.exists(path_m):
                write(path_m, gray3(metal), "JPEG")
            result["maps"]["m"] = os.path.basename(path_m)
    return result


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = argv[argv.index("--only") + 1].lower() if "--only" in argv else ""
    size = int(argv[argv.index("--size") + 1]) if "--size" in argv else SIZE
    force = "--force" in argv

    entries = [e for e in discover() if only in e["id"].lower()]
    print("наборов к обработке:", len(entries))
    results = []
    for i, entry in enumerate(entries, 1):
        try:
            res = process(entry, size, force)
        except Exception as exc:  # один битый набор не должен ронять остальные
            res = {"id": entry["id"], "group": entry["group"], "error": repr(exc)}
        results.append(res)
        flag = "ОШИБКА " + res["error"] if "error" in res else " ".join(sorted(res["maps"]))
        print(f"[{i}/{len(entries)}] {res['group']}/{res['id']}: {flag}")

    if not only:
        with open(MANIFEST, "w", encoding="utf-8") as f:
            json.dump(results, f, ensure_ascii=False, indent=1)
        print("манифест:", MANIFEST)
    bad = [r for r in results if "error" in r]
    print("готово: ok =", len(results) - len(bad), "ошибок =", len(bad))


main()
