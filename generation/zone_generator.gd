class_name ZoneGenerator
extends RefCounted
## Генератор зоны (срез 6, №41, №80, №81): ветвящийся рост от стартовой комнаты в трёх измерениях. Новая комната цепляется
## к свободному входу уже поставленной. Горизонтальный вход (проём в стене) стыкуется через переход (коридор, пандус,
## поворот) со входом той же ширины, сцена поворачивается на кратные 90 градусов. Вертикальный вход (проём в потолке или
## в полу) стыкуется напрямую с проёмом того же размера у комнаты, которая встаёт над или под ней. Габариты не должны
## пересекаться. Босс и эвакуация уходят в самые глубокие ветки, кладовые и магазин садятся на тупики, остальное бой.
## Результат это только данные (ZoneLayout).
## Одинаковые каталог, настройки, зона и сид дают одну и ту же зону.

var _settings: ZoneSettings
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _layout: ZoneLayout
## Свободные входы: x индекс поставленной части, y индекс входа.
var _open: Array[Vector2i] = []
var _rooms_by_kind: Dictionary = {}
var _corridors: Array[RoomDefinition] = []


func generate(catalog: Array[RoomDefinition], settings: ZoneSettings, zone_number: int, run_seed: int, zone_seed: int, world_level: int) -> ZoneLayout:
	_settings = settings
	_rng.seed = zone_seed
	_layout = ZoneLayout.new()
	_layout.zone_number = zone_number
	_layout.run_seed = run_seed
	_layout.zone_seed = zone_seed
	_layout.zone_level = ZoneMath.zone_level(settings, world_level, zone_number)
	_open.clear()
	_sort_catalog(catalog, zone_number)
	var starts: Array[RoomDefinition] = _rooms_by_kind.get(RoomDefinition.Kind.START, [] as Array[RoomDefinition])
	if starts.is_empty():
		_layout.warnings.append("в пуле нет стартовой комнаты")
		return _layout
	var start_definition: RoomDefinition = _weighted_order(starts, _weight_plain)[0]
	_place(start_definition, Transform3D.IDENTITY, -1, -1, 0)
	var failed: Array[RoomDefinition.Kind] = []
	for kind: RoomDefinition.Kind in _plan(zone_number):
		if not _grow(kind):
			failed.append(kind)
	# Вторая попытка для не поместившихся: к этому времени свободные входы могли появиться в других ветках.
	for kind: RoomDefinition.Kind in failed:
		if not _grow(kind):
			_layout.warnings.append("не удалось разместить комнату типа %s" % RoomDefinition.Kind.keys()[kind])
	return _layout


# --- пул

func _sort_catalog(catalog: Array[RoomDefinition], zone_number: int) -> void:
	_rooms_by_kind.clear()
	_corridors.clear()
	for definition: RoomDefinition in catalog:
		if not definition.is_allowed_on(zone_number) or definition.weight <= 0.0:
			continue
		var info: RoomInfo = RoomCatalog.info_of(definition)
		if info.problem != "":
			_layout.warnings.append("%s: %s" % [definition.resource_path, info.problem])
			continue
		if definition.kind == RoomDefinition.Kind.CORRIDOR:
			_corridors.append(definition)
			continue
		if not _rooms_by_kind.has(definition.kind):
			_rooms_by_kind[definition.kind] = [] as Array[RoomDefinition]
		(_rooms_by_kind[definition.kind] as Array[RoomDefinition]).append(definition)


