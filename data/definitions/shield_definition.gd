class_name ShieldDefinition
extends Resource
## Тип щита игрока (№93, Borderlands): ёмкость, задержка и скорость восстановления, у части видов ещё особенность. Данные:
## data/content/shields/*.tres, список типов в ShieldSettings. Новый вид щита это новый файл. Значения по умолчанию нейтральные:
## числа лежат только в .tres и требуют проверки в игре.

## Особенность вида.
## STANDARD: без особенности. NOVA: когда щит падает до нуля, вокруг игрока взрыв. SPIKE: каждое поглощённое щитом попадание ранит
## врагов вплотную. ABSORB: шанс поглотить попадание целиком и вернуть щиту часть урона.
enum Kind { STANDARD, NOVA, SPIKE, ABSORB }

@export_group("Вид")
## Название типа с большой буквы («Тяжёлый щит») и то же с маленькой для названия с прилагательным («ёмкий тяжёлый щит»).
@export var name_key: String = ""
@export var name_lower_key: String = ""
@export var description_key: String = ""
@export var kind: Kind = Kind.STANDARD
## Цвет щита в значке и карточке.
@export var color: Color = Color.WHITE
## Относительный шанс этого типа при выпадении (вес).
@export_range(0.1, 20.0, 0.1) var weight: float = 1.0

@export_group("Характеристики")
## Ёмкость на первом уровне (растёт с уровнем щита).
@export_range(1.0, 5000.0, 1.0) var base_capacity: float = 0.0
## Сколько секунд без урона нужно, чтобы щит начал восстанавливаться, и сколько единиц в секунду он набирает.
@export_range(0.0, 30.0, 0.1, "suffix:с") var recharge_delay: float = 0.0
@export_range(0.0, 1000.0, 0.5, "suffix:ед/с") var recharge_rate: float = 0.0
@export_range(0, 100000, 1) var base_price: int = 0

@export_group("Особенность")
## NOVA и SPIKE: урон врагам на первом уровне (растёт с уровнем щита) и радиус. SPIKE: пауза между срабатываниями.
@export_range(0.0, 3000.0, 1.0) var effect_damage: float = 0.0
@export_range(0.0, 20.0, 0.5, "suffix:м") var effect_radius: float = 0.0
@export_range(0.0, 10.0, 0.05, "suffix:с") var effect_cooldown: float = 0.0
## Стихия, которую взрыв и шипы накладывают на врагов (NONE — обычный урон).
@export var effect_element: CombatEnums.Element = CombatEnums.Element.NONE
## ABSORB: шанс поглотить попадание и какую долю его урона вернуть щиту (1.0 — всю).
@export_range(0.0, 1.0, 0.01) var effect_chance: float = 0.0
@export_range(0.0, 1.0, 0.05) var effect_restore: float = 0.0
