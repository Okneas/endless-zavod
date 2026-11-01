class_name EnemySpawner
extends Node3D
## Точка появления врага. Ставится в комнату, создаёт врага на своём месте, при желании
## возвращает его после смерти (для тестовой комнаты). В забеге врагов расставит генератор (срез 6).

signal spawned(enemy: Enemy)

## Сцена врага (chaser.tscn, flyer.tscn, turret.tscn, support.tscn).
@export var enemy_scene: PackedScene
## Через сколько секунд враг появляется снова после смерти. 0 — не появляется.
@export_range(0.0, 120.0, 0.5, "suffix:с") var respawn_time: float = 0.0

var enemy: Enemy


func _ready() -> void:
	_spawn()


func _spawn() -> void:
	if enemy_scene == null or not is_inside_tree():
		return
	enemy = enemy_scene.instantiate() as Enemy
	add_child(enemy)
	enemy.died.connect(_on_enemy_died)
	spawned.emit(enemy)


func _on_enemy_died(_dead: Enemy) -> void:
	if respawn_time > 0.0:
		get_tree().create_timer(respawn_time).timeout.connect(_spawn)
