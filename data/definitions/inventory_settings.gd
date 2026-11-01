class_name InventorySettings
extends Resource
## Настройки инвентаря, подбора предметов с земли и панели слотов на HUD. Данные: data/content/balance/inventory_settings.tres.
## Значения по умолчанию нейтральные, числа лежат только в .tres и требуют проверки в игре.

@export_group("Инвентарь")
## Число ячеек (№39). Экипированное оружие в лимит не входит, стопка занимает одну ячейку.
@export_range(1, 200, 1) var capacity: int = 0
## Ячеек в строке сетки (20 ячеек при 5 в строке это 5 x 4).
@export_range(1, 20, 1) var columns: int = 1

@export_group("Выброшенные предметы")
## На каком расстоянии перед камерой появляется выброшенный предмет.
@export_range(0.2, 5.0, 0.05, "suffix:м") var drop_distance: float = 0.0
## Скорость броска вперёд и вверх.
@export_range(0.0, 20.0, 0.1, "suffix:м/с") var drop_speed: float = 0.0
@export_range(0.0, 20.0, 0.1, "suffix:м/с") var drop_lift: float = 0.0
@export_range(1.0, 100.0, 0.5, "suffix:м/с²") var drop_gravity: float = 0.0
## Подбор по клавише interact: предмет в этом радиусе и в конусе перед камерой.
@export_range(0.5, 10.0, 0.1, "suffix:м") var interact_range: float = 0.0
@export_range(5.0, 90.0, 1.0, "suffix:°") var interact_cone: float = 0.0

@export_group("Панель слотов оружия на HUD")
## Прозрачность панели, когда оружие не переключают.
@export_range(0.0, 1.0, 0.05) var slots_idle_alpha: float = 0.0
## Сколько секунд после смены оружия панель остаётся яркой.
@export_range(0.0, 10.0, 0.1, "suffix:с") var slots_show_seconds: float = 0.0

@export_group("Отладка")
## Предметы, которые выдаёт отладочная клавиша debug_give_item (по кругу).
@export var debug_items: Array[ItemDefinition] = []