class_name ZonePortal
extends Node3D
## Портал (дверь) в конце испытания (№82): пока испытание не пройдено, закрыт и красный, потом открывается и горит
## зелёным. Игрок, вошедший в открытый портал, переносится дальше: в следующую зону, в хаб после эвакуации или победы над
## боссом (Run.Exit). Сам ничего не переносит, сообщает сигналом used, остальное делает забег (Run.use_exit).

signal used

const SIZE: Vector3 = Vector3(5.0, 6.0, 0.6)
const CLOSED_COLOR: Color = Color(0.9, 0.2, 0.15, 0.55)
const OPEN_COLOR: Color = Color(0.2, 1.0, 0.45, 0.6)

var is_open: bool = false
var exit_kind: Run.Exit = Run.Exit.NEXT_ZONE

var _mesh: MeshInstance3D
var _material: StandardMaterial3D
var _label: Label3D
var _area: Area3D


func setup(p_exit_kind: Run.Exit) -> void:
	exit_kind = p_exit_kind
	name = "Portal"
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var box: BoxMesh = BoxMesh.new()
	box.size = SIZE
	box.material = _material
	_mesh = MeshInstance3D.new()
	_mesh.mesh = box
	_mesh.position = Vector3(0.0, SIZE.y * 0.5, 0.0)
	add_child(_mesh)
	_label = Label3D.new()
	_label.font_size = 64
	_label.pixel_size = 0.01
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position = Vector3(0.0, SIZE.y + 0.8, 0.0)
	add_child(_label)
	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(SIZE.x, SIZE.y, 1.6)
	shape.shape = box_shape
	shape.position = Vector3(0.0, SIZE.y * 0.5, 0.0)
	_area.add_child(shape)
	add_child(_area)
	_area.body_entered.connect(_on_body_entered)
	set_open(false)


func set_open(value: bool) -> void:
	is_open = value
	_material.albedo_color = OPEN_COLOR if value else CLOSED_COLOR
	_label.text = tr(_label_key()) if value else ""
	_label.modulate = OPEN_COLOR


func _label_key() -> String:
	match exit_kind:
		Run.Exit.EVACUATE:
			return "PORTAL_EVACUATE"
		Run.Exit.BOSS_VICTORY:
			return "PORTAL_BOSS"
	return "PORTAL_NEXT_ZONE"


func _on_body_entered(body: Node3D) -> void:
	if not is_open or not body.is_in_group(&"player"):
		return
	is_open = false
	_material.albedo_color = CLOSED_COLOR
	used.emit()
