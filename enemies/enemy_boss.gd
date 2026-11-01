class_name EnemyBoss
extends EnemyChaser
## Босс отдела (№82): бронированный преследователь. Идёт к игроку по навигации и бьёт вплотную (как обычный преследующий),
## а раз в shockwave_interval замахивается и бьёт ударной волной по земле: кольцо расходится от босса со скоростью
## shockwave_speed, задевает игрока, пока ступни ниже shockwave_height над землёй (надо прыгнуть). На доле здоровья
## phase2_health_fraction начинается вторая фаза: босс быстрее, волны чаще, зовёт приспешников (summon_requested, их ставит
## контроллер комнаты на свободные места). Мини-босс шлюза (элитный враг) это не он, а обычный EnemyChaser с другими числами.

## Босс просит поставить приспешников (сцену и число берёт контроллер комнаты).
signal summon_requested(scene: PackedScene, count: int)
signal phase_changed(phase: int)
signal shockwave_launched

const WAVE_COLOR: Color = Color(1.0, 0.55, 0.15)
const WINDUP_FLASH: Color = Color(1.0, 0.9, 0.6)

var phase: int = 1
## Кольцо идёт: радиус (-1 — волны нет), откуда началось, задело ли оно уже игрока.
var wave_radius: float = -1.0

var _cooldown_left: float = 0.0
var _windup_left: float = -1.0
var _wave_origin: Vector3 = Vector3.ZERO
var _wave_hit: bool = false
var _wave_visual: MeshInstance3D


func _ready() -> void:
	super._ready()
	_cooldown_left = settings.shockwave_interval


func _behavior(delta: float, player: Player) -> void:
	_update_phase()
	_update_shockwave(delta, player)
	super._behavior(delta, player)


func _exit_tree() -> void:
	_clear_visual()


func _update_phase() -> void:
	if phase == 1 and settings.phase2_health_fraction > 0.0 and health <= get_max_health() * settings.phase2_health_fraction:
		phase = 2
		speed_multiplier = settings.phase2_speed_multiplier
		phase_changed.emit(phase)
		if settings.summon_scene != null and settings.summon_count > 0:
			summon_requested.emit(settings.summon_scene, settings.summon_count)


func _update_shockwave(delta: float, player: Player) -> void:
	if wave_radius >= 0.0:
		_advance_wave(delta, player)
	if _windup_left > 0.0:
		_windup_left -= delta
		movement_locked = true
		_body.scale = Vector3.ONE * (1.0 + 0.08 * sin(_windup_left * 30.0))
		if _windup_left <= 0.0:
			movement_locked = false
			_body.scale = Vector3.ONE
			_launch_wave()
		return
	if _cooldown_left > 0.0:
		_cooldown_left -= delta
		return
	if player != null and is_on_floor() and _flat_to(player).length() <= settings.shockwave_radius and wave_radius < 0.0:
		_windup_left = maxf(settings.shockwave_windup, 0.01)


func _launch_wave() -> void:
	wave_radius = 0.0
	_wave_origin = global_position
	_wave_hit = false
	_cooldown_left = settings.shockwave_interval * (settings.phase2_interval_multiplier if phase == 2 else 1.0)
	_make_visual()
	shockwave_launched.emit()


func _advance_wave(delta: float, player: Player) -> void:
	wave_radius += settings.shockwave_speed * delta
	if _wave_visual != null:
		_wave_visual.scale = Vector3(wave_radius, 0.3, wave_radius)
	if player != null and not _wave_hit:
		var flat: float = Vector2(player.global_position.x - _wave_origin.x, player.global_position.z - _wave_origin.z).length()
		var reach: float = settings.shockwave_thickness * 0.5 + 0.4
		if absf(flat - wave_radius) <= reach and player.global_position.y - _wave_origin.y < settings.shockwave_height:
			_wave_hit = true
			player.take_damage(settings.shockwave_damage * damage_scale, _wave_origin)
	if wave_radius >= settings.shockwave_radius:
		wave_radius = -1.0
		_clear_visual()


func _make_visual() -> void:
	_clear_visual()
	_wave_visual = MeshInstance3D.new()
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = 0.94
	mesh.outer_radius = 1.0
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = WAVE_COLOR
	mesh.material = material
	_wave_visual.mesh = mesh
	_wave_visual.top_level = true
	add_child(_wave_visual)
	_wave_visual.global_position = _wave_origin + Vector3(0.0, 0.15, 0.0)
	_wave_visual.scale = Vector3(0.01, 0.3, 0.01)


func _clear_visual() -> void:
	if _wave_visual != null and is_instance_valid(_wave_visual):
		_wave_visual.queue_free()
	_wave_visual = null
