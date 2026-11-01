class_name ItemPicture
extends Control
## Крупная картинка предмета в шапке карточки: силуэт оружия или значок прочего предмета (те же, что в ячейке).

var _item: InventoryItem


func _init() -> void:
	custom_minimum_size = Vector2(166.0, 73.0)


func set_item(item: InventoryItem) -> void:
	_item = item
	queue_redraw()


func _draw() -> void:
	if _item != null:
		ItemIcon.draw(self, Rect2(Vector2.ZERO, size), _item)
