extends Control
## Значок денег (монета) рядом со счётчиком вверху слева. Рисуется кодом.

@export var radius: float = 11.0
@export var fill_color: Color = Color(1.0, 0.82, 0.2)
@export var rim_color: Color = Color(0.65, 0.45, 0.05)


func _draw() -> void:
	var center: Vector2 = size * 0.5
	draw_circle(center, radius, rim_color)
	draw_circle(center, radius - 2.5, fill_color)
