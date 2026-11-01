class_name PartInstance
extends RefCounted
## Выпавшая часть оружия: вариант части (данные) плюс качество, модификаторы и особенности аксессуара (№28, №29).

var part: WeaponPart
## Индекс ступени шкалы качества (0 = самая низкая).
var quality: int = 0
var modifiers: Array[RolledModifier] = []
## Особенности аксессуара (у остальных частей пусто, фирменная особенность лежит в данных части).
var features: Array[PartFeature] = []
## Основа ключа слова от части в названии оружия или пустая строка, если часть слова не добавила.
var name_word: String = ""
## Прицел корпуса: механический или оптика (выпадает при генерации, только у корпуса).
var sight: CombatEnums.SightType = CombatEnums.SightType.IRON


static func create(p_part: WeaponPart, p_quality: int) -> PartInstance:
	var instance: PartInstance = PartInstance.new()
	instance.part = p_part
	instance.quality = p_quality
	return instance