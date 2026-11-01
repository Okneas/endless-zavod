class_name ShopFloor
extends Node3D
## Торговый зал магазина-хаба (срез 8, №88): пока магазин открыт, раз в customer_interval секунд (ночью реже, №88) впускает покупателя
## со случайными предпочтениями и бюджетом и строит ему маршрут по прилавкам с товаром (№89). Закрытие магазина отправляет всех покупателей домой.

## Новый покупатель вошёл в зал.
signal customer_entered(customer: Customer)

## Сколько секунд после открытия магазина до первого покупателя.
const FIRST_CUSTOMER_DELAY: float = 3.0
## Доля пути от входа до прилавков, на которую заходит покупатель, когда смотреть нечего.
const LOBBY_DEPTH: float = 0.3
## Прогулка по залу: доля пути от прилавков к входу (от и до).
const WANDER_DEPTH_MIN: float = 0.2
const WANDER_DEPTH_MAX: float = 0.5

var counters: Array[ShopCounter] = []
var register: ShopRegister
## Откуда покупатели входят и куда уходят (за дверью зала).
var entrance: Vector3 = Vector3.ZERO
var customers: Array[Customer] = []
## Приходят ли покупатели сами по таймеру. Проверки выключают, чтобы вести только своих покупателей.
var auto_spawn: bool = true

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _spawn_left: float = 0.0
var _was_open: bool = false


func setup(p_counters: Array[ShopCounter], p_register: ShopRegister, p_entrance: Vector3) -> void:
	counters = p_counters
	register = p_register
	entrance = p_entrance
	_rng.randomize()


func _process(delta: float) -> void:
	if Shop.is_open and not _was_open:
		_spawn_left = FIRST_CUSTOMER_DELAY
	if not Shop.is_open and _was_open:
		send_all_home()
	_was_open = Shop.is_open
	if not Shop.is_open or not auto_spawn:
		return
	_spawn_left -= delta
	if _spawn_left > 0.0:
		return
	var settings: ShopSettings = Config.data.shop
	_spawn_left = ShopMath.customer_interval(settings, GameClock.is_night) * _rng.randf_range(0.75, 1.25)
	if customers.size() < settings.max_customers:
		spawn_customer()


## Впустить покупателя (случайного или заданного, для проверок). Возвращает его.
func spawn_customer(profile: CustomerProfile = null) -> Customer:
	var settings: ShopSettings = Config.data.shop
	if profile == null:
		profile = CustomerProfile.roll(settings, Config.data.weapons, _rng, Progress.world_level)
	var customer: Customer = Customer.new()
	customer.setup(profile, _plan_route(profile, settings), lobby_point(), register, entrance, _rng, random_hall_point)
	add_child(customer)
	customer.global_position = entrance
	customers.append(customer)
	customer.left.connect(_on_customer_left)
	customer_entered.emit(customer)
	return customer


## Закрытие магазина: все покупатели возвращают товар на место и уходят.
func send_all_home() -> void:
	for customer: Customer in customers.duplicate():
		if is_instance_valid(customer):
			customer.leave_now()


# Маршрут покупателя (№89): от одного до max_visits разных прилавков, на которых лежит товар (к пустым не ходит). Прилавки с подходящим
# ему по вкусу и по карману товаром выбираются охотнее (вес taste_weight). Идёт вдоль стены в одну сторону, случайную.
func _plan_route(profile: CustomerProfile, settings: ShopSettings) -> Array[ShopCounter]:
	var pool: Array[ShopCounter] = []
	for counter: ShopCounter in counters:
		if counter.get_slot().is_free():
			pool.append(counter)
	var visits: int = mini(_rng.randi_range(1, maxi(settings.max_visits, 1)), pool.size())
	var route: Array[ShopCounter] = []
	for i: int in visits:
		var weights: Array[float] = []
		var total: float = 0.0
		for counter: ShopCounter in pool:
			var slot: ShopSlot = counter.get_slot()
			var interesting: bool = ShopMath.matches(profile, slot.item) and slot.price <= profile.budget
			weights.append(maxf(settings.taste_weight, 1.0) if interesting else 1.0)
			total += weights[weights.size() - 1]
		var roll: float = _rng.randf() * total
		var picked: int = pool.size() - 1
		for j: int in pool.size():
			roll -= weights[j]
			if roll <= 0.0:
				picked = j
				break
		route.append(pool[picked])
		pool.remove_at(picked)
	var left_to_right: bool = _rng.randf() < 0.5
	route.sort_custom(func(a: ShopCounter, b: ShopCounter) -> bool: return (a.global_position.x < b.global_position.x) == left_to_right)
	return route


## Куда идёт покупатель, когда смотреть нечего: чуть вглубь зала от входа, оглядеться.
func lobby_point() -> Vector3:
	return entrance.lerp(_stands_center(), LOBBY_DEPTH)


## Случайная точка для прогулки в середине зала между входом и прилавками (на сетке навигации, если она готова).
func random_hall_point() -> Vector3:
	var low: float = INF
	var high: float = -INF
	var stand_z: float = 0.0
	for counter: ShopCounter in counters:
		var stand: Vector3 = counter.stand_point()
		low = minf(low, stand.x)
		high = maxf(high, stand.x)
		stand_z = stand.z
	var point: Vector3 = Vector3(_rng.randf_range(low, high), entrance.y, lerpf(stand_z, entrance.z, _rng.randf_range(WANDER_DEPTH_MIN, WANDER_DEPTH_MAX)))
	var map: RID = get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) > 0 and not NavigationServer3D.map_get_regions(map).is_empty():
		point = NavigationServer3D.map_get_closest_point(map, point)
	return point


# Центр точек, где стоят покупатели у прилавков.
func _stands_center() -> Vector3:
	var sum: Vector3 = Vector3.ZERO
	for counter: ShopCounter in counters:
		sum += counter.stand_point()
	return sum / float(maxi(counters.size(), 1))


func _on_customer_left(customer: Customer) -> void:
	customers.erase(customer)
