class_name PlayerHook
extends Node3D
## Хук: цепляется к первой твёрдой поверхности в прицеле и тянет к точке зацепа, пока кнопка
## зажата. Текущее движение игрока не обрывается: скорость плавно подводится к направлению на
## точку (сначала медленно, потом быстрее), а гравитация постепенно затухает. После долёта игрока
## слегка подбрасывает вверх, и он на «пружине» возвращается к точке и успокаивается в ней.
## При отпускании остаётся накопленная скорость (инерция).
## Сам хук ничего не двигает: step() возвращает скорость, двигает игрок через move_and_slide().

enum Phase { NONE, PULL, SPRING }

## Слой физики «мир» (слой 1): хук цепляется только к нему.
const WORLD_LAYER_MASK: int = 1
## Где верёвка начинается относительно камеры: справа-снизу-впереди, как «из руки».
const ROPE_HAND_OFFSET: Vector3 = Vector3(0.25, -0.25, -0.4)
## Проверку «игрока держит препятствие» включаем, только когда скорость к цели уже набрана.
## Это порог эвристики, а не баланс.
const BLOCKED_CHECK_MIN_SPEED: float = 3.0
## Доля просимой скорости к цели, ниже которой считаем движение заблокированным (тоже эвристика).
const BLOCKED_PROGRESS_RATIO: float = 0.25

## Настройки хука. Править в Inspector здесь или двойным щелчком по hook_settings.tres.
@export var settings: HookSettings

var is_attached: bool = false
## Игрок долетел (или упёрся) и держится на пружине у точки зацепа.
var is_hanging: bool:
	get:
		return _phase == Phase.SPRING

var _player: CharacterBody3D
var _camera: Camera3D
var _phase: Phase = Phase.NONE
var _hit_point: Vector3
var _target: Vector3
var _spring_center: Vector3
var _time_since_attach: float = 0.0
var _blocked_time: float = 0.0

@onready var _rope: MeshInstance3D = $Rope


func setup(player: CharacterBody3D, camera: Camera3D) -> void:
	assert(settings != null, "У хука не назначены настройки (HookSettings)")
	_player = player
	_camera = camera
	# Верёвка живёт в мировых координатах и не должна ехать вместе с игроком.
	_rope.top_level = true
	_rope.visible = false


func _process(_delta: float) -> void:
	if not is_attached:
		return
	var from: Vector3 = _camera.global_transform * ROPE_HAND_OFFSET
	var length: float = from.distance_to(_hit_point)
	if length < 0.01:
		_rope.visible = false
		return
	var direction: Vector3 = (_hit_point - from) / length
	# Если смотрим строго вверх или вниз, look_at по умолчанию ломается: берём другую «верхнюю» ось.
	var up: Vector3 = Vector3.UP if absf(direction.y) < 0.99 else Vector3.RIGHT
	_rope.global_transform = Transform3D(Basis.looking_at(direction, up), from.lerp(_hit_point, 0.5))
	_rope.scale = Vector3(settings.rope_thickness, settings.rope_thickness, length)
	_rope.visible = true


## Пробует зацепиться за поверхность в прицеле. Возвращает true, если цель найдена.
func try_attach() -> bool:
	var from: Vector3 = _camera.global_position
	var to: Vector3 = from - _camera.global_basis.z * settings.max_range
	var exclude: Array[RID] = [_player.get_rid()]
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, WORLD_LAYER_MASK, exclude)
	var hit: Dictionary = _player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var normal: Vector3 = hit["normal"]
	_hit_point = hit["position"]
	_target = _hit_point + normal * settings.surface_offset
	_time_since_attach = 0.0
	_blocked_time = 0.0
	_phase = Phase.PULL
	is_attached = true
	return true


func release() -> void:
	is_attached = false
	_phase = Phase.NONE
	_blocked_time = 0.0
	_rope.visible = false


## Во сколько раз игрок ещё подвержен гравитации: 1 в момент зацепа, плавно до 0 к концу разгона.
## Так падение или полёт не обрываются, а постепенно сменяются притягиванием.
func get_gravity_scale() -> float:
	if _phase != Phase.PULL:
		return 0.0
	if settings.acceleration_ramp_time <= 0.0:
		return 0.0
	return 1.0 - smoothstep(0.0, settings.acceleration_ramp_time, _time_since_attach)


## Скорость игрока в этом шаге физики (без гравитации, её добавляет игрок по get_gravity_scale()).
## current_velocity: текущая скорость игрока. Хук её не обнуляет, а подводит к цели.
## real_velocity: фактическая скорость после прошлого move_and_slide() (чтобы заметить препятствие).
func step(current_velocity: Vector3, real_velocity: Vector3, delta: float) -> Vector3:
	if _phase == Phase.SPRING:
		return _spring_step(current_velocity, delta)
	var to_target: Vector3 = _target - _camera.global_position
	var distance: float = to_target.length()
	if distance <= settings.arrival_distance:
		# Долетели: подбрасываем вверх, дальше пружина вернёт к точке зацепа.
		return _start_spring(_target, Vector3.UP * settings.arrival_kick_speed)
	var direction: Vector3 = to_target / distance
	var speed_to_target: float = current_velocity.dot(direction)
	if speed_to_target > BLOCKED_CHECK_MIN_SPEED and real_velocity.dot(direction) < speed_to_target * BLOCKED_PROGRESS_RATIO:
		_blocked_time += delta
		if _blocked_time >= settings.blocked_timeout:
			# Упёрлись в препятствие по дороге: держимся там, где остановились, без подброса.
			return _start_spring(_camera.global_position, Vector3.ZERO)
	else:
		_blocked_time = 0.0
	_time_since_attach += delta
	# Разгон нарастает по S-кривой: хук берёт игрока мягко. Скорость не заменяется, а движется
	# к «скорость притягивания в сторону точки» с ограниченным ускорением, поэтому боковая и
	# падающая скорость, которые были при зацепе, плавно выравниваются в сторону точки.
	var ramp: float = 1.0
	if settings.acceleration_ramp_time > 0.0:
		ramp = smoothstep(0.0, settings.acceleration_ramp_time, _time_since_attach)
	var desired: Vector3 = direction * settings.pull_speed
	var new_velocity: Vector3 = current_velocity.move_toward(desired, settings.pull_acceleration * ramp * delta)
	# За шаг проходим не больше оставшегося расстояния, чтобы не проскочить точку.
	var along: float = new_velocity.dot(direction)
	var max_along: float = distance / delta
	if along > max_along:
		new_velocity -= direction * (along - max_along)
	return new_velocity


func _start_spring(center: Vector3, initial_velocity: Vector3) -> Vector3:
	_phase = Phase.SPRING
	_spring_center = center
	return initial_velocity


# Затухающая пружина к центру: ускорение = жёсткость * смещение - затухание * скорость.
# Затухание считается из коэффициента (2 * коэффициент * корень из жёсткости), чтобы автор
# правил понятное число: 0.4 слегка перелетает, 1 возвращает без раскачки.
func _spring_step(current_velocity: Vector3, delta: float) -> Vector3:
	var stiffness: float = settings.spring_stiffness
	var damping: float = 2.0 * settings.spring_damping_ratio * sqrt(stiffness)
	var offset: Vector3 = _spring_center - _camera.global_position
	var acceleration: Vector3 = offset * stiffness - current_velocity * damping
	return current_velocity + acceleration * delta
