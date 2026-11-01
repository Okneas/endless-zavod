class_name PlayerInteractor
extends Node
## Подбор предметов с пола по клавише interact. Каждый тик ищет предмет, на который смотрит игрок вблизи:
## в радиусе и в конусе перед камерой (InventorySettings), берёт ближайший к центру взгляда. HUD показывает подсказку.

signal focus_changed(target: Node3D)

## То, на что смотрит игрок: предмет на полу, постамент магазина, терминал эвакуации (группа interactables: методы
## interact(player), get_prompt(), get_prompt_color()).
var focused: Node3D

var _player: CharacterBody3D
var _camera: Camera3D


func setup(player: CharacterBody3D, camera: Camera3D) -> void:
	_player = player
	_camera = camera


func _physics_process(_delta: float) -> void:
	var best: Node3D = null
	var best_angle: float = INF
	if not _player.get("is_dead"):
		var settings: InventorySettings = Config.data.inventory
		var forward: Vector3 = -_camera.global_basis.z
		for node: Node in get_tree().get_nodes_in_group(&"interactables"):
			var target: Node3D = node as Node3D
			var to_item: Vector3 = target.global_position - _camera.global_position
			var distance: float = to_item.length()
			if distance > settings.interact_range or distance < 0.01:
				continue
			var angle: float = rad_to_deg(forward.angle_to(to_item))
			if angle <= settings.interact_cone and angle < best_angle:
				best = target
				best_angle = angle
	if best != focused:
		focused = best
		focus_changed.emit(focused)
	if focused != null and Input.is_action_just_pressed(&"interact"):
		focused.call(&"interact", _player)
