class_name EquipmentRow
extends Control
## Строка колонки «Выбранная экипировка» (набросок автора, 11-UI-design): слева значок оружия с уровнем,
## справа две строки текста (название и DPS). Пять строк: четыре слота оружия и слот гранат (после прототипа).
## Выбранная строка это слот, в который пойдёт «Экипировать». Наведение мыши показывает карточку оружия в слоте
## (её ведёт экран инвентаря), строка при этом подсвечивается. Размеры заданы в единицах эталона 1920 x 1080 (№78).

const BACKGROUND: Color = Color(0.07, 0.07, 0.09, 0.92)
const TOO_HIGH_COLOR: Color = Color(1.0, 0.35, 0.3)
const NAME_SIZE: int = 26
const DETAIL_SIZE: int = 22
const LEVEL_SIZE: int = 23

var slot: int = 0
var weapon: WeaponInstance
## Строка слота гранат (№92): вместо оружия показывает гранату из Inventory.grenade.
var grenade: GrenadeInstance
var is_grenade_row: bool = false
## Строка слота щита (№93): показывает щит из Inventory.shield.
var shield: ShieldInstance
var is_shield_row: bool = false
## Слот гранат: недоступен в прототипе.
var locked: bool = false
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()
## Над строкой курсор мыши: выставляет экран инвентаря.
var hovered: bool = false:
	set(value):
		hovered = value
		queue_redraw()
## Это активное оружие в руках.
var active: bool = false:
	set(value):
		active = value
		queue_redraw()

var _label_empty: String = ""
var _player_level: int = 1


func _init() -> void:
	custom_minimum_size = Vector2(0.0, 96.0)


func setup(p_slot: int, p_weapon: WeaponInstance, player_level: int, empty_text: String, p_locked: bool = false) -> void:
	slot = p_slot
	weapon = p_weapon
	_player_level = player_level
	_label_empty = empty_text
	locked = p_locked
	queue_redraw()


func setup_grenade(p_grenade: GrenadeInstance, player_level: int, empty_text: String) -> void:
	slot = 4
	is_grenade_row = true
	weapon = null
	grenade = p_grenade
	_player_level = player_level
	_label_empty = empty_text
	locked = false
	queue_redraw()


func setup_shield(p_shield: ShieldInstance, player_level: int, empty_text: String) -> void:
	slot = 5
	is_shield_row = true
	weapon = null
	shield = p_shield
	_player_level = player_level
	_label_empty = empty_text
	locked = false
	queue_redraw()


func _draw() -> void:
	if is_shield_row:
		_draw_shield_row()
		return
	if is_grenade_row:
		_draw_grenade_row()
		return
	var frame: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(frame, BACKGROUND)
	var font: Font = ThemeDB.fallback_font
	var icon_rect: Rect2 = Rect2(7.0, 7.0, size.y - 14.0, size.y - 14.0)
	var border: Color = Color(1.0, 1.0, 1.0, 0.15)
	if weapon != null:
		border = Color.WHITE
		var scale: QualityScale = weapon.settings.quality_scale if weapon.settings != null else null
		if scale != null:
			border = scale.tiers[weapon.get_quality()].color
		WeaponIcon.draw(self, icon_rect, weapon)
		var level_color: Color = TOO_HIGH_COLOR if weapon.level > _player_level else Color.WHITE
		draw_string_outline(font, Vector2(13.0, size.y - 13.0), str(weapon.level), HORIZONTAL_ALIGNMENT_LEFT, -1.0, LEVEL_SIZE, 6, Color.BLACK)
		draw_string(font, Vector2(13.0, size.y - 13.0), str(weapon.level), HORIZONTAL_ALIGNMENT_LEFT, -1.0, LEVEL_SIZE, level_color)
		var text_x: float = icon_rect.end.x + 17.0
		var text_width: float = size.x - text_x - 13.0
		# Длинное название переносится на вторую строку, а не обрезается; DPS внизу.
		draw_multiline_string(font, Vector2(text_x, size.y * 0.34), weapon.get_display_name(), HORIZONTAL_ALIGNMENT_LEFT, text_width, NAME_SIZE, 2, Color.WHITE)
		var detail: String = "%s %d" % [tr("CARD_DPS"), roundi(weapon.get_dps())]
		if weapon.is_eternal:
			detail += " · " + tr("CARD_ETERNAL")
		draw_string(font, Vector2(text_x, size.y - 15.0), detail, HORIZONTAL_ALIGNMENT_LEFT, text_width, DETAIL_SIZE, Color(0.78, 0.78, 0.82))
	else:
		var text_color: Color = Color(1.0, 1.0, 1.0, 0.3 if locked else 0.45)
		draw_string(font, Vector2(23.0, size.y * 0.6), _label_empty, HORIZONTAL_ALIGNMENT_LEFT, size.x - 33.0, NAME_SIZE, text_color)
	if locked:
		border = Color(1.0, 1.0, 1.0, 0.08)
	if hovered and not locked:
		draw_rect(frame, Color(1.0, 1.0, 1.0, 0.08))
	draw_rect(frame.grow(-2.0), border, false, 6.0 if selected or hovered else 3.0)
	if active:
		# Активное оружие в руках: светлая полоска слева.
		draw_rect(Rect2(0.0, 0.0, 7.0, size.y), Color(1.0, 0.9, 0.4))


