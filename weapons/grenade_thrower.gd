class_name GrenadeThrower
extends Node
## Бросок гранаты на клавишу G (действие grenade, №92). Бросает ту, что лежит в слоте гранат (Inventory.grenade), по взгляду дугой.
## После броска у гранаты идёт своя перезарядка (GrenadeInstance.cooldown_left, у каждой гранаты своя), пока она в слоте. Пока перезарядка не
## кончилась, бросить нельзя. Мёртвый игрок не бросает.

signal thrown(projectile: GrenadeProjectile)
## Попытка броска при перезарядке или пустом слоте.
signal refused

var _player: CharacterBody3D
var _camera: Camera3D


func setup(player: CharacterBody3D, camera: Camera3D) -> void:
	_player = player
	_camera = camera


func _physics_process(delta: float) -> void:
	var grenade: GrenadeInstance = Inventory.grenade
	if grenade != null:
		grenade.cooldown_left = maxf(grenade.cooldown_left - delta, 0.0)
	if Input.is_action_just_pressed(&"grenade"):
		throw_grenade()


## Можно ли бросить сейчас.
func can_throw() -> bool:
	var grenade: GrenadeInstance = Inventory.grenade
	return grenade != null and grenade.is_ready() and _player != null and not _player.get("is_dead")


## Бросок. Возвращает летящую гранату или null, если бросить нельзя.
func throw_grenade() -> GrenadeProjectile:
	if not can_throw():
		refused.emit()
		return null
	var grenade: GrenadeInstance = Inventory.grenade
	var settings: GrenadeSettings = Config.data.grenades
	var projectile: GrenadeProjectile = GrenadeProjectile.from_instance(grenade, settings)
	var forward: Vector3 = -_camera.global_basis.z
	_player.get_parent().add_child(projectile)
	projectile.global_position = _camera.global_position + forward * 0.5 + Vector3(0.0, -0.15, 0.0)
	projectile.linear_velocity = forward * settings.throw_speed + Vector3.UP * settings.throw_lift + _player.velocity * 0.5
	projectile.angular_velocity = Vector3(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
	grenade.cooldown_left = grenade.compute_stats().cooldown
	thrown.emit(projectile)
	Inventory.changed.emit()
	return projectile
