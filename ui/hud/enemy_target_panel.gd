class_name EnemyTargetPanel
extends Control
## Плашка цели над прицелом (срез 7в, №86, по референсам Borderlands 4 из 11-UI-design): когда прицел наведён на живого врага,
## над центром экрана видны полоска его здоровья в скобках, слева уровень цифрой и под полоской название. Над самим врагом в мире
## ничего не висит. Когда прицел ушёл, плашка гаснет не сразу (LINGER_TIME), чтобы не мигать при быстром перенаведении.
## Врага определяет луч из центра камеры по миру и врагам: стена перед врагом закрывает его.

## Дальность луча наведения и маска слоёв: 1 «мир» и 4 «враги».
const AIM_RANGE: float = 400.0
const AIM_MASK: int = 5
## Сколько секунд плашка остаётся после ухода прицела с врага.
const LINGER_TIME: float = 0.45
## Размеры в единицах эталона 1080p: полоска и расстояние от центра экрана до центра полоски.
const PANEL_SIZE: Vector2 = Vector2(440.0, 78.0)
const BAR_SIZE: Vector2 = Vector2(200.0, 14.0)
const BAR_ABOVE_CENTER: float = 175.0
## Как быстро полоска догоняет здоровье (1/с): урон виден плавным уходом.
const FILL_SPEED: float = 14.0
const FILL_COLOR: Color = Color(0.88, 0.26, 0.22)
## Враг под барьером щитовика: полоска фиолетовая, сразу видно, что урон по нему почти не идёт.
const WARD_COLOR: Color = Color(0.62, 0.52, 1.0)
const BACK_COLOR: Color = Color(0.04, 0.04, 0.05, 0.85)
## Щит врага (№93): тонкая синяя полоса над полоской здоровья.
const SHIELD_COLOR: Color = Color(0.4, 0.7, 1.0)
const SHIELD_BAR_HEIGHT: float = 6.0
const BRACKET_COLOR: Color = Color(1.0, 1.0, 1.0, 0.9)

var _player: Player
var _target: Enemy
var _linger_left: float = 0.0
var _shown_ratio: float = 1.0
var _shown_shield_ratio: float = 0.0
var _warded: bool = false
var _level_label: Label
var _name_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	offset_left = -PANEL_SIZE.x * 0.5
	offset_right = PANEL_SIZE.x * 0.5
	offset_top = -BAR_ABOVE_CENTER - BAR_SIZE.y * 0.5 - 6.0
	offset_bottom = offset_top + PANEL_SIZE.y
	var bar: Rect2 = _bar_rect()
	_level_label = _make_label(26, HORIZONTAL_ALIGNMENT_RIGHT)
	_level_label.position = Vector2(0.0, bar.position.y - 7.0)
	_level_label.size = Vector2(bar.position.x - 10.0, 30.0)
	_name_label = _make_label(24, HORIZONTAL_ALIGNMENT_CENTER)
	_name_label.position = Vector2(0.0, bar.end.y + 6.0)
	_name_label.size = Vector2(PANEL_SIZE.x, 30.0)
	visible = false


func bind(player: Player) -> void:
	_player = player


func _process(delta: float) -> void:
	if _player == null or _player.is_dead or get_tree().paused:
		visible = false
		_target = null
		_linger_left = 0.0
		return
	var aimed: Enemy = _aimed_enemy()
	if aimed != null:
		if aimed != _target:
			_target = aimed
			_shown_ratio = _health_ratio(aimed)
			_shown_shield_ratio = _shield_ratio(aimed)
			_name_label.text = aimed.get_display_name()
			_level_label.text = str(aimed.level)
			_level_label.add_theme_color_override("font_color", _level_color(aimed.level))
		_linger_left = LINGER_TIME
	else:
		_linger_left = maxf(_linger_left - delta, 0.0)
	if _target != null and (not is_instance_valid(_target) or _target.is_dead):
		_target = null
	visible = _target != null and _linger_left > 0.0
	if not visible:
		return
	_shown_ratio = lerpf(_shown_ratio, _health_ratio(_target), 1.0 - exp(-FILL_SPEED * delta))
	_shown_shield_ratio = lerpf(_shown_shield_ratio, _shield_ratio(_target), 1.0 - exp(-FILL_SPEED * delta))
	_warded = _target.get_damage_taken_multiplier() < 1.0
	queue_redraw()


