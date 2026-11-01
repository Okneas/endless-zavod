class_name GrenadeProjectile
extends RigidBody3D
## Брошенная граната (№92). Поведение по типу GrenadeDefinition.Kind: осколочная и стихийная отскакивают и взрываются по запалу (стихийные ещё
## и от касания врага), липкая прилипает к врагу или поверхности и взрывается через запал, кассетная при первом ударе разлетается на малые
## гранаты, сингулярность при падении стягивает врагов к центру и взрывается. Взрыв: Blast (урон врагам, ящикам и бочкам, игрока не задевает).
## Слой гранаты пустой: её никто не видит как препятствие, сама она сталкивается с миром и слоем врагов.

enum State { FLYING, STUCK, PULLING }

const WORLD_LAYER: int = 1
const ENEMY_LAYER: int = 4
const RADIUS: float = 0.11
const MAX_LIFETIME: float = 14.0
## Касание врага: центр гранаты ближе этого к центру врага.
const TOUCH_DISTANCE: float = 1.0
## Первые доли секунды после броска касание не считается ударом (граната ещё выходит из рук).
const ARM_TIME: float = 0.06
## Во сколько раз радиус стягивания больше радиуса взрыва.
const PULL_REACH: float = 1.4

var definition: GrenadeDefinition
var settings: GrenadeSettings
var damage: float = 0.0
var radius: float = 0.0
var fuse: float = 0.0
var bomblets: int = 0
var pull_time: float = 0.0
## Малая граната кассетной: взрывается по запалу, не разлетается.
var is_bomblet: bool = false
var state: State = State.FLYING
var detonated: bool = false

var _age: float = 0.0
var _fuse_left: float = 0.0
var _pull_left: float = 0.0
var _impact: bool = false
var _stuck_to: Node3D
var _stuck_offset: Vector3 = Vector3.ZERO
var _mesh: MeshInstance3D


## Граната из экземпляра игрока: числа берутся из его итоговых характеристик.
static func from_instance(grenade: GrenadeInstance, p_settings: GrenadeSettings) -> GrenadeProjectile:
	var stats: GrenadeInstance.Stats = grenade.compute_stats()
	var projectile: GrenadeProjectile = GrenadeProjectile.new()
	projectile.definition = grenade.definition
	projectile.settings = p_settings
	projectile.damage = stats.damage
	projectile.radius = stats.radius
	projectile.fuse = stats.fuse
	projectile.bomblets = stats.bomblets
	projectile.pull_time = stats.pull_time
	return projectile


func _ready() -> void:
	name = "Grenade"
	add_to_group(&"grenades")
	collision_layer = 0
	collision_mask = WORLD_LAYER | ENEMY_LAYER
	mass = 0.5
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4
	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.bounce = definition.bounciness
	material.friction = 0.7
	physics_material_override = material
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = RADIUS
	shape_node.shape = shape
	add_child(shape_node)
	var surface: StandardMaterial3D = StandardMaterial3D.new()
	surface.albedo_color = definition.color
	surface.emission_enabled = true
	surface.emission = definition.color
	surface.emission_energy_multiplier = 0.9
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = RADIUS * (0.7 if is_bomblet else 1.0)
	sphere.height = sphere.radius * 2.0
	sphere.material = surface
	_mesh = MeshInstance3D.new()
	_mesh.mesh = sphere
	add_child(_mesh)
	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color = definition.color
	glow.light_energy = 0.4
	glow.omni_range = 2.5
	glow.shadow_enabled = false
	add_child(glow)
	_fuse_left = fuse


func _integrate_forces(physics_state: PhysicsDirectBodyState3D) -> void:
	if state != State.FLYING or _impact or _age < ARM_TIME:
		return
	for i: int in physics_state.get_contact_count():
		var other: Object = physics_state.get_contact_collider_object(i)
		if other is Node and (other as Node).is_in_group(&"player"):
			continue
		_impact = true
		_stuck_to = other as Node3D if other is Enemy else null
		return


func _physics_process(delta: float) -> void:
	if detonated:
		return
	_age += delta
	if _age > MAX_LIFETIME:
		detonate()
		return
	match state:
		State.FLYING:
			_tick_flying(delta)
		State.STUCK:
			_tick_stuck(delta)
		State.PULLING:
			_tick_pulling(delta)


