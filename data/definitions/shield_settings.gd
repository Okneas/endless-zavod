class_name ShieldSettings
extends Resource
## Щиты (№93): типы, модификаторы, рост по уровню и источники. Данные: data/content/balance/shield_settings.tres (слот shields в
## game_config.tres). Значения по умолчанию нейтральные: числа лежат только в .tres и требуют проверки в игре.

@export_group("Состав")
## Все типы щитов, которые выпадают, и пул модификаторов.
@export var types: Array[ShieldDefinition] = []
@export var modifiers: Array[ShieldModifier] = []
## Стартовый вечный щит игрока.
@export var starter: ShieldDefinition

@export_group("Рост и цена")
## Прибавка к ёмкости и урону особенности за каждый уровень щита выше первого.
@export_range(0.0, 1.0, 0.01) var capacity_per_level: float = 0.0
## Цена: прибавка за уровень и надбавка за каждый модификатор (поверх базовой цены типа с множителем качества).
@export_range(0.0, 1.0, 0.01) var price_per_level: float = 0.0
@export_range(0, 1000, 1) var modifier_price: int = 0

@export_group("Бой")
## Доля щита, ниже которой полоска предупреждает (мигает).
@export_range(0.0, 1.0, 0.05) var low_warning_share: float = 0.0
## Верхняя граница шанса поглощения после модификаторов (чтобы щит не стал неуязвимостью).
@export_range(0.0, 1.0, 0.05) var absorb_chance_cap: float = 0.0
## Какая доля урона достаётся врагу на краю радиуса новы и шипов (у центра полный урон).
@export_range(0.0, 1.0, 0.05) var effect_edge_share: float = 0.0

@export_group("Источники")
## Шанс щита с точки награды в кладовой (шанс из врагов и ящиков задают EnemySettings.shield_item_chance и CrateDefinition.shield_chance).
@export_range(0.0, 1.0, 0.005) var loot_point_chance: float = 0.0
## Сколько щитов у торговца (уровень от уровня персонажа плюс trader_level_spread из ShopSettings).
@export_range(0, 8, 1) var trader_count: int = 0
