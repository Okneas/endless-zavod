class_name CustomerProfile
extends RefCounted
## Покупатель при генерации (05-shop-economy, №36): предпочтения (тип оружия, производитель, любовь к деталям и расходникам), модификатор
## нежелания (№6) и пул монет. Без автозагрузок: настройки и уровень мира передаются параметрами.

## Любимый тип оружия (CombatEnums.WeaponType) и производитель.
var weapon_type: int = 0
var manufacturer: Manufacturer
## Любит детали оружия и расходники (аптечки).
var likes_loose_items: bool = false
var unwillingness: float = 1.0
## Сколько монет покупатель ещё готов потратить.
var budget: int = 0
## Цвет «одежды» покупателя в хабе: от производителя, чтобы предпочтение читалось с первого взгляда.
var color: Color = Color.WHITE


static func roll(settings: ShopSettings, weapons: WeaponGenerationSettings, rng: RandomNumberGenerator, world_level: int) -> CustomerProfile:
	var profile: CustomerProfile = CustomerProfile.new()
	profile.weapon_type = weapons.weapon_types[rng.randi() % weapons.weapon_types.size()]
	if not weapons.manufacturers.is_empty():
		profile.manufacturer = weapons.manufacturers[rng.randi() % weapons.manufacturers.size()]
		profile.color = profile.manufacturer.color
	profile.likes_loose_items = rng.randf() < settings.loose_item_lover_chance
	profile.unwillingness = snappedf(rng.randf_range(settings.unwillingness_min, settings.unwillingness_max), 0.05)
	var growth: float = 1.0 + settings.budget_per_world_level * float(maxi(world_level - 1, 0))
	profile.budget = roundi(float(rng.randi_range(settings.budget_min, maxi(settings.budget_min, settings.budget_max))) * growth)
	return profile
