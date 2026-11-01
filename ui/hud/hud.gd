extends CanvasLayer
## HUD в забеге (11-UI-design): здоровье, уровень и опыт, деньги, прицел и патроны, уведомления
## о подборе, вспышка при уроне, экран смерти. Время суток, отдел и зона, Tab, панель слотов
## появятся в своих срезах.

## На сколько ниже центра экрана стоят заряды рывка (единицы эталона 1080p).
const DASH_INDICATOR_OFFSET: float = 96.0

## Что делать по клавише перезапуска на экране смерти. Пусто: перезагрузить текущую сцену.
var restart_action: Callable = Callable()
## Показывать ли собственный экран смерти. В забеге (срез 7) его заменяет экран итогов, поэтому сцена забега выключает его.
var shows_death_screen: bool = true

var _player: Player
var _weapon: Weapon
var _last_level: int = 0

@onready var _hp_bar: ProgressBar = %HpBar
@onready var _hp_value: Label = %HpValue
@onready var _crosshair: Control = $Root/Crosshair
@onready var _ammo_arc: Control = $Root/Crosshair/AmmoArc
@onready var _ammo_counter: Label = %AmmoCounter
@onready var _level_badge: Control = %LevelBadge
@onready var _money_label: Label = %MoneyLabel
@onready var _feed: VBoxContainer = %PickupFeed
@onready var _death_screen: Control = %DeathScreen
@onready var _death_hint: Label = %DeathHint
@onready var _hit_flash: ColorRect = %HitFlash
@onready var _slot_panel: Control = %WeaponSlots
@onready var _element_icon: Control = %ElementIcon
@onready var _interact_prompt: Label = %InteractPrompt
@onready var _inventory_screen: InventoryScreen = %InventoryScreen

var _interactor: PlayerInteractor
var _objective: Label
var _zone_label: Label
var _clock_label: Label
var _focused: Node3D
var _pause_menu: PauseMenu


func _ready() -> void:
	add_to_group(&"hud")
	Progress.money_changed.connect(_on_money_changed)
	Progress.xp_changed.connect(_on_xp_changed)
	Progress.level_changed.connect(_on_level_changed)
	_on_money_changed(Progress.money)
	_last_level = Progress.level
	_on_xp_changed(Progress.xp, Progress.xp_to_next())
	_pause_menu = PauseMenu.new()
	add_child(_pause_menu)
	_make_objective()
	_make_zone_label()
	_make_clock_label()
	Run.run_started.connect(func() -> void: _death_screen.visible = false)
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player == null:
		push_warning("HUD не нашёл игрока в группе player")
		return
	_player.health_changed.connect(_on_health_changed)
	_player.damaged.connect(_on_player_damaged)
	_player.died.connect(_on_player_died)
	# Игрок мог уже выставить здоровье до нашего _ready, поэтому читаем текущее значение.
	_on_health_changed(_player.health, _player.max_health)
	_weapon = _player.get_weapon()
	_weapon.hit_confirmed.connect(_on_hit_confirmed)
	_slot_panel.call(&"bind", _weapon, Config.data.inventory)
	_weapon.slot_changed.connect(func(_slot: int) -> void: _update_element())
	_weapon.loadout_changed.connect(_update_element)
	_update_element()
	_inventory_screen.bind_player(_player)
	_interactor = _player.get_node("Interactor") as PlayerInteractor
	_interactor.focus_changed.connect(_on_focus_changed)
	_make_dash_indicator()
	_make_target_panel()
	Inventory.rejected.connect(func(_item: InventoryItem) -> void: show_pickup(tr("HUD_INVENTORY_FULL"), Color(1.0, 0.3, 0.3)))


