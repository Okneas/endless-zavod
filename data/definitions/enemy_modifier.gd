class_name EnemyModifier
extends Resource
## Модификатор врага, префикс в названии (№92): «Громила», «Скороход» и т.д. Сдвигает характеристики, размер модели и даёт особенности.
## Данные: data/content/modifiers/*.tres, список в EnemyModifierSettings. Новый префикс с числами это новый файл без правки кода;
## особенности (восстановление, ярость, взрыв при гибели) включаются полями ниже.

@export_group("Вид")
## Слово перед названием врага («Громила»), ключ в таблице переводов.
@export var name_key: String = ""
## Размер модели и тело (1.0 — как обычно). Масштабируется весь враг, включая столкновения.
@export_range(0.3, 3.0, 0.05, "suffix:x") var model_scale: float = 1.0
## Оттенок модели и насколько сильно он подмешивается (0 — без оттенка).
@export var tint: Color = Color.WHITE
@export_range(0.0, 1.0, 0.05) var tint_amount: float = 0.0
## Относительный шанс выбора среди модификаторов (вес) и самая ранняя зона, где префикс встречается.
@export_range(0.1, 20.0, 0.1) var weight: float = 1.0
@export_range(1, 10, 1) var min_zone: int = 1

@export_group("Характеристики")
@export_range(0.1, 10.0, 0.05, "suffix:x") var health_mult: float = 1.0
## Множитель урона врага по игроку.
@export_range(0.1, 10.0, 0.05, "suffix:x") var damage_mult: float = 1.0
@export_range(0.1, 5.0, 0.05, "suffix:x") var speed_mult: float = 1.0
## Во сколько раз враг получает урон (0.6 — броня гасит 40%). Действует на выстрелы, гранаты и взрывы.
@export_range(0.05, 3.0, 0.05, "suffix:x") var damage_taken_mult: float = 1.0
## Щит (№93): доля максимального здоровья, которую префикс добавляет врагу щитом (0 — не даёт). Складывается со щитом самого типа.
@export_range(0.0, 5.0, 0.05) var shield_share: float = 0.0
## Награда: опыт и деньги, и шансы выпадения деталей, гранат и хлама.
@export_range(1.0, 10.0, 0.05, "suffix:x") var reward_mult: float = 1.0
@export_range(1.0, 10.0, 0.05, "suffix:x") var drop_mult: float = 1.0

@export_group("Особенности")
## Восстановление: доля максимального здоровья в секунду после regen_delay секунд без попаданий.
@export_range(0.0, 0.5, 0.005) var regen_per_second: float = 0.0
@export_range(0.0, 20.0, 0.1, "suffix:с") var regen_delay: float = 0.0
## Ярость: когда здоровье ниже этой доли, урон и скорость растут (0 — без ярости).
@export_range(0.0, 1.0, 0.05) var enrage_below: float = 0.0
@export_range(1.0, 5.0, 0.05, "suffix:x") var enrage_damage_mult: float = 1.0
@export_range(1.0, 5.0, 0.05, "suffix:x") var enrage_speed_mult: float = 1.0
## Взрыв при гибели: радиус и урон игроку в центре (растёт с уровнем врага вместе с уроном). 0 — не взрывается.
@export_range(0.0, 20.0, 0.5, "suffix:м") var death_blast_radius: float = 0.0
@export_range(0.0, 500.0, 1.0) var death_blast_damage: float = 0.0
