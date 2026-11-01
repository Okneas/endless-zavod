class_name RunScene
extends Node3D
## Сцена забега (срез 7, №82): ведёт забег по зонам. Генерирует зону за экраном загрузки, ставит игрока на старт, ждёт карту
## навигации и слушает Run: вход в следующую зону (портал шлюза) строит новую зону, конец забега (смерть, эвакуация, победа над
## боссом отдела) показывает экран итогов, кнопка «Новый забег» начинает с первой зоны. Хаба пока нет (срез 8).
## Запуск: открыть run/run.tscn и нажать F6 (главная сцена остаётся тестовой комнатой).
## Клавиши отладки (InputMap): debug_zone_next (]) и debug_zone_prev ([) меняют зону, debug_zone_reseed (N) новый сид зоны.
## Сид забега определяет зону комнаты эвакуации и способ оплаты, сид зоны саму планировку. Фиксированный сид: debug_seed в
## zone_settings.tres.

@onready var _builder: ZoneBuilder = $Zone
@onready var _player: Player = $Player
@onready var _hud: Node = $Hud
@onready var _loading: CanvasLayer = $Loading
@onready var _loading_text: Label = %LoadingText
@onready var _status: Label = $Status/Label

var zone_number: int = 1
var run_seed: int = 0
var zone_seed: int = 0
var layout: ZoneLayout

const HUB_SCENE: String = "res://hub/hub.tscn"

## Как сменить сцену (путь -> void). По умолчанию get_tree().change_scene_to_file; проверка подменяет его.
var hub_changer: Callable = Callable()

var _catalog: Array[RoomDefinition] = []
var _busy: bool = false
var _result_screen: RunResultScreen


func _ready() -> void:
	_catalog = RoomCatalog.load_all()
	_hud.shows_death_screen = false
	_result_screen = RunResultScreen.new()
	add_child(_result_screen)
	_result_screen.new_run_requested.connect(_begin_run)
	_result_screen.hub_requested.connect(_return_to_hub)
	if not Run.carried_loadout.is_empty():
		_player.get_weapon().import_loadout(Run.carried_loadout)
	_player.died.connect(_on_player_died)
	Run.zone_entered.connect(_on_zone_entered)
	Run.run_ended.connect(_on_run_ended)
	_begin_run()


func _process(_delta: float) -> void:
	if _busy or not Run.active:
		return
	if Input.is_action_just_pressed(&"debug_zone_next"):
		Run.set_zone(zone_number + 1)
	elif Input.is_action_just_pressed(&"debug_zone_prev"):
		Run.set_zone(zone_number - 1)
	elif Input.is_action_just_pressed(&"debug_zone_reseed"):
		Run.set_zone(zone_number)


## Начало забега: первая зона, полное здоровье. Деньги, опыт и уровень мира сохраняются между забегами.
func _begin_run() -> void:
	var settings: ZoneSettings = Config.data.zones
	run_seed = settings.debug_seed if settings.debug_seed != 0 else randi()
	if not _player.is_dead:
		_player.set_health(_player.max_health)
	Run.start(run_seed)


# Возврат в магазин: снаряжение (то, что осталось после эвакуации или смерти) уезжает с игроком.
func _return_to_hub() -> void:
	Run.carried_loadout = _player.get_weapon().export_loadout()
	var changer: Callable = hub_changer if hub_changer.is_valid() else func(path: String) -> void: get_tree().change_scene_to_file(path)
	changer.call(HUB_SCENE)


func _on_zone_entered(zone: int) -> void:
	generate(zone)


## Сгенерировать зону под экраном загрузки и поставить игрока на старт.
func generate(number: int) -> void:
	_busy = true
	var settings: ZoneSettings = Config.data.zones
	zone_number = clampi(number, 1, settings.zones_in_department)
	_loading.visible = true
	_loading_text.text = tr("ZONE_GENERATING").format({"zone": zone_number})
	_status.text = ""
	_hud.call(&"set_objective", "")
	# Два кадра: экран загрузки успевает нарисоваться до тяжёлой работы.
	await get_tree().process_frame
	await get_tree().process_frame
	# Фиксированный сид даёт одну и ту же зону, без него каждый запуск и каждое нажатие N новый.
	zone_seed = hash([settings.debug_seed, zone_number]) if settings.debug_seed != 0 else randi()
	layout = ZoneGenerator.new().generate(_catalog, settings, zone_number, run_seed, zone_seed, Progress.world_level)
	_builder.build(layout, settings)
	_place_player()
	# Карта навигации обновляется в потоке и несколько секунд не знает новой зоны: ждём её под экраном загрузки,
	# пока игрок стоит на месте.
	var previous_mode: Node.ProcessMode = _player.process_mode
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	var navigation_ready: bool = await _builder.wait_for_navigation()
	_player.process_mode = previous_mode
	_builder.add_props(Config.data.props)
	if not navigation_ready:
		push_warning("Карта навигации не подхватила зону за отведённое время: враги пойдут напрямую")
	_loading.visible = false
	_status.text = tr("ZONE_STATUS").format({"zone": zone_number, "level": layout.zone_level, "seed": zone_seed, "rooms": layout.room_count(), "links": layout.count(RoomDefinition.Kind.CORRIDOR), "warnings": layout.warnings.size()})
	_busy = false


func _place_player() -> void:
	var spawn: Marker3D = _builder.player_spawn
	if spawn == null:
		return
	if _player.is_dead:
		_player.respawn(spawn.global_position, spawn.global_rotation.y)
		return
	_player.velocity = Vector3.ZERO
	_player.global_position = spawn.global_position
	_player.rotation.y = spawn.global_rotation.y


# Смерть: короткая пауза, чтобы увидеть, что случилось, затем итоги забега (лут теряется там же, в Run.finish).
func _on_player_died() -> void:
	if not Run.active:
		return
	await get_tree().create_timer(1.2).timeout
	Run.finish(Run.Outcome.DEATH, _player)


func _on_run_ended(outcome: int) -> void:
	_hud.call(&"set_objective", "")
	var earned: int = Progress.money - Run.money_at_start
	_result_screen.present(outcome, Run.zone, Config.data.zones.zones_in_department, Progress.money, earned, Run.world_level_before, Run.world_level_after, Run.lost_items)
