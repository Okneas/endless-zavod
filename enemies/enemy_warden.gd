class_name EnemyWarden
extends EnemySupport
## Щитовик (срез 7б, №83): летающий саппорт, который не лечит, а почти полностью гасит весь урон игрока по связанному с ним
## врагу (в ward_damage_taken раз, например 0.03 — проходит 3%). Привязывается к одному врагу, парит над ним, связь видна
## лучом, а сам прикрытый враг подсвечен. Барьер пропадает, если щитовик убит или связанный враг дальше ward_range.
## Игроку остаётся убить щитовика (он хрупкий и летает) или сменить цель. Щитовики не прикрывают друг друга и саппортов.

const WARD_BEAM_COLOR: Color = Color(0.6, 0.5, 1.0)


func _get_beam_color() -> Color:
	return WARD_BEAM_COLOR


## Берёт только врагов, которых ещё никто не прикрывает.
func _accepts_ally(candidate: Enemy) -> bool:
	return candidate.warded_by == null or not is_instance_valid(candidate.warded_by) or candidate.warded_by.is_dead or candidate.warded_by == self


func is_warding(target: Enemy) -> bool:
	return target != null and target == ally and not is_dead and global_position.distance_to(target.global_position) <= settings.ward_range


func _affect_ally(_delta: float) -> bool:
	if not is_warding(ally):
		return false
	ally.warded_by = self
	return true
