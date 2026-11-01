class_name ItemDefinition
extends Resource
## Предмет инвентаря, который не оружие: расходник или материал (11-UI-design, раздел «Карточка прочих предметов»).
## Данные: data/content/items/*.tres. Оружие описывается не этим классом, а WeaponInstance.

enum Category { WEAPON, CONSUMABLE, MATERIAL, PART }

## Ключи названия и описания в таблице переводов.
@export var name_key: String = ""
@export var description_key: String = ""
@export var category: Category = Category.CONSUMABLE
## Сколько штук помещается в одной ячейке (стопка занимает одну ячейку).
@export_range(1, 999, 1) var max_stack: int = 1
@export_range(0, 100000, 1) var base_price: int = 0
## Цвет значка в ячейке и в мире.
@export var icon_color: Color = Color(0.8, 0.8, 0.8)
## Расходник: сколько здоровья восстанавливает при использовании. 0 = не лечит.
@export_range(0.0, 1000.0, 1.0) var heal_amount: float = 0.0