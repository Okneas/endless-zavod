class_name EnemyProjectile
extends Node3D
## Медленный снаряд турели: от него можно увернуться движением (решение автора). Каждый
## шаг физики проверяет отрезок пути лучом, поэтому сквозь тонкие стены и игрока не пролетает.

## Слои, с которыми снаряд сталкивается: 1 «world» и 2 «player».
const HIT_MASK: int = 3
const RADIUS: float = 0.15

var velocity: Vector3 = Vector3.ZERO
var damage: float = 0.0
var lifetime: float = 0.0
## Радиус снаряда: только вид (попадание считается по лучу вдоль пути).
var radius: float = RADIUS

var _age: float = 0.0


static func spawn(parent: Node, at: Vector3, p_velocity: Vector3, p_damage: float, p_lifetime: float, p_radius: float = 0.0) -> EnemyProjectile:
	if parent == null or not parent.is_inside_tree():
		return null
	var projectile: EnemyProjectile = EnemyProjectile.new()
	projectile.velocity = p_velocity
	projectile.damage = p_damage
	projectile.lifetime = p_lifetime
	projectile.radius = p_radius if p_radius > 0.0 else RADIUS
	parent.add_child(projectile)
	projectile.global_position = at
	return projectile


func _ready() -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.45, 0.15)
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.material = material
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.mesh = mesh
	add_child(visual)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > lifetime:
		queue_free()
		return
	var next: Vector3 = global_position + velocity * delta
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position, next, HIT_MASK)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var player: Player = hit["collider"] as Player
		if player != null and player.is_invulnerable():
			# Рывок: снаряд пролетает сквозь игрока.
			global_position = next
			return
		if player != null:
			player.take_damage(damage, global_position)
		queue_free()
		return
	global_position = next
