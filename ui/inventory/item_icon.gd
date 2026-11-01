class_name ItemIcon
extends RefCounted
## Значок любого предмета инвентаря: оружие рисуется силуэтом, прочие предметы цветным квадратом
## (у лечащих белый крест). Рисуется кодом.


## Граната (№92): шар цветом типа с кольцом цвета качества и колпачком.
static func draw_grenade(canvas: CanvasItem, rect: Rect2, grenade: GrenadeInstance, alpha: float = 1.0) -> void:
	var color: Color = grenade.definition.color
	color.a *= alpha
	var edge: Color = grenade.get_quality_color()
	edge.a *= alpha
	var c: Vector2 = rect.get_center() + Vector2(0.0, rect.size.y * 0.06)
	var r: float = minf(rect.size.x, rect.size.y) * 0.3
	canvas.draw_circle(c, r, color)
	canvas.draw_arc(c, r, 0.0, TAU, 28, edge, 3.0)
	canvas.draw_rect(Rect2(c + Vector2(-r * 0.32, -r * 1.28), Vector2(r * 0.64, r * 0.4)), edge)
	canvas.draw_circle(c + Vector2(-r * 0.3, -r * 0.3), r * 0.22, Color(1.0, 1.0, 1.0, 0.35 * alpha))


## Щит (№93): геральдический щит цветом типа с рамкой цвета качества.
static func draw_shield(canvas: CanvasItem, rect: Rect2, shield: ShieldInstance, alpha: float = 1.0) -> void:
	var color: Color = shield.definition.color
	color.a *= alpha
	var edge: Color = shield.get_quality_color()
	edge.a *= alpha
	var c: Vector2 = rect.get_center()
	var w: float = rect.size.x * 0.32
	var h: float = rect.size.y * 0.38
	var outline: PackedVector2Array = PackedVector2Array([c + Vector2(-w, -h), c + Vector2(w, -h), c + Vector2(w, h * 0.15), c + Vector2(0.0, h), c + Vector2(-w, h * 0.15), c + Vector2(-w, -h)])
	canvas.draw_colored_polygon(outline.slice(0, 5), color)
	canvas.draw_polyline(outline, edge, 3.0)
	canvas.draw_line(c + Vector2(0.0, -h), c + Vector2(0.0, h), Color(1.0, 1.0, 1.0, 0.25 * alpha), 2.0)


static func draw(canvas: CanvasItem, rect: Rect2, item: InventoryItem, alpha: float = 1.0) -> void:
	if item.shield != null:
		draw_shield(canvas, rect, item.shield, alpha)
		return
	if item.grenade != null:
		draw_grenade(canvas, rect, item.grenade, alpha)
		return
	if item.weapon != null:
		WeaponIcon.draw(canvas, rect, item.weapon, alpha)
		return
	if item.part != null:
		_draw_part(canvas, rect, item.part, item.get_quality_color(), alpha)
		return
	var color: Color = item.definition.icon_color
	color.a *= alpha
	var box: Rect2 = Rect2(rect.get_center() - rect.size * 0.3, rect.size * 0.6)
	canvas.draw_rect(box, color)
	if item.definition.heal_amount > 0.0:
		var center: Vector2 = rect.get_center()
		var arm: float = rect.size.x * 0.18
		var thickness: float = rect.size.x * 0.08
		var cross: Color = Color(1.0, 1.0, 1.0, alpha)
		canvas.draw_rect(Rect2(center - Vector2(arm, thickness * 0.5), Vector2(arm * 2.0, thickness)), cross)
		canvas.draw_rect(Rect2(center - Vector2(thickness * 0.5, arm), Vector2(thickness, arm * 2.0)), cross)


# Деталь оружия: силуэт по типу детали цветом производителя (временный значок, без финального арта).
static func _draw_part(canvas: CanvasItem, rect: Rect2, part: PartInstance, quality_color: Color, alpha: float) -> void:
	var color: Color = part.part.manufacturer.color if part.part.manufacturer != null else quality_color
	color.a *= alpha
	var edge: Color = quality_color
	edge.a *= alpha
	var c: Vector2 = rect.get_center()
	var w: float = rect.size.x
	var h: float = rect.size.y
	match part.part.part_type:
		WeaponPart.PartType.BODY:
			canvas.draw_rect(Rect2(c + Vector2(-w * 0.34, -h * 0.14), Vector2(w * 0.68, h * 0.28)), color)
			canvas.draw_rect(Rect2(c + Vector2(-w * 0.34, -h * 0.14), Vector2(w * 0.68, h * 0.28)), edge, false, 2.0)
		WeaponPart.PartType.BARREL:
			canvas.draw_rect(Rect2(c + Vector2(-w * 0.4, -h * 0.07), Vector2(w * 0.8, h * 0.14)), color)
			canvas.draw_rect(Rect2(c + Vector2(-w * 0.4, -h * 0.12), Vector2(w * 0.1, h * 0.24)), edge)
		WeaponPart.PartType.GRIP:
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-w * 0.1, -h * 0.34), c + Vector2(w * 0.12, -h * 0.34), c + Vector2(w * 0.2, h * 0.34), c + Vector2(-w * 0.02, h * 0.34)]), color)
		WeaponPart.PartType.MAGAZINE:
			canvas.draw_rect(Rect2(c + Vector2(-w * 0.12, -h * 0.34), Vector2(w * 0.24, h * 0.68)), color)
			canvas.draw_rect(Rect2(c + Vector2(-w * 0.12, -h * 0.34), Vector2(w * 0.24, h * 0.1)), edge)
		WeaponPart.PartType.STOCK:
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-w * 0.38, -h * 0.16), c + Vector2(w * 0.3, -h * 0.1), c + Vector2(w * 0.3, h * 0.1), c + Vector2(-w * 0.38, h * 0.24)]), color)
		_:
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -h * 0.3), c + Vector2(w * 0.22, 0.0), c + Vector2(0.0, h * 0.3), c + Vector2(-w * 0.22, 0.0)]), color)
			canvas.draw_circle(c, minf(w, h) * 0.07, edge)
