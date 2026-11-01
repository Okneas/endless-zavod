class_name Player
extends CharacterBody3D
## Игрок от первого лица: ходьба, спринт, приседание, подкат, двойной прыжок и хук.
## Числа лежат в Resource, а не в коде, и видны в Inspector прямо у этого узла.

signal health_changed(current: int, maximum: int)
## Игрок получил урон в здоровье: сколько и откуда (для вспышки на экране).
signal damaged(amount: float, from_position: Vector3)
## Щит принял удар (№93): сколько урона он впитал и откуда (синяя вспышка).
signal shield_damaged(amount: float, from_position: Vector3)
signal died
## Рывок начался: куда (горизонтальное направление).
signal dashed(direction: Vector3)

enum State { GROUND, AIR, SLIDE, HOOK }

## Предел наклона взгляда вверх и вниз.
const PITCH_LIMIT: float = deg_to_rad(89.0)
## Движение вперёд считается движением вперёд, только если стик/клавиши отклонены сильнее этого.
const FORWARD_INPUT_THRESHOLD: float = 0.1
## За сколько секунд угол обзора расширяется до полного эффекта рывка и возвращается.
const DASH_FOV_EASE: float = 0.12
## Если реальная скорость в рывке упала ниже этой доли от заданной, игрок упёрся в препятствие и рывок прекращается.
const DASH_BLOCKED_RATIO: float = 0.3

@export_group("Настройки")
## Здоровье, мышь, угол обзора. Правится здесь или двойным щелчком по player_settings.tres.
@export var settings: PlayerSettings
## Скорости, прыжок, подкат, размеры тела. Правится здесь или двойным щелчком по movement_settings.tres.
## Настройки хука лежат на узле Hook.
@export var movement: MovementSettings

var state: State = State.AIR
var health: int = 0
var max_health: int = 0
## Игрок погиб: ввод и движение отключены до перезапуска комнаты (заглушка до среза 7).
var is_dead: bool = false

var _air_jumps_left: int = 0
## Рывок (срез 7б, №83): заряды восстанавливаются по одному, пока рывок не использован полностью.
var dash_charges: int = 0
var _dash_recharge_left: float = 0.0
var _dash_time_left: float = 0.0
var _dash_direction: Vector3 = Vector3.FORWARD
var _invulnerable_left: float = 0.0
var _dash_fov_amount: float = 0.0
# Касание Shift: сколько секунд держится кнопка, отслеживается ли нажатие (для различения рывка и спринта).
var _sprint_held: float = 0.0
var _sprint_tracking: bool = false
var _crouching: bool = false
# Наклон взгляда складывается из того, куда повёл мышью игрок, и отдачи, которая сама возвращается.
# Отдача мягкая: выстрел задаёт цель подъёма, камера плавно набирает её, затем цель возвращается к нулю.
var _look_pitch: float = 0.0
var _recoil_pitch: float = 0.0
var _recoil_target: float = 0.0

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _hook: PlayerHook = $Hook
@onready var _weapon: Weapon = $Head/Camera3D/Weapon
@onready var _melee: PlayerMelee = $Melee
@onready var _interactor: PlayerInteractor = $Interactor
var _grenades: GrenadeThrower
var _shield: PlayerShield


# Группа нужна до чьего-либо _ready, чтобы HUD и отладочная надпись могли найти игрока.
func _enter_tree() -> void:
	add_to_group(&"player")


