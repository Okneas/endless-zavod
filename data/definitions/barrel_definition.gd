class_name BarrelDefinition
extends Resource
## Вид стихийной бочки (№91): цвет, стихия, прочность и взрыв. Данные: data/content/props/barrels/*.tres, подключены в
## PropSettings. Новый вид бочки это новый файл. Значения по умолчанию нейтральные: числа лежат только в .tres.

@export_group("Вид")
## Цвет корпуса и вспышки взрыва.
@export var color: Color = Color.WHITE
## Стихия, которую взрыв накладывает на врагов. NONE это обычная взрывная бочка.
@export var element: CombatEnums.Element = CombatEnums.Element.NONE
## Во сколько раз чаще этот вид встречается среди бочек (вес выбора).
@export_range(0.1, 20.0, 0.1) var weight: float = 1.0

@export_group("Прочность и взрыв")
## Сколько урона выдерживает бочка до взрыва.
@export_range(1.0, 2000.0, 1.0) var health: float = 0.0
@export_range(0.5, 20.0, 0.5, "suffix:м") var blast_radius: float = 0.0
## Урон врагам в центре взрыва. Растёт с уровнем зоны так же, как здоровье врагов, чтобы бочка не обесценивалась.
@export_range(0.0, 3000.0, 1.0) var blast_damage: float = 0.0
## Урон игроку в центре взрыва (не растёт с уровнем): взрыв задевает и игрока, но слабее, чем врагов (№91).
@export_range(0.0, 500.0, 1.0) var player_damage: float = 0.0
