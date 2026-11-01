class_name TargetDummy
extends StaticBody3D
## Мишень-болванка для отладки стрельбы: стоит, получает урон, показывает полоску здоровья,
## число и свой класс, после уничтожения возвращается. Это не враг (враги: enemies/enemy.gd).
## Класс мишени задаётся на узле: так видно, как таблица уязвимостей меняет урон разных типов оружия.

signal died

const BAR_WIDTH: float = 1.0
## Сколько секунд мишень подсвечивается после попадания.
const FLASH_TIME: float = 0.08

## Настройки мишени. Править в Inspector или двойным щелчком по target_dummy.tres.
@export var settings: TargetDummySettings
## Класс врага, которого изображает мишень (для таблицы уязвимостей).
@export var enemy_class: CombatEnums.EnemyClass = CombatEnums.EnemyClass.HEAVY

var health: float = 0.0
var is_dead: bool = false

var _flash_left: float = 0.0
var _material: StandardMaterial3D
var _base_color: Color

@onready var _body: MeshInstance3D = $Body
@onready var _bar_root: Node3D = $HealthBar
@onready var _bar_fill: MeshInstance3D = $HealthBar/Fill
@onready var _value_label: Label3D = $HealthBar/Value


func _ready() -> void:
	assert(settings != null, "У мишени не назначены настройки (TargetDummySettings)")
	# Материал свой у каждой мишени, иначе подсветка одной мигала бы у всех.
	_material = (_body.mesh.material as StandardMaterial3D).duplicate()
	_body.material_override = _material
	_base_color = _material.albedo_color
	health = settings.max_health
	_add_class_label()
	_update_bar()


func _process(delta: float) -> void:
	# Полоска всегда повёрнута к камере, но не наклоняется вместе с ней.
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		var to_camera: Vector3 = camera.global_position - _bar_root.global_position
		to_camera.y = 0.0
		if to_camera.length() > 0.01:
			_bar_root.global_transform = Transform3D(Basis.looking_at(-to_camera.normalized(), Vector3.UP), _bar_root.global_position)
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
		_material.albedo_color = _base_color.lerp(Color.WHITE, _flash_left / FLASH_TIME)


## Получить урон. Возвращает true, если мишень уничтожена этим попаданием.
func take_hit(info: DamageInfo) -> bool:
	if is_dead:
		return false
	var amount: float = info.amount
	if info.apply_vulnerability:
		amount *= Config.data.vulnerabilities.get_multiplier(enemy_class, info.weapon_type)
	health = maxf(health - amount, 0.0)
	_flash_left = FLASH_TIME
	DamageNumber.spawn_hit(get_parent(), info, amount)
	_update_bar()
	if health <= 0.0:
		_die()
		return true
	return false


func _die() -> void:
	is_dead = true
	visible = false
	set_deferred("collision_layer", 0)
	died.emit()
	get_tree().create_timer(settings.respawn_time).timeout.connect(_respawn)


func _respawn() -> void:
	is_dead = false
	health = settings.max_health
	visible = true
	collision_layer = 4
	_update_bar()


func _update_bar() -> void:
	var ratio: float = clampf(health / settings.max_health, 0.0, 1.0)
	_bar_fill.scale.x = maxf(ratio, 0.001)
	# Полоска убывает справа налево: левый край остаётся на месте.
	_bar_fill.position.x = -(1.0 - ratio) * 0.5 * BAR_WIDTH
	_value_label.text = str(ceili(health))


# Название класса под числом здоровья: по нему видно, какую уязвимость проверяет мишень.
func _add_class_label() -> void:
	var label: Label3D = Label3D.new()
	label.name = "ClassLabel"
	label.text = tr("ENEMY_CLASS_" + CombatEnums.EnemyClass.keys()[enemy_class])
	label.pixel_size = 0.005
	label.font_size = 36
	label.outline_size = 10
	label.modulate = Color(1.0, 0.9, 0.5)
	label.position = Vector3(0.0, 0.5, 0.0)
	_bar_root.add_child(label)
