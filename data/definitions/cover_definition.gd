class_name CoverDefinition
extends Resource
## Вид укрытия для врагов (№93): размер, цвет и сколько врагов могут прятаться за ним одновременно. Данные: data/content/props/cover/*.tres,
## подключены в PropSettings. Значения по умолчанию нейтральные: числа лежат только в .tres.

@export var color: Color = Color.WHITE
## Габариты: ширина (X), высота (Y) и толщина (Z). Врага (капсула 1.8 м) скрывает целиком барьер высотой не меньше 2 м.
@export var size: Vector3 = Vector3.ONE
## Во сколько раз чаще этот вид встречается среди укрытий (вес выбора).
@export_range(0.1, 20.0, 0.1) var weight: float = 1.0
## Сколько врагов могут занять места за ним одновременно.
@export_range(1, 6, 1) var capacity: int = 1
