class_name ChallengeController
extends Node3D
## Испытание в комнате (срез 7, №82): шлюз между зонами (волны врагов или элитный враг), эвакуационная комната (оплата или
## волны) и комната босса отдела. Игрок входит, двери закрываются, враги появляются через EnemyDirector, после победы двери
## открываются, и в комнате загорается портал (ZonePortal). Вход игрока в портал сообщается в Run.use_exit: следующая зона,
## выход после эвакуации или победа над боссом. Эвакуация начинается не входом, а выбором на терминале (EvacuationPanel).

signal started
signal wave_started(wave: int, total: int)
signal completed
signal portal_used

enum Mode { WAVES, ELITE, BOSS, EVACUATION }
enum State { IDLE, ACTIVE, PAUSE, DONE }

var mode: Mode = Mode.WAVES
var state: State = State.IDLE
var room: RoomPiece
var doors: Array[RoomDoor] = []
var director: EnemyDirector
var portal: ZonePortal
var terminal: EvacuationTerminal
var boss: EnemyBoss
## Номер идущей волны (с единицы) и сколько их всего.
var wave: int = 0
var waves_total: int = 0
## Эвакуация: цена и чем её платить в этой комнате (лутом или деньгами).
var price: int = 0
var pays_loot: bool = false

var _settings: ZoneSettings
var _run: RunSettings
var _zone_number: int = 1
var _trigger: Area3D
## Рост игрока для проверки «внутри комнаты» (капсула стоя).
const PLAYER_HEIGHT: float = 1.8
var _panel: EvacuationPanel


func setup(p_room: RoomPiece, p_mode: Mode, p_doors: Array[RoomDoor], settings: ZoneSettings, zone_number: int, zone_level: int, seed_value: int, run_seed: int, fall_limit: float = -INF) -> void:
	room = p_room
	mode = p_mode
	doors = p_doors
	_settings = settings
	_run = Config.data.run
	_zone_number = zone_number
	name = "Challenge"
	room.add_child(self)
	director = EnemyDirector.new()
	director.setup(room, settings, zone_number, zone_level, seed_value + 1, fall_limit)
	director.cleared.connect(_on_cleared)
	director.enemy_died.connect(_on_enemy_died)
	portal = ZonePortal.new()
	room.add_child(portal)
	portal.setup(_exit_kind())
	var portal_markers: Array[Marker3D] = room.get_markers(&"exit_portal")
	if not portal_markers.is_empty():
		portal.global_transform = portal_markers[0].global_transform
	else:
		portal.global_position = room.global_transform * (room.get_bounds().get_center() * Vector3(1.0, 0.0, 1.0))
	portal.used.connect(_on_portal_used)
	if mode == Mode.EVACUATION:
		price = ZoneMath.evacuation_price(_run, zone_number)
		pays_loot = ZoneMath.evacuation_pays_loot(_run, run_seed, zone_number)
		waves_total = _run.evacuation_waves
		_make_terminal()
	else:
		_make_trigger()


## Чем заканчивается испытание: что делает портал.
func _exit_kind() -> Run.Exit:
	match mode:
		Mode.EVACUATION:
			return Run.Exit.EVACUATE
		Mode.BOSS:
			return Run.Exit.BOSS_VICTORY
	return Run.Exit.NEXT_ZONE


func _make_trigger() -> void:
	var inner: AABB = room.get_trigger_box()
	_trigger = Area3D.new()
	_trigger.name = "Trigger"
	_trigger.collision_layer = 0
	_trigger.collision_mask = 2
	_trigger.position = inner.get_center()
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = inner.size
	shape_node.shape = shape
	_trigger.add_child(shape_node)
	add_child(_trigger)


func _make_terminal() -> void:
	terminal = EvacuationTerminal.new()
	room.add_child(terminal)
	var markers: Array[Marker3D] = room.get_markers(&"terminal")
	if not markers.is_empty():
		terminal.global_transform = markers[0].global_transform
	terminal.activated.connect(_open_panel)


# Испытание начинается, когда игрок целиком внутри комнаты (№87): на лестнице стыка плита закрылась бы у него перед носом.
func _physics_process(_delta: float) -> void:
	if state != State.IDLE or _trigger == null:
		return
	for body: Node3D in _trigger.get_overlapping_bodies():
		if body.is_in_group(&"player") and room.is_actor_inside(body.global_position, PLAYER_HEIGHT):
			begin.call_deferred()
			return


## Начать испытание: двери закрываются, враги появляются. Вызывается входом игрока, а в эвакуации выбором «отстоять волны».
func begin() -> void:
	if state != State.IDLE:
		return
	state = State.ACTIVE
	for door: RoomDoor in doors:
		door.set_closed(true)
	started.emit()
	match mode:
		Mode.WAVES:
			waves_total = _run.gate_waves
			_start_wave(1)
		Mode.EVACUATION:
			_start_wave(1)
		Mode.ELITE:
			_start_elite()
		Mode.BOSS:
			_start_boss()


