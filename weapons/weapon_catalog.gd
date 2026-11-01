class_name WeaponCatalog
extends RefCounted
## Каталог вариантов частей: все .tres частей с производителем из папки данных (в том числе из вложенных).
## Новый вариант части это новый .tres в папке, без правки кода (09-tech-godot).

static var _cache: Dictionary = {}

var parts: Array[WeaponPart] = []


## Каталог для папки. Загружается один раз за запуск (папка читается с диска).
static func for_directory(directory: String) -> WeaponCatalog:
	if not _cache.has(directory):
		var catalog: WeaponCatalog = WeaponCatalog.new()
		catalog.scan(directory)
		_cache[directory] = catalog
	return _cache[directory]


func scan(directory: String) -> void:
	for file_name: String in DirAccess.get_files_at(directory):
		# В собранной игре ресурсы лежат под именем .tres.remap: убираем хвост, load понимает исходное имя.
		var clean: String = file_name.trim_suffix(".remap")
		if not clean.ends_with(".tres") and not clean.ends_with(".res"):
			continue
		var resource: Resource = load(directory.path_join(clean))
		var part: WeaponPart = resource as WeaponPart
		if part != null and part.manufacturer != null:
			parts.append(part)
	for sub: String in DirAccess.get_directories_at(directory):
		scan(directory.path_join(sub))


## Варианты части данного вида у данного производителя, подходящие типу оружия.
func get_variants(part_type: WeaponPart.PartType, manufacturer: Manufacturer, weapon_type: CombatEnums.WeaponType) -> Array[WeaponPart]:
	var result: Array[WeaponPart] = []
	if not makes(manufacturer, weapon_type):
		return result
	for part: WeaponPart in parts:
		if part.part_type == part_type and part.manufacturer == manufacturer and fits(part, weapon_type):
			result.append(part)
	return result


## Делает ли производитель этот тип оружия (специализация, №72). Пустой список = любые типы.
static func makes(manufacturer: Manufacturer, weapon_type: CombatEnums.WeaponType) -> bool:
	return manufacturer.weapon_types.is_empty() or manufacturer.weapon_types.has(weapon_type)


## Подходит ли часть типу оружия: корпус по своему типу, остальные по списку (пустой список = любой тип).
static func fits(part: WeaponPart, weapon_type: CombatEnums.WeaponType) -> bool:
	if part.part_type == WeaponPart.PartType.BODY:
		return part.weapon_type == weapon_type
	return part.weapon_types.is_empty() or part.weapon_types.has(weapon_type)