# Esc открывает меню паузы (№79). Закрывают его инвентарь и сама пауза: они работают и на паузе игры, а HUD нет.
func _unhandled_input(event: InputEvent) -> void:
	if _player == null or not event.is_action_pressed(&"ui_cancel"):
		return
	if _inventory_screen.is_open() or _pause_menu.is_open() or _player.is_dead:
		return
	_pause_menu.open()
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_update_clock()
	if _player != null and _player.is_dead and shows_death_screen and Input.is_action_just_pressed(&"interact"):
		_restart()
		# Перезагрузка сцены убирает HUD из дерева сразу: дальше рисовать нечего.
		return
	if _weapon == null or _weapon.stats == null:
		return
	var capacity: int = _weapon.stats.magazine_size
	var progress: float = _weapon.get_reload_progress() if _weapon.is_reloading else -1.0
	_ammo_arc.call(&"set_state", _weapon.ammo, capacity, progress)
	_ammo_counter.text = tr("HUD_RELOADING") if _weapon.is_reloading else "%d/%d" % [_weapon.ammo, capacity]
	_crosshair.call(&"set_spread_pixels", _spread_in_pixels())
	# Дуга патронов отодвигается, когда плечи креста расходятся к ней.
	_ammo_arc.call(&"set_clearance", _crosshair.call(&"get_outer_radius"))
	_crosshair.call(&"set_aim", _weapon.aim_amount)
	_interact_prompt.visible = _focused != null and is_instance_valid(_focused) and not _inventory_screen.is_open()


## Строка в ленте подбора слева от центра (деньги, аптечки, опыт, уровень, предметы, предупреждения).
func show_pickup(text: String, color: Color = Color.WHITE) -> void:
	_feed.call(&"add_line", text, color)


## Цель текущего испытания по центру сверху (волна, элитный враг, босс). Пустая строка убирает надпись.
func set_objective(text: String, color: Color = Color.WHITE) -> void:
	_objective.text = text
	_objective.visible = text != ""
	_objective.add_theme_color_override("font_color", color)


## Открыть экран инвентаря в режиме оплаты лутом (срез 7): игрок отмечает предметы на сумму не меньше цены и платит.
## on_paid получает сумму выбранного, вызывается только после оплаты.
func open_payment(price: int, on_paid: Callable) -> void:
	_inventory_screen.open_payment(price, on_paid)


# «Зона 3/10» в строке денег (11-UI-design: отдел и зона под деньгами в забеге), пока идёт забег.
# Плашка цели над прицелом: здоровье, название и уровень врага, на которого наведён прицел (№86).
func _make_target_panel() -> void:
	var panel: EnemyTargetPanel = EnemyTargetPanel.new()
	panel.name = "EnemyTargetPanel"
	panel.bind(_player)
	$Root.add_child(panel)


# Заряды рывка: под прицелом по центру экрана.
func _make_dash_indicator() -> void:
	var indicator: DashIndicator = DashIndicator.new()
	indicator.name = "DashIndicator"
	indicator.bind(_player)
	indicator.set_anchors_preset(Control.PRESET_CENTER)
	indicator.grow_horizontal = Control.GROW_DIRECTION_BOTH
	indicator.offset_left = -indicator.size.x * 0.5
	indicator.offset_right = indicator.size.x * 0.5
	indicator.offset_top = DASH_INDICATOR_OFFSET
	indicator.offset_bottom = DASH_INDICATOR_OFFSET + indicator.size.y
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Root.add_child(indicator)


# Время суток (№35, срез 8): номер суток, день или ночь и сколько до смены фазы.
func _make_clock_label() -> void:
	_clock_label = Label.new()
	_clock_label.name = "ClockLabel"
	_clock_label.add_theme_font_size_override("font_size", 28)
	_clock_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_clock_label.add_theme_constant_override("outline_size", 8)
	_clock_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	$Root/MoneyRow.add_child(_clock_label)


func _update_clock() -> void:
	if _clock_label == null:
		return
	var clock: ClockSettings = Config.data.clock
	var is_night: bool = GameClock.is_night
	var phase_end: float = clock.day_duration_seconds if not is_night else clock.day_duration_seconds + clock.night_duration_seconds
	var left: int = maxi(ceili(phase_end - GameClock.time_in_cycle), 0)
	_clock_label.text = "   " + tr("HUD_CLOCK").format({"day": GameClock.day_index, "phase": tr("HUD_PHASE_NIGHT" if is_night else "HUD_PHASE_DAY"), "time": "%d:%02d" % [left / 60, left % 60]})
	_clock_label.add_theme_color_override("font_color", Color(0.65, 0.75, 1.0) if is_night else Color(1.0, 0.95, 0.75))


