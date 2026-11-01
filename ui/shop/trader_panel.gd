class_name TraderPanel
extends ModalPanel
## Окно торговца (срез 8, №88, расход денег в хабе): несколько случайных составных оружий за деньги. Ассортимент обновляется раз в
## ShopSettings.trader_refresh_days суток, цена выше цены по формуле (trader_markup). Окно временное, строится кодом.

const WIDTH: float = 1300.0


func _ready() -> void:
	super._ready()
	column.custom_minimum_size.x = WIDTH


func present() -> void:
	Shop.refresh_trader(GameClock.day_index)
	_build()
	open()


func _build() -> void:
	clear_column()
	add_title(tr("HUB_TRADER"))
	add_line(tr("TRADER_MONEY").format({"money": Progress.money}), Color(1.0, 0.85, 0.3))
	var settings: ShopSettings = Config.data.shop
	var left: int = maxi(settings.trader_refresh_days - (GameClock.day_index - Shop.trader_refreshed_day), 0)
	add_line(tr("TRADER_REFRESH").format({"days": left}), Color(1.0, 1.0, 1.0, 0.6))
	if Shop.trader_stock.is_empty():
		add_line(tr("TRADER_EMPTY"))
	var list: VBoxContainer = ShopUi.scroll_list(WIDTH, 520.0)
	column.add_child(list.get_meta(&"scroll"))
	for i: int in Shop.trader_stock.size():
		var slot: ShopSlot = Shop.trader_stock[i]
		var affordable: bool = Progress.money >= slot.price
		var subtitle: String
		if slot.item.is_shield():
			subtitle = "%s · %s · %s" % [slot.item.get_type_text(), ShopUi.tr_level(slot.item), tr("CARD_SHIELD_CAPACITY").format({"value": roundi(slot.item.shield.compute_stats().capacity)})]
		elif slot.item.is_grenade():
			var grenade_stats: GrenadeInstance.Stats = slot.item.grenade.compute_stats()
			subtitle = "%s · %s · %s" % [slot.item.get_type_text(), ShopUi.tr_level(slot.item), tr("CARD_GRENADE_COOLDOWN").format({"seconds": "%.0f" % grenade_stats.cooldown})]
		else:
			subtitle = "%s · %s · DPS %d" % [slot.item.get_type_text(), ShopUi.tr_level(slot.item), roundi(slot.item.weapon.get_dps())]
		list.add_child(ShopUi.item_row(slot.item, subtitle, str(slot.price), tr("TRADER_BUY"), _buy.bind(i), affordable))
	if Inventory.is_full():
		add_line(tr("HUB_BACKPACK_FULL"), Color(1.0, 0.5, 0.45))
	add_button(tr("HUB_CLOSE"), close)


func _buy(index: int) -> void:
	Shop.buy_from_trader(index)
	_build()
