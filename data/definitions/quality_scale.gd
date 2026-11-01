class_name QualityScale
extends Resource
## Шкала качества: ступени по возрастанию (брак, серийное, опытное, экспериментальное, прототип; №53).
## Данные: data/content/balance/quality_scale.tres.

@export var tiers: Array[QualityTier] = []


## Случайная ступень с учётом весов выпадения. Возвращает индекс в tiers.
func pick_index(rng: RandomNumberGenerator) -> int:
	var total: float = 0.0
	for tier: QualityTier in tiers:
		total += tier.drop_weight
	var roll: float = rng.randf() * total
	for i: int in tiers.size():
		roll -= tiers[i].drop_weight
		if roll <= 0.0:
			return i
	return tiers.size() - 1