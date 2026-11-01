class_name EnemySettings
extends Resource
## Настройки одного типа врага (02-combat-fps, №38). Данные: data/content/enemies/*.tres.
## В Inspector открываются у узла врага (поле Settings) или двойным щелчком по .tres.
## Значения по умолчанию нейтральные: числа лежат только в .tres, не в коде.
## Поля групп, не относящихся к типу врага (например «Стрельба» у преследующего), игнорируются.

@export_group("Общее")
## Ключ названия в таблице переводов.
@export var name_key: String = ""
@export var enemy_class: CombatEnums.EnemyClass = CombatEnums.EnemyClass.SWARM
@export_range(1.0, 100000.0, 1.0) var max_health: float = 0.0
## Высота верха врага над его точкой: здесь всплывают цифры урона и над этой точкой парит саппорт. Полоски над врагом в мире
## больше нет (№86): здоровье, название и уровень видны над прицелом, когда он наведён на врага.
@export_range(0.5, 6.0, 0.05, "suffix:м") var health_bar_height: float = 0.0

@export_group("Награда")
@export_range(0, 100000, 1) var xp_reward: int = 0
@export_range(0, 100000, 1) var money_min: int = 0
@export_range(0, 100000, 1) var money_max: int = 0
## Шанс выпадения детали оружия (отдельным предметом). Целое оружие из врагов не падает, детали падают заметно чаще.
@export_range(0.0, 1.0, 0.01) var part_chance: float = 0.0
## Шанс выпадения аптечки (0.08 = 8%).
@export_range(0.0, 1.0, 0.01) var medkit_chance: float = 0.0
## Сколько здоровья даёт выпавшая аптечка.
@export_range(0.0, 1000.0, 1.0) var medkit_heal: float = 0.0

@export_group("Движение")
## Скорость (у саппорта скорость полёта к союзнику). Мороз её уменьшает.
@export_range(0.0, 30.0, 0.1, "suffix:м/с") var move_speed: float = 0.0
## С какого расстояния враг замечает игрока и начинает действовать.
@export_range(0.0, 100.0, 0.5, "suffix:м") var aggro_range: float = 0.0
## Сила тяжести для наземных врагов (у летающего не используется).
@export_range(0.0, 100.0, 0.5, "suffix:м/с²") var gravity: float = 0.0
## Летающий: на какой высоте над центром игрока он держится.
@export_range(-2.0, 6.0, 0.05, "suffix:м") var fly_height_offset: float = 0.0

@export_group("Ближняя атака (преследующий, летающий)")
@export_range(0.0, 200.0, 0.5) var melee_damage: float = 0.0
## На каком расстоянии от игрока враг бьёт.
@export_range(0.0, 10.0, 0.05, "suffix:м") var melee_range: float = 0.0
@export_range(0.0, 10.0, 0.05, "suffix:с") var melee_cooldown: float = 0.0

@export_group("Стрельба (турель и стрелки)")
## Дальность, на которой турель замечает игрока в пределах угла обзора и стреляет.
@export_range(0.0, 200.0, 0.5, "suffix:м") var shoot_range: float = 0.0
## Угол обзора вокруг направления, в которое турель смотрит на старте.
@export_range(10.0, 360.0, 1.0, "suffix:°") var view_angle: float = 0.0
## Ближний радиус: внутри него турель замечает игрока со всех сторон, не глядя на угол обзора
## (прямая видимость всё равно нужна). 0 отключает.
@export_range(0.0, 100.0, 0.5, "suffix:м") var awareness_radius: float = 0.0
## Сколько секунд турель помнит игрока после потери из виду (вышел из угла обзора, скрылся за стеной).
@export_range(0.0, 10.0, 0.1, "suffix:с") var lose_sight_time: float = 0.0
## Сколько секунд турель целится, заметив игрока, перед первой очередью.
@export_range(0.0, 5.0, 0.05, "suffix:с") var aim_time: float = 0.0
## Сколько пуль в очереди. 1 — одиночные выстрелы.
@export_range(1, 10, 1) var burst_count: int = 1
## Пауза между пулями внутри очереди.
@export_range(0.0, 2.0, 0.01, "suffix:с") var burst_shot_interval: float = 0.0
## Время от начала одной очереди до начала следующей (не короче самой очереди).
@export_range(0.1, 10.0, 0.05, "suffix:с") var shoot_interval: float = 0.0
@export_range(10.0, 720.0, 5.0, "suffix:°/с") var turn_speed: float = 0.0
@export_range(0.0, 200.0, 0.5) var projectile_damage: float = 0.0
@export_range(1.0, 100.0, 0.5, "suffix:м/с") var projectile_speed: float = 0.0
@export_range(0.5, 20.0, 0.5, "suffix:с") var projectile_lifetime: float = 0.0

