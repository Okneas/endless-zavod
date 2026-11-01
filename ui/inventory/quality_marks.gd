class_name QualityMarks
extends Control
## Метки качества в шапке карточки (11-UI-design, №53): по квадрату на ступень шкалы, цвет ступени.
## В ячейке сетки те же метки рисуются в углу.

const MARK: float = 12.0
const GAP: float = 5.0

var _count: int = 0
var _color: Color = Color.WHITE


func set_marks(count: int, color: Color) -> void:
	_count = count
	_color = color
	custom_minimum_size = Vector2(float(count) * (MARK + GAP), MARK + 3.0)
	queue_redraw()


func _draw() -> void:
	for i: int in _count:
		draw_rect(Rect2(float(i) * (MARK + GAP), 1.5, MARK, MARK), _color)
