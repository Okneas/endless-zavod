class_name LootSettings
extends Resource
## Подбираемый дроп (деньги, аптечки): падение, притягивание и подбор. Данные:
## data/content/balance/loot_settings.tres (подключены в game_config.tres).
## Значения по умолчанию нейтральные: числа лежат только в .tres.

## С какого расстояния предмет начинает лететь к игроку.
@export_range(0.0, 20.0, 0.5, "suffix:м") var magnet_radius: float = 0.0
## Максимальная скорость притягивания.
@export_range(0.0, 60.0, 0.5, "suffix:м/с") var magnet_speed: float = 0.0
## Подбирается, когда ближе этого расстояния до центра игрока.
@export_range(0.1, 3.0, 0.05, "suffix:м") var collect_radius: float = 0.0
## Через сколько секунд лежащий предмет пропадает.
@export_range(1.0, 600.0, 1.0, "suffix:с") var lifetime: float = 0.0
## Начальный подброс вверх и разлёт в стороны при выпадении.
@export_range(0.0, 20.0, 0.5, "suffix:м/с") var toss_speed: float = 0.0
@export_range(0.0, 20.0, 0.5, "suffix:м/с") var scatter_speed: float = 0.0
@export_range(1.0, 100.0, 0.5, "suffix:м/с²") var gravity: float = 0.0
