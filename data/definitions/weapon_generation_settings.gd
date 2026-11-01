class_name WeaponGenerationSettings
extends Resource
## Правила генерации оружия (02-combat-fps, №15, №16, №28, №29, №49, №70). Данные: data/content/balance/weapon_generation.tres.
## Значения по умолчанию нейтральные, все числа в .tres стартовые и требуют проверки в игре.

@export_group("Каталог")
## Папка с вариантами частей. Любой .tres части с назначенным производителем (в том числе во вложенных папках)
## попадает в случайную генерацию без правки кода. Части без производителя (стартовые, отладочные) не выпадают.
@export_dir var parts_directory: String = ""
## Производители, которые участвуют в генерации.
@export var manufacturers: Array[Manufacturer] = []

@export_group("Типы оружия")
## Какие типы оружия выпадают (в прототипе пять, 10-prototype-scope).
@export var weapon_types: Array[CombatEnums.WeaponType] = []
## У каких типов есть приклад.
@export var stock_types: Array[CombatEnums.WeaponType] = []

@export_group("Уровень и слоты")
## Прибавка к урону за каждый уровень выше первого (0.06 = +6% за уровень).
@export_range(0.0, 1.0, 0.005) var damage_per_level: float = 0.0
## Число слотов оружия (№22).
@export_range(1, 8, 1) var slot_count: int = 1

@export_group("Качество")
@export var quality_scale: QualityScale
## Индекс ступени качества стартового оружия (0 = брак, 1 = серийное).
@export_range(0, 10, 1) var starter_quality: int = 0

@export_group("Производитель отдела")
## Шанс, что часть берётся у производителя отдела, если он задан (№15). Иначе производитель случайный.
@export_range(0.0, 1.0, 0.01) var department_manufacturer_chance: float = 0.0

@export_group("Прицел корпуса")
## Шанс, что на корпус любого производителя встанет оптика вместо механического прицела.
## Прицел это свойство корпуса (№28); у ОружИнтТочПрома шанс выше через Manufacturer.optic_chance_bonus.
@export_range(0.0, 1.0, 0.01) var optic_chance: float = 0.0
## Особенность, которая показывается на карточке, когда на корпусе оптика.
@export var optic_feature: PartFeature

@export_group("Аксессуар")
## Шанс, что у сгенерированного оружия есть аксессуар.
@export_range(0.0, 1.0, 0.01) var accessory_chance: float = 0.0
## Особенности, которые может получить аксессуар (огонь пока не входит: заглушка).
@export var accessory_features: Array[PartFeature] = []
## Во сколько раз чаще выпадают особенности, к которым тянется производитель аксессуара.
@export_range(1.0, 20.0, 0.5, "suffix:x") var preferred_feature_weight: float = 1.0

@export_group("Название (№49)")
## Шанс префикса в начале названия.
@export_range(0.0, 1.0, 0.01) var prefix_chance: float = 0.0
## Шанс слова от каждой части (дуло, рукоять, магазин, приклад, аксессуар).
@export_range(0.0, 1.0, 0.01) var part_word_chance: float = 0.0
## Не больше слов от частей в одном названии.
@export_range(0, 5, 1) var max_part_words: int = 0
## Основы ключей префиксов: к ним добавляются _M, _F, _N по роду корпуса (в таблице переводов).
@export var prefix_keys: Array[String] = []

@export_group("Цена оружия")
## Формула: цена = (1 + price_per_level x (уровень - 1)) x сумма(базовая цена части x множитель качества части) + надбавка за модификаторы.
@export_range(0.0, 5.0, 0.01) var price_per_level: float = 0.0
## Надбавка за каждый модификатор части.
@export_range(0, 10000, 1) var modifier_price: int = 0
