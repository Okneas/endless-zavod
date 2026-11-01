class_name Customer
extends Node3D
## Покупатель магазина-хаба (срез 8, №88, переделан в №89 по Moonlighter, 05-shop-economy): заходит, обходит несколько прилавков с товаром
## (маршрут задаёт ShopFloor), на каждом разглядывает и показывает реакцию на цену. Товар «не по вкусу» (тип оружия, производитель)
## он только отмечает («Не моё») и идёт дальше. На подходящем решает по шансу покупки (№6): берёт и идёт к кассе или переходит к следующему
## прилавку. Между осмотрами иногда прогуливается по залу. К пустым прилавкам не подходит. У кассы ждёт register_patience секунд,
## над головой значок настроения по остатку терпения; не дождался (№88): уходит, товар остаётся на прилавке. Ходит по сетке навигации
## зала (обходит прилавки и кассу) и сторонится других покупателей и игрока. Модель временная: капсула цвета любимого производителя.

enum State { WALK_TO_COUNTER, INSPECT, WALK_TO_REGISTER, WAIT_REGISTER, LEAVE, WANDER }

## Покупатель ушёл из магазина (вышел или не нашёл ничего подходящего).
signal left(customer: Customer)

const ARRIVE_DISTANCE: float = 0.15
const LABEL_HEIGHT: float = 2.3
const MOOD_HEIGHT: float = 2.8
## Сколько секунд покупатель оглядывается у входа, когда на прилавках нечего смотреть.
const LOOK_AROUND_SECONDS: float = 1.8
## Расхождение (№89): ближе этих расстояний покупатель отходит от другого покупателя и от игрока, у самой цели расхождение выключено.
const SEPARATION_RADIUS: float = 1.0
const PLAYER_AVOID_RADIUS: float = 1.4
const SEPARATION_WEIGHT: float = 1.5
## Доля отталкивания назад в расхождении (остальное боковой уход).
const AWAY_SHARE: float = 0.6
const AVOID_OFF_DISTANCE: float = 1.2
const NAV_REACHED_DISTANCE: float = 0.35
const REPATH_SECONDS: float = 0.5
const REACTION_COLORS: Dictionary = {
	ShopMath.Reaction.CHEAP: Color(0.5, 1.0, 0.55),
	ShopMath.Reaction.FAIR: Color(1.0, 1.0, 1.0),
	ShopMath.Reaction.EXPENSIVE: Color(1.0, 0.75, 0.35),
	ShopMath.Reaction.TOO_EXPENSIVE: Color(1.0, 0.4, 0.35),
}
const NOT_MINE_COLOR: Color = Color(0.7, 0.72, 0.8)
## Значок настроения у кассы: от какой доли оставшегося терпения он показывается (по убыванию), знак и цвет. Это не слова, а значки,
## поэтому не через таблицу переводов.
const MOODS: Array = [
	{"from": 0.6, "text": "^_^", "color": Color(0.5, 1.0, 0.55)},
	{"from": 0.3, "text": "-_-", "color": Color(1.0, 0.85, 0.35)},
	{"from": 0.0, "text": ">_<", "color": Color(1.0, 0.4, 0.35)},
]

var profile: CustomerProfile
## Маршрут по прилавкам с товаром (пустой, если смотреть нечего).
var route: Array[ShopCounter] = []
## Место, которое покупатель сейчас разглядывает или несёт к кассе (null, если сейчас ничего).
var slot: ShopSlot
var state: State = State.WALK_TO_COUNTER
## Последняя реакция на цену (-1, если товар не его) и шанс покупки, чтобы можно было проверить и показать.
var last_reaction: int = -1
var last_chance: float = 0.0
## Подходил ли последний осмотренный товар по вкусу.
var last_matched: bool = false
## Сколько прилавков покупатель осмотрел.
var visited: int = 0

