extends Control
## Прицел-крест (по наброску автора, 11-UI-design). Рисуется кодом, картинок нет.
## Узел стоит в центре экрана, начало координат Control и есть центр прицела.
## Расходится вслед за разбросом оружия и вспыхивает при попадании по цели.

@export var arm_length: float = 9.0
@export var gap: float = 5.0
@export var thickness: float = 2.0
@export var outline: float = 1.0
@export var color: Color = Color.WHITE
@export var outline_color: Color = Color(0.0, 0.0, 0.0, 0.8)
## Цвет вспышки при попадании и при крите.
@export var hit_color: Color = Color(1.0, 0.35, 0.3)
@export var crit_color: Color = Color(1.0, 0.85, 0.2)
## Как быстро гаснет вспышка попадания (больше — быстрее).
@export var flash_fade_speed: float = 6.0
## Прозрачность креста при полном прицеливании: целимся через прицел оружия, крест не нужен.
## 0 — скрыт совсем (вспышка попадания остаётся), 1 — виден как обычно.
@export_range(0.0, 1.0, 0.05) var aiming_alpha: float = 0.0

var _extra_gap: float = 0.0
var _flash: float = 0.0
var _flash_color: Color = Color.WHITE
var _aim: float = 0.0


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta * flash_fade_speed, 0.0)
		queue_redraw()


## Раздвигает прицел на столько пикселей: показывает текущий разброс оружия.
func set_spread_pixels(pixels: float) -> void:
	if not is_equal_approx(_extra_gap, pixels):
		_extra_gap = pixels
		queue_redraw()


## Насколько включено прицеливание (0..1): крест плавно гаснет до aiming_alpha.
func set_aim(amount: float) -> void:
	if not is_equal_approx(_aim, amount):
		_aim = amount
		queue_redraw()


## Внешний радиус креста (до конца плеч с контуром), пока крест виден. Скрытый крест (прицеливание) даёт 0.
## По нему дуга патронов держится снаружи и не перекрывается плечами при большом разбросе.
func get_outer_radius() -> float:
	if _visible_alpha() <= 0.05:
		return 0.0
	return gap + _extra_gap + arm_length + outline


func flash(is_crit: bool) -> void:
	_flash = 1.0
	_flash_color = crit_color if is_crit else hit_color
	queue_redraw()


# Видимость креста: гаснет при прицеливании, вспышка попадания остаётся видимой.
func _visible_alpha() -> float:
	return maxf(lerpf(1.0, aiming_alpha, _aim), _flash)


func _draw() -> void:
	var line_color: Color = color.lerp(_flash_color, _flash)
	var alpha: float = _visible_alpha()
	if alpha <= 0.0:
		return
	line_color.a *= alpha
	var shadow_color: Color = outline_color
	shadow_color.a *= alpha
	var inner_gap: float = gap + _extra_gap
	for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var from: Vector2 = direction * inner_gap
		var to: Vector2 = direction * (inner_gap + arm_length)
		# Сначала чуть более толстая тёмная линия: контур, чтобы прицел читался на любом фоне.
		draw_line(from - direction * outline, to + direction * outline, shadow_color, thickness + outline * 2.0)
		draw_line(from, to, line_color, thickness)
