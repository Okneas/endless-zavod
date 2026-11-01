class_name ItemCell
extends Control
## Ячейка сетки инвентаря (11-UI-design): значок предмета, рамка по качеству, метки качества в верхнем углу,
## уровень слева внизу (красный, если выше уровня персонажа), число штук справа внизу у стопки.
## Наведение мыши показывает карточку (её ведёт экран инвентаря), ячейка при этом подсвечивается.
## Размеры заданы в единицах эталона 1920 x 1080 (№78).

## Сторона квадратной ячейки.
const SIZE: float = 128.0
const FONT_SIZE: int = 25
const BACKGROUND: Color = Color(0.07, 0.07, 0.09, 0.92)
const EMPTY_BORDER: Color = Color(1.0, 1.0, 1.0, 0.12)
const TOO_HIGH_COLOR: Color = Color(1.0, 0.35, 0.3)

var item: InventoryItem
## Над ячейкой курсор мыши: выставляет экран инвентаря.
var hovered: bool = false:
	set(value):
		hovered = value
		queue_redraw()

## Отмечена в оплату (режим оплаты лутом, срез 7).
var marked: bool = false:
	set(value):
		marked = value
		queue_redraw()

var _player_level: int = 1


func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)


func set_item(p_item: InventoryItem, player_level: int) -> void:
	item = p_item
	_player_level = player_level
	queue_redraw()


func _draw() -> void:
	var frame: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(frame, BACKGROUND)
	if item == null:
		draw_rect(frame, EMPTY_BORDER, false, 3.0)
		return
	var color: Color = item.get_quality_color()
	ItemIcon.draw(self, frame.grow(-10.0), item)
	if hovered:
		draw_rect(frame, Color(1.0, 1.0, 1.0, 0.1))
	draw_rect(frame.grow(-2.0), color, false, 6.0 if hovered else 3.0)
	if marked:
		draw_rect(frame, Color(0.35, 1.0, 0.45, 0.28))
		draw_rect(frame.grow(-5.0), Color(0.4, 1.0, 0.5), false, 5.0)
	var font: Font = ThemeDB.fallback_font
	if item.is_weapon() or item.is_part():
		# Метки качества: по штриху на ступень в левом верхнем углу.
		for i: int in item.get_quality() + 1:
			draw_rect(Rect2(9.0 + float(i) * 10.0, 9.0, 7.0, 7.0), color)
	if item.is_weapon():
		var level_color: Color = TOO_HIGH_COLOR if item.get_level() > _player_level else Color.WHITE
		_text(font, Vector2(9.0, size.y - 9.0), str(item.get_level()), level_color, HORIZONTAL_ALIGNMENT_LEFT)
	if item.count > 1:
		_text(font, Vector2(size.x - 9.0, size.y - 9.0), str(item.count), Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)


func _text(font: Font, position: Vector2, text: String, color: Color, alignment: HorizontalAlignment) -> void:
	var origin: Vector2 = position
	if alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		origin.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, 6, Color.BLACK)
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, color)