# Какие комнаты нужны (кроме стартовой) в порядке размещения: сначала бой (он растит зону), потом эвакуация, босс или шлюз
# (в самые глубокие ветки), затем кладовые и магазин.
func _plan(zone_number: int) -> Array[RoomDefinition.Kind]:
	var others: int = ZoneMath.room_count(_settings, zone_number) - 1
	# Комнаты, без которых зона не проходится (эвакуация, босс, шлюз), встают сразу после боя: им достаются самые глубокие
	# входы, и необязательные тупики (кладовые, магазин) не могут занять все входы раньше них.
	var required: Array[RoomDefinition.Kind] = []
	if ZoneMath.has_evacuation(_settings, zone_number):
		required.append(RoomDefinition.Kind.EVACUATION)
	if ZoneMath.has_boss(_settings, zone_number):
		required.append(RoomDefinition.Kind.BOSS)
	elif ZoneMath.has_gate(_settings, zone_number) and _rooms_by_kind.has(RoomDefinition.Kind.GATE):
		# Шлюз в следующую зону (№82).
		required.append(RoomDefinition.Kind.GATE)
	var optional: Array[RoomDefinition.Kind] = []
	if _rooms_by_kind.has(RoomDefinition.Kind.SHOP) and _rng.randf() < _settings.shop_chance:
		optional.append(RoomDefinition.Kind.SHOP)
	var specials: int = required.size() + optional.size()
	var loot: int = mini(ZoneMath.loot_room_count(_settings, zone_number), maxi(others - specials - 1, 0))
	var combat: int = maxi(others - specials - loot, 1)
	var plan: Array[RoomDefinition.Kind] = []
	for i: int in combat:
		plan.append(RoomDefinition.Kind.COMBAT)
	plan.append_array(required)
	for i: int in loot:
		plan.append(RoomDefinition.Kind.LOOT)
	plan.append_array(optional)
	return plan


# --- рост

func _grow(kind: RoomDefinition.Kind) -> bool:
	var candidates: Array[RoomDefinition] = _rooms_by_kind.get(kind, [] as Array[RoomDefinition])
	if candidates.is_empty():
		return false
	for attempt: int in _settings.attempts_per_room:
		if _open.is_empty():
			return false
		# Вторая половина попыток берёт любой свободный вход: назначенный тип входа мог не подойти.
		var open_index: int = _pick_open(kind, attempt >= _settings.attempts_per_room / 2)
		if _try_attach(open_index, kind, candidates):
			return true
	return false


func _pick_open(kind: RoomDefinition.Kind, any_entrance: bool) -> int:
	if any_entrance:
		return _rng.randi_range(0, _open.size() - 1)
	if kind == RoomDefinition.Kind.COMBAT and _settings.vertical_chance > 0.0 and _rng.randf() < _settings.vertical_chance:
		var verticals: Array[int] = _open_indices(true)
		if not verticals.is_empty():
			return verticals[_rng.randi_range(0, verticals.size() - 1)]
	# Остальным типам вертикальные проёмы не годятся (у них нет проёма в полу или в потолке), пока есть другие входы.
	var pool: Array[int] = _open_indices(false)
	if pool.is_empty():
		pool = _open_indices(true)
	if kind == RoomDefinition.Kind.BOSS or kind == RoomDefinition.Kind.EVACUATION or kind == RoomDefinition.Kind.GATE:
		var deepest: Array[int] = []
		var best: int = -1
		for i: int in pool:
			var depth: int = _layout.pieces[_open[i].x].depth
			if depth > best:
				best = depth
				deepest = [i]
			elif depth == best:
				deepest.append(i)
		return deepest[_rng.randi_range(0, deepest.size() - 1)]
	if kind == RoomDefinition.Kind.COMBAT and _rng.randf() < _settings.deep_bias:
		return pool[_rng.randi_range(maxi(pool.size() - 3, 0), pool.size() - 1)]
	return pool[_rng.randi_range(0, pool.size() - 1)]


# Индексы свободных входов: вертикальных (проём в потолке или полу) или горизонтальных.
func _open_indices(vertical: bool) -> Array[int]:
	var result: Array[int] = []
	for i: int in _open.size():
		var open: Vector2i = _open[i]
		if _layout.pieces[open.x].info.entrances[open.y].is_vertical() == vertical:
			result.append(i)
	return result