var _settings: ShopSettings
var _rng: RandomNumberGenerator
var _lobby_point: Vector3
var _register: ShopRegister
var _exit_point: Vector3
## Откуда брать точку прогулки (Callable без аргументов -> Vector3).
var _wander_source: Callable
var _route_index: int = 0
var _target: Vector3
var _wander_arrived: bool = false
var _timer: float = 0.0
var _label: Label3D
var _label_left: float = 0.0
var _mood_label: Label3D
var _body_material: StandardMaterial3D
var _agent: NavigationAgent3D
var _nav_target: Vector3 = Vector3(INF, INF, INF)
var _repath_left: float = 0.0


func setup(p_profile: CustomerProfile, p_route: Array[ShopCounter], p_lobby_point: Vector3, p_register: ShopRegister, p_exit_point: Vector3, p_rng: RandomNumberGenerator, p_wander_source: Callable = Callable()) -> void:
	profile = p_profile
	route = p_route
	_lobby_point = p_lobby_point
	_register = p_register
	_exit_point = p_exit_point
	_rng = p_rng
	_wander_source = p_wander_source
	_settings = Config.data.shop
	_target = route[0].stand_point() if not route.is_empty() else _lobby_point


func _ready() -> void:
	name = "Customer"
	add_to_group(&"customers")
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = 0.35
	mesh.height = 1.7
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = profile.color if profile != null else Color.WHITE
	mesh.material = _body_material
	var body: MeshInstance3D = MeshInstance3D.new()
	body.mesh = mesh
	body.position = Vector3(0.0, 0.85, 0.0)
	add_child(body)
	_label = _make_label(LABEL_HEIGHT, 48)
	_mood_label = _make_label(MOOD_HEIGHT, 56)


func _make_label(height: float, font_size: int) -> Label3D:
	var label: Label3D = Label3D.new()
	label.font_size = font_size
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(0.0, height, 0.0)
	add_child(label)
	return label


# Если покупателя убрали вместе со сценой, не отдав товар, прилавок не должен остаться «занятым».
func _exit_tree() -> void:
	if slot != null:
		slot.carried = false
		slot.holder = null
	if _register != null:
		_register.dequeue(self)


func _process(delta: float) -> void:
	_label_left = maxf(_label_left - delta, 0.0)
	if _label_left <= 0.0:
		_label.text = ""
	_update_mood()
	match state:
		State.WALK_TO_COUNTER:
			if _move_to(_target, delta):
				_arrive_at_counter()
		State.INSPECT:
			_timer -= delta
			if _timer <= 0.0:
				_decide()
		State.WANDER:
			if not _wander_arrived:
				if _move_to(_target, delta):
					_wander_arrived = true
					_timer = _rng.randf_range(_settings.wander_pause_min, maxf(_settings.wander_pause_min, _settings.wander_pause_max))
			else:
				_timer -= delta
				if _timer <= 0.0:
					_walk_to_next_counter()
		State.WALK_TO_REGISTER:
			if _move_to(_register.queue_point(_queue_index()), delta):
				state = State.WAIT_REGISTER
				_timer = _settings.register_patience
		State.WAIT_REGISTER:
			if _move_to(_register.queue_point(_queue_index()), delta):
				_face(_register.global_position)
			_timer -= delta
			if _timer <= 0.0:
				_give_up()
		State.LEAVE:
			if _move_to(_exit_point, delta):
				left.emit(self)
				queue_free()


## Стоит ли покупатель у кассы первым и ждёт оплаты.
func is_waiting_at_register() -> bool:
	return state == State.WAIT_REGISTER and _queue_index() == 0 and global_position.distance_to(_register.queue_point(0)) < 0.5


## Несёт ли покупатель товар (взял, но ещё не заплатил).
func is_carrying() -> bool:
	return slot != null and slot.carried


## Значок настроения, который сейчас над головой (пустая строка, если не у кассы).
func get_mood_text() -> String:
	return _mood_label.text


## Игрок принял оплату на кассе: деньги в Shop, покупатель уходит с товаром.
func pay() -> void:
	if slot == null or not slot.carried:
		return
	var paid: int = Shop.complete_sale(slot)
	profile.budget = maxi(profile.budget - paid, 0)
	_register.dequeue(self)
	slot = null
	_say(tr("HUB_THANKS"), Color(0.5, 1.0, 0.55), 2.0)
	state = State.LEAVE


