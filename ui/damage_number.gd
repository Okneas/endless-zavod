class_name DamageNumber
extends Label3D
## Цифра урона, всплывающая над целью (11-UI-design, №50). Цвет по стихии, крит крупнее и жёлтым.
## Создаётся одним вызовом DamageNumber.spawn(...) и сама удаляется. Выстрел дробовика показывает цифру на
## каждую дробину (spawn_hit), они мельче и чуть разбросаны, чтобы читались вместе.

const RISE_HEIGHT: float = 0.9
const LIFETIME: float = 0.75
const COLOR_DEFAULT: Color = Color(1.0, 1.0, 1.0)
const COLOR_CRIT: Color = Color(1.0, 0.85, 0.2)
## Размер цифр дробин относительно обычной цифры и их разброс по высоте.
const PELLET_SCALE: float = 0.7
const PELLET_SPREAD: float = 0.35
const ELEMENT_COLORS: Dictionary = {
	CombatEnums.Element.ACID: Color(0.55, 1.0, 0.3),
	CombatEnums.Element.ELECTRIC: Color(0.45, 0.75, 1.0),
	CombatEnums.Element.FROST: Color(0.6, 0.95, 1.0),
	CombatEnums.Element.FIRE: Color(1.0, 0.55, 0.2),
}


## Цифры попадания: одна на цель, а у выстрела с несколькими дробинами по цифре на каждую дробину.
## final_amount: итоговый урон по цели после уязвимости и стихий, он делится между дробинами пропорционально.
static func spawn_hit(parent: Node, info: DamageInfo, final_amount: float) -> void:
	if info.pellets.size() <= 1:
		spawn(parent, info.hit_position, final_amount, info.is_crit, info.element)
		return
	var shown: Array[int] = _split_whole(info.pellets, final_amount)
	for i: int in info.pellets.size():
		spawn(parent, info.pellets[i].point, float(shown[i]), info.pellets[i].is_crit, info.element, PELLET_SCALE)


# Урон по дробинам целыми числами так, чтобы цифры в сумме давали округлённый урон по цели (метод наибольших остатков).
static func _split_whole(pellets: Array[PelletHit], final_amount: float) -> Array[int]:
	var total: float = 0.0
	for pellet: PelletHit in pellets:
		total += pellet.amount
	var scale: float = final_amount / total if total > 0.0 else 0.0
	var whole: Array[int] = []
	var fractions: Array[float] = []
	var assigned: int = 0
	for pellet: PelletHit in pellets:
		var raw: float = pellet.amount * scale
		whole.append(floori(raw))
		fractions.append(raw - floorf(raw))
		assigned += whole[whole.size() - 1]
	var missing: int = clampi(roundi(final_amount) - assigned, 0, pellets.size())
	for _step: int in missing:
		var best: int = 0
		for i: int in fractions.size():
			if fractions[i] > fractions[best]:
				best = i
		whole[best] += 1
		fractions[best] = -1.0
	return whole


static func spawn(parent: Node, position: Vector3, amount: float, is_crit: bool, element: CombatEnums.Element, size_scale: float = 1.0) -> DamageNumber:
	if parent == null or not parent.is_inside_tree():
		return null
	var number: DamageNumber = DamageNumber.new()
	number.text = str(roundi(amount))
	number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	number.no_depth_test = true
	number.pixel_size = 0.006
	number.font_size = roundi((72 if is_crit else 48) * size_scale)
	number.outline_size = 14
	number.render_priority = 10
	number.outline_render_priority = 9
	if is_crit:
		number.modulate = COLOR_CRIT
	else:
		number.modulate = ELEMENT_COLORS.get(element, COLOR_DEFAULT)
	parent.add_child(number)
	var jitter: float = 0.2 if size_scale >= 1.0 else PELLET_SPREAD
	number.global_position = position + Vector3(randf_range(-jitter, jitter), 0.3 + (randf() * PELLET_SPREAD if size_scale < 1.0 else 0.0), randf_range(-jitter, jitter))
	number._animate()
	return number


func _animate() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position:y", global_position.y + RISE_HEIGHT, LIFETIME)
	tween.tween_property(self, "modulate:a", 0.0, LIFETIME)
	tween.chain().tween_callback(queue_free)
