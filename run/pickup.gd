class_name Pickup
extends Node3D
## Подбираемый предмет, выпавший из врага: деньги или аптечка (№50, дроп в 10-prototype-scope).
## Падает на пол, подлетает к игроку, когда тот рядом, и подбирается сам (автоподбор с притягиванием).
## Аптечка не подбирается при полном здоровье: остаётся лежать. Числа: LootSettings в game_config.tres.

enum Kind { MONEY, MEDKIT }

## Насколько пол не доходит до центра предмета (лежит на полу, а не в нём).
const REST_HEIGHT: float = 0.2
## Скорость вращения и амплитуда покачивания (оформление).
const SPIN_SPEED: float = 2.5
const BOB_AMPLITUDE: float = 0.06

var kind: Kind = Kind.MONEY
## Деньги (число) или лечение (единицы здоровья).
var amount: float = 0.0

var _velocity: Vector3 = Vector3.ZERO
var _age: float = 0.0
var _landed: bool = false
var _magnet_speed: float = 0.0
var _player: Player
var _visual: Node3D
var _bob_origin: float = 0.0


static func spawn(parent: Node, at: Vector3, p_kind: Kind, p_amount: float) -> Pickup:
	if parent == null or not parent.is_inside_tree():
		return null
	var pickup: Pickup = Pickup.new()
	pickup.kind = p_kind
	pickup.amount = p_amount
	parent.add_child(pickup)
	pickup.global_position = at
	pickup._toss()
	return pickup


func _ready() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	if kind == Kind.MONEY:
		_build_coin()
	else:
		_build_medkit()


func _physics_process(delta: float) -> void:
	var loot: LootSettings = Config.data.loot
	_age += delta
	if _age > loot.lifetime:
		queue_free()
		return
	_visual.rotation.y += SPIN_SPEED * delta
	var player: Player = _get_player()
	if player != null and not player.is_dead and _can_collect(player):
		var to_player: Vector3 = player.get_center_position() - global_position
		var distance: float = to_player.length()
		if distance <= loot.collect_radius:
			_collect(player)
			return
		if distance <= loot.magnet_radius:
			_magnet_speed = move_toward(_magnet_speed, loot.magnet_speed, loot.magnet_speed * 4.0 * delta)
			global_position += to_player / distance * minf(_magnet_speed * delta, distance)
			_landed = true
			return
	_magnet_speed = 0.0
	if not _landed:
		_fall(delta, loot)
	else:
		_visual.position.y = sin(_age * 3.0) * BOB_AMPLITUDE


func _get_player() -> Player:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Player
	return _player


func _can_collect(player: Player) -> bool:
	# Аптечка при полном здоровье лежит, пока игрок не пострадает.
	return kind == Kind.MONEY or player.health < player.max_health


func _collect(player: Player) -> void:
	if kind == Kind.MONEY:
		Progress.add_money(roundi(amount))
		get_tree().call_group(&"hud", &"show_pickup", tr("HUD_PICKUP_MONEY").format({"amount": roundi(amount)}))
	else:
		player.heal(amount)
		get_tree().call_group(&"hud", &"show_pickup", tr("HUD_PICKUP_MEDKIT").format({"amount": roundi(amount)}))
	queue_free()


func _toss() -> void:
	var loot: LootSettings = Config.data.loot
	var angle: float = randf() * TAU
	_velocity = Vector3(cos(angle), 0.0, sin(angle)) * loot.scatter_speed * randf_range(0.3, 1.0)
	_velocity.y = loot.toss_speed


# Падение с разлётом: луч от текущей точки к следующей находит пол (садимся) или стену (гасим разлёт).
func _fall(delta: float, loot: LootSettings) -> void:
	_velocity.y -= loot.gravity * delta
	var next: Vector3 = global_position + _velocity * delta
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position, next + Vector3.DOWN * REST_HEIGHT, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = next
		return
	var normal: Vector3 = hit["normal"]
	var point: Vector3 = hit["position"]
	if normal.y > 0.5:
		global_position = point + Vector3.UP * REST_HEIGHT
		_velocity = Vector3.ZERO
		_landed = true
	else:
		_velocity.x = 0.0
		_velocity.z = 0.0
		global_position = point + normal * 0.1


func _build_coin() -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.18
	mesh.bottom_radius = 0.18
	mesh.height = 0.05
	mesh.material = _unshaded(Color(1.0, 0.82, 0.2))
	var coin: MeshInstance3D = MeshInstance3D.new()
	coin.mesh = mesh
	# Монета стоит на ребре: при вращении вокруг вертикали она «переворачивается».
	coin.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	_visual.add_child(coin)


func _build_medkit() -> void:
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.36, 0.24, 0.26)
	box.material = _unshaded(Color(0.95, 0.95, 0.95))
	var body: MeshInstance3D = MeshInstance3D.new()
	body.mesh = box
	_visual.add_child(body)
	var red: StandardMaterial3D = _unshaded(Color(0.85, 0.15, 0.15))
	for size: Vector3 in [Vector3(0.2, 0.02, 0.06), Vector3(0.06, 0.02, 0.2)]:
		var bar_mesh: BoxMesh = BoxMesh.new()
		bar_mesh.size = size
		bar_mesh.material = red
		var bar: MeshInstance3D = MeshInstance3D.new()
		bar.mesh = bar_mesh
		bar.position = Vector3(0.0, 0.125, 0.0)
		_visual.add_child(bar)


func _unshaded(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material