## Магазин закрыли или игрок ушёл в забег: покупатель возвращает товар на прилавок и уходит.
func leave_now() -> void:
	if state == State.LEAVE:
		return
	if slot != null:
		slot.carried = false
		slot.holder = null
		Shop.changed.emit()
		slot = null
	_register.dequeue(self)
	state = State.LEAVE


# Дошёл до прилавка маршрута (или до точки у входа, если смотреть нечего): начинает осмотр.
func _arrive_at_counter() -> void:
	if route.is_empty():
		state = State.INSPECT
		slot = null
		_say(tr("HUB_NOTHING"), Color(0.8, 0.8, 0.8), LOOK_AROUND_SECONDS)
		_timer = LOOK_AROUND_SECONDS
		return
	var candidate: ShopSlot = route[_route_index].get_slot()
	if not candidate.is_free():
		# Товар успели убрать или его уже смотрит другой: идём дальше, не подходя к пустому месту.
		_next_stop()
		return
	slot = candidate
	slot.holder = self
	visited += 1
	state = State.INSPECT
	_face(route[_route_index].global_position)
	if not ShopMath.matches(profile, slot.item):
		last_matched = false
		last_reaction = -1
		last_chance = 0.0
		_say(tr("HUB_REACT_NOT_MINE"), NOT_MINE_COLOR, _settings.inspect_time * _settings.not_mine_time_factor)
		_timer = _settings.inspect_time * _settings.not_mine_time_factor
		return
	last_matched = true
	var actual: int = slot.item.get_price()
	# Что не по карману, то и «слишком дорого»: покупатель не станет присматриваться к тому, чего не потянет.
	last_chance = ShopMath.purchase_chance(slot.price, actual, profile.unwillingness) if slot.price <= profile.budget else 0.0
	last_reaction = ShopMath.reaction(_settings, slot.price, actual, last_chance)
	_say(tr("HUB_REACT_" + ShopMath.Reaction.keys()[last_reaction]), REACTION_COLORS[last_reaction], _settings.inspect_time)
	_timer = _settings.inspect_time


# Решение после осмотра (№6): подходящий товар берётся по шансу покупки, иначе покупатель идёт дальше по маршруту.
func _decide() -> void:
	if slot == null:
		_start_leaving()
		return
	if not last_matched:
		_next_stop()
		return
	var buys: bool = _rng.randf() * 100.0 < last_chance and slot.price <= profile.budget
	if not buys:
		_say(tr("HUB_DECLINE"), Color(1.0, 0.6, 0.5), 2.0)
		_next_stop()
		return
	slot.carried = true
	Shop.changed.emit()
	_register.enqueue(self)
	state = State.WALK_TO_REGISTER


# К следующему прилавку маршрута, иногда с прогулкой по залу, или к выходу, если маршрут кончился.
func _next_stop() -> void:
	_release_slot()
	_route_index += 1
	if _route_index >= route.size():
		_start_leaving()
		return
	if _wander_source.is_valid() and _rng.randf() < _settings.wander_chance:
		_target = _wander_source.call()
		_wander_arrived = false
		state = State.WANDER
		return
	_walk_to_next_counter()


func _walk_to_next_counter() -> void:
	_target = route[_route_index].stand_point()
	state = State.WALK_TO_COUNTER


func _start_leaving() -> void:
	_release_slot()
	state = State.LEAVE


# Отпускает осматриваемый товар (не взятый).
func _release_slot() -> void:
	if slot != null and not slot.carried:
		slot.holder = null
		slot = null


func _give_up() -> void:
	_register.dequeue(self)
	slot.carried = false
	slot.holder = null
	slot = null
	Shop.changed.emit()
	_say(tr("HUB_GAVE_UP"), Color(1.0, 0.6, 0.5), 2.5)
	state = State.LEAVE


func _queue_index() -> int:
	var index: int = _register.queue.find(self)
	return index if index >= 0 else 0


