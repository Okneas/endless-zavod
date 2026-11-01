extends Control
## Панель слотов оружия внизу по центру HUD (11-UI-design, №48): четыре слота, у каждого значок оружия и номер.
## Активный слот подсвечен, рамка по качеству. Вне переключения панель полупрозрачная, при смене оружия
## на время становится яркой. Рисуется кодом.

const CELL: float = 64.0
const GAP: float = 8.0
const BACKGROUND: Color = Color(0.06, 0.06, 0.08, 0.7)

var _weapon: Weapon
var _settings: InventorySettings
var _hold: float = 0.0
var _alpha: float = 1.0
var _slot_count: int = 4


func bind(weapon: Weapon, settings: InventorySettings) -> void:
	_weapon = weapon
	_settings = settings
	_slot_count = weapon.slots.size()
	custom_minimum_size = Vector2(float(_slot_count) * CELL + float(_slot_count - 1) * GAP, CELL)
	size = custom_minimum_size
	_alpha = settings.slots_idle_alpha
	weapon.slot_changed.connect(func(_slot: int) -> void: _wake())
	weapon.loadout_changed.connect(_wake)
	queue_redraw()


## Текущая прозрачность панели (для проверок).
func get_alpha() -> float:
	return _alpha


func _wake() -> void:
	_hold = _settings.slots_show_seconds
	queue_redraw()


func _process(delta: float) -> void:
	if _weapon == null:
		return
	_hold = maxf(_hold - delta, 0.0)
	var target: float = 1.0 if _hold > 0.0 else _settings.slots_idle_alpha
	var next: float = move_toward(_alpha, target, delta * 3.0)
	if not is_equal_approx(next, _alpha):
		_alpha = next
		queue_redraw()


func _draw() -> void:
	if _weapon == null:
		return
	var font: Font = ThemeDB.fallback_font
	for i: int in _slot_count:
		var rect: Rect2 = Rect2(float(i) * (CELL + GAP), 0.0, CELL, CELL)
		var instance: WeaponInstance = _weapon.slots[i]
		var active: bool = i == _weapon.active_slot
		var background: Color = BACKGROUND
		background.a *= _alpha
		draw_rect(rect, background)
		var border: Color = Color(1.0, 1.0, 1.0, 0.18)
		if instance != null:
			var scale: QualityScale = instance.settings.quality_scale if instance.settings != null else null
			border = scale.tiers[instance.get_quality()].color if scale != null else Color.WHITE
			WeaponIcon.draw(self, rect.grow(-6.0), instance, _alpha)
		border.a *= _alpha
		draw_rect(rect.grow(-1.0), border, false, 4.0 if active else 2.0)
		if active:
			draw_rect(Rect2(rect.position.x, rect.end.y + 3.0, CELL, 3.0), Color(1.0, 0.9, 0.4, _alpha))
		var number_color: Color = Color(1.0, 1.0, 1.0, _alpha)
		draw_string_outline(font, rect.position + Vector2(5.0, 15.0), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, 4, Color(0.0, 0.0, 0.0, _alpha))
		draw_string(font, rect.position + Vector2(5.0, 15.0), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, number_color)