func _try_attach(open_index: int, kind: RoomDefinition.Kind, candidates: Array[RoomDefinition]) -> bool:
	var open: Vector2i = _open[open_index]
	var origin: PlacedPiece = _layout.pieces[open.x]
	if origin.info.entrances[open.y].is_vertical():
		return _try_attach_vertical(open_index, kind, candidates)
	var point: Vector3 = origin.entrance_position(open.y)
	var direction: Vector3 = origin.entrance_direction(open.y)
	var size: Vector2 = origin.info.entrances[open.y].size
	for corridor: RoomDefinition in _weighted_order(_corridors, _weight_plain):
		var corridor_info: RoomInfo = RoomCatalog.info_of(corridor)
		for near_end: int in _shuffled_indices(corridor_info.entrances.size()):
			var corridor_transform: Array = _align(corridor_info.entrances[near_end], point, direction, size)
			if corridor_transform.is_empty():
				continue
			var corridor_box: AABB = (corridor_transform[0] as Transform3D) * corridor_info.bounds
			if _collides(corridor_box, []):
				continue
			for far_end: int in corridor_info.entrances.size():
				if far_end == near_end:
					continue
				if _attach_room(origin, open, corridor, near_end, far_end, corridor_transform[0], corridor_box, kind, candidates):
					_open.remove_at(open_index)
					return true
	return false


# Вертикальный стык: комната встаёт прямо над или под свободным проёмом, без перехода. Нужен вход с противоположным
# направлением и проёмом того же размера (с учётом поворота), поворот вокруг вертикали подбирается из четырёх.
func _try_attach_vertical(open_index: int, kind: RoomDefinition.Kind, candidates: Array[RoomDefinition]) -> bool:
	var open: Vector2i = _open[open_index]
	var origin: PlacedPiece = _layout.pieces[open.x]
	var point: Vector3 = origin.entrance_position(open.y)
	var direction: Vector3 = origin.entrance_direction(open.y)
	var footprint: Vector2 = origin.entrance_footprint(open.y)
	for room: RoomDefinition in _weighted_order(candidates, _weight_for.bind(kind)):
		var room_info: RoomInfo = RoomCatalog.info_of(room)
		for entrance: int in _shuffled_indices(room_info.entrances.size()):
			var other: RoomInfo.Entrance = room_info.entrances[entrance]
			if not other.is_vertical() or other.direction.y * direction.y > -0.5:
				continue
			for step: int in _shuffled_indices(4):
				var basis: Basis = Basis(Vector3.UP, float(step) * PI * 0.5)
				if not other.footprint(basis).is_equal_approx(footprint):
					continue
				var placed: Transform3D = Transform3D(basis, point - basis * other.position)
				if _collides(placed * room_info.bounds, []):
					continue
				var piece: PlacedPiece = _place(room, placed, origin.index, entrance, origin.depth + 1)
				origin.links[open.y] = piece.index
				piece.links[entrance] = origin.index
				_open.remove_at(open_index)
				return true
	return false


# Комната на дальнем конце перехода: перебирает варианты и входы, ставит первый, что вошёл без пересечений.
func _attach_room(origin: PlacedPiece, open: Vector2i, corridor: RoomDefinition, near_end: int, far_end: int, corridor_transform: Transform3D, corridor_box: AABB, kind: RoomDefinition.Kind, candidates: Array[RoomDefinition]) -> bool:
	var corridor_info: RoomInfo = RoomCatalog.info_of(corridor)
	var far: RoomInfo.Entrance = corridor_info.entrances[far_end]
	var point: Vector3 = corridor_transform * far.position
	var direction: Vector3 = corridor_transform.basis * far.direction
	for room: RoomDefinition in _weighted_order(candidates, _weight_for.bind(kind)):
		var room_info: RoomInfo = RoomCatalog.info_of(room)
		for entrance: int in _shuffled_indices(room_info.entrances.size()):
			var room_transform: Array = _align(room_info.entrances[entrance], point, direction, far.size)
			if room_transform.is_empty():
				continue
			var room_box: AABB = (room_transform[0] as Transform3D) * room_info.bounds
			if _collides(room_box, [corridor_box]):
				continue
			var corridor_piece: PlacedPiece = _place(corridor, corridor_transform, origin.index, near_end, origin.depth + 1)
			origin.links[open.y] = corridor_piece.index
			corridor_piece.links[near_end] = origin.index
			var room_piece: PlacedPiece = _place(room, room_transform[0], corridor_piece.index, entrance, corridor_piece.depth + 1)
			corridor_piece.links[far_end] = room_piece.index
			room_piece.links[entrance] = corridor_piece.index
			return true
	return false