func _ready() -> void:
	assert(settings != null and movement != null, "У игрока не назначены настройки (PlayerSettings, MovementSettings)")
	floor_snap_length = movement.floor_snap_length
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.fov = settings.field_of_view
	_head.position.y = movement.stand_eye_height
	_apply_body_shape()
	_hook.setup(self, _camera)
	_weapon.setup(self, _camera)
	_update_crit_bonus()
	Progress.level_changed.connect(func(_level: int) -> void: _update_crit_bonus())
	_weapon.fired.connect(_on_weapon_fired)
	_melee.setup(self, _camera, _weapon)
	_interactor.setup(self, _camera)
	_grenades = GrenadeThrower.new()
	_grenades.name = "Grenades"
	add_child(_grenades)
	_grenades.setup(self, _camera)
	_shield = PlayerShield.new()
	_shield.name = "Shield"
	add_child(_shield)
	_shield.setup(self)
	max_health = settings.max_health
	set_health(max_health)
	dash_charges = movement.dash_charges_max
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event
		# При прицеливании чувствительность делится на зум: прицел не «летает», картинка крупнее.
		var sensitivity: float = settings.mouse_sensitivity / _weapon.get_zoom()
		# Растяжение окна (stretch, эталон 1920 x 1080) масштабирует relative: возвращаем сырые пиксели мыши, чтобы
		# чувствительность не зависела от размера окна.
		var relative: Vector2 = motion.relative * get_viewport().get_final_transform().get_scale()
		rotate_y(-relative.x * sensitivity)
		set_look_pitch(_look_pitch - relative.y * sensitivity)


func _process(delta: float) -> void:
	# Камера плавно догоняет цель отдачи (мягкий удар), а цель плавно возвращается к нулю.
	_recoil_pitch = lerpf(_recoil_pitch, _recoil_target, 1.0 - exp(-_weapon.shooting.recoil_attack_speed * delta))
	_recoil_target = lerpf(_recoil_target, 0.0, 1.0 - exp(-_weapon.shooting.recoil_recovery_speed * delta))
	_apply_head_pitch()
	# Прицеливание: угол обзора сужается ровно в zoom раз (по касательной, как у реальной оптики).
	var half_fov: float = deg_to_rad(settings.field_of_view) * 0.5
	_camera.fov = rad_to_deg(2.0 * atan(tan(half_fov) / _weapon.get_zoom()))
	# Рывок: угол обзора на миг расширяется и возвращается (ощущение скорости).
	_dash_fov_amount = move_toward(_dash_fov_amount, 1.0 if _dash_time_left > 0.0 else 0.0, delta / DASH_FOV_EASE)
	_camera.fov += movement.dash_fov_kick * _dash_fov_amount


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_weapon.motion_speed = get_horizontal_speed()
	_weapon.airborne = state == State.AIR or state == State.HOOK
	_weapon.sliding = state == State.SLIDE
	var input: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var wish_dir: Vector3 = (global_basis * Vector3(input.x, 0.0, input.y)).normalized()
	_update_dash_timers(delta)
	_update_dash_input(delta, wish_dir)
	_update_hook()
	if _dash_time_left > 0.0:
		_dash_step(delta)
		move_and_slide()
		_after_move()
		_update_eye_height(delta)
		return
	if state == State.GROUND and Input.is_action_just_pressed(&"crouch") and get_horizontal_speed() >= movement.slide_min_speed:
		_start_slide()
	_update_crouch_state()
	match state:
		State.HOOK:
			velocity = _hook.step(velocity, get_real_velocity(), delta)
			# Гравитация не пропадает мгновенно, а затухает по мере разгона хука: так падение
			# и боковой полёт в момент зацепа плавно переходят в притягивание.
			velocity.y = maxf(velocity.y - movement.gravity * _hook.get_gravity_scale() * delta, -movement.max_fall_speed)
		State.SLIDE:
			_slide_step(delta, input, wish_dir)
		_:
			_free_step(delta, input, wish_dir)
	move_and_slide()
	_after_move()
	_update_eye_height(delta)


func set_health(value: int) -> void:
	health = clampi(value, 0, max_health)
	health_changed.emit(health, max_health)


## Получить урон от врага. from_position нужен для вспышки на экране. Урон сначала впитывает щит (№93), остаток идёт в здоровье.
## При нуле здоровья игрок гибнет.
func take_damage(amount: float, from_position: Vector3 = Vector3.ZERO) -> void:
	if is_dead or amount <= 0.0 or _invulnerable_left > 0.0:
		return
	var through: float = _shield.absorb(amount)
	if through < amount:
		shield_damaged.emit(amount - through, from_position)
	if through <= 0.0:
		return
	set_health(health - ceili(through))
	damaged.emit(through, from_position)
	if health <= 0:
		_die()


## Неуязвим ли игрок прямо сейчас (рывок): снаряды врагов в этот момент пролетают сквозь него.
func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


