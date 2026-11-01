class_name ElementSettings
extends Resource
## Эффекты стихий на врагах (02-combat-fps, №37). Данные: data/content/balance/element_settings.tres
## (подключены в game_config.tres). Значения по умолчанию нейтральные: числа лежат только в .tres.
## Эффект накладывается каждым попаданием стихийного оружия и обновляется.

@export_group("Кислота")
## Сколько секунд враг уязвим после попадания.
@export_range(0.0, 30.0, 0.1, "suffix:с") var acid_duration: float = 0.0
## Во сколько раз больше урона получает уязвимый враг (1.3 = +30%).
@export_range(1.0, 5.0, 0.05, "suffix:x") var acid_damage_taken_multiplier: float = 1.0

@export_group("Электричество")
@export_range(0.0, 30.0, 0.1, "suffix:с") var electric_duration: float = 0.0
## Урон в секунду как доля урона попавшего выстрела (0.6 = 60% урона выстрела за секунду).
@export_range(0.0, 5.0, 0.05) var electric_dps_fraction: float = 0.0
## Радиус, в котором другие поражённые током враги усиливают урон в секунду (связь между врагами).
@export_range(0.0, 30.0, 0.5, "suffix:м") var electric_chain_radius: float = 0.0
## Прибавка к урону в секунду за каждого соседа под током (0.5 = +50%).
@export_range(0.0, 3.0, 0.05) var electric_chain_bonus: float = 0.0
## Сколько соседей учитывается максимум.
@export_range(0, 20, 1) var electric_chain_max_neighbors: int = 0
## Во сколько раз попадание тока сильнее съедает щит врага (№93, как в Borderlands). Остальные стихии щит не усиливают.
@export_range(1.0, 5.0, 0.05, "suffix:x") var electric_shield_multiplier: float = 1.0

@export_group("Мороз")
@export_range(0.0, 30.0, 0.1, "suffix:с") var frost_duration: float = 0.0
## Во сколько раз замедляется движение (0.5 = вдвое медленнее).
@export_range(0.05, 1.0, 0.05, "suffix:x") var frost_speed_multiplier: float = 1.0

@export_group("Огонь (заглушка)")
## Эффект огня не определён (99-open-questions): пока враг только подсвечивается.
@export_range(0.0, 30.0, 0.1, "suffix:с") var fire_duration: float = 0.0
