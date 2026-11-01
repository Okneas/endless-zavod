class_name EvacuationTerminal
extends Node3D
## Терминал эвакуации в эвакуационной комнате (№82): игрок смотрит на него и жмёт interact, открывается панель выбора
## (заплатить или отстоять волны). Сам ничего не решает, сообщает сигналом activated.

signal activated

var enabled: bool = true


func _ready() -> void:
	name = "Terminal"
	add_to_group(&"interactables")
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(1.4, 2.0, 0.8)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.6, 0.9)
	mesh.material = material
	var body: MeshInstance3D = MeshInstance3D.new()
	body.mesh = mesh
	body.position = Vector3(0.0, 1.0, 0.0)
	add_child(body)
	var label: Label3D = Label3D.new()
	label.text = tr("TERMINAL_TITLE")
	label.font_size = 48
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(0.0, 2.6, 0.0)
	add_child(label)


func interact(_player: Node) -> bool:
	if not enabled:
		return false
	activated.emit()
	return true


func get_prompt() -> String:
	return tr("HUD_INTERACT_TERMINAL").format({"key": KeyHint.text(&"interact")})


func get_prompt_color() -> Color:
	return Color(0.5, 0.85, 1.0)
