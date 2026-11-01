class_name ClockSettings
extends Resource
## Настройки игровых часов. Данные: data/content/balance/clock_settings.tres.
## Значения по умолчанию нейтральные: баланс лежит только в .tres, а не в коде.

## Длительность дня, секунды. Стартовое значение 720 (12 минут), предложение автора, №35.
@export var day_duration_seconds: float = 0.0
## Длительность ночи, секунды. Стартовое значение 480 (8 минут), предложение автора, №35.
@export var night_duration_seconds: float = 0.0
## Смещение старта часов от начала дня, секунды. 0 = игра стартует с начала дня.
## Стартовое значение выбрано ассистентом, требует проверки.
@export var start_offset_seconds: float = 0.0
