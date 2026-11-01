extends CanvasLayer
## ОТЛАДКА: сутки, фаза, время, последнее нажатое действие InputMap, скорость и состояние игрока
## (нужны, чтобы настраивать движение), оружие в руках с частями и характеристиками, а также выдача
## случайного оружия в инвентарь по клавише debug_give_weapon (G) и тестового предмета по debug_give_item (T). Это не интерфейс игры.
## Остальная отладка (деньги, время суток, уровень мира, сид) в панели по F1 (autoload DebugTools); выдачу предметов делает она же.

@onready var _label: Label = $Label

var _last_action: StringName = &""


func _ready() -> void:
	# Экран инвентаря прячет надпись на время открытия (группа), чтобы текст не просвечивал сквозь панели.
	add_to_group(&"debug_overlay")


func _input(event: InputEvent) -> void:
	for action: StringName in InputMap.get_actions():
		# Встроенные ui_* действия Godot нам не интересны, проверяем только свои.
		if String(action).begins_with("ui_"):
			continue
		if event.is_action_pressed(action):
			_last_action = action
			return


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"debug_give_weapon"):
		DebugTools.give_weapon()
	if Input.is_action_just_pressed(&"debug_give_item"):
		DebugTools.give_item()
	var phase: String = tr("DEBUG_PHASE_NIGHT") if GameClock.is_night else tr("DEBUG_PHASE_DAY")
	var minutes: int = floori(GameClock.time_in_cycle / 60.0)
	var seconds: int = floori(fposmod(GameClock.time_in_cycle, 60.0))
	var lines: PackedStringArray = []
	lines.append(tr("DEBUG_CLOCK").format({
		"day": GameClock.day_index,
		"phase": phase,
		"time": "%d:%02d" % [minutes, seconds],
	}))
	lines.append(tr("DEBUG_PROGRESS").format({"level": Progress.level, "xp": Progress.xp, "next": Progress.xp_to_next(), "money": Progress.money}))
	# Имя действия — технический идентификатор, его не переводим.
	var action_name: String = String(_last_action) if _last_action != &"" else tr("DEBUG_NO_ACTION")
	lines.append(tr("DEBUG_LAST_ACTION").format({"action": action_name}))
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player != null:
		lines.append(tr("DEBUG_SPEED").format({
			"speed": "%.1f" % player.get_horizontal_speed(),
			"vertical": "%.1f" % player.velocity.y,
		}))
		lines.append(tr("DEBUG_STATE").format({"state": tr("DEBUG_STATE_" + player.get_state_key())}))
		# Оружие: патроны, текущий разброс и прицеливание, нужны, чтобы настраивать стрельбу.
		var weapon: Weapon = player.get_weapon()
		if weapon != null and weapon.stats != null:
			lines.append(tr("DEBUG_WEAPON").format({
				"name": weapon.get_display_name(),
				"ammo": weapon.ammo,
				"cap": weapon.stats.magazine_size,
				"spread": "%.1f" % weapon.get_current_spread(),
				"aim": roundi(weapon.aim_amount * 100.0),
			}))
			lines.append_array(_weapon_details(weapon))
		# Порог подката на виду: если подкат не запускается, видно, не хватает ли скорости.
		lines.append(tr("DEBUG_SLIDE").format({
			"need": "%.1f" % player.movement.slide_min_speed,
			"speed": "%.1f" % player.get_horizontal_speed(),
		}))
	_label.text = "\n".join(lines)


# Слот, тип, уровень, качество, производитель, ключевые характеристики и список частей.
func _weapon_details(weapon: Weapon) -> PackedStringArray:
	var lines: PackedStringArray = []
	var weapon_instance: WeaponInstance = weapon.instance
	var stats: WeaponStats = weapon.stats
	var maker: Manufacturer = weapon_instance.get_manufacturer()
	var tiers: Array[QualityTier] = weapon_instance.settings.quality_scale.tiers
	lines.append(tr("DEBUG_WEAPON_INFO").format({
		"slot": weapon.active_slot + 1,
		"slots": weapon.slots.size(),
		"type": weapon_instance.get_type_name(),
		"level": weapon_instance.level,
		"quality": tr(tiers[weapon_instance.get_quality()].name_key),
		"maker": tr(maker.name_key) if maker != null else "-",
	}))
	lines.append(tr("DEBUG_WEAPON_STATS").format({
		"damage": "%.1f" % stats.damage,
		"rate": "%.1f" % stats.fire_rate,
		"range": "%.0f" % stats.weapon_range,
		"reload": "%.2f" % stats.reload_time,
		"recoil": "%.2f" % stats.recoil_deg,
		"crit": roundi(stats.crit_chance * 100.0),
	}))
	for line: String in weapon_instance.describe_parts():
		lines.append("   " + line)
	return lines
