class_name CrateDefinition
extends Resource
## Вид ящика (№91): прочность, размер и что из него выпадает, когда его разбили. Данные: data/content/props/crates/*.tres,
## подключены в PropSettings. Значения по умолчанию нейтральные: числа лежат только в .tres.

@export_group("Вид")
@export var color: Color = Color.WHITE
@export var size: Vector3 = Vector3.ONE
## Во сколько раз чаще этот вид встречается среди ящиков (вес выбора).
@export_range(0.1, 20.0, 0.1) var weight: float = 1.0
@export_range(1.0, 2000.0, 1.0) var health: float = 0.0

@export_group("Что выпадает")
## Шанс монет и их количество.
@export_range(0.0, 1.0, 0.01) var money_chance: float = 0.0
@export_range(0, 1000, 1) var money_min: int = 0
@export_range(0, 1000, 1) var money_max: int = 0
@export_range(0.0, 1.0, 0.01) var medkit_chance: float = 0.0
## Сколько здоровья даёт выпавшая аптечка.
@export_range(0.0, 200.0, 1.0) var medkit_heal: float = 0.0
## Шанс детали оружия («компонента»).
@export_range(0.0, 1.0, 0.01) var part_chance: float = 0.0
## Шанс гранаты (№92), уровня зоны.
@export_range(0.0, 1.0, 0.01) var grenade_chance: float = 0.0
## Шанс щита игрока (№93), уровня зоны.
@export_range(0.0, 1.0, 0.01) var shield_chance: float = 0.0
## Шанс хлама (лута на продажу) и сколько штук в выпавшей стопке.
@export_range(0.0, 1.0, 0.01) var junk_chance: float = 0.0
@export_range(1, 10, 1) var junk_min: int = 1
@export_range(1, 10, 1) var junk_max: int = 1
