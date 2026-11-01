class_name HubStation
extends Node3D
## Интерактивный объект хаба (срез 8, №88): сундук, справочник цен, вывеска открытия магазина, дверь в забег, торговец. Сам ничего не решает:
## игрок смотрит на него и жмёт interact, объект сообщает сигналом activated, а сцена хаба открывает панель или выполняет действие.

signal activated(kind: Kind)

enum Kind { CHEST, PRICE_BOOK, SIGN, RUN_DOOR, TRADER }

@export var kind: Kind = Kind.CHEST

const SIZES: Dictionary = {
	Kind.CHEST: Vector3(1.4, 1.0, 1.0),
	Kind.PRICE_BOOK: Vector3(0.9, 1.3, 0.7),
	Kind.SIGN: Vector3(1.6, 0.4, 0.2),
	Kind.RUN_DOOR: Vector3(0.6, 4.0, 4.0),
	Kind.TRADER: Vector3(0.9, 1.8, 0.9),
}
const COLORS: Dictionary = {
	Kind.CHEST: Color(0.5, 0.35, 0.15),
	Kind.PRICE_BOOK: Color(0.35, 0.4, 0.6),
	Kind.SIGN: Color(0.9, 0.75, 0.2),
	Kind.RUN_DOOR: Color(0.9, 0.35, 0.15),
	Kind.TRADER: Color(0.7, 0.3, 0.7),
}
const TITLES: Dictionary = {
	Kind.CHEST: "HUB_CHEST",
	Kind.PRICE_BOOK: "HUB_PRICE_BOOK",
	Kind.SIGN: "",
	Kind.RUN_DOOR: "HUB_RUN_DOOR",
	Kind.TRADER: "HUB_TRADER",
}

var _label: Label3D


func _ready() -> void:
	add_to_group(&"interactables")
	var size: Vector3 = SIZES[kind]
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = COLORS[kind]
	if kind == Kind.RUN_DOOR:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0.9, 0.4, 0.15, 0.7)
	mesh.material = material
	var body: MeshInstance3D = MeshInstance3D.new()
	body.mesh = mesh
	body.position = Vector3(0.0, size.y * 0.5, 0.0)
	add_child(body)
	if kind != Kind.RUN_DOOR:
		var collision: StaticBody3D = StaticBody3D.new()
		var shape: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = size
		shape.shape = box
		collision.add_child(shape)
		collision.position = body.position
		add_child(collision)
	_label = Label3D.new()
	_label.font_size = 56
	_label.pixel_size = 0.007
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position = Vector3(0.0, size.y + 0.7, 0.0)
	add_child(_label)
	Shop.changed.connect(_refresh_label)
	_refresh_label()


# Название над объектом; у вывески оно показывает, открыт ли магазин.
func _refresh_label() -> void:
	if kind == Kind.SIGN:
		_label.text = tr("HUB_SIGN_OPEN") if Shop.is_open else tr("HUB_SIGN_CLOSED")
		_label.modulate = Color(0.6, 1.0, 0.6) if Shop.is_open else Color(1.0, 0.6, 0.5)
	else:
		_label.text = tr(TITLES[kind])


func interact(_player: Node) -> bool:
	activated.emit(kind)
	return true


func get_prompt() -> String:
	var key: String = "HUD_INTERACT_" + Kind.keys()[kind]
	if kind == Kind.SIGN:
		key = "HUD_INTERACT_SIGN_CLOSE" if Shop.is_open else "HUD_INTERACT_SIGN_OPEN"
	return tr(key).format({"key": KeyHint.text(&"interact")})


func get_prompt_color() -> Color:
	return COLORS[kind].lightened(0.3)
