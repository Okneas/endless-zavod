extends SceneTree
## Создаёт библиотеку материалов assets/materials/<группа>/ из манифеста текстурной библиотеки.
##   <id>.tres      обычные UV (для моделей из Blender, UV 0..1 = один тайл)
##   <id>_tri.tres  мировой триплпланар (для блоков, рамп и хаба без развёртки), тайл в метрах из TILE_METERS
## Существующие файлы не перезаписываются: правки автора в Inspector остаются.
## Запуск: godot --headless --path <проект> --script <этот файл> [-- --dry]

const MANIFEST: String = "res://assets/source/scripts/lib_manifest.json"
const LIB: String = "res://assets/textures/lib/"
const OUT: String = "res://assets/materials/"

## Сколько метров занимает один тайл текстуры в мировом триплпланаре. Стартовые значения, правятся в .tres.
const TILE_METERS: Dictionary = {
	"brick": 1.5, "concrete": 3.0, "fabric": 1.0, "floor": 2.0, "ground": 3.0, "metal": 2.0,
	"other": 0.6, "plaster": 3.0, "rust": 2.0, "tiles": 1.5, "wall": 3.0,
}
const DEFAULT_TILE_METERS: float = 2.0


func _initialize() -> void:
	var dry: bool = OS.get_cmdline_user_args().has("--dry")
	var text: String = FileAccess.get_file_as_string(ProjectSettings.globalize_path(MANIFEST))
	var items: Array = JSON.parse_string(text) as Array
	if items.is_empty():
		push_error("манифест пуст или не читается: " + MANIFEST)
		quit(1)
		return
	var created: int = 0
	var skipped: int = 0
	var failed: int = 0
	for entry_variant: Variant in items:
		var entry: Dictionary = entry_variant as Dictionary
		if entry.has("error"):
			push_error("набор с ошибкой: " + str(entry))
			failed += 1
			continue
		for triplanar: bool in [false, true]:
			var result: int = _make(entry, triplanar, dry)
			if result > 0:
				created += 1
			elif result == 0:
				skipped += 1
			else:
				failed += 1
	print("материалов создано: %d, уже были: %d, ошибок: %d" % [created, skipped, failed])
	quit(1 if failed > 0 else 0)


## 1 создан, 0 уже есть, -1 ошибка.
func _make(entry: Dictionary, triplanar: bool, dry: bool) -> int:
	var group: String = entry["group"]
	var id: String = entry["id"]
	var maps: Dictionary = entry["maps"]
	var path: String = OUT + group + "/" + id + ("_tri" if triplanar else "") + ".tres"
	if FileAccess.file_exists(path):
		return 0

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.resource_name = id + ("_tri" if triplanar else "")
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS

	var albedo: Texture2D = _tex(group, maps, "c")
	if albedo == null:
		push_error("нет цвета: " + path)
		return -1
	mat.albedo_texture = albedo

	var rough: Texture2D = _tex(group, maps, "r")
	if rough != null:
		mat.roughness = 1.0
		mat.roughness_texture = rough
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED

	var metal: Texture2D = _tex(group, maps, "m")
	if metal != null:
		mat.metallic = 1.0
		mat.metallic_texture = metal
		mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED

	var normal: Texture2D = _tex(group, maps, "n")
	if normal != null:
		mat.normal_enabled = true
		mat.normal_texture = normal

	if triplanar:
		var scale: float = 1.0 / float(TILE_METERS.get(group, DEFAULT_TILE_METERS))
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = Vector3(scale, scale, scale)

	if dry:
		print("[dry] ", path)
		return 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err: int = ResourceSaver.save(mat, path)
	if err != OK:
		push_error("не сохранено (%d): %s" % [err, path])
		return -1
	return 1


func _tex(group: String, maps: Dictionary, key: String) -> Texture2D:
	if not maps.has(key):
		return null
	return load(LIB + group + "/" + str(maps[key])) as Texture2D
