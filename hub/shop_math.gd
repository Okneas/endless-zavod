class_name ShopMath
extends RefCounted
## Формулы магазина (05-shop-economy, №6, №88). Без состояния и автозагрузок, чтобы проверять без сцены. Все числа берутся из ShopSettings.

enum Reaction { CHEAP, FAIR, EXPENSIVE, TOO_EXPENSIVE }


## Наценка игрока над фактической ценой (доля): штрафуется только переплата, цена ниже фактической даёт 0 (№6).
static func markup(player_price: int, actual_price: int) -> float:
	return maxf(0.0, float(player_price - actual_price) / float(maxi(actual_price, 1)))


## Шанс покупки, % (№6): 100 - наценка x 100 x модификатор_нежелания, от 0 до 100.
static func purchase_chance(player_price: int, actual_price: int, unwillingness: float) -> float:
	return clampf(100.0 - markup(player_price, actual_price) * 100.0 * unwillingness, 0.0, 100.0)


## Реакция при осмотре: по шансу покупки и тому, насколько цена ниже фактической.
static func reaction(settings: ShopSettings, player_price: int, actual_price: int, chance: float) -> Reaction:
	if chance <= 0.0:
		return Reaction.TOO_EXPENSIVE
	if chance < settings.expensive_below_chance:
		return Reaction.EXPENSIVE
	if float(actual_price - player_price) >= float(actual_price) * settings.cheap_markdown and settings.cheap_markdown > 0.0:
		return Reaction.CHEAP
	return Reaction.FAIR


## Пауза до следующего покупателя: ночью покупателей меньше (№88), пауза делится на множитель ночи.
static func customer_interval(settings: ShopSettings, is_night: bool) -> float:
	return settings.customer_interval / (settings.night_traffic_multiplier if is_night else 1.0)


## Подходит ли предмет покупателю: оружие по типу или производителю, детали по любви к деталям или производителю, расходники только
## любителям деталей и расходников, хлам любому.
static func matches(profile: CustomerProfile, item: InventoryItem) -> bool:
	if item.weapon != null:
		return item.weapon.get_weapon_type() == profile.weapon_type or (profile.manufacturer != null and item.weapon.get_manufacturer() == profile.manufacturer)
	if item.part != null:
		return profile.likes_loose_items or (profile.manufacturer != null and item.part.part.manufacturer == profile.manufacturer)
	# Хлам (№91) нужен любому покупателю: у него нет типа и производителя.
	if item.get_category() == ItemDefinition.Category.JUNK:
		return true
	return profile.likes_loose_items


## Ограничивает цену игрока: не ниже 1 и не выше фактической, умноженной на max_price_multiplier.
static func clamp_price(settings: ShopSettings, actual_price: int, price: int) -> int:
	return clampi(price, 1, maxi(1, roundi(float(actual_price) * settings.max_price_multiplier)))


## Шаг цены кнопками, в монетах (процент фактической цены, не меньше 1).
static func price_step(settings: ShopSettings, actual_price: int) -> int:
	return maxi(1, roundi(float(actual_price) * float(settings.price_step_percent) / 100.0))


## Цена торговца.
static func trader_price(settings: ShopSettings, item: InventoryItem) -> int:
	return maxi(1, roundi(float(item.get_price()) * settings.trader_markup))
