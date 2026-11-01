class_name ShopSettings
extends Resource
## Настройки магазина-хаба (срез 8, №88, 05-shop-economy): покупатели, прилавки, сундук, торговец. Данные: data/content/balance/shop_settings.tres
## (слот shop в game_config.tres). Значения по умолчанию нейтральные: числа лежат только в .tres и требуют проверки в игре.

@export_group("Покупатели")
## Пауза между приходом покупателей днём. Ночью пауза растёт: делится на night_traffic_multiplier (ночью покупателей меньше).
@export_range(2.0, 300.0, 1.0, "suffix:с") var customer_interval: float = 0.0
## Во сколько раз ночью приходит меньше покупателей (0.4 — на 60% реже). Больше ночь ничего не меняет (№88).
@export_range(0.05, 1.0, 0.05) var night_traffic_multiplier: float = 1.0
## Сколько покупателей может быть в магазине одновременно.
@export_range(1, 12, 1) var max_customers: int = 0
@export_range(0.5, 10.0, 0.1, "suffix:м/с") var walk_speed: float = 0.0
## Сколько секунд покупатель разглядывает товар перед решением (и показывает реакцию на цену).
@export_range(0.5, 30.0, 0.5, "suffix:с") var inspect_time: float = 0.0
## Сколько секунд покупатель ждёт у кассы. Не дождавшись, уходит, а товар возвращается на прилавок (№88).
@export_range(2.0, 120.0, 1.0, "suffix:с") var register_patience: float = 0.0
## Пул монет покупателя: сколько он готов потратить. Растёт с уровнем мира на budget_per_world_level за каждый уровень выше первого.
@export_range(1, 99999, 1) var budget_min: int = 0
@export_range(1, 99999, 1) var budget_max: int = 0
@export_range(0.0, 1.0, 0.01) var budget_per_world_level: float = 0.0
## Модификатор нежелания (№6): чем он выше, тем сильнее переплата снижает шанс покупки. У скупого выше.
@export_range(0.1, 5.0, 0.05) var unwillingness_min: float = 1.0
@export_range(0.1, 5.0, 0.05) var unwillingness_max: float = 1.0
## Доля покупателей, которые любят детали и расходники (остальные ищут оружие своего типа или производителя).
@export_range(0.0, 1.0, 0.05) var loose_item_lover_chance: float = 0.0

@export_group("Покупатели: обход зала")
## Сколько прилавков с товаром покупатель обходит за визит (от одного до этого числа). После каждого осмотра он решает, брать ли товар.
@export_range(1, 6, 1) var max_visits: int = 1
## Во сколько раз охотнее покупатель идёт к прилавку с подходящим ему и по карману товаром, чем к чужому (вес при выборе маршрута).
@export_range(1.0, 10.0, 0.5, "suffix:x") var taste_weight: float = 1.0
## Доля обычного времени осмотра, которую покупатель тратит на товар «не его» (тип оружия или производитель не подходят).
@export_range(0.1, 1.0, 0.05) var not_mine_time_factor: float = 1.0
## Шанс, что между осмотрами покупатель пройдётся по залу и постоит, оглядываясь (живее выглядит, но растягивает визит).
@export_range(0.0, 1.0, 0.05) var wander_chance: float = 0.0
@export_range(0.0, 10.0, 0.1, "suffix:с") var wander_pause_min: float = 0.0
@export_range(0.0, 10.0, 0.1, "suffix:с") var wander_pause_max: float = 0.0

@export_group("Реакция на цену")
## Шанс покупки ниже этого значения (%) покупатель называет цену дорогой.
@export_range(0.0, 100.0, 1.0, "suffix:%") var expensive_below_chance: float = 0.0
## Цена игрока ниже фактической хотя бы на эту долю — «дёшево» (0.15 — на 15%).
@export_range(0.0, 1.0, 0.01) var cheap_markdown: float = 0.0

@export_group("Прилавки и сундук")
## Сколько прилавков в магазине.
@export_range(1, 12, 1) var counter_count: int = 0
## Сколько предметов вмещает сундук (сверх рюкзака на 20).
@export_range(5, 400, 1) var chest_capacity: int = 0
## Цену можно поставить не выше фактической, умноженной на это число.
@export_range(1.0, 20.0, 0.5, "suffix:x") var max_price_multiplier: float = 1.0
## Шаг кнопок цены, % от фактической цены.
@export_range(1, 50, 1, "suffix:%") var price_step_percent: int = 5

@export_group("Торговец (расход денег в хабе)")
## Сколько случайных составных оружий у торговца.
@export_range(1, 12, 1) var trader_stock_size: int = 0
## Раз в сколько суток ассортимент торговца обновляется.
@export_range(1, 14, 1, "suffix:сут") var trader_refresh_days: int = 1
## Цена торговца во сколько раз выше цены оружия по формуле.
@export_range(1.0, 5.0, 0.05, "suffix:x") var trader_markup: float = 1.0
## Уровень оружия у торговца: от уровня персонажа до него плюс это число (чтобы игрок мог экипировать покупку).
@export_range(0, 10, 1) var trader_level_spread: int = 0