func _say(text: String, color: Color, seconds: float) -> void:
	_label.text = text
	_label.modulate = color
	_label_left = seconds


# Значок настроения по остатку терпения у кассы.
func _update_mood() -> void:
	if state != State.WAIT_REGISTER or _settings.register_patience <= 0.0:
		_mood_label.text = ""
		return
	var left_share: float = clampf(_timer / _settings.register_patience, 0.0, 1.0)
	for mood: Dictionary in MOODS:
		if left_share >= float(mood["from"]):
			_mood_label.text = mood["text"]
			_mood_label.modulate = mood["color"]
			return


func _face(point: Vector3) -> void:
	var flat: Vector3 = Vector3(point.x - global_position.x, 0.0, point.z - global_position.z)
	if flat.length() > 0.01:
		rotation.y = atan2(-flat.x, -flat.z)


# Шаг к точке: по сетке навигации зала (если она готова, иначе прямо), с расхождением от других покупателей и игрока.
# Возвращает true, когда дошёл.
func _move_to(point: Vector3, delta: float) -> bool:
	var flat: Vector3 = Vector3(point.x - global_position.x, 0.0, point.z - global_position.z)
	var distance: float = flat.length()
	if distance <= ARRIVE_DISTANCE:
		return true
	var direction: Vector3 = _path_direction(point, flat / distance, delta)
	if distance > AVOID_OFF_DISTANCE:
		direction = (direction + _avoidance(direction) * SEPARATION_WEIGHT).normalized()
	global_position += direction * minf(_settings.walk_speed * delta, distance)
	rotation.y = atan2(-direction.x, -direction.z)
	return Vector2(point.x - global_position.x, point.z - global_position.z).length() <= ARRIVE_DISTANCE


func _path_direction(point: Vector3, direct: Vector3, delta: float) -> Vector3:
	var map: RID = get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0 or NavigationServer3D.map_get_regions(map).is_empty():
		return direct
	if _agent == null:
		_agent = NavigationAgent3D.new()
		_agent.path_desired_distance = NAV_REACHED_DISTANCE
		_agent.target_desired_distance = NAV_REACHED_DISTANCE
		add_child(_agent)
	_repath_left -= delta
	if _repath_left <= 0.0 or _nav_target.distance_to(point) > 0.3:
		_agent.target_position = point
		_nav_target = point
		_repath_left = REPATH_SECONDS
	if _agent.is_navigation_finished():
		return direct
	var to_next: Vector3 = _agent.get_next_path_position() - global_position
	to_next.y = 0.0
	if to_next.length() < 0.05:
		return direct
	return to_next.normalized()


# Отталкивание от других покупателей и от игрока (№89): ближе радиуса тем сильнее, у цели не действует. К отталкиванию добавлен
# боковой уход мимо препятствия, иначе при встрече лоб в лоб покупатель застрял бы перед ним.
func _avoidance(direction: Vector3) -> Vector3:
	var push: Vector3 = Vector3.ZERO
	for other: Node in get_tree().get_nodes_in_group(&"customers"):
		if other != self:
			push += _push_from((other as Node3D).global_position, SEPARATION_RADIUS, direction)
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if player != null:
		push += _push_from(player.global_position, PLAYER_AVOID_RADIUS, direction)
	return push


func _push_from(point: Vector3, radius: float, direction: Vector3) -> Vector3:
	var away: Vector3 = global_position - point
	away.y = 0.0
	var distance: float = away.length()
	if distance >= radius or distance < 0.001:
		return Vector3.ZERO
	var strength: float = 1.0 - distance / radius
	# Препятствие справа (cross > 0): уходим влево, слева: вправо. Прямо по курсу: сторона по чётности номера.
	var cross: float = direction.x * -away.z - direction.z * -away.x
	var left: bool = cross > 0.0 or (is_zero_approx(cross) and get_instance_id() % 2 == 0)
	var lateral: Vector3 = Vector3(direction.z, 0.0, -direction.x) * (1.0 if left else -1.0)
	return (away / distance * AWAY_SHARE + lateral) * strength
