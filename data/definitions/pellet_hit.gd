class_name PelletHit
extends RefCounted
## Попадание одной дробины выстрела: её урон, крит и точка. Цель показывает цифру урона на каждую дробину.

var amount: float = 0.0
var is_crit: bool = false
var point: Vector3 = Vector3.ZERO


static func create(p_amount: float, p_is_crit: bool, p_point: Vector3) -> PelletHit:
	var hit: PelletHit = PelletHit.new()
	hit.amount = p_amount
	hit.is_crit = p_is_crit
	hit.point = p_point
	return hit
