class_name ZoneLayout
extends RefCounted
## Результат генерации зоны: поставленные комнаты и переходы, сиды, уровень зоны и замечания. Сцены не создаёт,
## это только данные (ZoneBuilder строит по ним узлы).

var pieces: Array[PlacedPiece] = []
var zone_number: int = 1
var zone_level: int = 1
var run_seed: int = 0
var zone_seed: int = 0
## Что не удалось разместить и прочие замечания (пустой список: зона собрана как задумано).
var warnings: PackedStringArray = []


func get_start() -> PlacedPiece:
	for piece: PlacedPiece in pieces:
		if piece.kind() == RoomDefinition.Kind.START:
			return piece
	return null


func count(kind: RoomDefinition.Kind) -> int:
	var total: int = 0
	for piece: PlacedPiece in pieces:
		if piece.kind() == kind:
			total += 1
	return total


## Комнаты без переходов.
func room_count() -> int:
	return pieces.size() - count(RoomDefinition.Kind.CORRIDOR)


func get_bounds() -> AABB:
	var result: AABB = pieces[0].world_bounds() if not pieces.is_empty() else AABB()
	for piece: PlacedPiece in pieces:
		result = result.merge(piece.world_bounds())
	return result


## Сколько раз вход не стыкуется ни с чем (глухой проём, будет заделан).
func open_entrance_count() -> int:
	var total: int = 0
	for piece: PlacedPiece in pieces:
		total += piece.info.entrances.size() - piece.links.size()
	return total


func describe() -> String:
	return "зона %d, уровень %d, сид %d: комнат %d, переходов %d" % [zone_number, zone_level, zone_seed, room_count(), count(RoomDefinition.Kind.CORRIDOR)]
