class_name GameConfig
extends Resource
## Общий конфиг игры. Данные: data/content/balance/game_config.tres.
## Значения по умолчанию нейтральные: реальные значения лежат только в .tres, не в коде.
## Настройки игрока, движения и хука сюда не входят: они лежат на самих узлах (Player, Hook),
## чтобы их можно было править в Inspector прямо у узла. Здесь общие таблицы без «хозяина»-узла.

## Открытый инвентарь ставит игру и часы на паузу (№51). Флаг нужен, чтобы позже
## проверить режим без паузы. Читает инвентарь (срез 5), здесь он только хранится.
## Стартовое значение в .tres: true.
@export var pause_in_run: bool = false
## Настройки игровых часов.
@export var clock: ClockSettings
## Таблица уязвимостей классов врагов к типам оружия.
@export var vulnerabilities: VulnerabilityTable
## Эффекты стихий на врагах.
@export var elements: ElementSettings
## Опыт и уровень персонажа.
@export var progression: ProgressionSettings
## Падение, притягивание и подбор дропа.
@export var loot: LootSettings
## Правила генерации оружия, каталог частей и шкала качества.
@export var weapons: WeaponGenerationSettings
## Инвентарь, выброшенные предметы, панель слотов на HUD.
@export var inventory: InventorySettings
## Меню: пауза, настройки, инвентарь (масштаб).
@export var menus: MenuSettings
## Генерация зоны (срез 6): число комнат, пул врагов, награда, навигация.
@export var zones: ZoneSettings
## Забег (срез 7): уровень мира, волны, элитный враг и босс, эвакуация, магазин.
@export var run: RunSettings
## Магазин-хаб: покупатели, прилавки, сундук, торговец (срез 8).
@export var shop: ShopSettings
