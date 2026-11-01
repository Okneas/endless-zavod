class_name RoomInfo
extends RefCounted
## Сведения о сцене комнаты или перехода для генератора: входы (позиция, направление, размер проёма) и габариты в
## координатах сцены. Считываются один раз из самой сцены, поэтому комната из редактора не требует отдельного описания.
## Входы бывают горизонтальными (проём в стене) и вертикальными (проём в потолке или полу, №81: комнаты стыкуются
## друг над другом).


class Entrance:
	extends RefCounted
	var position: Vector3 = Vector3.ZERO
	## Куда смотрит вход наружу: единичный вектор вдоль оси X или Z, у вертикального вверх (потолок) или вниз (пол).
	var direction: Vector3 = Vector3.FORWARD
	## Горизонтальный вход: ширина и высота проёма. Вертикальный: размеры проёма вдоль осей X и Y узла-маркера
	## (X это направление подъёма лестницы стыка, Y поперёк).
	var size: Vector2 = Vector2(4.0, 4.0)
	## Ориентация узла-маркера в координатах комнаты (нужна вертикальным входам: ось X задаёт направление лестницы).
	var frame: Basis = Basis.IDENTITY

	func is_vertical() -> bool:
		return absf(direction.y) > 0.5

	## Горизонтальное направление оси X маркера вертикального входа (куда поднимается лестница стыка).
	func heading() -> Vector3:
		var along: Vector3 = Vector3(frame.x.x, 0.0, frame.x.z)
		return along.normalized() if along.length() > 0.001 else Vector3.RIGHT

	## Размеры проёма вдоль мировых осей X и Z, если комнату повернули на данную базис (поворот вокруг вертикали).
	func footprint(rotation: Basis) -> Vector2:
		var rotated: Basis = rotation * frame
		return Vector2(
			absf(rotated.x.x) * size.x + absf(rotated.y.x) * size.y,
			absf(rotated.x.z) * size.x + absf(rotated.y.z) * size.y)


var entrances: Array[Entrance] = []
var bounds: AABB = AABB()
## Сцена без входов или без габаритов не годится для генерации (описание проблемы).
var problem: String = ""


static func from_scene(scene: PackedScene) -> RoomInfo:
	var info: RoomInfo = RoomInfo.new()
	var root: RoomPiece = scene.instantiate() as RoomPiece
	if root == null:
		info.problem = "корень сцены не RoomPiece"
		return info
	info.bounds = root.get_bounds()
	if info.bounds.size == Vector3.ZERO:
		info.problem = "нет габаритов (bounds_size или GridMap)"
	for marker: RoomEntrance in root.get_entrances():
		var transform_in_room: Transform3D = _relative_transform(marker, root)
		var entrance: Entrance = Entrance.new()
		entrance.position = transform_in_room.origin
		entrance.frame = transform_in_room.basis
		var forward: Vector3 = -transform_in_room.basis.z
		if absf(forward.y) > 0.95:
			entrance.direction = Vector3.UP if forward.y > 0.0 else Vector3.DOWN
		else:
			entrance.direction = Vector3(roundf(forward.x), 0.0, roundf(forward.z)).normalized()
			if absf(forward.y) > 0.05 or (absf(forward.x) > 0.05 and absf(forward.z) > 0.05):
				info.problem = "вход %s смотрит не вдоль оси X, Z или вертикали" % marker.name
		entrance.size = marker.opening
		info.entrances.append(entrance)
	if info.entrances.is_empty():
		info.problem = "нет входов (узлы RoomEntrance)"
	root.free()
	return info


# Положение узла в координатах корня сцены (сцена вне дерева, global_transform недоступен).
static func _relative_transform(node: Node3D, root: Node3D) -> Transform3D:
	var result: Transform3D = node.transform
	var parent: Node = node.get_parent()
	while parent != null and parent != root:
		var parent_3d: Node3D = parent as Node3D
		if parent_3d != null:
			result = parent_3d.transform * result
		parent = parent.get_parent()
	return result
