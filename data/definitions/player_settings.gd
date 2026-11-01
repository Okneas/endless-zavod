class_name PlayerSettings
extends Resource
## Общие настройки игрока. Данные: data/content/balance/player_settings.tres.
## В Inspector открываются у узла Player (поле Settings) или двойным щелчком по .tres.
## Значения по умолчанию нейтральные: баланс лежит только в .tres, а не в коде.

## Здоровье на старте, брони нет (№37).
@export_range(1, 1000, 1) var max_health: int = 0
## Шанс крита игрока на старте (0.02 = 2%, №37). Складывается с критом оружия.
@export_range(0.0, 1.0, 0.01) var crit_chance: float = 0.0
## Чувствительность мыши, радиан на пиксель. Стартовое значение требует проверки.
@export_range(0.0005, 0.02, 0.0001) var mouse_sensitivity: float = 0.0
## Горизонтальный угол обзора. Стартовое значение требует проверки.
@export_range(60.0, 130.0, 1.0, "suffix:°") var field_of_view: float = 0.0