# Слот щита (№93): значок, название, уровень и ёмкость. Рамка цвета качества.
func _draw_shield_row() -> void:
	var frame: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(frame, BACKGROUND)
	var font: Font = ThemeDB.fallback_font
	var icon_rect: Rect2 = Rect2(7.0, 7.0, size.y - 14.0, size.y - 14.0)
	var border: Color = Color(1.0, 1.0, 1.0, 0.15)
	if shield != null:
		border = shield.get_quality_color()
		ItemIcon.draw_shield(self, icon_rect, shield)
		var level_color: Color = TOO_HIGH_COLOR if shield.level > _player_level else Color.WHITE
		draw_string_outline(font, Vector2(13.0, size.y - 13.0), str(shield.level), HORIZONTAL_ALIGNMENT_LEFT, -1.0, LEVEL_SIZE, 6, Color.BLACK)
		draw_string(font, Vector2(13.0, size.y - 13.0), str(shield.level), HORIZONTAL_ALIGNMENT_LEFT, -1.0, LEVEL_SIZE, level_color)
		var text_x: float = icon_rect.end.x + 17.0
		var text_width: float = size.x - text_x - 13.0
		draw_multiline_string(font, Vector2(text_x, size.y * 0.34), shield.get_display_name(), HORIZONTAL_ALIGNMENT_LEFT, text_width, NAME_SIZE, 2, Color.WHITE)
		var detail: String = tr("CARD_SHIELD_CAPACITY").format({"value": roundi(shield.compute_stats().capacity)})
		if shield.is_eternal:
			detail += " · " + tr("CARD_ETERNAL")
		draw_string(font, Vector2(text_x, size.y - 15.0), detail, HORIZONTAL_ALIGNMENT_LEFT, text_width, DETAIL_SIZE, Color(0.78, 0.78, 0.82))
	else:
		draw_string(font, Vector2(23.0, size.y * 0.6), _label_empty, HORIZONTAL_ALIGNMENT_LEFT, size.x - 33.0, NAME_SIZE, Color(1.0, 1.0, 1.0, 0.45))
	if hovered:
		draw_rect(frame, Color(1.0, 1.0, 1.0, 0.08))
	draw_rect(frame.grow(-2.0), border, false, 6.0 if hovered else 3.0)


# Слот гранат: значок, название, уровень и перезарядка. Рамка цвета качества.
func _draw_grenade_row() -> void:
	var frame: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(frame, BACKGROUND)
	var font: Font = ThemeDB.fallback_font
	var icon_rect: Rect2 = Rect2(7.0, 7.0, size.y - 14.0, size.y - 14.0)
	var border: Color = Color(1.0, 1.0, 1.0, 0.15)
	if grenade != null:
		border = grenade.get_quality_color()
		ItemIcon.draw_grenade(self, icon_rect, grenade)
		var level_color: Color = TOO_HIGH_COLOR if grenade.level > _player_level else Color.WHITE
		draw_string_outline(font, Vector2(13.0, size.y - 13.0), str(grenade.level), HORIZONTAL_ALIGNMENT_LEFT, -1.0, LEVEL_SIZE, 6, Color.BLACK)
		draw_string(font, Vector2(13.0, size.y - 13.0), str(grenade.level), HORIZONTAL_ALIGNMENT_LEFT, -1.0, LEVEL_SIZE, level_color)
		var text_x: float = icon_rect.end.x + 17.0
		var text_width: float = size.x - text_x - 13.0
		draw_multiline_string(font, Vector2(text_x, size.y * 0.34), grenade.get_display_name(), HORIZONTAL_ALIGNMENT_LEFT, text_width, NAME_SIZE, 2, Color.WHITE)
		var detail: String = tr("CARD_GRENADE_COOLDOWN").format({"seconds": "%.0f" % grenade.compute_stats().cooldown})
		if grenade.is_eternal:
			detail += " · " + tr("CARD_ETERNAL")
		draw_string(font, Vector2(text_x, size.y - 15.0), detail, HORIZONTAL_ALIGNMENT_LEFT, text_width, DETAIL_SIZE, Color(0.78, 0.78, 0.82))
	else:
		draw_string(font, Vector2(23.0, size.y * 0.6), _label_empty, HORIZONTAL_ALIGNMENT_LEFT, size.x - 33.0, NAME_SIZE, Color(1.0, 1.0, 1.0, 0.45))
	if hovered:
		draw_rect(frame, Color(1.0, 1.0, 1.0, 0.08))
	draw_rect(frame.grow(-2.0), border, false, 6.0 if hovered else 3.0)
