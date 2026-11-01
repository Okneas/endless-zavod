class_name QualityTier
extends Resource
## Одна ступень шкалы качества (№53). Названия и цвета рабочие, автор утверждает их ([[99-open-questions]]).

## Ключ названия в таблице переводов.
@export var name_key: String = ""
## Цвет рамки и надписи на карточке и в ячейках.
@export var color: Color = Color.WHITE
## Сколько модификаторов получает часть этого качества (№29).
@export_range(0, 10, 1) var modifier_count: int = 0
## Сколько особенностей у аксессуара этого качества (одна, у высоких две).
@export_range(0, 4, 1) var accessory_feature_count: int = 0
## Относительный шанс выпадения этого качества (вес).
@export_range(0.0, 1000.0, 0.5) var drop_weight: float = 0.0
## Во сколько раз часть этого качества дороже базовой цены (цена оружия, 05-shop-economy).
@export_range(0.0, 100.0, 0.05, "suffix:x") var price_multiplier: float = 1.0
