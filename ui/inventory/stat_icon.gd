class_name StatIcon
extends Control
## Значок основной характеристики на плитке карточки оружия (11-UI-design, эталон: ряд из пяти плиток с иконками).
## Рисуется кодом: урон (звезда), разброс (мишень), темп (три пули), перезарядка (круговая стрелка), магазин (патроны).

enum Kind { DAMAGE, SPREAD, RATE, RELOAD, MAGAZINE }

@export var color: Color = Color(0.92, 0.94, 1.0)

var kind: Kind = Kind.DAMAGE:
	set(value):
		kind = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(33.0, 33.0)


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.45
	# Мелкие размеры (толщина линий, острия) пропорциональны значку.
	var k: float = minf(size.x, size.y) / 20.0
	match kind:
		Kind.DAMAGE:
			var points: PackedVector2Array = PackedVector2Array()
			for i: int in 16:
				var angle: float = TAU * float(i) / 16.0 - PI * 0.5
				points.append(c + Vector2.from_angle(angle) * (r if i % 2 == 0 else r * 0.45))
			draw_colored_polygon(points, color)
		Kind.SPREAD:
			draw_arc(c, r * 0.7, 0.0, TAU, 24, color, 2.0 * k, true)
			draw_circle(c, r * 0.15, color)
			for angle: float in [0.0, PI * 0.5, PI, PI * 1.5]:
				var direction: Vector2 = Vector2.from_angle(angle)
				draw_line(c + direction * r * 0.4, c + direction * r * 1.05, color, 2.0 * k)
		Kind.RATE:
			for i: int in 3:
				var y: float = c.y + (float(i) - 1.0) * r * 0.65
				draw_rect(Rect2(c.x - r, y - 1.5 * k, r * 1.3, 3.0 * k), color)
				draw_colored_polygon(PackedVector2Array([Vector2(c.x + r * 0.35, y - 3.5 * k), Vector2(c.x + r, y), Vector2(c.x + r * 0.35, y + 3.5 * k)]), color)
		Kind.RELOAD:
			var radius: float = r * 0.75
			var end_angle: float = PI * 1.85
			draw_arc(c, radius, PI * 0.35, end_angle, 20, color, 2.5 * k, true)
			var tip: Vector2 = c + Vector2.from_angle(end_angle) * radius
			var tangent: Vector2 = Vector2(-sin(end_angle), cos(end_angle))
			var normal: Vector2 = Vector2(cos(end_angle), sin(end_angle))
			draw_colored_polygon(PackedVector2Array([tip + tangent * 5.0 * k, tip + normal * 4.0 * k, tip - normal * 4.0 * k]), color)
		Kind.MAGAZINE:
			for i: int in 3:
				var x: float = c.x + (float(i) - 1.0) * r * 0.7
				draw_rect(Rect2(x - 2.0 * k, c.y - r * 0.35, 4.0 * k, r * 1.1), color)
				draw_circle(Vector2(x, c.y - r * 0.35), 2.2 * k, color)
