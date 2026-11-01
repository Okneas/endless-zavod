class_name ShopRegister
extends Node3D
## Касса магазина-хаба (срез 8, №88): покупатель с товаром встаёт в очередь, игрок смотрит на кассу и жмёт interact, чтобы принять оплату
## первого в очереди. Не дождавшийся покупатель уходит сам (терпение в ShopSettings.register_patience).
## Лицо кассы (№89) это местная ось +Z: с этой стороны стоят покупатели (на полу метка у первого места, очередь тянется от кассы по +Z),
## игрок работает с обратной стороны, спиной к стене. Сторону выбирает поворот узла: в сцене касса стоит у восточной стены лицом в зал.

signal served(customer: Customer)

## Где стоит первый покупатель перед кассой (по местной оси +Z) и шаг очереди.
const QUEUE_FIRST: float = 1.6
const QUEUE_STEP: float = 1.3

## Покупатели в очереди; первый стоит у кассы.
var queue: Array[Customer] = []


func _ready() -> void:
	add_to_group(&"interactables")
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(1.4, 1.0, 1.0)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.5, 0.35)
	mesh.material = material
	var body: MeshInstance3D = MeshInstance3D.new()
	body.mesh = mesh
	body.position = Vector3(0.0, 0.5, 0.0)
	add_child(body)
	var collision: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = mesh.size
	shape.shape = box
	collision.add_child(shape)
	collision.position = Vector3(0.0, 0.5, 0.0)
	add_child(collision)
	var label: Label3D = Label3D.new()
	label.text = tr("HUB_REGISTER")
	label.font_size = 56
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(0.0, 1.7, 0.0)
	add_child(label)
	# Метка на полу: тут ждёт первый покупатель.
	var plate_mesh: BoxMesh = BoxMesh.new()
	plate_mesh.size = Vector3(1.2, 0.03, 1.0)
	var plate_material: StandardMaterial3D = StandardMaterial3D.new()
	plate_material.albedo_color = Color(0.95, 0.8, 0.25)
	plate_mesh.material = plate_material
	var plate: MeshInstance3D = MeshInstance3D.new()
	plate.mesh = plate_mesh
	plate.position = Vector3(0.0, 0.02, QUEUE_FIRST)
	add_child(plate)


func enqueue(customer: Customer) -> void:
	if not queue.has(customer):
		queue.append(customer)


func dequeue(customer: Customer) -> void:
	queue.erase(customer)


## Точка в очереди: 0 это место у кассы, дальше вереница вдоль местной оси +Z (с лицевой стороны кассы).
func queue_point(position_in_queue: int) -> Vector3:
	return global_transform * Vector3(0.0, 0.0, QUEUE_FIRST + QUEUE_STEP * float(position_in_queue))


## Первый в очереди дошёл до кассы и ждёт оплаты.
func has_customer_waiting() -> bool:
	return not queue.is_empty() and queue[0].is_waiting_at_register()


func interact(_player: Node) -> bool:
	if not has_customer_waiting():
		return false
	var customer: Customer = queue[0]
	customer.pay()
	served.emit(customer)
	return true


func get_prompt() -> String:
	if has_customer_waiting():
		return tr("HUD_INTERACT_REGISTER").format({"key": KeyHint.text(&"interact"), "price": queue[0].slot.price})
	return tr("HUD_REGISTER_IDLE")


func get_prompt_color() -> Color:
	return Color(0.5, 1.0, 0.6) if has_customer_waiting() else Color(0.7, 0.7, 0.7)