# Стыковка входа с точкой: поворот на кратный 90 градусам так, чтобы входы смотрели друг на друга, и сдвиг, чтобы
# проёмы совпали. Пустой массив, если проёмы разного размера или вход не вдоль оси.
func _align(entrance: RoomInfo.Entrance, point: Vector3, point_direction: Vector3, point_size: Vector2) -> Array:
	if not entrance.size.is_equal_approx(point_size):
		return []
	var angle: float = entrance.direction.signed_angle_to(-point_direction, Vector3.UP)
	angle = roundf(angle / (PI * 0.5)) * PI * 0.5
	var basis: Basis = Basis(Vector3.UP, angle)
	if (basis * entrance.direction).distance_to(-point_direction) > 0.01:
		return []
	return [Transform3D(basis, point - basis * entrance.position)]


func _collides(box: AABB, ignore: Array) -> bool:
	var probe: AABB = box.grow(-_settings.overlap_margin)
	for piece: PlacedPiece in _layout.pieces:
		if probe.intersects(piece.world_bounds().grow(-_settings.overlap_margin)):
			return true
	for other: Variant in ignore:
		if probe.intersects((other as AABB).grow(-_settings.overlap_margin)):
			return true
	return false


func _place(definition: RoomDefinition, placed_transform: Transform3D, parent: int, parent_entrance: int, depth: int) -> PlacedPiece:
	var piece: PlacedPiece = PlacedPiece.new()
	piece.definition = definition
	piece.info = RoomCatalog.info_of(definition)
	piece.transform = placed_transform
	piece.index = _layout.pieces.size()
	piece.parent = parent
	piece.parent_entrance = parent_entrance
	piece.depth = depth
	_layout.pieces.append(piece)
	if definition.kind != RoomDefinition.Kind.CORRIDOR:
		for i: int in piece.info.entrances.size():
			if i != parent_entrance:
				_open.append(Vector2i(piece.index, i))
	return piece


# --- случайный выбор по весам

func _weight_plain(definition: RoomDefinition) -> float:
	return definition.weight


# Тупиковым типам (кладовая, магазин, босс, эвакуация) нужны комнаты с одним входом, бою с несколькими входами проще продолжать зону.
func _weight_for(definition: RoomDefinition, kind: RoomDefinition.Kind) -> float:
	var entrances: int = RoomCatalog.info_of(definition).entrances.size()
	var dead_end_kind: bool = kind == RoomDefinition.Kind.LOOT or kind == RoomDefinition.Kind.SHOP or kind == RoomDefinition.Kind.BOSS or kind == RoomDefinition.Kind.EVACUATION or kind == RoomDefinition.Kind.GATE
	if dead_end_kind:
		return definition.weight * (4.0 if entrances == 1 else 1.0)
	return definition.weight * (2.0 if entrances >= 2 else 1.0)


# Случайный порядок с учётом весов (чем больше вес, тем вероятнее раньше): ключ -ln(случайное) / вес по возрастанию.
func _weighted_order(definitions: Array[RoomDefinition], weight_of: Callable) -> Array[RoomDefinition]:
	var keyed: Array = []
	for definition: RoomDefinition in definitions:
		var weight: float = maxf(weight_of.call(definition), 0.0001)
		keyed.append([-log(maxf(_rng.randf(), 0.0000001)) / weight, definition])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var result: Array[RoomDefinition] = []
	for pair: Array in keyed:
		result.append(pair[1])
	return result


func _shuffled_indices(count: int) -> Array[int]:
	var result: Array[int] = []
	for i: int in count:
		result.append(i)
	for i: int in range(count - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var swap: int = result[i]
		result[i] = result[j]
		result[j] = swap
	return result
