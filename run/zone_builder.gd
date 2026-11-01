class_name ZoneBuilder
extends Node3D
## Строит зону из готового плана ZoneLayout (№41): ставит сцены комнат и переходов на свои места, закрывает глухие
## проёмы заглушками (в стенах, в полу и в потолке), ставит двери комнатам с боем, ставит лестницу в проёмы, где комнаты
## стоят друг над другом (№81), запекает навигацию врагов по геометрии зоны и подписывает комнаты (пометки для отладки). Игрока и врагов не создаёт: старт игрока отдаёт через player_spawn, враги появляются из
## контроллера комнаты при входе игрока.

signal built

var layout: ZoneLayout
## Экземпляры сцен по индексу части плана.
var pieces: Array[RoomPiece] = []
var controllers: Array[RoomController] = []
## Испытания шлюза, эвакуации и босса (№82) и магазины.
var challenges: Array[ChallengeController] = []
var shops: Array[ShopController] = []
var doors: Array[RoomDoor] = []
var plugs: Array[RoomDoor] = []
## Лестницы в проёмах вертикальных стыков (по одной на стык).
var links: Array[Node3D] = []
var navigation_region: NavigationRegion3D
## Точка старта игрока в стартовой комнате.
var player_spawn: Marker3D

var _pieces_root: Node3D
var _doors_root: Node3D
## Двери комнат с боем по индексу части плана.
var _doors_by_piece: Dictionary = {}


## Сколько секунд ждать, пока карта навигации подхватит новую зону, прежде чем сдаться (по часам, а не по кадрам:
## карта считается в потоке, и число кадров за это время зависит от их скорости).
const NAVIGATION_WAIT_SECONDS: float = 60.0
## Карта увидела зону, если ближайшая точка сетки к контрольной точке ближе этого, м.
const NAVIGATION_PROBE_DISTANCE: float = 2.0


func clear() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	pieces.clear()
	controllers.clear()
	challenges.clear()
	shops.clear()
	doors.clear()
	plugs.clear()
	links.clear()
	_doors_by_piece.clear()
	navigation_region = null
	player_spawn = null
	layout = null


func build(zone_layout: ZoneLayout, settings: ZoneSettings) -> void:
	clear()
	layout = zone_layout
	_pieces_root = Node3D.new()
	_pieces_root.name = "Pieces"
	add_child(_pieces_root)
	_doors_root = Node3D.new()
	_doors_root.name = "Doors"
	add_child(_doors_root)
	for piece: PlacedPiece in layout.pieces:
		var instance: RoomPiece = piece.definition.scene.instantiate() as RoomPiece
		instance.name = "%02d_%s" % [piece.index, RoomDefinition.Kind.keys()[piece.kind()].to_lower()]
		instance.transform = piece.transform
		_pieces_root.add_child(instance)
		pieces.append(instance)
	for piece: PlacedPiece in layout.pieces:
		_close_openings(piece)
		_add_vertical_links(piece, settings)
	var fall_limit: float = layout.get_bounds().position.y - settings.fall_margin
	for piece: PlacedPiece in layout.pieces:
		_add_controller(piece, settings, fall_limit)
	var start_markers: Array[Marker3D] = pieces[0].get_markers(&"player_spawn")
	player_spawn = start_markers[0] if not start_markers.is_empty() else null
	_bake_navigation(settings)
	built.emit()


