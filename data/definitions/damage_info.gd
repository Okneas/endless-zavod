class_name DamageInfo
extends RefCounted
## Одно попадание: что и как нанесло урон. Передаётся в take_hit() цели (враг, мишень).

var amount: float = 0.0
var is_crit: bool = false
var element: CombatEnums.Element = CombatEnums.Element.NONE
var weapon_type: CombatEnums.WeaponType = CombatEnums.WeaponType.PISTOL
## Таблица уязвимостей работает только для оружия; удар в ближнем бою её не использует.
var apply_vulnerability: bool = true
var hit_position: Vector3 = Vector3.ZERO
## Попадания отдельных дробин выстрела в эту цель (у оружия с одной пулей пусто или одна запись).
## amount при этом сумма всех дробин, цель применяет урон один раз, а цифры показывает по дробинам.
var pellets: Array[PelletHit] = []


static func create(p_amount: float, p_is_crit: bool, p_hit_position: Vector3) -> DamageInfo:
	var info: DamageInfo = DamageInfo.new()
	info.amount = p_amount
	info.is_crit = p_is_crit
	info.hit_position = p_hit_position
	return info
