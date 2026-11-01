class_name MenuSettings
extends Resource
## Настройки меню (пауза, настройки, инвентарь), №79. Данные: data/content/balance/menu_settings.tres.
## Значения по умолчанию нейтральные, числа лежат только в .tres.

@export_group("Масштаб меню")
## Ступени, которые можно выбрать в настройках. 1 это размер эталона 1920 x 1080 (№78).
@export var scale_steps: PackedFloat32Array = PackedFloat32Array()
## Масштаб меню при первом запуске, пока игрок не выбрал свой.
@export_range(0.25, 4.0, 0.05) var default_scale: float = 1.0
