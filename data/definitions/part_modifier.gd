class_name PartModifier
extends Resource
## Модификатор части: улучшает одну характеристику оружия на несколько процентов (№29, №70).
## Число модификаторов у части задаёт её качество, выбираются они из пула производителя части.
## Число всегда «улучшение»: для урона, темпа, магазина и дальности это прибавка, для перезарядки,
## разброса, отдачи и времени прицеливания уменьшение. Модификаторов без знака «хуже» нет.

## Ключ названия в таблице переводов.
@export var name_key: String = ""
@export var stat: CombatEnums.Stat = CombatEnums.Stat.DAMAGE
## Нижняя граница улучшения (0.05 = 5%). Для шанса крита это прибавка к шансу.
@export_range(0.0, 0.9, 0.005) var min_value: float = 0.0
## Верхняя граница улучшения. Значение при выпадении берётся случайно между границами.
@export_range(0.0, 0.9, 0.005) var max_value: float = 0.0


## Множитель характеристики при заданном улучшении (для шанса крита не используется, там прибавка).
static func factor_for(p_stat: CombatEnums.Stat, value: float) -> float:
	match p_stat:
		CombatEnums.Stat.DAMAGE, CombatEnums.Stat.FIRE_RATE, CombatEnums.Stat.MAGAZINE_SIZE, CombatEnums.Stat.RANGE:
			return 1.0 + value
		CombatEnums.Stat.CRIT_CHANCE:
			return 1.0
		_:
			return maxf(1.0 - value, 0.05)