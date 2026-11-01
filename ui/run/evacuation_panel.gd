class_name EvacuationPanel
extends ModalPanel
## Панель терминала эвакуации (№82, 04-extraction): выход из забега либо оплатой (деньгами или лутом, способ случаен для
## комнаты), либо отстоять волны врагов. Если оплаты не хватает, остаются волны. Выбор отдаёт сигналом chosen.

signal chosen(choice: int)

enum Choice { PAY_MONEY, PAY_LOOT, WAVES, CANCEL }


## price: цена. pays_loot: комната требует лут (иначе деньги). money и loot_value: сколько у игрока, waves: сколько волн.
func present(price: int, pays_loot: bool, money: int, loot_value: int, waves: int) -> void:
	clear_column()
	add_title(tr("EVAC_TITLE"))
	if pays_loot:
		add_line(tr("EVAC_PRICE_LOOT").format({"price": price}))
		add_line(tr("EVAC_YOUR_LOOT").format({"value": loot_value}), Color(1.0, 1.0, 1.0, 0.65))
		add_button(tr("EVAC_PAY_LOOT"), _choose.bind(Choice.PAY_LOOT), loot_value >= price)
	else:
		add_line(tr("EVAC_PRICE_MONEY").format({"price": price}))
		add_line(tr("EVAC_YOUR_MONEY").format({"money": money}), Color(1.0, 1.0, 1.0, 0.65))
		add_button(tr("EVAC_PAY_MONEY").format({"price": price}), _choose.bind(Choice.PAY_MONEY), money >= price)
	add_button(tr("EVAC_WAVES").format({"waves": waves}), _choose.bind(Choice.WAVES))
	add_button(tr("EVAC_CANCEL"), _choose.bind(Choice.CANCEL))
	open()


func _choose(choice: Choice) -> void:
	close()
	chosen.emit(choice)


func _on_cancel() -> void:
	_choose(Choice.CANCEL)