@export_group("Охват игрока (подход сбоку)")
## Насколько далеко в сторону от прямой на игрока уходит маршрут врага, пока он далеко. У каждого врага своя боковая полоса
## (случайная сторона и ширина), поэтому толпа делится на потоки и заходит с разных сторон. 0 — идёт прямо.
@export_range(0.0, 40.0, 0.5, "suffix:м") var flank_width: float = 0.0
## Ближе этого расстояния до игрока полоса сходится в ноль: враг идёт прямо на игрока.
@export_range(0.0, 50.0, 0.5, "suffix:м") var flank_close_distance: float = 0.0
## На сколько метров дальше «ближней» дистанции боковая полоса достигает полной ширины (между ними она плавно растёт).
@export_range(1.0, 100.0, 0.5, "suffix:м") var flank_fade_distance: float = 1.0

@export_group("Стрелок (наземный и летающий)")
## Расстояние, на котором стрелок держится от игрока: подходит, пока дальше. Летающий отступает, если ближе retreat_range.
@export_range(0.0, 100.0, 0.5, "suffix:м") var preferred_range: float = 0.0
## Летающий стрелок пятится, если игрок ближе этого. 0 отключает.
@export_range(0.0, 50.0, 0.5, "suffix:м") var retreat_range: float = 0.0
## Боковое движение во время стрельбы (доля move_speed). 0 — стоит на месте.
@export_range(0.0, 1.0, 0.05) var strafe_fraction: float = 0.0
## Как часто (секунды) стрелок меняет сторону бокового движения.
@export_range(0.2, 10.0, 0.1, "suffix:с") var strafe_change_time: float = 0.0
## Разброс выстрела: случайное отклонение от прямой на игрока.
@export_range(0.0, 20.0, 0.1, "suffix:°") var projectile_spread: float = 0.0
## Радиус снаряда (для попадания и вида).
@export_range(0.05, 1.0, 0.01, "suffix:м") var projectile_radius: float = 0.0

@export_group("Прыжок на игрока (преследующий)")
## Пауза между прыжками. 0 отключает прыжок целиком.
@export_range(0.0, 30.0, 0.1, "suffix:с") var leap_cooldown: float = 0.0
## Дистанция до игрока, на которой враг решается прыгнуть: не ближе и не дальше этих значений.
@export_range(0.0, 30.0, 0.5, "suffix:м") var leap_min_range: float = 0.0
@export_range(0.0, 40.0, 0.5, "suffix:м") var leap_max_range: float = 0.0
## Замах перед прыжком: враг замирает и подсвечивается, игроку виден знак.
@export_range(0.0, 3.0, 0.05, "suffix:с") var leap_windup: float = 0.0
## Время полёта до точки, где стоял игрок в момент прыжка. Меньше — быстрее и резче.
@export_range(0.1, 3.0, 0.05, "suffix:с") var leap_air_time: float = 0.0
## Урон от прыжка во сколько раз больше обычного удара.
@export_range(0.1, 10.0, 0.1, "suffix:x") var leap_damage_multiplier: float = 1.0
## Дальше этого от места приземления прыжок игрока не задевает.
@export_range(0.5, 6.0, 0.1, "suffix:м") var leap_hit_radius: float = 0.0

@export_group("Камикадзе (летающий)")
## С какого расстояния до игрока враг останавливается и готовит рывок.
@export_range(1.0, 60.0, 0.5, "suffix:м") var charge_range: float = 0.0
## Замах перед рывком (враг замирает и мигает). Точка рывка фиксируется в конце замаха.
@export_range(0.0, 3.0, 0.05, "suffix:с") var charge_windup: float = 0.0
@export_range(1.0, 80.0, 0.5, "suffix:м/с") var charge_speed: float = 0.0
## Рывок прекращается взрывом, если за это время точки не достиг.
@export_range(0.1, 5.0, 0.1, "suffix:с") var charge_max_time: float = 0.0
@export_range(0.5, 12.0, 0.1, "suffix:м") var explosion_radius: float = 0.0
@export_range(0.0, 400.0, 0.5) var explosion_damage: float = 0.0