# --- волны

func _start_wave(number: int) -> void:
	wave = number
	director.spawn_pool(ZoneMath.wave_enemy_count(_run, _zone_number, number))
	wave_started.emit(wave, waves_total)
	_update_objective()
	if director.enemies_alive == 0:
		_wave_cleared()


func _wave_cleared() -> void:
	if wave >= waves_total:
		_complete()
		return
	state = State.PAUSE
	_set_objective(tr("OBJ_NEXT_WAVE").format({"wave": wave + 1, "total": waves_total, "seconds": ceili(_run.wave_pause)}), Color(1.0, 0.9, 0.5))
	get_tree().create_timer(_run.wave_pause, false).timeout.connect(_next_wave)


func _next_wave() -> void:
	if state == State.PAUSE:
		state = State.ACTIVE
		_start_wave(wave + 1)


# --- элитный враг и босс

func _start_elite() -> void:
	director.spawn_scene(_run.elite_scene, _run.elite_count, &"elite_spawn", true)
	if _run.elite_escort > 0:
		director.spawn_pool(_run.elite_escort)
	_set_objective(tr("OBJ_ELITE"), Color(0.85, 0.5, 1.0))
	if director.enemies_alive == 0:
		_complete()


func _start_boss() -> void:
	var spawned: Array[Enemy] = director.spawn_scene(_run.boss_scene, 1, &"boss_spawn", true)
	if spawned.is_empty():
		_complete()
		return
	boss = spawned[0] as EnemyBoss
	if boss != null:
		boss.summon_requested.connect(_on_summon_requested)
		boss.phase_changed.connect(func(_phase: int) -> void: _set_objective(tr("OBJ_BOSS_PHASE_2"), Color(1.0, 0.4, 0.3)))
	_set_objective(tr("OBJ_BOSS"), Color(1.0, 0.4, 0.3))


func _on_summon_requested(scene: PackedScene, count: int) -> void:
	if state == State.ACTIVE and boss != null and is_instance_valid(boss):
		director.spawn_around(scene, count, boss.global_position, 10.0)


func _on_enemy_died(enemy: Enemy) -> void:
	if state != State.ACTIVE:
		return
	if mode == Mode.BOSS and enemy == boss:
		# Босс пал: приспешники не остаются бродить по комнате.
		_complete()
		director.kill_all()
	elif mode == Mode.WAVES or mode == Mode.EVACUATION:
		_update_objective()


func _on_cleared() -> void:
	if state != State.ACTIVE:
		return
	match mode:
		Mode.WAVES, Mode.EVACUATION:
			_wave_cleared()
		Mode.ELITE:
			_complete()


## Испытание пройдено: двери открыты, портал горит.
func _complete() -> void:
	if state == State.DONE:
		return
	state = State.DONE
	for door: RoomDoor in doors:
		if is_instance_valid(door):
			door.set_closed(false)
	portal.set_open(true)
	if terminal != null:
		terminal.enabled = false
	_set_objective(tr("OBJ_PORTAL_OPEN"), Color(0.5, 1.0, 0.6))
	completed.emit()


func _on_portal_used() -> void:
	_set_objective("")
	portal_used.emit()
	Run.use_exit(_exit_kind())


# --- эвакуация

## Сумма цен лута, которым можно платить (вечные предметы не берутся).
func loot_value() -> int:
	var total: int = 0
	for item: InventoryItem in Inventory.items:
		if not item.is_eternal():
			total += item.get_total_price()
	return total


func _open_panel() -> void:
	if state != State.IDLE or (_panel != null and _panel.is_open()):
		return
	if _panel == null:
		_panel = EvacuationPanel.new()
		add_child(_panel)
		_panel.chosen.connect(_on_choice)
	_panel.present(price, pays_loot, Progress.money, loot_value(), waves_total)


func _on_choice(choice: int) -> void:
	match choice:
		EvacuationPanel.Choice.PAY_MONEY:
			if Progress.spend_money(price):
				_complete()
		EvacuationPanel.Choice.PAY_LOOT:
			get_tree().call_group(&"hud", &"open_payment", price, _on_loot_paid)
		EvacuationPanel.Choice.WAVES:
			begin()


func _on_loot_paid(_total: int) -> void:
	_complete()


func _update_objective() -> void:
	_set_objective(tr("OBJ_WAVE").format({"wave": wave, "total": waves_total, "left": director.enemies_alive}), Color(1.0, 0.9, 0.5))


func _set_objective(text: String, color: Color = Color.WHITE) -> void:
	get_tree().call_group(&"hud", &"set_objective", text, color)