## Рывок идёт прямо сейчас.
func is_dashing() -> bool:
	return _dash_time_left > 0.0


## Какая доля восстанавливающегося заряда накоплена (0..1), для индикатора. При полных зарядах 1.
func get_dash_recharge_progress() -> float:
	if dash_charges >= movement.dash_charges_max or movement.dash_recharge_time <= 0.0:
		return 1.0
	return 1.0 - clampf(_dash_recharge_left / movement.dash_recharge_time, 0.0, 1.0)


func heal(amount: float) -> void:
	if is_dead:
		return
	set_health(health + roundi(amount))


## Центр тела: сюда целятся враги и к нему летит дроп.
func get_center_position() -> Vector3:
	return global_position + Vector3(0.0, movement.stand_height * 0.5, 0.0)


func _die() -> void:
	is_dead = true
	velocity = Vector3.ZERO
	_hook.release()
	# Оружие и ближний бой выключаются целиком: они читают ввод сами.
	_weapon.process_mode = Node.PROCESS_MODE_DISABLED
	_melee.process_mode = Node.PROCESS_MODE_DISABLED
	_grenades.process_mode = Node.PROCESS_MODE_DISABLED
	died.emit()


## Воскрешение для нового забега (срез 7): здоровье полное, ввод и оружие включены, игрок стоит в точке.
func respawn(at: Vector3, yaw: float) -> void:
	is_dead = false
	velocity = Vector3.ZERO
	global_position = at
	rotation.y = yaw
	state = State.AIR
	_weapon.process_mode = Node.PROCESS_MODE_INHERIT
	_melee.process_mode = Node.PROCESS_MODE_INHERIT
	_grenades.process_mode = Node.PROCESS_MODE_INHERIT
	set_health(max_health)
	_shield.refresh(true)
	dash_charges = movement.dash_charges_max
	_dash_recharge_left = 0.0
	_dash_time_left = 0.0
	_invulnerable_left = 0.0
	_sprint_tracking = false


func _update_crit_bonus() -> void:
	_weapon.crit_bonus = settings.crit_chance + Progress.get_crit_bonus()


func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func get_grenades() -> GrenadeThrower:
	return _grenades


func get_shield() -> PlayerShield:
	return _shield


func get_weapon() -> Weapon:
	return _weapon


## Идёт ли прицеливание (ПКМ), 0..1. Перезарядка его прерывает.
func get_aim_amount() -> float:
	return _weapon.aim_amount


## Задаёт наклон взгляда без отдачи (радианы): мышь и тесты.
func set_look_pitch(pitch: float) -> void:
	_look_pitch = clampf(pitch, -PITCH_LIMIT, PITCH_LIMIT)
	_apply_head_pitch()


func _apply_head_pitch() -> void:
	_head.rotation.x = clampf(_look_pitch + _recoil_pitch, -PITCH_LIMIT, PITCH_LIMIT)


func _on_weapon_fired(recoil_degrees: float) -> void:
	_recoil_target += deg_to_rad(recoil_degrees)


## Ключ состояния для отладочной надписи (DEBUG_STATE_<КЛЮЧ> в таблице переводов).
func get_state_key() -> String:
	if _dash_time_left > 0.0:
		return "DASH"
	match state:
		State.HOOK:
			return "HANG" if _hook.is_hanging else "HOOK"
		State.SLIDE:
			return "SLIDE"
		State.AIR:
			return "AIR"
	if _crouching:
		return "CROUCH"
	if Input.is_action_pressed(&"sprint") and get_horizontal_speed() > movement.walk_speed + 0.1:
		return "SPRINT"
	return "GROUND"


# Заряды рывка восстанавливаются по одному; неуязвимость рывка тоже тикает здесь.
func _update_dash_timers(delta: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)
	if dash_charges >= movement.dash_charges_max:
		_dash_recharge_left = 0.0
		return
	_dash_recharge_left -= delta
	if _dash_recharge_left <= 0.0:
		dash_charges += 1
		_dash_recharge_left = movement.dash_recharge_time if dash_charges < movement.dash_charges_max else 0.0