func _draw() -> void:
	var bar: Rect2 = _bar_rect()
	draw_rect(bar, BACK_COLOR)
	var fill: Rect2 = Rect2(bar.position + Vector2(2.0, 2.0), Vector2((bar.size.x - 4.0) * clampf(_shown_ratio, 0.0, 1.0), bar.size.y - 4.0))
	draw_rect(fill, WARD_COLOR if _warded else FILL_COLOR)
	if _target != null and is_instance_valid(_target) and _target.max_shield > 0.0:
		var shield_rect: Rect2 = Rect2(bar.position + Vector2(0.0, -SHIELD_BAR_HEIGHT - 3.0), Vector2(bar.size.x, SHIELD_BAR_HEIGHT))
		draw_rect(shield_rect, BACK_COLOR)
		draw_rect(Rect2(shield_rect.position + Vector2(1.0, 1.0), Vector2((shield_rect.size.x - 2.0) * clampf(_shown_shield_ratio, 0.0, 1.0), shield_rect.size.y - 2.0)), SHIELD_COLOR)
	# Скобки по краям полоски, как на референсе.
	var notch: float = 5.0
	var left: float = bar.position.x - 3.0
	var right: float = bar.end.x + 3.0
	draw_polyline(PackedVector2Array([Vector2(left + notch, bar.position.y - 2.0), Vector2(left, bar.position.y - 2.0), Vector2(left, bar.end.y + 2.0), Vector2(left + notch, bar.end.y + 2.0)]), BRACKET_COLOR, 2.0)
	draw_polyline(PackedVector2Array([Vector2(right - notch, bar.position.y - 2.0), Vector2(right, bar.position.y - 2.0), Vector2(right, bar.end.y + 2.0), Vector2(right - notch, bar.end.y + 2.0)]), BRACKET_COLOR, 2.0)


## Плашка сейчас показана.
func is_showing() -> bool:
	return visible


func get_target() -> Enemy:
	return _target if _target != null and is_instance_valid(_target) else null


func get_name_text() -> String:
	return _name_label.text


func get_level_text() -> String:
	return _level_label.text


## Заполнение полоски 0..1, как оно сейчас нарисовано.
func get_fill_ratio() -> float:
	return _shown_ratio


## Заполнение полосы щита 0..1 (0, если щита у цели нет).
func get_shield_fill_ratio() -> float:
	return _shown_shield_ratio


func _bar_rect() -> Rect2:
	return Rect2(Vector2((PANEL_SIZE.x - BAR_SIZE.x) * 0.5, 8.0), BAR_SIZE)


func _make_label(font_size: int, alignment: HorizontalAlignment) -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 7)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _aimed_enemy() -> Enemy:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return null
	var from: Vector3 = camera.global_position
	var to: Vector3 = from + (-camera.global_basis.z) * AIM_RANGE
	var hit: Dictionary = _player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, AIM_MASK))
	if hit.is_empty():
		return null
	var enemy: Enemy = hit["collider"] as Enemy
	return enemy if enemy != null and not enemy.is_dead else null


func _health_ratio(enemy: Enemy) -> float:
	return clampf(enemy.health / maxf(enemy.get_max_health(), 0.001), 0.0, 1.0)


func _shield_ratio(enemy: Enemy) -> float:
	return clampf(enemy.shield / enemy.max_shield, 0.0, 1.0) if enemy.max_shield > 0.0 else 0.0


# Белый: не выше уровня игрока, жёлтый: на 1-2 выше, красный: на 3 и больше.
func _level_color(enemy_level: int) -> Color:
	var gap: int = enemy_level - Progress.level
	if gap >= 3:
		return Color(1.0, 0.35, 0.3)
	if gap >= 1:
		return Color(1.0, 0.85, 0.3)
	return Color.WHITE
