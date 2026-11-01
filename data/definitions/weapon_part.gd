class_name WeaponPart
extends Resource
## Часть оружия: корпус, дуло, рукоять, магазин и т.д. (02-combat-fps, №28).
## Корпус даёт базу (раздел «База»), остальные части сдвигают отдельные характеристики
## множителями (раздел «Сдвиги»). Новая часть = новый .tres, без правки кода.
## Вариант части одного производителя: данные лежат в data/content/parts/<производитель>/ (случайная выдача берёт
## любые части с назначенным производителем), стартовый набор и отладочные части без производителя лежат в parts/.
## Качество, модификаторы и особенности аксессуара принадлежат не варианту, а выпавшей части (PartInstance).
## Значения по умолчанию нейтральные: числа лежат только в .tres.

enum PartType { BODY, BARREL, GRIP, MAGAZINE, STOCK, ACCESSORY }

@export var part_type: PartType = PartType.BODY
## Ключ названия в таблице переводов.
@export var name_key: String = ""

@export_group("База (заполняется только у корпуса)")
## Тип оружия определяется корпусом (02-combat-fps). От него зависит таблица уязвимостей врагов.
@export var weapon_type: CombatEnums.WeaponType = CombatEnums.WeaponType.PISTOL
@export_range(0.0, 1000.0, 0.5) var base_damage: float = 0.0
## Выстрелов в секунду.
@export_range(0.0, 30.0, 0.1, "suffix:выстр/с") var base_fire_rate: float = 0.0
## Автоматическая стрельба: пока зажата кнопка. Иначе одно нажатие, один выстрел.
@export var automatic: bool = false
@export_range(0, 200, 1) var base_magazine_size: int = 0
@export_range(0.0, 10.0, 0.05, "suffix:с") var base_reload_time: float = 0.0
## Половина угла конуса разброса в покое.
@export_range(0.0, 20.0, 0.05, "suffix:°") var base_spread_deg: float = 0.0
## Дальность луча.
@export_range(0.0, 500.0, 1.0, "suffix:м") var base_range: float = 0.0
## Подъём камеры за один выстрел.
@export_range(0.0, 10.0, 0.05, "suffix:°") var base_recoil_deg: float = 0.0
## Сколько секунд занимает вход в прицеливание (ПКМ).
@export_range(0.01, 2.0, 0.01, "suffix:с") var base_aim_time: float = 0.0
## Кратность приближения в прицеливании: прицел считается свойством корпуса (02-combat-fps).
@export_range(1.0, 10.0, 0.05, "suffix:x") var aim_zoom: float = 1.0
## Шанс крита самого оружия (0.05 = 5%), складывается с критом игрока.
@export_range(0.0, 1.0, 0.01) var base_crit_chance: float = 0.0

@export_group("Особенность аксессуара")
## Стихия, которую оружие накладывает на врагов при попадании. NONE = без стихии.
@export var element: CombatEnums.Element = CombatEnums.Element.NONE

@export_group("Сдвиги (у любой части, 1.0 = без изменений)")
@export_range(0.0, 5.0, 0.01) var damage_mult: float = 1.0
@export_range(0.0, 5.0, 0.01) var fire_rate_mult: float = 1.0
@export_range(0.0, 5.0, 0.01) var magazine_size_mult: float = 1.0
@export_range(0.0, 5.0, 0.01) var reload_time_mult: float = 1.0
@export_range(0.0, 5.0, 0.01) var spread_mult: float = 1.0
@export_range(0.0, 5.0, 0.01) var range_mult: float = 1.0
@export_range(0.0, 5.0, 0.01) var recoil_mult: float = 1.0
@export_range(0.0, 5.0, 0.01) var aim_time_mult: float = 1.0
@export_range(0.0, 1.0, 0.01) var crit_chance_add: float = 0.0
## Стабильность в движении: множитель добавки разброса от движения (меньше 1.0 лучше). Это дело приклада.
@export_range(0.0, 5.0, 0.01) var movement_spread_mult: float = 1.0

@export_group("Корпус: дополнительная база")
## Сколько дробин вылетает за выстрел (урон делится между ними). 1 = обычная пуля.
@export_range(1, 30, 1) var base_pellets: int = 1

@export_group("Производитель и подбор")
## Производитель. Части без производителя не выпадают в случайной генерации (стартовые, отладочные).
@export var manufacturer: Manufacturer
## Каким типам оружия подходит часть (у корпуса его собственный тип). Пусто = любым (аксессуар).
@export var weapon_types: Array[CombatEnums.WeaponType] = []
## Базовая цена части без модификаторов (справочник цен, срез 8).
@export_range(0, 100000, 1) var base_price: int = 0

@export_group("Название (№49)")
## Род названия корпуса (для прилагательных). Только у корпуса.
@export var gender: CombatEnums.Gender = CombatEnums.Gender.MASCULINE
## Пул слов названия от этой части: основы ключей, к ним добавляются _M, _F, _N (в таблице переводов).
@export var name_words: Array[String] = []
## Семейство оружия внутри типа (помповый дробовик, двустволка, снайперка с затвором): ключ названия
## в таблице переводов, показывается вместо названия типа. Пусто = только тип. Только у корпуса.
@export var family_key: String = ""

@export_group("Фирменная особенность")
## Особенность производителя, закреплённая за этой частью (дульный тормоз, увеличенный магазин, оптика).
@export var signature: PartFeature

@export_group("Модель (плейсхолдер)")
## Размер коробки части и смещение её центра от точки крепления (у корпуса от начала модели).
@export var model_size: Vector3 = Vector3.ZERO
@export var model_offset: Vector3 = Vector3.ZERO
@export_subgroup("Только корпус")
## Точка, через которую смотрит глаз с механическим прицелом (прорезь целика). Приближение с ним: aim_zoom.
@export var aim_anchor_position: Vector3 = Vector3.ZERO
## То же с оптикой: центр рамки оптики и приближение. Оптика ставится на корпус при генерации с шансом
## (у любого производителя, у некоторых выше; Manufacturer.optic_chance_bonus). Приближение 1.0 = оптики для корпуса нет.
@export var optic_aim_anchor_position: Vector3 = Vector3.ZERO
## Парное оружие (акимбо): смещение второй копии модели относительно первой. Ноль = обычное оружие.
## Оба ствола одинаковые и стреляют по очереди. Оптики у парного оружия нет (optic_aim_zoom не задаётся).
@export var second_model_offset: Vector3 = Vector3.ZERO
## То же при полном прицеливании: стволы сводятся к середине. Ноль = не сводятся.
@export var second_aim_offset: Vector3 = Vector3.ZERO
## Наклон стволов к середине при прицеливании (крен внутрь, поворот внутрь вдвое меньше).
@export_range(0.0, 45.0, 0.5, "suffix:°") var dual_aim_tilt_deg: float = 0.0
@export_range(1.0, 10.0, 0.05, "suffix:x") var optic_aim_zoom: float = 1.0
## Точки крепления частей на корпусе (единые для типа оружия, №09-tech-godot).
@export var mount_barrel: Vector3 = Vector3.ZERO
@export var mount_grip: Vector3 = Vector3.ZERO
@export var mount_magazine: Vector3 = Vector3.ZERO
@export var mount_stock: Vector3 = Vector3.ZERO
@export var mount_accessory: Vector3 = Vector3.ZERO

## Есть ли для этого корпуса оптика (заданы её приближение и точка прицела).
func has_optic() -> bool:
	return optic_aim_zoom > 1.0
