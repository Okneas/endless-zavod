class_name RoomController
extends Node3D
## Поведение одной комнаты зоны (№41, №81, №82). Комната с врагами: при входе игрока двери закрываются, из пула врагов зоны
## появляется нужное число врагов (формула зоны на множитель комнаты), после гибели последнего двери открываются. Появление
## врагов и присмотр за ними (свободные места, сторож провалившихся и застрявших) делает EnemyDirector. Кладовая: при входе
## игрока на точках награды лежит гарантированный лут (оружие уровня зоны и деньги). Остальные типы комнат ведут свои
## контроллеры (шлюз, эвакуация, босс: ChallengeController, магазин: ShopController).

signal combat_started
signal combat_cleared
signal loot_spawned

enum State { IDLE, ACTIVE, DONE }

var state: State = State.IDLE
var kind: RoomDefinition.Kind = RoomDefinition.Kind.COMBAT
var room: RoomPiece
var doors: Array[RoomDoor] = []
var director: EnemyDirector
## Живые враги комнаты, их число и сколько раз сторож переносил провалившихся: данные директора.
var enemies: Array[Enemy]:
	get:
		return director.enemies
var enemies_alive: int:
	get:
		return director.enemies_alive
var relocations: int:
	get:
		return director.relocations

## Рост игрока для проверки «внутри комнаты» (капсула стоя, MovementSettings.stand_height).
const PLAYER_HEIGHT: float = 1.8

var _settings: ZoneSettings
var _zone_number: int = 1
var _zone_level: int = 1
var _enemy_scale: float = 1.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _trigger: Area3D


func setup(p_room: RoomPiece, p_kind: RoomDefinition.Kind, p_doors: Array[RoomDoor], settings: ZoneSettings, zone_number: int, zone_level: int, seed_value: int, enemy_scale: float = 1.0, fall_limit: float = -INF) -> void:
	room = p_room
	kind = p_kind
	doors = p_doors
	_settings = settings
	_zone_number = zone_number
	_zone_level = zone_level
	_enemy_scale = enemy_scale
	_rng.seed = seed_value
	name = "Controller"
	room.add_child(self)
	director = EnemyDirector.new()
	director.setup(room, settings, zone_number, zone_level, seed_value + 1, fall_limit)
	director.cleared.connect(_on_cleared)
	# Зона внутри комнаты без стен: вошёл игрок, значит бой или кладовая начинаются.
	var inner: AABB = room.get_trigger_box()
	_trigger = Area3D.new()
	_trigger.name = "Trigger"
	_trigger.collision_layer = 0
	_trigger.collision_mask = 2
	_trigger.position = inner.get_center()
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = inner.size
	shape_node.shape = shape
	_trigger.add_child(shape_node)
	add_child(_trigger)


# Бой начинается, когда игрок стоит внутри комнаты целиком (№87), а не когда он задел зону краем: иначе на лестнице стыка (она
# проходит сквозь плиту пола комнаты) плита закрывалась бы под ногами и игрок оказывался в стене.
func _physics_process(_delta: float) -> void:
	if state != State.IDLE:
		return
	for body: Node3D in _trigger.get_overlapping_bodies():
		if body.is_in_group(&"player") and room.is_actor_inside(body.global_position, PLAYER_HEIGHT):
			_on_player_inside()
			return


func _on_player_inside() -> void:
	state = State.ACTIVE
	match kind:
		RoomDefinition.Kind.COMBAT:
			_start_combat.call_deferred()
		RoomDefinition.Kind.LOOT:
			_spawn_loot.call_deferred()
		_:
			state = State.DONE


func _start_combat() -> void:
	for door: RoomDoor in doors:
		door.set_closed(true)
	var count: int = maxi(roundi(float(ZoneMath.enemy_count(_settings, _zone_number)) * _enemy_scale), 1)
	director.spawn_pool(count)
	combat_started.emit()
	if director.enemies_alive == 0:
		_finish()


func _on_cleared() -> void:
	if state == State.ACTIVE:
		_finish()


func _finish() -> void:
	state = State.DONE
	for door: RoomDoor in doors:
		if is_instance_valid(door):
			door.set_closed(false)
	combat_cleared.emit()


func _spawn_loot() -> void:
	var generator: WeaponGenerator = WeaponGenerator.new(Config.data.weapons)
	var markers: Array[Marker3D] = room.get_markers(&"loot_spawn")
	for i: int in markers.size():
		var at: Vector3 = markers[i].global_position
		if i < _settings.loot_weapons and _rng.randf() < _settings.loot_weapon_chance:
			var weapon: WeaponInstance = generator.generate(_rng, _zone_level)
			if weapon != null:
				ItemPickup.spawn(room, InventoryItem.from_weapon(weapon), at, Vector3.ZERO)
		elif i < _settings.loot_weapons:
			# Оружие не выпало: на этой точке лежат деньги.
			Pickup.spawn(room, at, Pickup.Kind.MONEY, float(_rng.randi_range(_settings.loot_money_min, maxi(_settings.loot_money_min, _settings.loot_money_max))))
		elif i < _settings.loot_weapons + _settings.loot_parts:
			var rolled: PartInstance = generator.generate_part(_rng)
			if rolled != null:
				ItemPickup.spawn(room, InventoryItem.from_part(rolled, Config.data.weapons), at, Vector3.ZERO)
		else:
			# Последние точки: деньги, а иногда хлам для продажи (№91).
			var junk: InventoryItem = JunkLoot.roll(_rng, Config.data.props) if _rng.randf() < Config.data.props.loot_junk_chance else null
			if _rng.randf() < Config.data.grenades.loot_point_chance:
				var grenades: GrenadeGenerator = GrenadeGenerator.new(Config.data.grenades, Config.data.weapons.quality_scale)
				ItemPickup.spawn(room, InventoryItem.from_grenade(grenades.generate(_rng, _zone_level)), at, Vector3.ZERO)
			elif _rng.randf() < Config.data.shields.loot_point_chance:
				var shields: ShieldGenerator = ShieldGenerator.new(Config.data.shields, Config.data.weapons.quality_scale)
				ItemPickup.spawn(room, InventoryItem.from_shield(shields.generate(_rng, _zone_level)), at, Vector3.ZERO)
			elif junk != null:
				ItemPickup.spawn(room, junk, at, Vector3.ZERO)
			else:
				Pickup.spawn(room, at, Pickup.Kind.MONEY, float(_rng.randi_range(_settings.loot_money_min, maxi(_settings.loot_money_min, _settings.loot_money_max))))
	state = State.DONE
	loot_spawned.emit()