# Полёт: запал идёт от броска, кроме липкой (она ждёт удара). Касание врага запускает свойство типа.
func _tick_flying(delta: float) -> void:
	if is_bomblet:
		_fuse_left -= delta
		if _fuse_left <= 0.0:
			detonate()
		return
	var touching: Enemy = _touching_enemy() if _age >= ARM_TIME else null
	match definition.kind:
		GrenadeDefinition.Kind.FRAG:
			_fuse_left -= delta
			if _fuse_left <= 0.0 or (definition.explodes_on_enemy and touching != null):
				detonate()
		GrenadeDefinition.Kind.STICKY:
			if _impact or touching != null:
				_stick(touching)
		GrenadeDefinition.Kind.CLUSTER:
			_fuse_left -= delta
			if _impact or touching != null or _fuse_left <= 0.0:
				_burst()
		GrenadeDefinition.Kind.SINGULARITY:
			_fuse_left -= delta
			if _impact or touching != null or _fuse_left <= 0.0:
				_start_pull()


func _tick_stuck(delta: float) -> void:
	if _stuck_to != null:
		if not is_instance_valid(_stuck_to) or (_stuck_to is Enemy and (_stuck_to as Enemy).is_dead):
			detonate()
			return
		global_position = _stuck_to.global_position + _stuck_offset
	_fuse_left -= delta
	# Мигает всё чаще, пока горит запал.
	_mesh.visible = _fuse_left > 0.8 or int(_fuse_left * 8.0) % 2 == 0
	if _fuse_left <= 0.0:
		detonate()


func _tick_pulling(delta: float) -> void:
	_pull_left -= delta
	var center: Vector3 = global_position
	var reach: float = radius * PULL_REACH
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: Enemy = node as Enemy
		if enemy == null or enemy.is_dead or enemy.dormant:
			continue
		var to_center: Vector3 = center - enemy.global_position
		if not enemy.is_flier():
			to_center.y = 0.0
		var distance: float = to_center.length()
		if distance > reach or distance < 0.6:
			continue
		var step: Vector3 = to_center / distance * minf(definition.pull_speed * delta, distance - 0.5)
		if not enemy.test_move(enemy.global_transform, step):
			enemy.global_position += step
	_mesh.scale = Vector3.ONE * (1.0 + 0.35 * sin(_age * 18.0)) * 1.6
	if _pull_left <= 0.0:
		detonate()


func _stick(enemy: Enemy) -> void:
	state = State.STUCK
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	_fuse_left = fuse
	if enemy != null:
		_stuck_to = enemy
	if _stuck_to != null:
		_stuck_offset = global_position - _stuck_to.global_position


func _start_pull() -> void:
	state = State.PULLING
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	_pull_left = maxf(pull_time, 0.1)


# Кассетная: основная граната исчезает, из неё разлетаются малые, каждая взрывается по своему короткому запалу.
func _burst() -> void:
	detonated = true
	var parent: Node = get_parent()
	var origin: Vector3 = global_position
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var count: int = maxi(bomblets, 1)
	for i: int in count:
		var child: GrenadeProjectile = GrenadeProjectile.new()
		child.definition = definition
		child.settings = settings
		child.is_bomblet = true
		child.damage = damage * definition.bomblet_damage_share
		child.radius = radius * 0.6
		child.fuse = rng.randf_range(0.45, 0.9)
		child.bomblets = 0
		parent.add_child(child)
		child.global_position = origin + Vector3(0.0, 0.1, 0.0)
		var angle: float = TAU * (float(i) + rng.randf() * 0.5) / float(count)
		var direction: Vector3 = Vector3(cos(angle), rng.randf_range(0.5, 1.0), sin(angle)).normalized()
		child.linear_velocity = direction * definition.bomblet_speed
	BlastEffect.spawn(parent, origin, maxf(radius * 0.4, 0.8), definition.color)
	queue_free()


## Взрыв: вспышка и урон по радиусу (Blast), стихия типа накладывается на врагов.
func detonate() -> void:
	if detonated:
		return
	detonated = true
	var origin: Vector3 = global_position
	BlastEffect.spawn(get_parent(), origin, radius, definition.color)
	Blast.apply(self, origin, radius, damage, definition.element, settings.blast_edge_share, 0.0, [get_rid()])
	queue_free()


func _touching_enemy() -> Enemy:
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: Enemy = node as Enemy
		if enemy == null or enemy.is_dead or enemy.dormant:
			continue
		if global_position.distance_to(enemy.global_position + Vector3(0.0, 0.9, 0.0)) < TOUCH_DISTANCE:
			return enemy
	return null
