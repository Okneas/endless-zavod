class_name RoomDoor
extends StaticBody3D
## Дверь в проёме комнаты (№41). Закрытая перекрывает проход для игрока, врагов и пуль, открытая нет. Глухая заглушка
## (plug) закрывает проём, у которого нет соседа, и не открывается. Размер берётся из проёма, положение из узла входа.

## Слой игрока: плита проверяет, не закрывается ли она на нём.
const PLAYER_MASK: int = 2
const THICKNESS: float = 1.0
## Толщина плиты перекрытия в проёме пола или потолка: одна ячейка набора заглушек (2 м).
const SLAB_THICKNESS: float = 2.0
const MATERIAL_PATH: String = "res://assets/placeholders/greybox_block.tres"

## Заглушка проёма без соседа: всегда закрыта.
var is_plug: bool = false
## Плита в проёме пола или потолка (стык комнат друг над другом, №85), а не дверь в стене.
var is_vertical: bool = false
var is_closed: bool = false
## Плита хотела закрыться, но в её объёме стоял игрок: закроется, когда тот выйдет.
var _pending_close: bool = false

var _mesh: MeshInstance3D
var _shape: CollisionShape3D


## entrance_transform: мировое положение входа (минус Z смотрит наружу), opening: ширина и высота проёма. Вертикальный
## вход (проём в полу или потолке, №81): плита закрывает проём на всю толщу перекрытия, opening это его размеры вдоль X и Y маркера.
func setup(entrance_transform: Transform3D, opening: Vector2, plug: bool, vertical: bool = false) -> void:
	is_plug = plug
	is_vertical = vertical
	name = "Plug" if plug else "Door"
	var size: Vector3
	if vertical:
		transform = entrance_transform * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, SLAB_THICKNESS * 0.5))
		size = Vector3(opening.x, opening.y, SLAB_THICKNESS)
	else:
		# Дверь стоит внутри толщи стены: от внешней плоскости проёма на полметра вглубь.
		transform = entrance_transform * Transform3D(Basis.IDENTITY, Vector3(0.0, opening.y * 0.5, THICKNESS * 0.5))
		size = Vector3(opening.x, opening.y, THICKNESS)
	_mesh = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	box.material = load(MATERIAL_PATH)
	_mesh.mesh = box
	add_child(_mesh)
	_shape = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	_shape.shape = shape
	add_child(_shape)
	_apply(plug)


func _ready() -> void:
	# Плите нужен физический кадр, только пока она ждёт, когда игрок выйдет из её объёма.
	set_physics_process(false)


func set_closed(value: bool) -> void:
	if is_plug:
		return
	# Предохранитель (№87): плита в проёме пола или потолка не закрывается, пока в её объёме стоит игрок, иначе он оказался бы
	# в стене без выхода. Закроется, как только выйдет.
	if value and is_vertical and _overlaps_player():
		_pending_close = true
		set_physics_process(true)
		return
	_pending_close = false
	set_physics_process(false)
	_apply(value)


func _physics_process(_delta: float) -> void:
	if _pending_close and not _overlaps_player():
		_pending_close = false
		set_physics_process(false)
		_apply(true)


func _overlaps_player() -> bool:
	if _shape == null or not is_inside_tree():
		return false
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = _shape.shape
	query.transform = _shape.global_transform
	query.collision_mask = PLAYER_MASK
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _apply(closed: bool) -> void:
	is_closed = closed
	_mesh.visible = closed
	# Меняется и из физических сигналов (враг умер), поэтому отложенно.
	set_deferred("collision_layer", 1 if closed else 0)
