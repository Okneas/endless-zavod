class_name EnemyPoolEntry
extends Resource
## Запись пула врагов для комнат с боем (№41): сцена врага, вес и самая ранняя зона. Данные в zone_settings.tres.

@export var scene: PackedScene
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0
@export_range(1, 99, 1) var min_zone: int = 1
