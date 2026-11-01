extends Control
## Дуга патронов слева от прицела (набросок автора в 11-UI-design): один штрих на патрон,
## без цифр (число патронов показывает счётчик справа снизу). Во время перезарядки штрихи
## заполняются по мере прогресса. Узел стоит в центре прицела, начало координат и есть центр.
## При большом разбросе дуга отодвигается вслед за крестом, чтобы плечи креста её не перекрывали:
## наружу она уезжает мгновенно, обратно возвращается плавно.

## Радиус дуги при спокойном прицеле.
@export var radius: float = 34.0
## Зазор между плечами креста и дугой, когда дугу отодвигает крест.
@export var clearance_margin: float = 8.0
## Как быстро дуга возвращается внутрь, когда разброс падает.
@export var return_speed: float = 140.0
## Края дуги в градусах (отсчёт по часовой стрелке от «вправо»: 180 это влево).
@export var start_degrees: float = 135.0
@export var end_degrees: float = 225.0
@export var line_width: float = 3.0
@export var color_full: Color = Color(1.0, 1.0, 1.0, 0.95)
@export var color_empty: Color = Color(1.0, 1.0, 1.0, 0.18)
@export var color_reload: Color = Color(1.0, 0.8, 0.3, 0.95)

var _ammo: int = 0
var _capacity: int = 0
## Прогресс перезарядки 0..1, или -1, если перезарядки нет.
var _reload_progress: float = -1.0
var _current_radius: float = 0.0
var _clearance: float = 0.0


func _ready() -> void:
	_current_radius = radius


func _process(delta: float) -> void:
	var target: float = maxf(radius, _clearance + clearance_margin) if _clearance > 0.0 else radius
	var next: float = target if target > _current_radius else move_toward(_current_radius, target, return_speed * delta)
	if not is_equal_approx(next, _current_radius):
		_current_radius = next
		queue_redraw()


## Внешний радиус креста: дуга не заходит внутрь него. 0, если крест скрыт.
func set_clearance(outer_radius: float) -> void:
	_clearance = outer_radius


## Радиус, на котором дуга нарисована сейчас.
func get_current_radius() -> float:
	return _current_radius


func set_state(ammo: int, capacity: int, reload_progress: float) -> void:
	if ammo == _ammo and capacity == _capacity and is_equal_approx(reload_progress, _reload_progress):
		return
	_ammo = ammo
	_capacity = capacity
	_reload_progress = reload_progress
	queue_redraw()


func _draw() -> void:
	if _capacity <= 0:
		return
	var reloading: bool = _reload_progress >= 0.0
	var filled: int = roundi(_capacity * _reload_progress) if reloading else _ammo
	var start: float = deg_to_rad(start_degrees)
	var segment: float = deg_to_rad(end_degrees - start_degrees) / float(_capacity)
	var gap: float = segment * 0.3
	for i: int in _capacity:
		var from_angle: float = start + segment * i + gap * 0.5
		var color: Color = color_empty
		if i < filled:
			color = color_reload if reloading else color_full
		draw_arc(Vector2.ZERO, _current_radius, from_angle, from_angle + segment - gap, 6, color, line_width, true)
