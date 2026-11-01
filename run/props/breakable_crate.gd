class_name BreakableCrate
extends StaticBody3D
## Ящик (№91): ломается от выстрелов, удара и взрыва, а из него выпадают монеты, аптечка, деталь оружия («компонент») и хлам для
## продажи. Слой «enemy» (4): по ящику идут выстрелы и удар; слой «player_solid» (16) делает его твёрдым для игрока (врагов игрок не задерживает). Что и с каким шансом падает,
## лежит в CrateDefinition. Расстановка в комнатах: PropScatterer.

const ENEMY_LAYER: int = 4
const PLAYER_SOLID_LAYER: int = 16
const FLASH_TIME: float = 0.1
const DEBRIS_PIECES: int = 6
const DEBRIS_TIME: float = 0.6

signal broken(at: Vector3)

var definition: CrateDefinition
var settings: PropSettings
var health: float = 0.0
var is_broken: bool = false
## Зерно выпадения: ящик с одним зерном даёт одно и то же (зерно берётся от сида зоны).
var loot_seed: int = 0
## Уровень зоны: задаёт уровень выпавшей гранаты (№92).
var zone_level: int = 1

var _material: StandardMaterial3D
var _flash_left: float = 0.0


static func create(p_definition: CrateDefinition, p_settings: PropSettings, p_seed: int) -> BreakableCrate:
	var crate: BreakableCrate = BreakableCrate.new()
	crate.definition = p_definition
	crate.settings = p_settings
	crate.loot_seed = p_seed
	return crate


func _ready() -> void:
	name = "Crate"
	add_to_group(&"props")
	health = definition.health
	collision_layer = ENEMY_LAYER | PLAYER_SOLID_LAYER
	collision_mask = 0
	set_physics_process(false)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = definition.size
	shape_node.shape = shape
	shape_node.position.y = definition.size.y * 0.5
	add_child(shape_node)
	_material = StandardMaterial3D.new()
	_material.albedo_color = definition.color
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = definition.size
	mesh.material = _material
	var body: MeshInstance3D = MeshInstance3D.new()
	body.mesh = mesh
	body.position.y = definition.size.y * 0.5
	add_child(body)
	# Перекладины сверху и по бокам: по ним ящик узнаётся издали.
	var strap_material: StandardMaterial3D = StandardMaterial3D.new()
	strap_material.albedo_color = definition.color.darkened(0.45)
	for offset: float in [-0.3, 0.3]:
		var strap_mesh: BoxMesh = BoxMesh.new()
		strap_mesh.size = Vector3(definition.size.x * 1.03, definition.size.y * 1.03, 0.08)
		strap_mesh.material = strap_material
		var strap: MeshInstance3D = MeshInstance3D.new()
		strap.mesh = strap_mesh
		strap.position = Vector3(0.0, definition.size.y * 0.5, definition.size.z * offset)
		add_child(strap)


func _physics_process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		_material.albedo_color = definition.color.lightened(0.5) if _flash_left > 0.0 else definition.color
		if _flash_left <= 0.0:
			set_physics_process(false)


## Любой урон (выстрел, удар, взрыв) снимает прочность. Возвращает true, если ящик разбит этим попаданием.
func take_hit(info: DamageInfo) -> bool:
	if is_broken:
		return false
	_flash_left = FLASH_TIME
	set_physics_process(true)
	DamageNumber.spawn_hit(get_parent(), info, info.amount)
	health -= info.amount
	if health <= 0.0:
		_break()
		return true
	return false


func _break() -> void:
	is_broken = true
	var parent: Node = get_parent()
	var at: Vector3 = global_position + Vector3(0.0, definition.size.y * 0.6, 0.0)
	_drop_loot(parent, at)
	_spawn_debris(parent)
	broken.emit(at)
	queue_free()


# Выпадение по таблице ящика. Деньги и аптечка летят сами (Pickup), деталь и хлам лежат предметами.
func _drop_loot(parent: Node, at: Vector3) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = loot_seed
	if rng.randf() < definition.money_chance:
		var money: int = rng.randi_range(definition.money_min, maxi(definition.money_min, definition.money_max))
		if money > 0:
			Pickup.spawn(parent, at, Pickup.Kind.MONEY, float(money))
	if rng.randf() < definition.medkit_chance:
		Pickup.spawn(parent, at, Pickup.Kind.MEDKIT, definition.medkit_heal)
	if rng.randf() < definition.part_chance:
		var generator: WeaponGenerator = WeaponGenerator.new(Config.data.weapons)
		var rolled: PartInstance = generator.generate_part(rng)
		if rolled != null:
			ItemPickup.spawn_tossed(parent, InventoryItem.from_part(rolled, Config.data.weapons), at, rng)
	if rng.randf() < definition.grenade_chance:
		var generator: GrenadeGenerator = GrenadeGenerator.new(Config.data.grenades, Config.data.weapons.quality_scale)
		ItemPickup.spawn_tossed(parent, InventoryItem.from_grenade(generator.generate(rng, zone_level)), at, rng)
	if rng.randf() < definition.shield_chance:
		var shield_generator: ShieldGenerator = ShieldGenerator.new(Config.data.shields, Config.data.weapons.quality_scale)
		ItemPickup.spawn_tossed(parent, InventoryItem.from_shield(shield_generator.generate(rng, zone_level)), at, rng)
	if rng.randf() < definition.junk_chance:
		var junk: InventoryItem = JunkLoot.roll(rng, settings, definition.junk_min, definition.junk_max)
		if junk != null:
			ItemPickup.spawn_tossed(parent, junk, at, rng)


# Обломки: несколько кубиков разлетаются и исчезают. Только оформление.
func _spawn_debris(parent: Node) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var debris: Node3D = Node3D.new()
	debris.name = "Debris"
	parent.add_child(debris)
	debris.global_position = global_position + Vector3(0.0, definition.size.y * 0.5, 0.0)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = definition.color.darkened(0.2)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var tween: Tween = debris.create_tween().set_parallel(true)
	for i: int in DEBRIS_PIECES:
		var piece_mesh: BoxMesh = BoxMesh.new()
		piece_mesh.size = Vector3.ONE * rng.randf_range(0.12, 0.25)
		piece_mesh.material = material
		var piece: MeshInstance3D = MeshInstance3D.new()
		piece.mesh = piece_mesh
		debris.add_child(piece)
		var target: Vector3 = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.2, 0.9), rng.randf_range(-1.0, 1.0))
		tween.tween_property(piece, "position", target, DEBRIS_TIME).set_ease(Tween.EASE_OUT)
		tween.tween_property(piece, "scale", Vector3.ZERO, DEBRIS_TIME).set_delay(DEBRIS_TIME * 0.4)
	tween.chain().tween_callback(debris.queue_free)
