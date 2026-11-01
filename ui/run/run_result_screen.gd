class_name RunResultScreen
extends ModalPanel
## Экран итогов забега (срез 7, №82): погиб, эвакуировался или победил босса отдела. Пока хаба нет (срез 8), единственная
## кнопка начинает новый забег. Esc экран не закрывает.

signal new_run_requested
## Игрок вернулся в магазин-хаб (срез 8): основной выход после забега.
signal hub_requested


## outcome: Run.Outcome. Остальное для строк итогов: достигнутая зона и зон в отделе, деньги, уровень мира до и после,
## сколько предметов потеряно при смерти.
func present(outcome: int, zone: int, zones_total: int, money: int, earned: int, world_before: int, world_after: int, lost_items: int) -> void:
	clear_column()
	var title_key: String = "RESULT_DEATH"
	var color: Color = Color(1.0, 0.35, 0.3)
	if outcome == Run.Outcome.EVACUATED:
		title_key = "RESULT_EVACUATED"
		color = Color(0.5, 0.9, 1.0)
	elif outcome == Run.Outcome.BOSS_DEFEATED:
		title_key = "RESULT_BOSS"
		color = Color(0.5, 1.0, 0.55)
	add_title(tr(title_key)).add_theme_color_override("font_color", color)
	add_line(tr("RESULT_ZONE").format({"zone": zone, "total": zones_total}))
	add_line(tr("RESULT_MONEY").format({"money": money, "earned": earned}))
	if outcome == Run.Outcome.DEATH:
		add_line(tr("RESULT_LOST").format({"count": lost_items}), Color(1.0, 0.6, 0.5))
	else:
		add_line(tr("RESULT_KEPT"), Color(0.7, 1.0, 0.75))
	if world_after != world_before:
		add_line(tr("RESULT_WORLD_LEVEL").format({"before": world_before, "after": world_after}), Color(1.0, 0.9, 0.5))
	add_button(tr("RESULT_TO_SHOP"), _on_to_shop)
	add_button(tr("RESULT_NEW_RUN"), _on_new_run)
	open()


func _on_to_shop() -> void:
	close()
	hub_requested.emit()


func _on_new_run() -> void:
	close()
	new_run_requested.emit()


func _on_cancel() -> void:
	pass
