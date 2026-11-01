class_name GrenadeDefinition
extends Resource
## Тип гранаты (№92, решение №33: гранаты не составные, у них тип, качество и модификаторы). Данные: data/content/grenades/*.tres,
## список типов в GrenadeSettings. Новый тип гранаты это новый файл. Значения по умолчанию нейтральные: числа лежат только в .tres.

## Как ведёт себя граната после броска.
## FRAG: летит, отскакивает и взрывается по запалу. STICKY: прилипает к врагу или поверхности и взрывается по запалу.
## CLUSTER: при первом ударе разлетается на несколько малых гранат. SINGULARITY: при падении стягивает врагов к центру и взрывается.
enum Kind { FRAG, STICKY, CLUSTER, SINGULARITY }

@export_group("Вид")
## Название типа с большой буквы («Осколочная граната») и то же с маленькой для названия с прилагательным («мощная осколочная граната»).
@export var name_key: String = ""
@export var name_lower_key: String = ""
@export var description_key: String = ""
@export var kind: Kind = Kind.FRAG
## Стихия, которую взрыв накладывает на врагов (NONE — обычный взрыв).
@export var element: CombatEnums.Element = CombatEnums.Element.NONE
## Цвет гранаты в мире, значка и вспышки взрыва.
@export var color: Color = Color.WHITE
## Относительный шанс этого типа при выпадении (вес).
@export_range(0.1, 20.0, 0.1) var weight: float = 1.0

@export_group("Характеристики")
## Урон врагам в центре взрыва на первом уровне (растёт с уровнем гранаты).
@export_range(0.0, 3000.0, 1.0) var base_damage: float = 0.0
@export_range(0.5, 20.0, 0.5, "suffix:м") var blast_radius: float = 0.0
## Запал: сколько секунд от броска (у липкой от прилипания) до взрыва.
@export_range(0.1, 10.0, 0.05, "suffix:с") var fuse_time: float = 0.0
## Взрывается ли при касании врага, не дожидаясь запала (стихийные).
@export var explodes_on_enemy: bool = false
## Перезарядка после броска, секунд.
@export_range(1.0, 120.0, 0.5, "suffix:с") var cooldown: float = 0.0
@export_range(0, 100000, 1) var base_price: int = 0
## Упругость отскока от поверхностей (0 — нет, 1 — полностью).
@export_range(0.0, 1.0, 0.05) var bounciness: float = 0.0

@export_group("Кассетная")
## На сколько малых гранат разлетается, какую долю урона несёт каждая и как далеко разлетается (скорость).
@export_range(0, 20, 1) var bomblets: int = 0
@export_range(0.0, 1.0, 0.05) var bomblet_damage_share: float = 0.0
@export_range(0.0, 30.0, 0.5, "suffix:м/с") var bomblet_speed: float = 0.0

@export_group("Сингулярность")
## Сколько секунд держит врагов в центре и как быстро их стягивает.
@export_range(0.0, 20.0, 0.1, "suffix:с") var pull_time: float = 0.0
@export_range(0.0, 30.0, 0.5, "suffix:м/с") var pull_speed: float = 0.0
