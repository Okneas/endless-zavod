class_name DebugPanel
extends ModalPanel
## Панель отладки (срез 9, №89), F1: выдать деньги, оружие, деталь и предмет, переключить день и ночь, поднять уровень персонажа,
## задать уровень мира и сид зон. Строится кодом на общей ModalPanel, закрывается F1 или Esc. Только для разработки.

const WIDTH: float = 1100.0
const ROW_HEIGHT: float = 64.0
const MONEY_STEPS: Array[int] = [100, 1000, 10000]
const WORLD_STEP: int = 5
const SEED_MAX: float = 999999999.0


func _ready() -> void:
	super._ready()
	column.custom_minimum_size.x = WIDTH


func present() -> void:
	_build()
	open()


func _build() -> void:
	clear_column()
	add_title(tr("DBG_TITLE"))
	add_line(tr("DBG_STATUS").format({
		"money": Progress.money,
		"level": Progress.level,
		"world": Progress.world_level,
		"day": GameClock.day_index,
		"phase": tr("HUD_PHASE_NIGHT") if GameClock.is_night else tr("HUD_PHASE_DAY"),
	}), Color(1.0, 0.85, 0.3))
	var money: Array[Button] = []
	for amount: int in MONEY_STEPS:
		money.append(_button(tr("DBG_MONEY").format({"amount": amount}), _give_money.bind(amount)))
	_row(money)
	_row([
		_button(tr("DBG_GIVE_WEAPON"), _act.bind(DebugTools.give_weapon)),
		_button(tr("DBG_GIVE_PART"), _act.bind(DebugTools.give_part)),
		_button(tr("DBG_GIVE_ITEM"), _act.bind(DebugTools.give_item)),
		_button(tr("DBG_GIVE_GRENADE"), _act.bind(DebugTools.give_grenade)),
		_button(tr("DBG_GIVE_SHIELD"), _act.bind(DebugTools.give_shield)),
	])
	_row([
		_button(tr("DBG_PHASE_DAY"), _set_phase.bind(false), not GameClock.is_night),
		_button(tr("DBG_PHASE_NIGHT"), _set_phase.bind(true), GameClock.is_night),
		_button(tr("DBG_LEVEL_UP"), _level_up),
	])
	_row([
		_button("-%d" % WORLD_STEP, _add_world_level.bind(-WORLD_STEP)),
		_label_cell("%s %d" % [tr("DBG_WORLD"), Progress.world_level]),
		_button("+%d" % WORLD_STEP, _add_world_level.bind(WORLD_STEP)),
	])
	var seed_row: HBoxContainer = HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 14)
	seed_row.add_child(_label_cell(tr("DBG_SEED")))
	var seed_field: SpinBox = SpinBox.new()
	seed_field.min_value = 0.0
	seed_field.max_value = SEED_MAX
	seed_field.step = 1.0
	seed_field.value = float(Config.data.zones.debug_seed)
	seed_field.custom_minimum_size = Vector2(300.0, ROW_HEIGHT)
	seed_field.value_changed.connect(_on_seed_changed)
	seed_row.add_child(seed_field)
	column.add_child(seed_row)
	add_line(tr("DBG_NOTE"), Color(1.0, 1.0, 1.0, 0.5))
	add_button(tr("HUB_CLOSE"), close)


func _button(text: String, action: Callable, disabled: bool = false) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = disabled
	button.pressed.connect(action)
	return button


func _label_cell(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	return label


func _row(cells: Array) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	for cell: Control in cells:
		row.add_child(cell)
	column.add_child(row)


# Действия панели перестраивают её, чтобы строка состояния и недоступные кнопки были свежими.
func _give_money(amount: int) -> void:
	DebugTools.give_money(amount)
	_build()


func _act(action: Callable) -> void:
	action.call()
	_build()


func _set_phase(night: bool) -> void:
	DebugTools.set_phase(night)
	_build()


func _level_up() -> void:
	DebugTools.level_up()
	_build()


func _add_world_level(delta: int) -> void:
	DebugTools.set_world_level(Progress.world_level + delta)
	_build()


func _on_seed_changed(value: float) -> void:
	DebugTools.set_zone_seed(int(value))
