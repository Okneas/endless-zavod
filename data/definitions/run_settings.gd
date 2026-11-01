class_name RunSettings
extends Resource
## Настройки забега (срез 7, №82): уровень мира, сила врагов по уровню зоны, волны шлюза и эвакуации, элитный враг и босс
## отдела, цена эвакуации, магазин в забеге. Данные: data/content/balance/run_settings.tres.
## Значения по умолчанию нейтральные: числа лежат только в .tres и требуют проверки в игре.

@export_group("Уровень мира")
## На сколько растёт уровень мира после победы над боссом отдела (03-run-structure).
@export_range(0, 100, 1) var world_level_step: int = 0
## Предел уровня мира (число отделов x 10).
@export_range(1, 999, 1) var world_level_max: int = 1

@export_group("Сила врагов по уровню зоны")
## Во сколько раз растёт здоровье врага за каждый уровень зоны выше первого, сложным процентом: 0.3 даёт x1.3 на втором уровне,
## x1.69 на третьем, x2.2 на четвёртом и так далее. Кривая нарочно крутая (№83): со стартовым оружием дальше 3-4 зоны не пройти.
@export_range(0.0, 2.0, 0.005) var enemy_health_per_level: float = 0.0
## То же для урона врага игроку (тоже сложным процентом).
@export_range(0.0, 2.0, 0.005) var enemy_damage_per_level: float = 0.0

@export_group("Волны")
## Сколько волн в шлюзе с волнами.
@export_range(1, 20, 1) var gate_waves: int = 1
## Сколько волн надо отстоять в эвакуационной комнате вместо оплаты (03-run-structure, 04-extraction: 3).
@export_range(1, 20, 1) var evacuation_waves: int = 1
## Врагов в первой волне, прибавка за каждую следующую волну и за каждую следующую зону, предел.
@export_range(1, 60, 1) var wave_enemies_base: int = 1
@export_range(0.0, 10.0, 0.1) var wave_enemies_per_wave: float = 0.0
@export_range(0.0, 10.0, 0.1) var wave_enemies_per_zone: float = 0.0
@export_range(1, 60, 1) var wave_enemies_max: int = 1
## Пауза между волнами после гибели последнего врага.
@export_range(0.0, 30.0, 0.5, "suffix:с") var wave_pause: float = 0.0
## Расчёт числа врагов волны: см. ZoneMath.wave_enemy_count.

@export_group("Шлюз с элитным врагом")
## Элитный враг (мини-босс зоны, не босс отдела): сцена, сколько штук и сколько обычных врагов из пула идёт с ним.
@export var elite_scene: PackedScene
@export_range(1, 5, 1) var elite_count: int = 1
@export_range(0, 30, 1) var elite_escort: int = 0

@export_group("Босс отдела")
## Босс в комнате последней зоны отдела.
@export var boss_scene: PackedScene

@export_group("Эвакуация")
## Стандартная цена: оплата деньгами и лутом равна номер_зоны x стандартная_цена x модификатор (04-extraction).
@export_range(0, 100000, 1) var evacuation_price: int = 0
## Модификатор цены (для мета-прогрессии и событий, по умолчанию 1.0).
@export_range(0.0, 10.0, 0.05) var evacuation_price_modifier: float = 1.0
## Шанс, что эвакуационная комната требует оплату лутом, а не деньгами (способ случаен, выбирается по сиду зоны).
@export_range(0.0, 1.0, 0.05) var evacuation_loot_chance: float = 0.0

@export_group("Магазин в забеге")
## Сколько оружия и аптечек стоит на постаментах (не больше числа постаментов в комнате).
@export_range(0, 10, 1) var shop_weapons: int = 0
@export_range(0, 10, 1) var shop_medkits: int = 0
## Во сколько раз покупка дороже цены предмета (цена предмета это цена продажи).
@export_range(0.0, 10.0, 0.05) var shop_markup: float = 0.0
## Аптечка, которую продаёт магазин (ItemDefinition).
@export var shop_medkit: ItemDefinition

@export_group("Появление врагов")
## Сколько секунд место появления светится, прежде чем там встанет враг (№87). Двери закрываются сразу при входе, враги
## появляются после этой паузы. 0 — враги появляются сразу.
@export_range(0.0, 6.0, 0.1, "suffix:с") var spawn_warning_time: float = 0.0
