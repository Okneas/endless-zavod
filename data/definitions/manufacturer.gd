class_name Manufacturer
extends Resource
## Производитель оружия (02-combat-fps, №28, №70). Данные: data/content/manufacturers/*.tres.
## У производителя уклон характеристик, пул уникальных модификаторов и склонность аксессуаров к стихиям.
## Фирменные особенности закреплены за частями (поле Signature у WeaponPart).
## Уклон применяет та часть, которой принадлежит характеристика: урон и темп корпус, разброс и дальность дуло,
## отдача и скорость прицеливания рукоять, магазин и перезарядка магазин, стабильность в движении приклад.
## Так оружие из частей разных производителей получает смешанный уклон, а не удвоенный.
## Значения по умолчанию нейтральные (1.0), числа лежат только в .tres.

## Ключ названия в таблице переводов.
@export var name_key: String = ""
## Ключ короткого описания (стиль и роль).
@export var description_key: String = ""
## Цвет значка и моделей-плейсхолдеров этого производителя.
@export var color: Color = Color(0.6, 0.6, 0.6)

@export_group("Специализация")
## Какие типы оружия делает производитель (№72). Части и корпуса остальных типов в выдачу не попадают.
## Пусто = любые типы. Тип, который делают минимум два производителя, получает смешанные сборки.
@export var weapon_types: Array[CombatEnums.WeaponType] = []

@export_group("Уклон характеристик (1.0 = без изменений)")
@export_range(0.1, 3.0, 0.01) var damage_mult: float = 1.0
@export_range(0.1, 3.0, 0.01) var fire_rate_mult: float = 1.0
@export_range(0.1, 3.0, 0.01) var magazine_size_mult: float = 1.0
@export_range(0.1, 3.0, 0.01) var reload_time_mult: float = 1.0
@export_range(0.1, 3.0, 0.01) var spread_mult: float = 1.0
@export_range(0.1, 3.0, 0.01) var range_mult: float = 1.0
@export_range(0.1, 3.0, 0.01) var recoil_mult: float = 1.0
@export_range(0.1, 3.0, 0.01) var aim_time_mult: float = 1.0
@export_range(0.1, 3.0, 0.01) var movement_spread_mult: float = 1.0

@export_group("Прицел")
## Добавка к общему шансу оптики на корпусе этого производителя (1.0 = оптика всегда). Общий шанс в
## WeaponGenerationSettings.optic_chance одинаков для всех, у «своих» производителей он выше.
@export_range(0.0, 1.0, 0.01) var optic_chance_bonus: float = 0.0

@export_group("Модификаторы и аксессуары")
## Пул уникальных модификаторов производителя: из него выбираются модификаторы его частей.
@export var modifier_pool: Array[PartModifier] = []
## Особенности, к которым тянутся аксессуары производителя (при выпадении их шанс выше).
@export var preferred_features: Array[PartFeature] = []