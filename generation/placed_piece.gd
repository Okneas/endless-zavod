class_name PlacedPiece
extends RefCounted
## Поставленная в зону комната или переход: определение, сведения, положение в мире и связи с соседями.

var definition: RoomDefinition
var info: RoomInfo
var transform: Transform3D = Transform3D.IDENTITY
var index: int = 0
## Через какой вход (индекс в info.entrances) подключена к родителю и родитель (-1 у стартовой).
var parent: int = -1
var parent_entrance: int = -1
## Расстояние от стартовой по цепочке комнат и переходов.
var depth: int = 0
## Вход (индекс) в индекс соседней поставленной части.
var links: Dictionary = {}


func kind() -> RoomDefinition.Kind:
	return definition.kind


func is_corridor() -> bool:
	return definition.kind == RoomDefinition.Kind.CORRIDOR


func world_bounds() -> AABB:
	return transform * info.bounds


func entrance_position(entrance_index: int) -> Vector3:
	return transform * info.entrances[entrance_index].position


func entrance_direction(entrance_index: int) -> Vector3:
	return transform.basis * info.entrances[entrance_index].direction


## Размеры проёма вертикального входа вдоль мировых осей X и Z с учётом поворота части.
func entrance_footprint(entrance_index: int) -> Vector2:
	return info.entrances[entrance_index].footprint(transform.basis)


## Направление подъёма лестницы стыка у вертикального входа в мире (горизонтальный единичный вектор).
func entrance_heading(entrance_index: int) -> Vector3:
	return (transform.basis * info.entrances[entrance_index].heading()).normalized()