## Ждёт, пока карта навигации подхватит сетку этой зоны. Карта обновляется в отдельном потоке и в большой зоне
## несколько секунд остаётся пустой или со старыми данными прошлой зоны: пока она не готова, враги не огибают
## препятствия. Вызывается под экраном загрузки. Контрольная точка стоит в последней поставленной комнате, готовность
## определяется по тому, что ближайшая к ней точка сетки принадлежит новому региону (а не сетке прошлой зоны).
## Возвращает true, если карта готова.
func wait_for_navigation() -> bool:
	if navigation_region == null or layout == null or layout.pieces.is_empty():
		return false
	var last: PlacedPiece = layout.pieces[layout.pieces.size() - 1]
	var probe: Vector3 = last.entrance_position(0)
	for entrance: RoomInfo.Entrance in last.info.entrances:
		if not entrance.is_vertical():
			probe = last.transform * (entrance.position - entrance.direction * 1.5)
			break
	var map: RID = get_world_3d().navigation_map
	var deadline: int = Time.get_ticks_msec() + int(NAVIGATION_WAIT_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var closest: Vector3 = NavigationServer3D.map_get_closest_point(map, probe)
		# Ближайшая точка должна принадлежать именно новому региону: у карты ещё может лежать сетка прошлой зоны.
		if closest != Vector3.ZERO and closest.distance_to(probe) < NAVIGATION_PROBE_DISTANCE and NavigationServer3D.map_get_closest_point_owner(map, probe) == navigation_region.get_rid():
			return true
		await get_tree().physics_frame
	return false


# Каждый вход без соседа заделывается заглушкой, у комнат с боем горизонтальные входы с соседом получают дверь.
# Вертикальные стыки (комнаты друг над другом, №85) закрываются так же, как горизонтальные: плита дверей закрывает проём в полу
# или потолке комнаты на время боя, шлюза, эвакуации и боя с боссом, иначе игрок мог бы уйти вверх или вниз посреди боя.
func _close_openings(piece: PlacedPiece) -> void:
	var instance: RoomPiece = pieces[piece.index]
	var entrances: Array[RoomEntrance] = instance.get_entrances()
	for i: int in entrances.size():
		var vertical: bool = piece.info.entrances[i].is_vertical()
		var door: RoomDoor = null
		if not piece.links.has(i):
			door = RoomDoor.new()
			_doors_root.add_child(door)
			door.setup(entrances[i].global_transform, entrances[i].opening, true, vertical)
			plugs.append(door)
		elif _locks_doors(piece.kind()):
			door = RoomDoor.new()
			_doors_root.add_child(door)
			door.setup(entrances[i].global_transform, entrances[i].opening, false, vertical)
			door.set_closed(false)
			doors.append(door)
			if not _doors_by_piece.has(piece.index):
				_doors_by_piece[piece.index] = [] as Array[RoomDoor]
			(_doors_by_piece[piece.index] as Array[RoomDoor]).append(door)


# Лестница стыка ставится один раз, от нижней комнаты: по маркеру проёма в её потолке, ось X сцены идёт по оси X маркера.
func _add_vertical_links(piece: PlacedPiece, settings: ZoneSettings) -> void:
	if settings.vertical_link == null:
		return
	for i: int in piece.links:
		var entrance: RoomInfo.Entrance = piece.info.entrances[i]
		if not entrance.is_vertical() or entrance.direction.y < 0.0:
			continue
		var heading: Vector3 = piece.entrance_heading(i)
		var link: Node3D = settings.vertical_link.instantiate() as Node3D
		link.name = "Link_%02d_%d" % [piece.index, i]
		link.transform = Transform3D(Basis(Vector3.UP, atan2(-heading.z, heading.x)), piece.entrance_position(i))
		_pieces_root.add_child(link)
		links.append(link)


# Двери у комнат, где идёт бой или испытание: закрываются, пока оно не пройдено.
func _locks_doors(kind: RoomDefinition.Kind) -> bool:
	return kind == RoomDefinition.Kind.COMBAT or kind == RoomDefinition.Kind.GATE or kind == RoomDefinition.Kind.EVACUATION or kind == RoomDefinition.Kind.BOSS


func _add_controller(piece: PlacedPiece, settings: ZoneSettings, fall_limit: float) -> void:
	var kind: RoomDefinition.Kind = piece.kind()
	var instance: RoomPiece = pieces[piece.index]
	_add_label(instance, piece)
	var own_doors: Array[RoomDoor] = _doors_by_piece.get(piece.index, [] as Array[RoomDoor])
	var seed_value: int = hash([layout.zone_seed, piece.index])
	match kind:
		RoomDefinition.Kind.COMBAT, RoomDefinition.Kind.LOOT:
			var controller: RoomController = RoomController.new()
			controller.setup(instance, kind, own_doors, settings, layout.zone_number, layout.zone_level, seed_value, piece.definition.enemy_scale, fall_limit)
			controllers.append(controller)
		RoomDefinition.Kind.GATE, RoomDefinition.Kind.EVACUATION, RoomDefinition.Kind.BOSS:
			var mode: ChallengeController.Mode = ChallengeController.Mode.EVACUATION
			if kind == RoomDefinition.Kind.BOSS:
				mode = ChallengeController.Mode.BOSS
			elif kind == RoomDefinition.Kind.GATE:
				mode = ChallengeController.Mode.ELITE if piece.definition.gate_mode == RoomDefinition.GateMode.ELITE else ChallengeController.Mode.WAVES
			var challenge: ChallengeController = ChallengeController.new()
			challenge.setup(instance, mode, own_doors, settings, layout.zone_number, layout.zone_level, seed_value, layout.run_seed, fall_limit)
			challenges.append(challenge)
		RoomDefinition.Kind.SHOP:
			var shop: ShopController = ShopController.new()
			shop.setup(instance, layout.zone_level, seed_value)
			shops.append(shop)


# Пометка типа комнаты под потолком: нужна, пока комнаты безликие (отладка).
func _add_label(instance: RoomPiece, piece: PlacedPiece) -> void:
	if piece.is_corridor():
		return
	var bounds: AABB = instance.get_bounds()
	var label: Label3D = Label3D.new()
	label.name = "Label"
	label.text = tr("ROOM_KIND_" + RoomDefinition.Kind.keys()[piece.kind()])
	label.font_size = 96
	label.pixel_size = 0.02
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color(1.0, 0.9, 0.5, 0.9)
	label.position = bounds.get_center() + Vector3(0.0, bounds.size.y * 0.5 - 4.0, 0.0)
	instance.add_child(label)


# Сетка навигации по мешам всех комнат и переходов (двери в неё не входят): враги на земле идут по ней.
func _bake_navigation(settings: ZoneSettings) -> void:
	navigation_region = NavigationRegion3D.new()
	navigation_region.name = "Navigation"
	navigation_region.navigation_mesh = NavigationBaker.bake(_pieces_root, settings)
	add_child(navigation_region)
