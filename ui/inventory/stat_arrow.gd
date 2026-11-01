class_name StatArrow
extends Control
## Стрелка сравнения рядом с характеристикой: зелёная вверх, если лучше экипированного, красная вниз, если хуже
## (11-UI-design, режим сравнения). Нулевое направление ничего не рисует.

@export var better_color: Color = Color(0.4, 0.9, 0.45)
@export var worse_color: Color = Color(1.0, 0.4, 0.35)

## 1 лучше, -1 хуже, 0 без стрелки.
var direction: int = 0:
	set(value):
		direction = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(23.0, 23.0)


func _draw() -> void:
	if direction == 0:
		return
	var center: Vector2 = size * 0.5
	var half: float = minf(size.x, size.y) * 0.4
	if direction > 0:
		draw_colored_polygon(PackedVector2Array([center + Vector2(0.0, -half), center + Vector2(half, half), center + Vector2(-half, half)]), better_color)
	else:
		draw_colored_polygon(PackedVector2Array([center + Vector2(0.0, half), center + Vector2(half, -half), center + Vector2(-half, -half)]), worse_color)
