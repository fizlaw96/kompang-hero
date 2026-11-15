extends Control

const Levels := preload("res://scripts/levels.gd")
const ShopRow := preload("res://scenes/shop/shop_row.tscn")

var toast_timer := 0.0

@onready var list: VBoxContainer = $Root/List
@onready var cash_label: Label = $Root/Bar/CashLabel
@onready var toast: Label = $Root/Toast


func _ready() -> void:
	$Root/Bar/BackButton.pressed.connect(func() -> void:
		Sfx.play("click")
		get_tree().change_scene_to_file("res://scenes/levels/levels.tscn"))
	_refresh()


func _process(delta: float) -> void:
	if toast_timer > 0.0:
		toast_timer -= delta
		toast.modulate.a = clampf(toast_timer * 2.0, 0.0, 1.0)


func _refresh() -> void:
	cash_label.text = "CASH  %d" % Save.wallet
	for c in list.get_children():
		c.queue_free()
	for item: Dictionary in Levels.SHOP:
		var row: PanelContainer = ShopRow.instantiate()
		list.add_child(row)
		row.call("setup", item)
		row.connect("buy_pressed", _buy)


func _buy(item: Dictionary, price: int) -> void:
	if Save.wallet < price:
		_toast("Not enough cash!", Color(1, 0.4, 0.4))
		Sfx.play("miss")
		return
	Save.wallet -= price
	if item.id == "shield":
		Save.shields += 1
	else:
		Save.upgrades[item.id] = int(Save.upgrades[item.id]) + 1
	Save.save_data()
	Sfx.play("buy")
	_toast("Purchased %s!" % item.name, Color(0.4, 1, 0.55))
	_refresh()


func _toast(text: String, col: Color) -> void:
	toast.text = text
	toast.add_theme_color_override("font_color", col)
	toast.modulate.a = 1.0
	toast_timer = 2.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/levels/levels.tscn")
