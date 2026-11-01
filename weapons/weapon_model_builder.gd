class_name WeaponModelBuilder
extends RefCounted
## Сборка модели оружия из частей (09-tech-godot): плейсхолдеры из примитивов. Корпус задаёт точки крепления
## и прицел, остальные части ставятся на эти точки. Размеры и смещения лежат в данных части, цвет
## берётся у производителя. Настоящие модели позже заменят коробки, точки крепления останутся теми же.

## Цвета стихий на модели аксессуара.
const ELEMENT_COLORS: Dictionary = {
	CombatEnums.Element.ACID: Color(0.55, 1.0, 0.3),
	CombatEnums.Element.ELECTRIC: Color(0.45, 0.75, 1.0),
	CombatEnums.Element.FROST: Color(0.6, 0.95, 1.0),
	CombatEnums.Element.FIRE: Color(1.0, 0.55, 0.2),
}
const NEUTRAL_COLOR: Color = Color(0.5, 0.5, 0.55)
const DARK_METAL: Color = Color(0.2, 0.21, 0.24)
const SIGHT_COLOR: Color = Color(0.1, 0.1, 0.12)
## Размеры механических прицелов (как у первой модели пистолета).
const REAR_SIGHT_SIZE: Vector3 = Vector3(0.012, 0.022, 0.016)
const FRONT_SIGHT_SIZE: Vector3 = Vector3(0.01, 0.03, 0.014)
## Оптика: рамка вокруг линии прицела (внутри пусто, чтобы смотреть сквозь неё).
const OPTIC_HALF: float = 0.02
const OPTIC_FRAME: float = 0.006
const OPTIC_LENGTH: float = 0.09


## Результат сборки: корень с коробками, точка дула и точка прицела в координатах модели.
## У парного оружия (акимбо) есть второе дуло: выстрелы идут из него и из первого по очереди.
class Result extends RefCounted:
	var root: Node3D
	var muzzle: Vector3 = Vector3.ZERO
	var aim_anchor: Vector3 = Vector3.ZERO
	var has_second: bool = false
	var second_muzzle: Vector3 = Vector3.ZERO


static func build(instance: WeaponInstance) -> Result:
	var result: Result = Result.new()
	var root: Node3D = Node3D.new()
	root.name = "Generated"
	result.root = root
	var body: WeaponPart = instance.get_body().part
	result.aim_anchor = instance.get_aim_anchor()
	if body.second_model_offset != Vector3.ZERO:
		# Парное оружие (акимбо): два одинаковых ствола с одинаковыми прицелами, правый First и левый Second.
		var first: Node3D = Node3D.new()
		first.name = "First"
		root.add_child(first)
		result.muzzle = _add_complete_gun(first, instance, result.aim_anchor)
		var second: Node3D = Node3D.new()
		second.name = "Second"
		second.position = body.second_model_offset
		root.add_child(second)
		_add_complete_gun(second, instance, result.aim_anchor)
		result.has_second = true
		result.second_muzzle = result.muzzle + body.second_model_offset
	else:
		result.muzzle = _add_complete_gun(root, instance, result.aim_anchor)
	return result


# Ствол целиком: части на корпусе и прицел (целик с мушкой или оптика). Возвращает точку дула.
static func _add_complete_gun(parent: Node3D, instance: WeaponInstance, anchor: Vector3) -> Vector3:
	var muzzle: Vector3 = _add_gun(parent, instance)
	var body: WeaponPart = instance.get_body().part
	if instance.get_sight() == CombatEnums.SightType.OPTIC:
		_add_optic(parent, body, anchor)
	else:
		_add_iron_sights(parent, body, anchor, muzzle)
	return muzzle


# Корпус и остальные части на точках крепления корпуса. Возвращает точку дула: передний край ствола.
static func _add_gun(parent: Node3D, instance: WeaponInstance) -> Vector3:
	var body_instance: PartInstance = instance.get_body()
	var body: WeaponPart = body_instance.part
	_add_box(parent, "Body", body.model_size, body.model_offset, _part_color(body_instance))
	var barrel_length: float = 0.0
	for part_instance: PartInstance in instance.parts:
		var part: WeaponPart = part_instance.part
		if part.part_type == WeaponPart.PartType.BODY:
			continue
		var mount: Vector3 = _mount(body, part.part_type)
		_add_box(parent, str(WeaponPart.PartType.keys()[part.part_type]).capitalize(), part.model_size, mount + part.model_offset, _part_color(part_instance))
		if part.part_type == WeaponPart.PartType.BARREL:
			barrel_length = part.model_size.z
	return body.mount_barrel + Vector3(0.0, 0.0, -barrel_length)


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


