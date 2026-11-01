class_name RoomCatalog
extends RefCounted
## Пул комнат отдела: все RoomDefinition из папки data/content/rooms/ (в том числе из подпапок). Новая комната это
## новый .tres в этой папке без правки кода (№41, №40).

const FOLDER: String = "res://data/content/rooms/"

# Сведения о сценах считаются один раз за запуск: путь сцены -> RoomInfo.
static var _infos: Dictionary = {}


static func load_all(folder: String = FOLDER) -> Array[RoomDefinition]:
	var result: Array[RoomDefinition] = []
	_scan(folder, result)
	result.sort_custom(func(a: RoomDefinition, b: RoomDefinition) -> bool: return a.resource_path < b.resource_path)
	return result


static func info_of(definition: RoomDefinition) -> RoomInfo:
	var key: String = definition.scene.resource_path
	if not _infos.has(key):
		_infos[key] = RoomInfo.from_scene(definition.scene)
	return _infos[key]


static func _scan(folder: String, result: Array[RoomDefinition]) -> void:
	var dir: DirAccess = DirAccess.open(folder)
	if dir == null:
		return
	for subfolder: String in dir.get_directories():
		_scan(folder.path_join(subfolder), result)
	for file: String in dir.get_files():
		var path: String = file.trim_suffix(".remap")
		if path.ends_with(".tres"):
			var definition: RoomDefinition = load(folder.path_join(path)) as RoomDefinition
			if definition != null and definition.scene != null:
				result.append(definition)
