class_name ItemPickup
extends Node3D
## Предмет инвентаря на полу (выброшенный или выпавший, №54 диздока «Выбросить»). Лежит и покачивается,
## подбирается по клавише interact, когда игрок смотрит на него вблизи (PlayerInteractor). Без места
## в инвентаре остаётся лежать. Столбик света окрашен по качеству.

const WORLD_MASK: int = 1
const REST_HEIGHT: float = 0.25
const SPIN_SPEED: float = 1.2
const BOB_AMPLITUDE: float = 0.05

var item: InventoryItem
## Цена в магазине забега (срез 7): больше нуля, и предмет продаётся, а не лежит даром. Деньги списываются при подборе.
var price: int = 0

var _velocity: Vector3 = Vector3.ZERO
var _landed: bool = false
var _age: float = 0.0
var _visual: Node3D


static func spawn(parent: Node, p_item: InventoryItem, at: Vector3, p_velocity: Vector3, p_price: int = 0) -> ItemPickup:
	if parent == null or not parent.is_inside_tree():
		return null
	var pickup: ItemPickup = ItemPickup.new()
	pickup.item = p_item
	pickup.price = p_price
	pickup._velocity = p_velocity
	parent.add_child(pickup)
	pickup.global_position = at
	return pickup


func _ready() -> void:
	add_to_group(&"item_pickups")
	add_to_group(&"interactables")
	_visual = Node3D.new()
	add_child(_visual)
	var color: Color = item.get_quality_color()
	if item.weapon != null and item.weapon.get_body().part.model_size != Vector3.ZERO:
		var built: WeaponModelBuilder.Result = WeaponModelBuilder.build(item.weapon)
		_visual.add_child(built.root)
	else:
		_add_box(_visual, Vector3(0.3, 0.12, 0.12) if item.weapon != null else Vector3(0.22, 0.22, 0.22), color)
	# Столбик света: издали видно, где лежит предмет и какого он качества.
	var beam_material: StandardMaterial3D = StandardMaterial3D.new()
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_material.albedo_color = Color(color.r, color.g, color.b, 0.35)
	var beam_mesh: BoxMesh = BoxMesh.new()
	beam_mesh.size = Vector3(0.05, 1.6, 0.05)
	beam_mesh.material = beam_material
	var beam: MeshInstance3D = MeshInstance3D.new()
	beam.mesh = beam_mesh
	beam.position = Vector3(0.0, 0.8, 0.0)
	add_child(beam)
	if price > 0:
		var tag: Label3D = Label3D.new()
		tag.name = "PriceTag"
		tag.text = str(price)
		tag.font_size = 72
		tag.pixel_size = 0.006
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.modulate = Color(1.0, 0.85, 0.3)
		tag.position = Vector3(0.0, 1.0, 0.0)
		add_child(tag)


func _physics_process(delta: float) -> void:
	_age += delta
	if not _landed:
		_fall(delta)
	else:
		_visual.position.y = sin(_age * 2.5) * BOB_AMPLITUDE
	_visual.rotation.y += SPIN_SPEED * delta


## Подобрать предмет (в магазине забега купить). Возвращает true, если он лёг в инвентарь, иначе остаётся на месте.
func interact(_player: Node) -> bool:
	if price > 0 and Progress.money < price:
		get_tree().call_group(&"hud", &"show_pickup", tr("HUD_NOT_ENOUGH_MONEY").format({"price": price}), Color(1.0, 0.3, 0.3))
		return false
	if not Inventory.add(item):
		return false
	if price > 0:
		Progress.spend_money(price)
		get_tree().call_group(&"hud", &"show_pickup", tr("HUD_BOUGHT_ITEM").format({"name": item.get_display_name(), "price": price}), item.get_quality_color())
	else:
		get_tree().call_group(&"hud", &"show_pickup", tr("HUD_PICKUP_ITEM").format({"name": item.get_display_name()}), item.get_quality_color())
	queue_free()
	return true


## Подсказка у предмета: что нажать и что случится.
func get_prompt() -> String:
	var key: String = KeyHint.text(&"interact")
	if price > 0:
		return tr("HUD_INTERACT_BUY").format({"key": key, "name": item.get_display_name(), "price": price})
	return tr("HUD_INTERACT_PICKUP").format({"key": key, "name": item.get_display_name()})


func get_prompt_color() -> Color:
	return item.get_quality_color()


# Падение: луч от текущей точки к следующей находит пол (садимся) или стену (гасим разлёт).
func _fall(delta: float) -> void:
	_velocity.y -= Config.data.inventory.drop_gravity * delta
	var next: Vector3 = global_position + _velocity * delta
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position, next + Vector3.DOWN * REST_HEIGHT, WORLD_MASK)
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


func _add_box(parent: Node3D, size: Vector3, color: Color) -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	parent.add_child(node)
