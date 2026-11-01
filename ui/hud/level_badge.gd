extends Control
## Круг с уровнем персонажа слева снизу (набросок автора в 11-UI-design: «1 Lvl»).
## По ободу идёт полоска опыта до следующего уровня. Рисуется кодом, картинок нет.

@export var ring_width: float = 5.0
@export var fill_color: Color = Color(0.06, 0.06, 0.08, 0.78)
@export var ring_color: Color = Color(1.0, 1.0, 1.0, 0.22)
@export var xp_color: Color = Color(0.95, 0.8, 0.3, 1.0)
@export var text_color: Color = Color.WHITE
@export var level_font_size: int = 38
@export var caption_font_size: int = 15

var _level: int = 1
var _xp: int = 0
var _to_next: int = 1


func set_state(level: int, xp: int, to_next: int) -> void:
	if level == _level and xp == _xp and to_next == _to_next:
		return
	_level = level
	_xp = xp
	_to_next = to_next
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5 - ring_width
	draw_circle(center, radius, fill_color)
	draw_arc(center, radius, 0.0, TAU, 64, ring_color, ring_width, true)
	if _to_next > 0:
		var ratio: float = clampf(float(_xp) / float(_to_next), 0.0, 1.0)
		if ratio > 0.0:
			draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * ratio, 64, xp_color, ring_width, true)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(0.0, center.y + level_font_size * 0.2), str(_level), HORIZONTAL_ALIGNMENT_CENTER, size.x, level_font_size, text_color)
	draw_string(font, Vector2(0.0, center.y + level_font_size * 0.2 + caption_font_size + 2.0), tr("HUD_LEVEL"), HORIZONTAL_ALIGNMENT_CENTER, size.x, caption_font_size, text_color)