@export_group("Лучи (турель-лучемёт)")
@export_range(1, 8, 1) var beam_count: int = 0
@export_range(0.5, 30.0, 0.1, "suffix:м") var beam_length: float = 0.0
@export_range(0.05, 1.0, 0.01, "suffix:м") var beam_thickness: float = 0.0
## Высота лучей над ногами турели. Игрок может перепрыгнуть луч или пройти под ним, если он выше его роста.
@export_range(0.1, 3.0, 0.05, "suffix:м") var beam_height: float = 0.0
## Скорость вращения лучей.
@export_range(5.0, 720.0, 5.0, "suffix:°/с") var spin_speed: float = 0.0
## Урон одного удара луча и пауза между ударами, пока игрок в луче.
@export_range(0.0, 200.0, 0.5) var beam_damage: float = 0.0
@export_range(0.05, 3.0, 0.05, "suffix:с") var beam_tick_interval: float = 0.0
## Лучи включаются, когда игрок ближе этого. 0 — всегда включены.
@export_range(0.0, 100.0, 0.5, "suffix:м") var beam_active_range: float = 0.0

@export_group("Барьер (саппорт-щитовик)")
## Во сколько раз остаётся урон по связанному врагу (0.03 — проходит 3%).
@export_range(0.0, 1.0, 0.01) var ward_damage_taken: float = 1.0
## Дальше этого от связанного врага барьер пропадает.
@export_range(0.0, 50.0, 0.5, "suffix:м") var ward_range: float = 0.0

@export_group("Лечение (саппорт)")
## Сколько здоровья в секунду восстанавливает привязанному врагу.
@export_range(0.0, 200.0, 0.5, "suffix:HP/с") var heal_per_second: float = 0.0
@export_range(0.0, 50.0, 0.5, "suffix:м") var heal_range: float = 0.0
## Насколько выше полоски здоровья союзника парит саппорт (сам саппорт летающий).
@export_range(0.0, 10.0, 0.05, "suffix:м") var hover_height: float = 0.0
## В каком радиусе саппорт выбирает, к кому привязаться.
@export_range(0.0, 100.0, 0.5, "suffix:м") var search_range: float = 0.0

@export_group("Босс отдела (ударная волна, призыв)")
## Пауза между ударными волнами, с.
@export_range(0.0, 30.0, 0.1, "suffix:с") var shockwave_interval: float = 0.0
## Сколько секунд босс замахивается перед волной (стоит на месте).
@export_range(0.0, 5.0, 0.05, "suffix:с") var shockwave_windup: float = 0.0
## Скорость расширения кольца, до какого радиуса оно идёт и какой оно толщины.
@export_range(1.0, 60.0, 0.5, "suffix:м/с") var shockwave_speed: float = 0.0
@export_range(2.0, 120.0, 0.5, "suffix:м") var shockwave_radius: float = 0.0
@export_range(0.2, 6.0, 0.1, "suffix:м") var shockwave_thickness: float = 0.0
## Выше этой высоты над землёй (ступни игрока) волна не задевает: надо прыгнуть.
@export_range(0.1, 6.0, 0.1, "suffix:м") var shockwave_height: float = 0.0
@export_range(0.0, 300.0, 0.5) var shockwave_damage: float = 0.0
## При каком остатке здоровья (доля) начинается вторая фаза, как она меняет скорость и паузу волн.
@export_range(0.0, 1.0, 0.05) var phase2_health_fraction: float = 0.0
@export_range(1.0, 5.0, 0.05) var phase2_speed_multiplier: float = 1.0
@export_range(0.1, 1.0, 0.05) var phase2_interval_multiplier: float = 1.0
## Кого и сколько зовёт на помощь в начале второй фазы.
@export var summon_scene: PackedScene
@export_range(0, 20, 1) var summon_count: int = 0
