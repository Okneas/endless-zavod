class_name PropSettings
extends Resource
## Бочки, ящики и хлам (№91). Список видов, сколько их ставить в комнатах, как бочка летит после удара и сколько хлама
## падает. Данные: data/content/balance/prop_settings.tres (слот props в game_config.tres).
## Значения по умолчанию нейтральные: числа лежат только в .tres и требуют проверки в игре.

@export_group("Виды")
## Включена ли расстановка бочек и ящиков в зонах (для проверок и настройки).
@export var enabled: bool = false
@export var barrels: Array[BarrelDefinition] = []
@export var crates: Array[CrateDefinition] = []
## Укрытия для врагов (№93).
@export var cover: Array[CoverDefinition] = []
## Хлам: лут только на продажу. Вес выпадения у каждого предмета свой (`ItemDefinition.drop_weight`).
@export var junk_items: Array[ItemDefinition] = []

@export_group("Расстановка")
## Сколько бочек и ящиков в боевой комнате (случайно от и до).
@export_range(0, 30, 1) var combat_barrels_min: int = 0
@export_range(0, 30, 1) var combat_barrels_max: int = 0
@export_range(0, 30, 1) var combat_crates_min: int = 0
@export_range(0, 30, 1) var combat_crates_max: int = 0
## То же в кладовой.
@export_range(0, 30, 1) var loot_barrels_min: int = 0
@export_range(0, 30, 1) var loot_barrels_max: int = 0
@export_range(0, 30, 1) var loot_crates_min: int = 0
@export_range(0, 30, 1) var loot_crates_max: int = 0
## Ближе этого к проёму комнаты и к месту старта игрока ничего не ставится (чтобы не перегородить вход).
@export_range(0.0, 20.0, 0.5, "suffix:м") var entrance_clearance: float = 0.0
## Минимальное расстояние между соседними бочками и ящиками.
@export_range(0.0, 20.0, 0.5, "suffix:м") var min_spacing: float = 0.0

@export_group("Укрытия для врагов (№93)")
## Сколько укрытий в боевой комнате (случайно от и до). В кладовых, шлюзах и прочих комнатах их нет.
@export_range(0, 20, 1) var combat_cover_min: int = 0
@export_range(0, 20, 1) var combat_cover_max: int = 0
## Ближе этого к месту появления врагов укрытие не ставится.
@export_range(0.0, 20.0, 0.5, "suffix:м") var cover_spawn_clearance: float = 0.0
## Свободный проход вокруг укрытия: ближе этого к стенам и другим телам оно не ставится (чтобы не перегородить комнату).
@export_range(0.0, 5.0, 0.1, "suffix:м") var cover_walk_margin: float = 0.0
## Насколько глубже поверхности укрытия стоит спрятавшийся враг, насколько дальше бокового края он выглядывает и расстояние между
## соседними местами за одним укрытием.
@export_range(0.0, 5.0, 0.05, "suffix:м") var cover_hide_margin: float = 0.0
@export_range(0.0, 5.0, 0.05, "suffix:м") var cover_peek_margin: float = 0.0
@export_range(0.0, 5.0, 0.05, "suffix:м") var cover_slot_spacing: float = 0.0

@export_group("Толчок и взрыв")
## Как далеко бочка ищет врага после удара в ближнем бою.
@export_range(0.0, 150.0, 1.0, "suffix:м") var push_seek_range: float = 0.0
## Скорость полёта бочки к врагу и вперёд, если врагов не видно.
@export_range(1.0, 80.0, 0.5, "suffix:м/с") var push_speed: float = 0.0
@export_range(1.0, 80.0, 0.5, "suffix:м/с") var push_idle_speed: float = 0.0
## Сколько секунд после толчка бочка не взрывается от касания земли (успевает оторваться).
@export_range(0.0, 2.0, 0.01, "suffix:с") var push_launch_delay: float = 0.0
## Задержка цепного взрыва: бочка, задетая взрывом, взрывается через это время.
@export_range(0.0, 2.0, 0.01, "suffix:с") var chain_delay: float = 0.0
## Какая доля урона достаётся цели на краю радиуса взрыва (у центра полный урон).
@export_range(0.0, 1.0, 0.05) var blast_edge_share: float = 0.0

@export_group("Хлам из других источников")
## Шанс, что точка денег в кладовой даёт хлам вместо монет.
@export_range(0.0, 1.0, 0.01) var loot_junk_chance: float = 0.0
