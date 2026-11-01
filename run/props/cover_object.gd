class_name CoverObject
extends StaticBody3D
## Укрытие для врагов (№93, основа механики): твёрдый барьер в боевой комнате, за которым стрелок сможет спрятаться от игрока. Игроку
## укрытие ничего не даёт (он за ним не прячется), но это обычное твёрдое тело мира: оно держит пули, мешает пройти и закрывает от
## взрывов. Поведение врагов укрытий пока не использует: объект отдаёт им места (get_spot) и ведёт учёт занятости (claim, release),
## а подобрать лучшее укрытие под игрока умеет CoverFinder. Расстановка в комнатах: PropScatterer.scatter_cover.

const WORLD_LAYER: int = 1
## Запас от бокового края укрытия, дальше которого соседние места не отодвигаются.
const EDGE_MARGIN: float = 0.3

var definition: CoverDefinition
var settings: PropSettings

# Кто занял какое место (по номеру места), свободные места null.
var _claims: Array[Object] = []


static func create(p_definition: CoverDefinition, p_settings: PropSettings) -> CoverObject:
	var cover: CoverObject = CoverObject.new()
	cover.definition = p_definition
	cover.settings = p_settings
	return cover


func _ready() -> void:
	name = "CoverObject"
	add_to_group(&"cover")
	collision_layer = WORLD_LAYER
	collision_mask = 0
	_claims.resize(definition.capacity)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = definition.size
	shape_node.shape = shape
	shape_node.position.y = definition.size.y * 0.5
	add_child(shape_node)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = definition.color
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = definition.size
	mesh.material = material
	var body: MeshInstance3D = MeshInstance3D.new()
	body.mesh = mesh
	body.position.y = definition.size.y * 0.5
	add_child(body)
	# Тёмная полоса поверх барьера: издали видно, что это укрытие, а не стена комнаты.
	var cap_material: StandardMaterial3D = StandardMaterial3D.new()
	cap_material.albedo_color = definition.color.darkened(0.5)
	var cap_mesh: BoxMesh = BoxMesh.new()
	cap_mesh.size = Vector3(definition.size.x + 0.06, 0.12, definition.size.z + 0.06)
	cap_mesh.material = cap_material
	var cap: MeshInstance3D = MeshInstance3D.new()
	cap.mesh = cap_mesh
	cap.position.y = definition.size.y
	add_child(cap)


func get_capacity() -> int:
	return definition.capacity


## Место за укрытием под угрозу в точке threat (мировые координаты). Прятаться нужно с той стороны, что дальше от угрозы:
## выбирается ось, по которой угроза стоит дальше от центра в долях полуразмера, и берётся противоположная сторона.
func get_spot(threat: Vector3, slot: int = 0) -> CoverSpot:
	var local_threat: Vector3 = to_local(threat)
	var half: Vector3 = definition.size * 0.5
	var along_z: bool = absf(local_threat.z) / half.z >= absf(local_threat.x) / half.x
	var depth_axis: Vector3 = Vector3.BACK if along_z else Vector3.RIGHT
	var lateral_axis: Vector3 = Vector3.RIGHT if along_z else Vector3.BACK
	var toward_threat: float = local_threat.z if along_z else local_threat.x
	var behind: float = -1.0 if toward_threat >= 0.0 else 1.0
	var half_depth: float = half.z if along_z else half.x
	var half_lateral: float = half.x if along_z else half.z
	var depth: float = behind * (half_depth + settings.cover_hide_margin)
	var reach: float = maxf(half_lateral - EDGE_MARGIN, 0.0)
	var lateral: float = clampf((float(slot) - float(definition.capacity - 1) * 0.5) * settings.cover_slot_spacing, -reach, reach)
	var spot: CoverSpot = CoverSpot.new()
	spot.cover = self
	spot.slot = slot
	spot.hide_position = to_global(depth_axis * depth + lateral_axis * lateral)
	for side: float in [-1.0, 1.0]:
		spot.peek_positions.append(to_global(depth_axis * depth + lateral_axis * side * (half_lateral + settings.cover_peek_margin)))
	return spot


## Какое место может занять claimer: то, что он уже занимает, иначе первое свободное. -1, если мест нет.
func get_free_slot(claimer: Object) -> int:
	var free: int = -1
	for i: int in _claims.size():
		if _claims[i] == claimer and claimer != null:
			return i
		if free < 0 and (_claims[i] == null or not is_instance_valid(_claims[i])):
			free = i
	return free


## Занять место. false, если оно занято кем-то другим. Занять новое место может только тот, кто ещё ничего здесь не занимает.
func claim(slot: int, claimer: Object) -> bool:
	if slot < 0 or slot >= _claims.size() or claimer == null:
		return false
	var holder: Object = _claims[slot]
	if holder != null and is_instance_valid(holder) and holder != claimer:
		return false
	release(claimer)
	_claims[slot] = claimer
	return true


## Освободить места, занятые claimer.
func release(claimer: Object) -> void:
	for i: int in _claims.size():
		if _claims[i] == claimer:
			_claims[i] = null


func is_claimed_by(claimer: Object) -> bool:
	return claimer != null and _claims.has(claimer)


## Сколько мест занято живыми претендентами.
func get_claim_count() -> int:
	var count: int = 0
	for holder: Object in _claims:
		if holder != null and is_instance_valid(holder):
			count += 1
	return count
