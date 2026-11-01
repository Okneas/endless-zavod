extends Node
## Прогресс персонажа: деньги, опыт и уровень. Живёт между комнатами и перезапусками (при смерти
## опыт и деньги сохраняются, 04-extraction). Таблица опыта в Config.data.progression.

signal money_changed(amount: int)
## Опыт внутри текущего уровня и сколько нужно до следующего (0 на максимальном уровне).
signal xp_changed(xp: int, to_next: int)
signal level_changed(level: int)
signal world_level_changed(level: int)

var money: int = 0
var xp: int = 0
var level: int = 1
## Уровень мира: потолок уровня зон и дропа (03-run-structure). Растёт после босса отдела, между забегами сохраняется.
var world_level: int = 1


func _ready() -> void:
	reset()


## Сбрасывает прогресс к началу игры (новая игра, тесты).
func reset() -> void:
	var settings: ProgressionSettings = Config.data.progression
	money = 0
	xp = 0
	level = settings.start_level
	world_level = Config.data.zones.world_level_start
	money_changed.emit(money)
	xp_changed.emit(xp, xp_to_next())
	level_changed.emit(level)
	world_level_changed.emit(world_level)


func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)


## Потратить деньги. Возвращает false (и ничего не списывает), если их не хватает.
func spend_money(amount: int) -> bool:
	if amount > money:
		return false
	money -= amount
	money_changed.emit(money)
	return true


## Поднять уровень мира на шаг из настроек забега (победа над боссом отдела). Возвращает новый уровень.
## Задаёт уровень мира напрямую (отладка, №89), от 1 до предела забега.
func set_world_level(level: int) -> void:
	world_level = clampi(level, 1, Config.data.run.world_level_max)
	world_level_changed.emit(world_level)


func raise_world_level() -> int:
	world_level = ZoneMath.next_world_level(Config.data.run, world_level)
	world_level_changed.emit(world_level)
	return world_level


## Опыт идёт в текущий уровень; набрав порог, уровень растёт (несколько сразу, если опыта много).
func add_xp(amount: int) -> void:
	var settings: ProgressionSettings = Config.data.progression
	if level >= settings.max_level:
		return
	xp += amount
	while level < settings.max_level and xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		level_changed.emit(level)
	if level >= settings.max_level:
		xp = 0
	xp_changed.emit(xp, xp_to_next())


## Сколько опыта нужно на текущем уровне до следующего. На максимальном уровне 0.
func xp_to_next() -> int:
	var settings: ProgressionSettings = Config.data.progression
	if level >= settings.max_level:
		return 0
	return maxi(1, roundi(settings.xp_base * pow(float(level), settings.xp_exponent)))


## Прибавка к шансу крита от уровня (складывается с критом игрока и оружия).
func get_crit_bonus() -> float:
	var settings: ProgressionSettings = Config.data.progression
	return float(level - 1) * settings.crit_per_level
