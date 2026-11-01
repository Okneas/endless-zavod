class_name PartInfo
extends RefCounted
## Основной плюс и побочный минус части по её множителям (02-combat-fps, №28). Для режима «Компоненты» на карточке.
## Возвращает ключи названий характеристик в таблице переводов или пустую строку, если у части нет сдвигов.


## {"plus": ключ, "minus": ключ}: самый выгодный и самый невыгодный сдвиг части.
static func plus_minus(part: WeaponPart) -> Dictionary:
	# Каждая запись: ключ названия, во сколько раз изменилось в лучшую сторону (меньше 1 значит хуже).
	var shifts: Array = [
		["CARD_STAT_DAMAGE", part.damage_mult],
		["CARD_STAT_RATE", part.fire_rate_mult],
		["CARD_STAT_MAGAZINE", part.magazine_size_mult],
		["CARD_STAT_RELOAD", _inverse(part.reload_time_mult)],
		["CARD_STAT_SPREAD", _inverse(part.spread_mult)],
		["CARD_STAT_RANGE", part.range_mult],
		["CARD_STAT_RECOIL", _inverse(part.recoil_mult)],
		["CARD_STAT_AIM", _inverse(part.aim_time_mult)],
		["CARD_STAT_STABILITY", _inverse(part.movement_spread_mult)],
	]
	if part.crit_chance_add > 0.0:
		shifts.append(["CARD_STAT_CRIT", 1.0 + part.crit_chance_add])
	var best: Array = ["", 1.0]
	var worst: Array = ["", 1.0]
	for shift: Array in shifts:
		if shift[1] > best[1] + 0.0001:
			best = shift
		if shift[1] < worst[1] - 0.0001:
			worst = shift
	return {"plus": best[0], "minus": worst[0]}


static func _inverse(value: float) -> float:
	return 1.0 / maxf(value, 0.0001)
