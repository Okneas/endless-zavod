class_name PlayerMelee
extends Node
## Удар в ближнем бою на одну кнопку (V), как в Borderlands (02-combat-fps).
## Бьёт шаром перед камерой по мишеням (слой «enemy»), урон и размер зоны в MeleeSettings.

signal swung(hit_something: bool)

const ENEMY_LAYER_MASK: int = 4
## Сколько целей максимум обрабатываем за один удар.
const MAX_TARGETS: int = 8

## Настройки удара. Править в Inspector здесь или двойным щелчком по melee_settings.tres.
@export var settings: MeleeSettings

var _player: CharacterBody3D
var _camera: Camera3D
var _weapon: Weapon
var _cooldown: float = 0.0


func setup(player: CharacterBody3D, camera: Camera3D, weapon: Weapon) -> void:
	assert(settings != null, "У ближнего боя не назначены настройки (MeleeSettings)")
	_player = player
	_camera = camera
	_weapon = weapon


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if Input.is_action_just_pressed(&"melee") and _cooldown <= 0.0:
		swing()


## Бьёт. Возвращает true, если задели хотя бы одну цель.
func swing() -> bool:
	_cooldown = settings.cooldown
	_weapon.play_melee_swing(settings.swing_time)
	var center: Vector3 = _camera.global_position - _camera.global_basis.z * settings.reach
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = settings.radius
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.collision_mask = ENEMY_LAYER_MASK
	var results: Array[Dictionary] = _player.get_world_3d().direct_space_state.intersect_shape(query, MAX_TARGETS)
	var nearest: Node3D = null
	var nearest_distance: float = INF
	for result: Dictionary in results:
		var collider: Object = result["collider"]
		if collider is Node3D and collider.has_method(&"take_hit"):
			var distance: float = _camera.global_position.distance_to((collider as Node3D).global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = collider as Node3D
	if nearest != null:
		# Удар не оружие: таблица уязвимостей и стихии на него не действуют.
		# Особенность аксессуара оружия в руках усиливает и удар в ближнем бою.
		var info: DamageInfo = DamageInfo.create(settings.damage * (1.0 + _weapon.stats.melee_damage_bonus), false, center)
		info.apply_vulnerability = false
		info.is_melee = true
		info.direction = -_camera.global_basis.z
		nearest.call(&"take_hit", info)
	swung.emit(nearest != null)
	return nearest != null
