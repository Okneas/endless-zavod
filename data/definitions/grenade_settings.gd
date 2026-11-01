class_name GrenadeSettings
extends Resource
## Гранаты (№92): типы, модификаторы, бросок, рост по уровню и источники. Данные: data/content/balance/grenade_settings.tres (слот grenades
## в game_config.tres). Значения по умолчанию нейтральные: числа лежат только в .tres и требуют проверки в игре.

@export_group("Состав")
## Все типы гранат, которые выпадают, и пул модификаторов.
@export var types: Array[GrenadeDefinition] = []
@export var modifiers: Array[GrenadeModifier] = []
## Стартовая вечная граната игрока (осколочная).
@export var starter: GrenadeDefinition

@export_group("Бросок")
## Скорость броска вперёд по взгляду и добавка вверх, чтобы граната летела дугой.
@export_range(1.0, 60.0, 0.5, "suffix:м/с") var throw_speed: float = 0.0
@export_range(0.0, 30.0, 0.5, "suffix:м/с") var throw_lift: float = 0.0
## Какая доля урона достаётся цели на краю радиуса взрыва (у центра полный урон).
@export_range(0.0, 1.0, 0.05) var blast_edge_share: float = 0.0
## Задержка цепного взрыва бочки, задетой гранатой.
@export_range(0.0, 2.0, 0.01, "suffix:с") var chain_delay: float = 0.0

@export_group("Рост и цена")
## Прибавка урона за каждый уровень гранаты выше первого (как у оружия).
@export_range(0.0, 1.0, 0.01) var damage_per_level: float = 0.0
## Цена: прибавка за уровень и надбавка за каждый модификатор (поверх базовой цены типа с множителем качества).
@export_range(0.0, 1.0, 0.01) var price_per_level: float = 0.0
@export_range(0, 1000, 1) var modifier_price: int = 0

@export_group("Источники")
## Шанс гранаты из убитого рядового врага (на врага можно задать свой множитель в EnemySettings.grenade_chance), с точки награды в кладовой.
@export_range(0.0, 1.0, 0.005) var loot_point_chance: float = 0.0
## Сколько гранат у торговца и какого уровня (от уровня персонажа плюс до trader_level_spread).
@export_range(0, 8, 1) var trader_count: int = 0
