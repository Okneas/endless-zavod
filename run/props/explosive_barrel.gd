class_name ExplosiveBarrel
extends RigidBody3D
## Стихийная бочка (№91): стоит в комнате, взрывается от выстрела или от соседнего взрыва и задевает врагов в радиусе, накладывая стихию.
## Удар в ближнем бою (V) не ломает бочку, а толкает: она летит к ближайшему видимому врагу (как в Borderlands 4), без врагов вперёд,
## и взрывается при первом ударе о врага, стену или землю. Игрока взрыв тоже задевает, но слабее (BarrelDefinition.player_damage).
## Слой бочки «enemy» (4): по ней идут выстрелы и удар, враги упираются в неё как в препятствие; слой «player_solid» (16) делает её твёрдой для игрока.

const WORLD_LAYER: int = 1
const ENEMY_LAYER: int = 4
const PLAYER_SOLID_LAYER: int = 16
const PLAYER_LAYER: int = 2
const RADIUS: float = 0.42
const HEIGHT: float = 1.0
## Взрыв в полёте, когда центр бочки ближе этого к центру врага.
const PROXIMITY: float = 1.1
## Касание земли в первые секунды полёта не взрывает (бочка ещё скользит по полу), касание стены или врага взрывает.
const FLOOR_GRACE: float = 0.35
const MAX_FLIGHT_TIME: float = 6.0
const FLASH_TIME: float = 0.1

signal blasted(at: Vector3)

var definition: BarrelDefinition
var settings: PropSettings
## Множитель урона врагам от уровня зоны (ZoneMath.enemy_health_scale).
var damage_scale: float = 1.0
var health: float = 0.0
var exploded: bool = false
## Летит после толчка.
var launched: bool = false

var _flight_time: float = 0.0
var _fuse_left: float = -1.0
var _flash_left: float = 0.0
var _impact: bool = false
var _material: StandardMaterial3D
var _spin_rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func create(p_definition: BarrelDefinition, p_settings: PropSettings, p_damage_scale: float) -> ExplosiveBarrel:
	var barrel: ExplosiveBarrel = ExplosiveBarrel.new()
	barrel.definition = p_definition
	barrel.settings = p_settings
	barrel.damage_scale = p_damage_scale
	return barrel


func _ready() -> void:
	name = "Barrel"
	add_to_group(&"props")
	health = definition.health
	collision_layer = ENEMY_LAYER | PLAYER_SOLID_LAYER
	collision_mask = WORLD_LAYER | ENEMY_LAYER
	mass = 60.0
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 6
	_spin_rng.randomize()
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = RADIUS
	shape.height = HEIGHT
	shape_node.shape = shape
	add_child(shape_node)
	_material = StandardMaterial3D.new()
	_material.albedo_color = definition.color
	_material.emission_enabled = true
	_material.emission = definition.color
	_material.emission_energy_multiplier = 0.35
	var body_mesh: CylinderMesh = CylinderMesh.new()
	body_mesh.top_radius = RADIUS
	body_mesh.bottom_radius = RADIUS
	body_mesh.height = HEIGHT
	body_mesh.material = _material
	var body: MeshInstance3D = MeshInstance3D.new()
	body.mesh = body_mesh
	add_child(body)
	# Тёмные обручи и светящаяся крышка: издали бочку видно и по цвету узнаётся стихия.
	var hoop_material: StandardMaterial3D = StandardMaterial3D.new()
	hoop_material.albedo_color = Color(0.12, 0.12, 0.13)
	for y: float in [-0.28, 0.28]:
		var hoop_mesh: CylinderMesh = CylinderMesh.new()
		hoop_mesh.top_radius = RADIUS + 0.015
		hoop_mesh.bottom_radius = RADIUS + 0.015
		hoop_mesh.height = 0.06
		hoop_mesh.material = hoop_material
		var hoop: MeshInstance3D = MeshInstance3D.new()
		hoop.mesh = hoop_mesh
		hoop.position.y = y
		add_child(hoop)
	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color = definition.color
	glow.light_energy = 0.5
	glow.omni_range = 3.5
	glow.shadow_enabled = false
	glow.position.y = 0.7
	add_child(glow)
	sleeping = true


