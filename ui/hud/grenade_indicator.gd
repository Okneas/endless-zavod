class_name GrenadeIndicator
extends Control
## Значок гранаты в углу экрана (№92, 11-UI-design: «значки гранаты» справа внизу): шар цветом типа, по кругу заполняется перезарядка,
## готовая граната светится рамкой, под значком клавиша броска. Берёт гранату из слота (Inventory.grenade), сама ничего не хранит.

const SIZE: float = 84.0
const RING_WIDTH: float = 7.0
const READY_COLOR: Color = Color(1.0, 0.95, 0.6)
const BACKGROUND: Color = Color(0.05, 0.05, 0.07, 0.75)


func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE + 24.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var grenade: GrenadeInstance = Inventory.grenade
	var center: Vector2 = Vector2(SIZE * 0.5, SIZE * 0.5)
	draw_circle(center, SIZE * 0.5 - 2.0, BACKGROUND)
	var font: Font = ThemeDB.fallback_font
	if grenade == null:
		draw_arc(center, SIZE * 0.5 - 6.0, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, 0.18), RING_WIDTH * 0.5)
		return
	var cooldown: float = grenade.compute_stats().cooldown
	var progress: float = 1.0 if grenade.is_ready() else clampf(1.0 - grenade.cooldown_left / maxf(cooldown, 0.01), 0.0, 1.0)
	var alpha: float = 1.0 if grenade.is_ready() else 0.45
	ItemIcon.draw_grenade(self, Rect2(Vector2(8.0, 8.0), Vector2(SIZE - 16.0, SIZE - 16.0)), grenade, alpha)
	var ring: Color = READY_COLOR if grenade.is_ready() else grenade.definition.color
	draw_arc(center, SIZE * 0.5 - 6.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 40, ring, RING_WIDTH)
	if not grenade.is_ready():
		var seconds: String = "%d" % ceili(grenade.cooldown_left)
		draw_string_outline(font, Vector2(0.0, SIZE * 0.5 + 9.0), seconds, HORIZONTAL_ALIGNMENT_CENTER, SIZE, 26, 5, Color.BLACK)
		draw_string(font, Vector2(0.0, SIZE * 0.5 + 9.0), seconds, HORIZONTAL_ALIGNMENT_CENTER, SIZE, 26, Color.WHITE)
	draw_string(font, Vector2(0.0, SIZE + 20.0), KeyHint.text(&"grenade"), HORIZONTAL_ALIGNMENT_CENTER, SIZE, 20, Color(1.0, 1.0, 1.0, 0.8))
