extends RefCounted
## Помощник тестов (№81): тело с капсулой игрока идёт по пути сетки навигации физически (стены, пандусы, заглушки, двери,
## лестницы стыков). Сетка навигации разрешает ступеньки до одной ячейки высоты (0.3 м), а капсула без прыжка берёт только
## около 0.1 м, поэтому при застревании тело прыгает, как игрок (прыжок игрока 1.9 м), и считает прыжки: если их много, на
## пути настоящая преграда, а не ступенька. Подключается через preload, сам по себе не запускается.

const RADIUS: float = 0.4
const HEIGHT: float = 1.8
const STALL_FRAMES: int = 20
const JUMP_SPEED: float = 6.0
const GRAVITY: float = 30.0
const PHYSICS_FPS: float = 120.0


## Возвращает Vector3(остаток по горизонтали, остаток по вертикали, число прыжков). parent: узел в мире зоны.
static func walk(parent: Node, map: RID, from: Vector3, to: Vector3, speed: float, limit_seconds: float = 400.0) -> Vector3:
	var tree: SceneTree = parent.get_tree()
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, from, to, true)
	var body: CharacterBody3D = CharacterBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 1
	body.floor_max_angle = deg_to_rad(45.0)
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = HEIGHT * 0.5
	body.add_child(shape)
	parent.add_child(body)
	body.global_position = from + Vector3(0.0, 0.05, 0.0)
	var frames_left: int = int(PHYSICS_FPS * limit_seconds)
	var jumps: int = 0
	var stalled: int = 0
	for i: int in range(1, path.size()):
		var goal: Vector3 = path[i]
		while frames_left > 0:
			var flat: Vector3 = Vector3(goal.x - body.global_position.x, 0.0, goal.z - body.global_position.z)
			if flat.length() < 0.5:
				break
			var before: Vector3 = body.global_position
			body.velocity.x = flat.normalized().x * speed
			body.velocity.z = flat.normalized().z * speed
			body.velocity.y = 0.0 if body.is_on_floor() else body.velocity.y - GRAVITY / PHYSICS_FPS
			if stalled >= STALL_FRAMES and body.is_on_floor():
				body.velocity.y = JUMP_SPEED
				stalled = 0
				jumps += 1
			body.move_and_slide()
			await tree.physics_frame
			frames_left -= 1
			if Vector2(body.global_position.x - before.x, body.global_position.z - before.z).length() < speed / PHYSICS_FPS * 0.3:
				stalled += 1
			else:
				stalled = 0
	var left: Vector3 = to - body.global_position
	body.queue_free()
	return Vector3(Vector2(left.x, left.z).length(), absf(left.y), float(jumps))
