class_name MaterialLibrary
extends RefCounted
## Подмена материалов импортированных моделей на материалы библиотеки проекта.
##
## В Blender материал называется как набор текстур (например "painted_metal_004"), .glb экспортируется
## без картинок. Здесь материал с таким именем заменяется файлом assets/materials/<группа>/<имя>.tres
## (суффикс "_tri" в имени даёт мировой триплпланар). Общий меш не меняется: подмена идёт через
## surface override на узле, поэтому один .glb можно ставить с разными материалами.

const ROOT: String = "res://assets/materials/"

static var _paths: Dictionary = {}
static var _loaded: Dictionary = {}


## Заменяет материалы всех MeshInstance3D под root. Возвращает число подменённых поверхностей.
static func apply(root: Node) -> int:
	var replaced: int = 0
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh == null:
			continue
		for surface: int in mi.mesh.get_surface_count():
			var source: Material = mi.get_surface_override_material(surface)
			if source == null:
				source = mi.mesh.surface_get_material(surface)
			if source == null:
				continue
			var library: Material = get_material(source.resource_name)
			if library != null:
				mi.set_surface_override_material(surface, library)
				replaced += 1
	return replaced


## Материал библиотеки по имени или null, если такого набора нет.
static func get_material(material_name: String) -> Material:
	if material_name.is_empty():
		return null
	if _paths.is_empty():
		_scan()
	if not _paths.has(material_name):
		return null
	if not _loaded.has(material_name):
		_loaded[material_name] = load(_paths[material_name]) as Material
	return _loaded[material_name]


## Имена всех материалов библиотеки (для проверок и отчётов).
static func all_names() -> PackedStringArray:
	if _paths.is_empty():
		_scan()
	return PackedStringArray(_paths.keys())


static func _scan() -> void:
	for group: String in ResourceLoader.list_directory(ROOT):
		if not group.ends_with("/"):
			continue
		for file: String in ResourceLoader.list_directory(ROOT + group):
			if file.ends_with(".tres"):
				_paths[file.get_basename()] = ROOT + group + file
