class_name WeaponIcon
extends RefCounted
## Значок оружия: боковой силуэт из размеров его частей (вид сбоку, дуло справа). Рисуется кодом, картинок нет.
## Один рисунок на ячейках инвентаря, строках экипировки и панели слотов HUD.

# Запасной силуэт для оружия без данных модели (стартовый пистолет): центр по Z и по Y, длина, высота.
const FALLBACK_BOXES: Array = [
	[0.0, 0.0, 0.26, 0.09, Color(0.45, 0.47, 0.5)],
	[-0.2, 0.02, 0.14, 0.035, Color(0.3, 0.32, 0.36)],
	[0.09, -0.09, 0.06, 0.12, Color(0.35, 0.3, 0.28)],
]


static func draw(canvas: CanvasItem, rect: Rect2, weapon: WeaponInstance, alpha: float = 1.0) -> void:
	var boxes: Array = _boxes(weapon)
	var bounds: Rect2 = boxes[0][0]
	for entry: Array in boxes:
		bounds = bounds.merge(entry[0])
	var factor: float = minf(rect.size.x / bounds.size.x, rect.size.y / bounds.size.y) * 0.85
	var origin: Vector2 = rect.get_center() - bounds.get_center() * factor
	for entry: Array in boxes:
		var box: Rect2 = entry[0]
		var color: Color = entry[1]
		color.a *= alpha
		canvas.draw_rect(Rect2(origin + box.position * factor, box.size * factor), color)


# Прямоугольники вида сбоку: по горизонтали минус Z (дуло справа), по вертикали минус Y.
static func _boxes(weapon: WeaponInstance) -> Array:
	var result: Array = []
	var body: PartInstance = weapon.get_body()
	if body.part.model_size == Vector3.ZERO:
		for entry: Array in FALLBACK_BOXES:
			result.append([Rect2(-entry[0] - entry[2] * 0.5, -entry[1] - entry[3] * 0.5, entry[2], entry[3]), entry[4]])
		return result
	result.append([_side_rect(body.part.model_offset, body.part.model_size), WeaponModelBuilder.part_color(body)])
	for instance: PartInstance in weapon.parts:
		if instance.part.part_type == WeaponPart.PartType.BODY:
			continue
		var mount: Vector3 = _mount(body.part, instance.part.part_type)
		result.append([_side_rect(mount + instance.part.model_offset, instance.part.model_size), WeaponModelBuilder.part_color(instance)])
	return result


static func _side_rect(center: Vector3, size: Vector3) -> Rect2:
	return Rect2(-center.z - size.z * 0.5, -center.y - size.y * 0.5, size.z, size.y)


static func _mount(body: WeaponPart, part_type: WeaponPart.PartType) -> Vector3:
	match part_type:
		WeaponPart.PartType.BARREL:
			return body.mount_barrel
		WeaponPart.PartType.GRIP:
			return body.mount_grip
		WeaponPart.PartType.MAGAZINE:
			return body.mount_magazine
		WeaponPart.PartType.STOCK:
			return body.mount_stock
		WeaponPart.PartType.ACCESSORY:
			return body.mount_accessory
	return Vector3.ZERO
