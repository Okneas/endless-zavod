class_name DashIndicator
extends Control
## Заряды рывка (срез 7б, №83): по штриху на заряд под прицелом. Полный заряд светлый, восстанавливающийся заполняется слева
## направо по мере накопления, пустой тёмный. Игрока читает сам, в HUD только привязывается через bind().

@export var pip_width: float = 40.0
@export var pip_height: float = 6.0
@export var gap: float = 8.0
@export var color_full: Color = Color(0.75, 0.95, 1.0, 0.95)
@export var color_charging: Color = Color(0.75, 0.95, 1.0, 0.5)
@export var color_empty: Color = Color(1.0, 1.0, 1.0, 0.15)

var _player: Player


func bind(player: Player) -> void:
	_player = player
	var count: int = player.movement.dash_charges_max
	custom_minimum_size = Vector2(float(count) * pip_width + float(maxi(count - 1, 0)) * gap, pip_height)
	size = custom_minimum_size


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _player == null:
		return
	var count: int = _player.movement.dash_charges_max
	var progress: float = _player.get_dash_recharge_progress()
	for i: int in count:
		var rect: Rect2 = Rect2(Vector2(float(i) * (pip_width + gap), 0.0), Vector2(pip_width, pip_height))
		draw_rect(rect, color_empty)
		if i < _player.dash_charges:
			draw_rect(rect, color_full)
		elif i == _player.dash_charges:
			draw_rect(Rect2(rect.position, Vector2(pip_width * progress, pip_height)), color_charging)