# Короткое касание Shift — рывок (в момент отпускания), долгое удержание остаётся спринтом.
func _update_dash_input(delta: float, wish_dir: Vector3) -> void:
	if Input.is_action_just_pressed(&"sprint"):
		_sprint_held = 0.0
		_sprint_tracking = true
	if not _sprint_tracking:
		return
	_sprint_held += delta
	if Input.is_action_just_released(&"sprint"):
		_sprint_tracking = false
		if _sprint_held <= movement.dash_tap_time:
			_try_dash(wish_dir)
	elif _sprint_held > movement.dash_tap_time:
		_sprint_tracking = false


func _try_dash(wish_dir: Vector3) -> void:
	if dash_charges <= 0 or state == State.HOOK or _dash_time_left > 0.0:
		return
	# Без нажатых клавиш движения рывок идёт вперёд по взгляду.
	var direction: Vector3 = wish_dir
	if direction == Vector3.ZERO:
		direction = -global_basis.z
		direction.y = 0.0
		direction = direction.normalized()
	if dash_charges >= movement.dash_charges_max:
		_dash_recharge_left = movement.dash_recharge_time
	dash_charges -= 1
	_dash_direction = direction
	_dash_time_left = movement.dash_duration
	_invulnerable_left = movement.dash_invulnerability
	if state == State.SLIDE:
		state = State.GROUND if is_on_floor() else State.AIR
	dashed.emit(direction)


func _dash_step(delta: float) -> void:
	_dash_time_left = maxf(_dash_time_left - delta, 0.0)
	velocity = _dash_direction * movement.dash_speed
	# Упёрся в стену — рывок кончается, иначе игрок «прилипал» бы к ней до конца времени.
	if _dash_time_left > 0.0 and _dash_time_left < movement.dash_duration - delta and get_real_velocity().length() < movement.dash_speed * DASH_BLOCKED_RATIO:
		_dash_time_left = 0.0
	if _dash_time_left <= 0.0:
		velocity = _dash_direction * minf(movement.dash_exit_speed, movement.dash_speed)


func _update_hook() -> void:
	if state == State.HOOK:
		if not Input.is_action_pressed(&"hook"):
			# Скорость притягивания остаётся в velocity: это и есть инерция при отпускании.
			_hook.release()
			state = State.AIR
	elif Input.is_action_just_pressed(&"hook") and _hook.try_attach():
		state = State.HOOK
		# Хук возвращает прыжок в воздухе, иначе после зацепа на высоте нечем маневрировать.
		_air_jumps_left = movement.air_jumps


func _update_crouch_state() -> void:
	var wants_crouch: bool = Input.is_action_pressed(&"crouch") or state == State.SLIDE
	if wants_crouch:
		_set_crouching(true)
	elif _crouching and _can_stand():
		_set_crouching(false)


func _set_crouching(value: bool) -> void:
	if value == _crouching:
		return
	_crouching = value
	_apply_body_shape()


func _apply_body_shape() -> void:
	var height: float = movement.crouch_height if _crouching else movement.stand_height
	var capsule: CapsuleShape3D = _collision.shape as CapsuleShape3D
	capsule.radius = movement.body_radius
	capsule.height = height
	# Начало координат игрока у ног, поэтому капсула растёт вверх от них.
	_collision.position.y = height * 0.5


## Хватит ли над головой места, чтобы встать (под низкой балкой остаёмся в приседе).
func _can_stand() -> bool:
	var extra_height: float = movement.stand_height - movement.crouch_height
	return not test_move(global_transform, Vector3.UP * extra_height)


func _free_step(delta: float, input: Vector2, wish_dir: Vector3) -> void:
	var on_floor: bool = is_on_floor()
	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var target_speed: float = _target_speed(input)
	if on_floor:
		var acceleration: float = movement.ground_acceleration if wish_dir != Vector3.ZERO else movement.ground_deceleration
		horizontal = horizontal.move_toward(wish_dir * target_speed, acceleration * delta)
	elif wish_dir != Vector3.ZERO:
		# В воздухе управляем направлением, но не набираем скорость сверх прежней: лишнюю скорость
		# не гасим (инерция от подката, хука и спринта сохраняется), а суммарную не повышаем.
		# Без потолка поворот камеры или A/D в полёте накручивали скорость втрое (эффект бхопа).
		var old_speed: float = horizontal.length()
		var speed_along_input: float = horizontal.dot(wish_dir)
		var gain: float = clampf(target_speed - speed_along_input, 0.0, movement.air_acceleration * delta)
		horizontal += wish_dir * gain
		var speed_cap: float = maxf(old_speed, target_speed)
		if horizontal.length() > speed_cap:
			horizontal = horizontal.normalized() * speed_cap
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not on_floor:
		velocity.y = maxf(velocity.y - movement.gravity * delta, -movement.max_fall_speed)
	if Input.is_action_just_pressed(&"jump"):
		_try_jump(on_floor)


