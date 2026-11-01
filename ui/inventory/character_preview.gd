extends Node3D
## Превью персонажа с оружием в руках (колонка слева на экране инвентаря). Заглушка из примитивов:
## капсула, шар и коробки, оружие собирается из частей. Медленно вращается. Живёт в своём SubViewport.

@export var turn_speed: float = 0.6

var _figure: Node3D
var _hand: Node3D


func _ready() -> void:
	var camera: Camera3D = Camera3D.new()
	camera.fov = 35.0
	add_child(camera)
	camera.position = Vector3(0.0, 1.05, 3.4)
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.95, 0.0))
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
	add_child(light)
	_figure = Node3D.new()
	add_child(_figure)
	_box(_figure, Vector3(0.5, 0.65, 0.3), Vector3(0.0, 1.0, 0.0), Color(0.35, 0.4, 0.5))
	_box(_figure, Vector3(0.2, 0.7, 0.22), Vector3(-0.13, 0.35, 0.0), Color(0.25, 0.28, 0.35))
	_box(_figure, Vector3(0.2, 0.7, 0.22), Vector3(0.13, 0.35, 0.0), Color(0.25, 0.28, 0.35))
	_box(_figure, Vector3(0.14, 0.55, 0.14), Vector3(-0.34, 1.0, 0.0), Color(0.35, 0.4, 0.5))
	var head_mesh: SphereMesh = SphereMesh.new()
	head_mesh.radius = 0.17
	head_mesh.height = 0.34
	head_mesh.material = _material(Color(0.8, 0.72, 0.62))
	var head: MeshInstance3D = MeshInstance3D.new()
	head.mesh = head_mesh
	head.position = Vector3(0.0, 1.5, 0.0)
	_figure.add_child(head)
	# Правая рука вперёд, в кисти оружие.
	_box(_figure, Vector3(0.14, 0.14, 0.5), Vector3(0.34, 1.12, -0.22), Color(0.35, 0.4, 0.5))
	_hand = Node3D.new()
	_hand.position = Vector3(0.34, 1.1, -0.45)
	_figure.add_child(_hand)


func _process(delta: float) -> void:
	if _figure != null:
		_figure.rotation.y += turn_speed * delta


## Показать оружие в руке. null убирает оружие.
func show_weapon(weapon: WeaponInstance) -> void:
	if _hand == null:
		return
	for child: Node in _hand.get_children():
		_hand.remove_child(child)
		child.queue_free()
	if weapon == null:
		return
	if weapon.get_body().part.model_size != Vector3.ZERO:
		var built: WeaponModelBuilder.Result = WeaponModelBuilder.build(weapon)
		built.root.scale = Vector3.ONE * 1.1
		_hand.add_child(built.root)
	else:
		# Стартовый пистолет без данных модели: простой силуэт.
		var holder: Node3D = Node3D.new()
		_box(holder, Vector3(0.06, 0.09, 0.26), Vector3.ZERO, Color(0.45, 0.47, 0.5))
		_box(holder, Vector3(0.035, 0.035, 0.14), Vector3(0.0, 0.02, -0.2), Color(0.3, 0.32, 0.36))
		_box(holder, Vector3(0.05, 0.12, 0.06), Vector3(0.0, -0.09, 0.09), Color(0.35, 0.3, 0.28))
		_hand.add_child(holder)


func _box(parent: Node3D, size: Vector3, position: Vector3, color: Color) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.position = position
	parent.add_child(node)


func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material