## Выстрел повреждает бочку, удар в ближнем бою толкает. Возвращает true, если бочка взорвана этим попаданием.
func take_hit(info: DamageInfo) -> bool:
	if exploded:
		return false
	if info.is_melee:
		push(info.direction)
		return false
	_flash_left = FLASH_TIME
	DamageNumber.spawn_hit(get_parent(), info, info.amount)
	health -= info.amount
	if health <= 0.0:
		detonate()
		return true
	return false


## Толчок: бочка летит к ближайшему видимому врагу, а если таких нет, вперёд по направлению удара.
func push(forward: Vector3) -> void:
	if exploded or launched:
		return
	var target: Enemy = _find_target()
	var velocity: Vector3
	if target != null:
		velocity = _ballistic_velocity(global_position, target.global_position + Vector3(0.0, 0.9, 0.0), settings.push_speed)
	else:
		var flat: Vector3 = Vector3(forward.x, 0.0, forward.z)
		flat = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
		velocity = flat * settings.push_idle_speed + Vector3.UP * 4.0
	sleeping = false
	launched = true
	_flight_time = 0.0
	_impact = false
	linear_velocity = velocity
	angular_velocity = Vector3(_spin_rng.randf_range(-6.0, 6.0), _spin_rng.randf_range(-6.0, 6.0), _spin_rng.randf_range(-6.0, 6.0))


## Взрыв: вспышка, урон врагам и игроку в радиусе, цепной взрыв соседних бочек.
func detonate() -> void:
	if exploded:
		return
	exploded = true
	var origin: Vector3 = global_position
	BlastEffect.spawn(get_parent(), origin, definition.blast_radius, definition.color)
	_apply_blast(origin)
	blasted.emit(origin)
	queue_free()


## Взрыв бочки задетой соседним взрывом: не сразу, а через chain_delay.
func chain_detonate() -> void:
	if exploded or _fuse_left >= 0.0:
		return
	_fuse_left = settings.chain_delay


func _physics_process(delta: float) -> void:
	if exploded:
		return
	if _flash_left > 0.0:
		_flash_left -= delta
		_material.emission_energy_multiplier = 2.5 if _flash_left > 0.0 else 0.35
	if _fuse_left >= 0.0:
		_fuse_left -= delta
		if _fuse_left <= 0.0:
			detonate()
			return
	if not launched:
		return
	_flight_time += delta
	if _flight_time > MAX_FLIGHT_TIME or _impact or _near_enemy():
		detonate()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not launched or _flight_time < settings.push_launch_delay:
		return
	for i: int in state.get_contact_count():
		var other: Object = state.get_contact_collider_object(i)
		if other is Node and (other as Node).is_in_group(&"player"):
			continue
		var floor_contact: bool = state.get_contact_local_normal(i).y > 0.7
		if floor_contact and _flight_time < FLOOR_GRACE:
			continue
		_impact = true
		return


func _near_enemy() -> bool:
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: Enemy = node as Enemy
		if enemy == null or enemy.is_dead or enemy.dormant:
			continue
		if global_position.distance_to(enemy.global_position + Vector3(0.0, 0.9, 0.0)) < PROXIMITY + 0.3:
			return true
	return false


# Ближайший живой видимый враг в радиусе поиска (прямая видимость до его центра).
func _find_target() -> Enemy:
	var best: Enemy = null
	var best_distance: float = settings.push_seek_range
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: Enemy = node as Enemy
		if enemy == null or enemy.is_dead or enemy.dormant:
			continue
		var center: Vector3 = enemy.global_position + Vector3(0.0, 0.9, 0.0)
		var distance: float = global_position.distance_to(center)
		if distance >= best_distance:
			continue
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(global_position, center, WORLD_LAYER)).is_empty():
			continue
		best_distance = distance
		best = enemy
	return best


# Скорость, с которой тело, брошенное из from со скоростью по земле speed, под действием тяжести попадёт в to.
func _ballistic_velocity(from: Vector3, to: Vector3, speed: float) -> Vector3:
	var delta: Vector3 = to - from
	var flat: Vector3 = Vector3(delta.x, 0.0, delta.z)
	var time: float = maxf(flat.length() / maxf(speed, 0.1), 0.3)
	var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity")) * gravity_scale
	var rise: float = (delta.y + 0.5 * gravity * time * time) / time
	return flat / time + Vector3.UP * rise


func _apply_blast(origin: Vector3) -> void:
	Blast.apply(self, origin, definition.blast_radius, definition.blast_damage * damage_scale, definition.element, settings.blast_edge_share, definition.player_damage, [get_rid()])
