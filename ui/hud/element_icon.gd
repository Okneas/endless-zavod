class_name ElementIcon
extends Control
## Иконка стихии оружия рядом со счётчиком патронов (11-UI-design, №48). Простые значки, рисуются кодом.
## Без стихии ничего не рисуется.

const COLORS: Dictionary = {
	CombatEnums.Element.ACID: Color(0.55, 1.0, 0.3),
	CombatEnums.Element.ELECTRIC: Color(0.45, 0.75, 1.0),
	CombatEnums.Element.FROST: Color(0.6, 0.95, 1.0),
	CombatEnums.Element.FIRE: Color(1.0, 0.55, 0.2),
}

var element: CombatEnums.Element = CombatEnums.Element.NONE


func set_element(value: CombatEnums.Element) -> void:
	if value != element:
		element = value
		queue_redraw()


func _draw() -> void:
	if element == CombatEnums.Element.NONE:
		return
	var color: Color = COLORS[element]
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.42
	draw_circle(c, r + 3.0, Color(0.0, 0.0, 0.0, 0.55))
	match element:
		CombatEnums.Element.ACID:
			# Капля: круг и острие.
			draw_circle(c + Vector2(0.0, r * 0.25), r * 0.55, color)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -r), c + Vector2(r * 0.5, r * 0.1), c + Vector2(-r * 0.5, r * 0.1)]), color)
		CombatEnums.Element.ELECTRIC:
			draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.2, -r), c + Vector2(-r * 0.6, r * 0.15), c + Vector2(-r * 0.05, r * 0.15), c + Vector2(-r * 0.25, r), c + Vector2(r * 0.6, -r * 0.2), c + Vector2(r * 0.05, -r * 0.2)]), color)
		CombatEnums.Element.FROST:
			for angle: float in [0.0, PI / 3.0, PI * 2.0 / 3.0]:
				var direction: Vector2 = Vector2.from_angle(angle) * r
				draw_line(c - direction, c + direction, color, 2.5, true)
		CombatEnums.Element.FIRE:
			draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -r), c + Vector2(r * 0.65, r * 0.2), c + Vector2(r * 0.3, r), c + Vector2(-r * 0.3, r), c + Vector2(-r * 0.65, r * 0.2), c + Vector2(-r * 0.15, -r * 0.2)]), color)
