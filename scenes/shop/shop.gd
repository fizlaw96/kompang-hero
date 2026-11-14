extends Control

const Levels := preload("res://scripts/levels.gd")

var list: VBoxContainer
var cash_label: Label
var toast: Label
var toast_timer := 0.0


func _ready() -> void:
	_build()
	_refresh()


func _process(delta: float) -> void:
	queue_redraw()
	if toast_timer > 0.0:
		toast_timer -= delta
		toast.modulate.a = clampf(toast_timer * 2.0, 0.0, 1.0)


func _draw() -> void:
	for i in 40:
		draw_rect(Rect2(0, size.y * i / 40.0, size.x, size.y / 40.0 + 1), Color(0.16, 0.06, 0.36).lerp(Color(0.48, 0.12, 0.56), float(i) / 39.0))


func _build() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24
	root.offset_right = -24
	root.offset_top = 16
	root.offset_bottom = -16

	var bar := HBoxContainer.new()
	root.add_child(bar)
	var back := Button.new()
	back.text = "< BACK"
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(func() -> void:
		Sfx.play("click")
		get_tree().change_scene_to_file("res://scenes/levels/levels.tscn"))
	bar.add_child(back)
	var title := Label.new()
	title.text = "SHOP"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.25))
	bar.add_child(title)
	cash_label = Label.new()
	cash_label.add_theme_font_size_override("font_size", 26)
	cash_label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	bar.add_child(cash_label)

	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(list)

	toast = Label.new()
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_font_size_override("font_size", 24)
	toast.modulate.a = 0.0
	root.add_child(toast)


func _refresh() -> void:
	cash_label.text = "CASH  %d" % Save.wallet
	for c in list.get_children():
		c.queue_free()
	for item: Dictionary in Levels.SHOP:
		var id: String = item.id
		var is_shield := id == "shield"
		var lv := int(Save.shields) if is_shield else int(Save.upgrades[id])
		var maxed := (not is_shield) and lv >= int(item.max)
		var price := int(item.prices[0]) if is_shield else int(item.prices[mini(lv, int(item.max) - 1)])

		var panel := PanelContainer.new()
		list.add_child(panel)
		var m := MarginContainer.new()
		for s in ["left", "right", "top", "bottom"]:
			m.add_theme_constant_override("margin_" + s, 14)
		panel.add_child(m)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		m.add_child(row)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var name_l := Label.new()
		name_l.text = item.name
		name_l.add_theme_font_size_override("font_size", 24)
		info.add_child(name_l)
		var desc := Label.new()
		desc.text = item.desc
		desc.modulate = Color(1, 1, 1, 0.8)
		info.add_child(desc)
		var eff := Label.new()
		if is_shield:
			eff.text = Levels.shop_effect(id, 1)
		elif maxed:
			eff.text = "MAX: " + Levels.shop_effect(id, lv)
		else:
			eff.text = "Next: " + Levels.shop_effect(id, lv + 1)
		eff.add_theme_color_override("font_color", Color(1, 0.85, 0.25))
		info.add_child(eff)
		var status := Label.new()
		status.text = "Owned: %d shield%s" % [lv, "" if lv == 1 else "s"] if is_shield else "Level %d / %d" % [lv, int(item.max)]
		status.modulate = Color(0.7, 0.9, 1)
		info.add_child(status)

		var buy := Button.new()
		buy.text = "MAXED" if maxed else "BUY  %d" % price
		buy.disabled = maxed
		buy.custom_minimum_size = Vector2(170, 56)
		buy.add_theme_font_size_override("font_size", 22)
		buy.pressed.connect(func() -> void: _buy(item, price))
		row.add_child(buy)


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
