class_name RolledModifier
extends RefCounted
## Выпавший модификатор части: данные модификатора и конкретное значение улучшения (№29).

var modifier: PartModifier
## Выпавшее улучшение (0.06 = 6%).
var value: float = 0.0


static func create(p_modifier: PartModifier, p_value: float) -> RolledModifier:
	var rolled: RolledModifier = RolledModifier.new()
	rolled.modifier = p_modifier
	rolled.value = p_value
	return rolled