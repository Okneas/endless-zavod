class_name TargetDummySettings
extends Resource
## Мишень-болванка для отладки стрельбы. Данные: data/content/enemies/target_dummy.tres.
## Значения по умолчанию нейтральные: числа лежат только в .tres.

@export_range(1.0, 100000.0, 1.0) var max_health: float = 0.0
## Через сколько секунд после уничтожения мишень возвращается.
@export_range(0.0, 60.0, 0.5, "suffix:с") var respawn_time: float = 0.0
