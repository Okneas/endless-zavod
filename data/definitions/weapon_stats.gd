class_name WeaponStats
extends RefCounted
## Итоговые характеристики оружия: считаются из частей в WeaponDefinition.compute_stats().
## Сами числа живут в частях (WeaponPart), здесь только результат.

var damage: float = 0.0
## Выстрелов в секунду.
var fire_rate: float = 0.0
var automatic: bool = false
var magazine_size: int = 0
var reload_time: float = 0.0
## Половина угла конуса разброса в покое, градусы.
var spread_deg: float = 0.0
## Дальность луча, м.
var weapon_range: float = 0.0
## Подъём камеры за выстрел, градусы.
var recoil_deg: float = 0.0
## Время входа в прицеливание, секунды.
var aim_time: float = 0.0
## Кратность приближения в прицеливании (1.5 = в полтора раза).
var aim_zoom: float = 1.0
## Шанс крита самого оружия (складывается с критом игрока).
var crit_chance: float = 0.0
## Тип оружия (от корпуса) и стихия (от аксессуара).
var weapon_type: CombatEnums.WeaponType = CombatEnums.WeaponType.PISTOL
var element: CombatEnums.Element = CombatEnums.Element.NONE

## Дробин за выстрел (урон делится между ними).
var pellets: int = 1
## Множитель добавки разброса от движения (меньше 1.0 лучше, приклад).
var movement_spread_mult: float = 1.0
## Бонус урона аксессуара в подкате и в воздухе (0.3 = +30%) и к удару в ближнем бою.
var slide_damage_bonus: float = 0.0
var air_damage_bonus: float = 0.0
var melee_damage_bonus: float = 0.0
