class_name ShopCounter
extends Node3D
## Прилавок в магазине-хабе (срез 8, №88): игрок смотрит на него и жмёт interact, открывается панель выставления товара и цены.
## Товар на столе виден (модель оружия или цветной ящик), над ним цена игрока. Состояние берётся из автозагрузки Shop (прилавок с номером index).

signal activated(index: int)

@export var index: int = 0

var _display: Node3D
var _price_label: Label3D


func _ready() -> void:
	add_to_group(&"interactables")
	var table: BoxMesh = BoxMesh.new()
	table.size = Vector3(2.0, 0.9, 1.0)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.45, 0.32, 0.2)
	table.material = material
	var body: MeshInstance3D = MeshInstance3D.new()
	body.mesh = table
	body.position = Vector3(0.0, 0.45, 0.0)
	add_child(body)
	var collision: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = table.size
	shape.shape = box
	collision.add_child(shape)
	collision.position = Vector3(0.0, 0.45, 0.0)
	add_child(collision)
	_price_label = Label3D.new()
	_price_label.font_size = 56
	_price_label.pixel_size = 0.006
	_price_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_price_label.no_depth_test = true
	_price_label.modulate = Color(1.0, 0.85, 0.3)
	_price_label.position = Vector3(0.0, 1.9, 0.0)
	add_child(_price_label)
	_display = Node3D.new()
	_display.position = Vector3(0.0, 0.95, 0.0)
	add_child(_display)
	Shop.changed.connect(refresh)
	refresh()


func get_slot() -> ShopSlot:
	return Shop.counters[index]


## Перерисовать товар и цену по состоянию Shop.
func refresh() -> void:
	for child: Node in _display.get_children():
		_display.remove_child(child)
		child.queue_free()
	var slot: ShopSlot = get_slot()
	if slot.is_empty() or slot.carried:
		_price_label.text = ""
		return
	_price_label.text = str(slot.price)
	if slot.item.weapon != null and slot.item.weapon.get_body().part.model_size != Vector3.ZERO:
		var built: WeaponModelBuilder.Result = WeaponModelBuilder.build(slot.item.weapon)
		_display.add_child(built.root)
		return
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.4, 0.2, 0.3)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = slot.item.get_quality_color()
	mesh.material = material
	var box: MeshInstance3D = MeshInstance3D.new()
	box.mesh = mesh
	box.position = Vector3(0.0, 0.1, 0.0)
	_display.add_child(box)


func interact(_player: Node) -> bool:
	activated.emit(index)
	return true


func get_prompt() -> String:
	var slot: ShopSlot = get_slot()
	var key: String = "HUD_INTERACT_COUNTER_EMPTY" if slot.is_empty() else "HUD_INTERACT_COUNTER"
	return tr(key).format({"key": KeyHint.text(&"interact"), "number": index + 1})


func get_prompt_color() -> Color:
	return Color(1.0, 0.85, 0.3)


## Где стоит покупатель, разглядывая этот прилавок (перед ним, по местной оси +Z).
func stand_point() -> Vector3:
	return global_transform * Vector3(0.0, 0.0, 2.0)
