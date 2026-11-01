class_name HubScene
extends Node3D
## Сцена хаба-магазина (срез 8, №88, 05-shop-economy): игрок выставляет лут на прилавки и назначает цены, открывает магазин, обслуживает
## покупателей на кассе, прячет лишнее в сундук, смотрит справочник цен, тратит деньги у торговца и уходит в забег через дверь. Время суток
## идёт в хабе так же, как в забеге; ночью покупателей меньше, а освещение темнее. Состояние магазина хранит автозагрузка Shop (оно живёт
## между хабом и забегом). Запуск: главная сцена проекта.

const RUN_SCENE: String = "res://run/run.tscn"
## Свет дня и ночи: энергия солнца, окружающего света и ламп, цвет фона.
const DAY_SUN: float = 1.0
const NIGHT_SUN: float = 0.1
const DAY_AMBIENT: float = 0.55
const NIGHT_AMBIENT: float = 0.18
const DAY_LAMPS: float = 0.0
const NIGHT_LAMPS: float = 1.6
const DAY_BACKGROUND: Color = Color(0.45, 0.6, 0.8)
const NIGHT_BACKGROUND: Color = Color(0.03, 0.04, 0.09)
const PHASE_BLEND_SECONDS: float = 2.0

## Как сменить сцену (путь -> void). По умолчанию get_tree().change_scene_to_file; проверка подменяет его, чтобы не уходить из теста.
var scene_changer: Callable = Callable()
var counters: Array[ShopCounter] = []
var navigation_region: NavigationRegion3D
var register: ShopRegister
var floor_node: ShopFloor
var counter_panel: ShopCounterPanel
var chest_panel: ShopChestPanel
var price_book_panel: PriceBookPanel
var trader_panel: TraderPanel

var _player: Player
var _hud: Node
var _sun: DirectionalLight3D
var _environment: Environment
var _lamps: Array[OmniLight3D] = []
var _tween: Tween


func _ready() -> void:
	_player = $Player as Player
	_hud = $Hud
	_sun = $Sun as DirectionalLight3D
	_environment = ($WorldEnvironment as WorldEnvironment).environment
	for child: Node in $Counters.get_children():
		var counter: ShopCounter = child as ShopCounter
		counters.append(counter)
		counter.activated.connect(_on_counter)
	register = $Register as ShopRegister
	_bake_navigation()
	floor_node = $ShopFloor as ShopFloor
	floor_node.setup(counters, register, ($Entrance as Marker3D).global_position)
	for child: Node in find_children("*", "HubStation", true, false):
		(child as HubStation).activated.connect(_on_station)
	for child: Node in find_children("*", "OmniLight3D", true, false):
		_lamps.append(child as OmniLight3D)
	counter_panel = _add_panel(ShopCounterPanel.new()) as ShopCounterPanel
	chest_panel = _add_panel(ShopChestPanel.new()) as ShopChestPanel
	price_book_panel = _add_panel(PriceBookPanel.new()) as PriceBookPanel
	trader_panel = _add_panel(TraderPanel.new()) as TraderPanel
	var spawn: Marker3D = $PlayerSpawn as Marker3D
	_player.global_position = spawn.global_position
	_player.rotation.y = spawn.global_rotation.y
	if not Run.carried_loadout.is_empty():
		_player.get_weapon().import_loadout(Run.carried_loadout)
	Shop.refresh_trader(GameClock.day_index)
	Shop.day_closed.connect(_on_day_closed)
	GameClock.phase_changed.connect(func(is_night: bool) -> void: _apply_phase(is_night, false))
	_apply_phase(GameClock.is_night, true)


# Сетка навигации зала для покупателей (№89): по коллизиям пола, стен, прилавков, кассы и станций. Игрока и его оружие в неё не берём.
func _bake_navigation() -> void:
	var sources: Array[Node] = [$Geometry, $Counters, $Register]
	for station: Node in find_children("*", "HubStation", true, false):
		sources.append(station)
	navigation_region = NavigationRegion3D.new()
	navigation_region.name = "Navigation"
	navigation_region.navigation_mesh = NavigationBaker.bake_roots(sources, Config.data.zones, NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS)
	add_child(navigation_region)


## Подхватила ли карта навигации сетку зала (покупатели до этого ходят по прямой).
func is_navigation_ready() -> bool:
	var map: RID = get_world_3d().navigation_map
	return NavigationServer3D.map_get_iteration_id(map) > 0 and not NavigationServer3D.map_get_regions(map).is_empty()


func _add_panel(panel: ModalPanel) -> ModalPanel:
	add_child(panel)
	return panel


func _on_counter(index: int) -> void:
	counter_panel.present(index)


func _on_station(kind: HubStation.Kind) -> void:
	match kind:
		HubStation.Kind.CHEST:
			chest_panel.present()
		HubStation.Kind.PRICE_BOOK:
			price_book_panel.present()
		HubStation.Kind.TRADER:
			trader_panel.present()
		HubStation.Kind.SIGN:
			toggle_shop()
		HubStation.Kind.RUN_DOOR:
			enter_run()


## Открыть магазин, если закрыт, и закрыть, если открыт.
func toggle_shop() -> void:
	if Shop.is_open:
		Shop.close_shop()
	else:
		Shop.open_shop()


## Уйти в забег: магазин закрывается, покупатели расходятся (товар возвращается на прилавки), снаряжение уезжает с игроком.
func enter_run() -> void:
	if Shop.is_open:
		Shop.close_shop()
	floor_node.send_all_home()
	Run.carried_loadout = _player.get_weapon().export_loadout()
	var changer: Callable = scene_changer if scene_changer.is_valid() else func(path: String) -> void: get_tree().change_scene_to_file(path)
	changer.call(RUN_SCENE)


func _on_day_closed(earned: int) -> void:
	_hud.call(&"show_pickup", tr("HUB_DAY_RESULT").format({"earned": earned}), Color(1.0, 0.85, 0.3))


# Смена времени суток: свет плавно темнеет и светлеет, лампы по ночам горят.
func _apply_phase(is_night: bool, instant: bool) -> void:
	var sun_energy: float = NIGHT_SUN if is_night else DAY_SUN
	var ambient: float = NIGHT_AMBIENT if is_night else DAY_AMBIENT
	var background: Color = NIGHT_BACKGROUND if is_night else DAY_BACKGROUND
	var lamps: float = NIGHT_LAMPS if is_night else DAY_LAMPS
	if _tween != null:
		_tween.kill()
	if instant:
		_sun.light_energy = sun_energy
		_environment.ambient_light_energy = ambient
		_environment.background_color = background
		for lamp: OmniLight3D in _lamps:
			lamp.light_energy = lamps
		return
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_sun, "light_energy", sun_energy, PHASE_BLEND_SECONDS)
	_tween.tween_property(_environment, "ambient_light_energy", ambient, PHASE_BLEND_SECONDS)
	_tween.tween_property(_environment, "background_color", background, PHASE_BLEND_SECONDS)
	for lamp: OmniLight3D in _lamps:
		_tween.tween_property(lamp, "light_energy", lamps, PHASE_BLEND_SECONDS)