func _target_speed(input: Vector2) -> float:
	if _crouching:
		return movement.crouch_speed
	if Input.is_action_pressed(&"sprint") and input.y < -FORWARD_INPUT_THRESHOLD:
		return movement.sprint_speed
	return movement.walk_speed


func _try_jump(on_floor: bool) -> void:
	if on_floor:
		velocity.y = _jump_velocity(movement.jump_height)
	elif _air_jumps_left > 0:
		_air_jumps_left -= 1
		velocity.y = _jump_velocity(movement.air_jump_height)


# Из высоты прыжка и гравитации: v = sqrt(2·g·h). Так автор правит высоту в метрах, а не скорость.
func _jump_velocity(height: float) -> float:
	return sqrt(2.0 * movement.gravity * height)


func _start_slide() -> void:
	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var speed: float = horizontal.length()
	if speed < 0.001:
		return
	# Рывок поднимает скорость до потолка. Если игрок уже быстрее потолка (хук, подкат с разгона),
	# скорость не режем, она просто затухает.
	var boosted: float = speed if speed >= movement.slide_max_speed else minf(speed * movement.slide_start_boost, movement.slide_max_speed)
	horizontal = horizontal / speed * boosted
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	state = State.SLIDE
	_set_crouching(true)


func _slide_step(delta: float, input: Vector2, wish_dir: Vector3) -> void:
	# Выходы из подката: сошли с земли, отпустили Ctrl или скорость упала до скорости приседания.
	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var speed: float = horizontal.length()
	if not is_on_floor():
		state = State.AIR
		_free_step(delta, input, wish_dir)
		return
	if not Input.is_action_pressed(&"crouch") or speed <= movement.crouch_speed:
		state = State.GROUND
		_free_step(delta, input, wish_dir)
		return
	if Input.is_action_just_pressed(&"jump"):
		# Скорость не трогаем: прыжок из подката сохраняет инерцию.
		state = State.AIR
		_air_jumps_left = movement.air_jumps
		velocity.y = _jump_velocity(movement.jump_height)
		return
	var direction: Vector3 = horizontal / speed
	# Доворот берём из get_axis, а не из input.x: get_vector нормализует диагональ, и при зажатых
	# W+D доворот был бы в 1/√2 раза слабее, чем указано в настройках.
	var steer: float = Input.get_axis(&"move_left", &"move_right")
	# Вправо = по часовой стрелке при взгляде сверху, а это отрицательный угол вокруг оси Y.
	direction = direction.rotated(Vector3.UP, -steer * deg_to_rad(movement.slide_steer_degrees_per_second) * delta)
	speed = maxf(speed - movement.slide_deceleration * delta, 0.0)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed


func _after_move() -> void:
	var on_floor: bool = is_on_floor()
	if state == State.AIR and on_floor:
		_land()
	elif state == State.GROUND and not on_floor:
		state = State.AIR


func _land() -> void:
	state = State.GROUND
	_air_jumps_left = movement.air_jumps
	# Ctrl зажат в момент приземления на скорости: сразу подкат (как slide-hop).
	if Input.is_action_pressed(&"crouch") and get_horizontal_speed() >= movement.slide_min_speed:
		_start_slide()


func _update_eye_height(delta: float) -> void:
	var target: float = movement.stand_eye_height
	if state == State.SLIDE:
		target = movement.slide_eye_height
	elif _crouching:
		target = movement.crouch_eye_height
	_head.position.y = move_toward(_head.position.y, target, movement.eye_height_speed * delta)
