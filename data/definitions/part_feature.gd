class_name PartFeature
extends Resource
## Особенность части: показывается на карточке с названием и описанием (11-UI-design).
## Бывает фирменной (закреплена за частью производителя: дульный тормоз, увеличенный магазин, оптика)
## и особенностью аксессуара (стихия или бонус урона в подкате, в воздухе, в ближнем бою; №28, №70).

## Ключ названия в таблице переводов.
@export var name_key: String = ""
## Ключ описания. В тексте можно писать {value}: подставится процент особенности.
@export var description_key: String = ""
@export var kind: CombatEnums.FeatureKind = CombatEnums.FeatureKind.STATS
## Стихия (только для вида «стихия»).
@export var element: CombatEnums.Element = CombatEnums.Element.NONE
## Бонус урона в ситуации (0.3 = +30%) для видов «урон в подкате, в воздухе, в ближнем бою».
@export_range(0.0, 5.0, 0.05) var value: float = 0.0
## Сдвиги характеристик, которые несёт особенность (у фирменных). Берётся среднее между границами.
@export var stat_changes: Array[PartModifier] = []