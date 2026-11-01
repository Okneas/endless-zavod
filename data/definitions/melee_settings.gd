class_name MeleeSettings
extends Resource
## Удар в ближнем бою на одну кнопку (V). Данные: data/content/balance/melee_settings.tres.
## В Inspector открываются у узла Melee внутри Player (поле Settings) или двойным щелчком по .tres.
## Значения по умолчанию нейтральные: баланс лежит только в .tres, а не в коде.

@export_range(0.0, 1000.0, 0.5) var damage: float = 0.0
## На каком расстоянии от камеры центр зоны удара.
@export_range(0.0, 5.0, 0.05, "suffix:м") var reach: float = 0.0
## Радиус зоны удара (шар).
@export_range(0.1, 3.0, 0.05, "suffix:м") var radius: float = 0.0
## Пауза между ударами.
@export_range(0.0, 3.0, 0.05, "suffix:с") var cooldown: float = 0.0
## Длительность взмаха оружия (только визуально).
@export_range(0.05, 1.0, 0.01, "suffix:с") var swing_time: float = 0.0
