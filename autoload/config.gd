extends Node
## Доступ к конфигу игры через Config.data. Сами значения лежат в Resource.

const CONFIG_PATH: String = "res://data/content/balance/game_config.tres"

var data: GameConfig


# _init, а не _ready: к моменту _ready остальных autoload конфиг уже должен быть загружен.
func _init() -> void:
	data = load(CONFIG_PATH) as GameConfig
	assert(data != null, "Не удалось загрузить конфиг игры: %s" % CONFIG_PATH)