func _make_zone_label() -> void:
	_zone_label = Label.new()
	_zone_label.name = "ZoneLabel"
	_zone_label.add_theme_font_size_override("font_size", 28)
	_zone_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_zone_label.add_theme_constant_override("outline_size", 8)
	_zone_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	$Root/MoneyRow.add_child(_zone_label)
	Run.zone_entered.connect(_update_zone_label)
	Run.run_ended.connect(func(_outcome: int) -> void: _update_zone_label(Run.zone))
	_update_zone_label(Run.zone)


func _update_zone_label(zone: int) -> void:
	_zone_label.visible = Run.active
	_zone_label.text = "   " + tr("HUD_ZONE").format({"zone": zone, "total": Config.data.zones.zones_in_department})


func _make_objective() -> void:
	_objective = Label.new()
	_objective.name = "Objective"
	_objective.anchor_right = 1.0
	_objective.offset_top = 96.0
	_objective.offset_bottom = 150.0
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective.add_theme_font_size_override("font_size", 34)
	_objective.add_theme_color_override("font_outline_color", Color.BLACK)
	_objective.add_theme_constant_override("outline_size", 8)
	_objective.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective.visible = false
	$Root.add_child(_objective)


# Подсказка подбора: клавиша и название предмета цветом его качества.
func _on_focus_changed(target: Node3D) -> void:
	_focused = target
	if target == null:
		return
	_interact_prompt.text = target.call(&"get_prompt")
	_interact_prompt.add_theme_color_override("font_color", target.call(&"get_prompt_color"))


# Иконка стихии оружия в руках рядом со счётчиком патронов.
func _update_element() -> void:
	if _weapon != null and _weapon.stats != null:
		_element_icon.call(&"set_element", _weapon.stats.element)


func _restart() -> void:
	if restart_action.is_valid():
		restart_action.call()
	else:
		get_tree().reload_current_scene()


func _on_health_changed(current: int, maximum: int) -> void:
	_hp_bar.max_value = maximum
	_hp_bar.value = current
	_hp_value.text = str(current)


func _on_money_changed(amount: int) -> void:
	_money_label.text = str(amount)


func _on_xp_changed(xp: int, to_next: int) -> void:
	_level_badge.call(&"set_state", Progress.level, xp, to_next)


func _on_level_changed(level: int) -> void:
	_level_badge.call(&"set_state", level, Progress.xp, Progress.xp_to_next())
	if level > _last_level and _last_level > 0:
		show_pickup(tr("HUD_LEVEL_UP").format({"level": level}))
	_last_level = level


func _on_hit_confirmed(is_crit: bool, _killed: bool) -> void:
	_crosshair.call(&"flash", is_crit)


# Красная вспышка по всему экрану: игрок получил урон.
func _on_player_damaged(_amount: float, _from_position: Vector3) -> void:
	_hit_flash.modulate.a = 0.35
	var tween: Tween = create_tween()
	tween.tween_property(_hit_flash, "modulate:a", 0.0, 0.4)


func _on_player_died() -> void:
	_hit_flash.modulate.a = 0.0
	if not shows_death_screen:
		return
	_death_hint.text = tr("HUD_RESTART_HINT").format({"key": _restart_key_name()})
	_death_screen.visible = true


func _restart_key_name() -> String:
	var events: Array[InputEvent] = InputMap.action_get_events(&"interact")
	if events.is_empty():
		return "?"
	var key: InputEventKey = events[0] as InputEventKey
	if key != null:
		return OS.get_keycode_string(key.physical_keycode)
	return events[0].as_text()


# Перевод угла разброса в пиксели на экране: прицел расходится ровно настолько, куда могут лечь пули.
func _spread_in_pixels() -> float:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return 0.0
	var width: float = get_viewport().get_visible_rect().size.x
	var half_fov: float = deg_to_rad(camera.fov) * 0.5
	return tan(deg_to_rad(_weapon.get_current_spread())) * (width * 0.5) / tan(half_fov)
