class_name FeatureIcon
extends Control
## Значок особенности в списке на карточке (11-UI-design): плитка с условным знаком по виду особенности.
## Стихия показывается значком стихии, остальное рисуется кодом.

const TILE_BACKGROUND: Color = Color(0.1, 0.11, 0.15)
const GLYPH: Color = Color(1.0, 0.9, 0.5)

var _feature: PartFeature


func _init() -> void:
	custom_minimum_size = Vector2(50.0, 50.0)


func set_feature(feature: PartFeature) -> void:
	_feature = feature
	if feature.kind == CombatEnums.FeatureKind.ELEMENT:
		var icon: ElementIcon = ElementIcon.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 5)
		icon.set_element(feature.element)
	queue_redraw()


func _draw() -> void:
	var frame: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(frame, TILE_BACKGROUND)
	draw_rect(frame.grow(-1.0), Color(1.0, 1.0, 1.0, 0.25), false, 2.0)
	if _feature == null:
		return
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.3
	# Толщина линий пропорциональна плитке (30 px было эталоном для 3 px).
	var k: float = minf(size.x, size.y) / 30.0
	match _feature.kind:
		CombatEnums.FeatureKind.STATS:
			draw_rect(Rect2(c.x - r, c.y - 1.5 * k, r * 2.0, 3.0 * k), GLYPH)
			draw_rect(Rect2(c.x - 1.5 * k, c.y - r, 3.0 * k, r * 2.0), GLYPH)
		CombatEnums.FeatureKind.SLIDE_DAMAGE:
			for offset: float in [-r * 0.5, r * 0.5]:
				draw_polyline(PackedVector2Array([Vector2(c.x + offset - r * 0.4, c.y - r), Vector2(c.x + offset + r * 0.4, c.y), Vector2(c.x + offset - r * 0.4, c.y + r)]), GLYPH, 2.5 * k)
		CombatEnums.FeatureKind.AIR_DAMAGE:
			draw_colored_polygon(PackedVector2Array([Vector2(c.x, c.y - r), Vector2(c.x + r, c.y), Vector2(c.x + r * 0.4, c.y), Vector2(c.x + r * 0.4, c.y + r), Vector2(c.x - r * 0.4, c.y + r), Vector2(c.x - r * 0.4, c.y), Vector2(c.x - r, c.y)]), GLYPH)
		CombatEnums.FeatureKind.MELEE_DAMAGE:
			draw_line(c + Vector2(-r, r), c + Vector2(r, -r), GLYPH, 3.0 * k)
			draw_line(c + Vector2(-r * 0.2, -r * 0.4), c + Vector2(r * 0.4, r * 0.2), GLYPH, 2.5 * k)