# Целик и мушка: вырез между двумя стойками и мушка на одной линии с точкой прицела.
static func _add_iron_sights(root: Node3D, body: WeaponPart, anchor: Vector3, muzzle: Vector3) -> void:
	_add_box(root, "RearSightLeft", REAR_SIGHT_SIZE, anchor + Vector3(-0.014, -0.006, 0.0), SIGHT_COLOR)
	_add_box(root, "RearSightRight", REAR_SIGHT_SIZE, anchor + Vector3(0.014, -0.006, 0.0), SIGHT_COLOR)
	var front: Vector3 = Vector3(anchor.x, anchor.y - 0.01, muzzle.z + 0.04)
	_add_box(root, "FrontSight", FRONT_SIGHT_SIZE, front, SIGHT_COLOR)
	# Стойка мушки до ствола, чтобы она не висела в воздухе над низким стволом.
	var base_y: float = body.mount_barrel.y + 0.02
	var gap: float = (front.y - FRONT_SIGHT_SIZE.y * 0.5) - base_y
	if gap > 0.002:
		_add_box(root, "FrontSightPost", Vector3(0.008, gap, 0.01), Vector3(front.x, base_y + gap * 0.5, front.z), SIGHT_COLOR)


# Оптика: четыре планки рамки вокруг линии прицела и стойка к корпусу. Центр свободен.
static func _add_optic(root: Node3D, body: WeaponPart, anchor: Vector3) -> void:
	var frame: Vector3 = Vector3(OPTIC_HALF * 2.0 + OPTIC_FRAME, OPTIC_FRAME, OPTIC_LENGTH)
	_add_box(root, "OpticTop", frame, anchor + Vector3(0.0, OPTIC_HALF, 0.0), SIGHT_COLOR)
	_add_box(root, "OpticBottom", frame, anchor + Vector3(0.0, -OPTIC_HALF, 0.0), SIGHT_COLOR)
	var side: Vector3 = Vector3(OPTIC_FRAME, OPTIC_HALF * 2.0 + OPTIC_FRAME, OPTIC_LENGTH)
	_add_box(root, "OpticLeft", side, anchor + Vector3(-OPTIC_HALF, 0.0, 0.0), SIGHT_COLOR)
	_add_box(root, "OpticRight", side, anchor + Vector3(OPTIC_HALF, 0.0, 0.0), SIGHT_COLOR)
	var top: float = body.model_offset.y + body.model_size.y * 0.5
	var stand: float = (anchor.y - OPTIC_HALF) - top
	if stand > 0.002:
		_add_box(root, "OpticStand", Vector3(0.02, stand, 0.04), Vector3(anchor.x, top + stand * 0.5, anchor.z), SIGHT_COLOR)


static func _add_box(root: Node3D, node_name: String, size: Vector3, position: Vector3, color: Color) -> void:
	if size == Vector3.ZERO:
		return
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	mesh.material = material
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = position
	root.add_child(node)


## Цвет части на модели и на значках оружия.
static func part_color(instance: PartInstance) -> Color:
	return _part_color(instance)


# Цвет части: производитель задаёт тон, вид части оттенок. Аксессуар со стихией красится в цвет стихии.
static func _part_color(instance: PartInstance) -> Color:
	var part: WeaponPart = instance.part
	var tone: Color = part.manufacturer.color if part.manufacturer != null else NEUTRAL_COLOR
	match part.part_type:
		WeaponPart.PartType.BODY:
			return tone.darkened(0.25)
		WeaponPart.PartType.BARREL:
			return DARK_METAL.lerp(tone, 0.25)
		WeaponPart.PartType.GRIP:
			return tone.darkened(0.5)
		WeaponPart.PartType.MAGAZINE:
			return tone.darkened(0.1)
		WeaponPart.PartType.STOCK:
			return tone.darkened(0.4)
		WeaponPart.PartType.ACCESSORY:
			for feature: PartFeature in instance.features:
				if feature.kind == CombatEnums.FeatureKind.ELEMENT and ELEMENT_COLORS.has(feature.element):
					return ELEMENT_COLORS[feature.element]
			if part.element != CombatEnums.Element.NONE and ELEMENT_COLORS.has(part.element):
				return ELEMENT_COLORS[part.element]
			return Color(0.8, 0.8, 0.85)
	return tone
