extends Node
## Единый источник игровых суток: идут в хабе, городе и забеге (№35).
## Пауза: узел в режиме PAUSABLE (по умолчанию), поэтому при get_tree().paused
## часы стоят сами. Когда ставить паузу, решает инвентарь по флагу Config.data.pause_in_run.

## Сменилась фаза суток: true = наступила ночь, false = наступил день.
signal phase_changed(is_night: bool)
## Начались новые сутки.
signal day_started(day_index: int)

## Номер суток, начиная с 1.
var day_index: int = 1
## Секунды от начала дня в текущих сутках.
var time_in_cycle: float = 0.0
var is_night: bool = false

var _day_duration: float = 0.0
var _cycle_duration: float = 0.0


func _ready() -> void:
	var settings: ClockSettings = Config.data.clock
	_day_duration = settings.day_duration_seconds
	_cycle_duration = settings.day_duration_seconds + settings.night_duration_seconds
	assert(_cycle_duration > 0.0, "Длительность суток должна быть больше нуля")
	reset()


func _process(delta: float) -> void:
	advance(delta)


## Возвращает часы к началу игры. Сигналы не шлёт: это исходное состояние, а не смена.
func reset() -> void:
	var settings: ClockSettings = Config.data.clock
	day_index = 1
	time_in_cycle = fposmod(settings.start_offset_seconds, _cycle_duration)
	is_night = time_in_cycle >= _day_duration


## Переключает фазу суток сразу (отладка, №89): день с его начала, ночь с её начала. Номер суток не меняется, сигнал фазы приходит.
func set_phase(night: bool) -> void:
	if night == is_night:
		return
	is_night = night
	time_in_cycle = _day_duration if night else 0.0
	phase_changed.emit(night)


## Двигает время вперёд. Вынесено из _process, чтобы проверять логику без реального времени.
## Большой delta может пересечь несколько границ фаз, сигналы придут по каждой.
func advance(delta: float) -> void:
	assert(delta >= 0.0, "Время не идёт назад")
	time_in_cycle += delta
	while true:
		if is_night:
			if time_in_cycle < _cycle_duration:
				break
			time_in_cycle -= _cycle_duration
			day_index += 1
			is_night = false
			phase_changed.emit(false)
			day_started.emit(day_index)
		else:
			if time_in_cycle < _day_duration:
				break
			is_night = true
			phase_changed.emit(true)
