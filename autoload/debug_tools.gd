extends Node
## Отладочные инструменты (срез 9, №89): панель по F1 (действие debug_panel) и функции, которыми она и отладочная надпись выдают предметы
## и меняют состояние: деньги, оружие, детали, время суток, уровень мира, сид зон. Нужны, чтобы быстро пройти цикл при проверке баланса.
## Панель и клавиши работают только в отладочной сборке (OS.is_debug_build()), в финальную сборку не попадают.

var panel: DebugPanel

var _generator: WeaponGenerator
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _item_index: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.is_debug_build():
		set_process_unhandled_input(false)
		return
	_rng.randomize()
	panel = DebugPanel.new()
	add_child(panel)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_panel"):
		toggle_panel()
		get_viewport().set_input_as_handled()


## Открыть панель или закрыть, если открыта. Поверх другого окна (пауза, инвентарь, магазин) не открывается.
func toggle_panel() -> void:
	if panel == null:
		return
	if panel.is_open():
		panel.close()
	elif not get_tree().paused:
		panel.present()


## Случайное оружие уровня персонажа в инвентарь. false, если игрока нет или он мёртв.
func give_weapon() -> bool:
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player == null or player.is_dead:
		return false
	var instance: WeaponInstance = _get_generator().generate(_rng, Progress.level)
	if instance == null:
		return false
	Inventory.add(InventoryItem.from_weapon(instance))
	return true


## Случайная деталь оружия в инвентарь.
func give_part() -> bool:
	var part: PartInstance = _get_generator().generate_part(_rng)
	if part == null:
		return false
	Inventory.add(InventoryItem.from_part(part, Config.data.weapons))
	return true


## Следующий тестовый предмет из InventorySettings.debug_items (по кругу).
func give_item() -> bool:
	var definitions: Array[ItemDefinition] = Config.data.inventory.debug_items
	if definitions.is_empty():
		return false
	Inventory.add(InventoryItem.from_definition(definitions[_item_index % definitions.size()]))
	_item_index += 1
	return true


func give_money(amount: int) -> void:
	Progress.add_money(amount)


## Поднять уровень персонажа на один (добавляет нужный опыт).
func level_up() -> void:
	Progress.add_xp(maxi(Progress.xp_to_next() - Progress.xp, 1))


func set_phase(night: bool) -> void:
	GameClock.set_phase(night)


func set_world_level(level: int) -> void:
	Progress.set_world_level(level)


## Сид зон: 0 случайный, иначе каждая зона забега строится одинаково. Меняет значение в памяти, файл настроек не трогает.
func set_zone_seed(value: int) -> void:
	Config.data.zones.debug_seed = value


func _get_generator() -> WeaponGenerator:
	if _generator == null:
		_generator = WeaponGenerator.new(Config.data.weapons)
	return _generator
