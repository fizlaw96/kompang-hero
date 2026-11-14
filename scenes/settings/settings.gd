extends Control


func _ready() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	root.custom_minimum_size = Vector2(520, 0)
	root.offset_left = -260
	root.offset_right = 260
	root.offset_top = 20

	var bar := HBoxContainer.new()
	root.add_child(bar)
	var back := Button.new()
	back.text = "< BACK"
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(_back)
	bar.add_child(back)
	var title := Label.new()
	title.text = "SETTINGS"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.25))
	bar.add_child(title)

	_slider(root, "Master volume", "master")
	_slider(root, "Music volume", "music")
	_slider(root, "Drum effects volume", "sfx")
	_check(root, "Background music", "music_on")
	_check(root, "Sound effects", "sfx_on")
	_check(root, "Assist mode (wider timing windows)", "assist")
	_check(root, "Reduce screen flashing", "reduce_flash")
	_check(root, "Show tutorial hints", "hints")

	var reset := Button.new()
	reset.text = "RESET ALL PROGRESS"
	reset.add_theme_font_size_override("font_size", 18)
	reset.custom_minimum_size = Vector2(0, 44)
	reset.pressed.connect(func() -> void:
		if reset.text == "RESET ALL PROGRESS":
			reset.text = "PRESS AGAIN TO CONFIRM"
		else:
			Save.reset()
			reset.text = "PROGRESS ERASED")
	root.add_child(reset)


func _draw() -> void:
	for i in 40:
		draw_rect(Rect2(0, size.y * i / 40.0, size.x, size.y / 40.0 + 1), Color(0.16, 0.06, 0.36).lerp(Color(0.48, 0.12, 0.56), float(i) / 39.0))


func _process(_delta: float) -> void:
	queue_redraw()


func _slider(parent: Control, text: String, key: String) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(220, 0)
	l.add_theme_font_size_override("font_size", 20)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.value = float(Save.settings[key])
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(0, 30)
	row.add_child(s)
	var v := Label.new()
	v.text = str(int(s.value))
	v.custom_minimum_size = Vector2(40, 0)
	row.add_child(v)
	s.value_changed.connect(func(val: float) -> void:
		Save.settings[key] = int(val)
		v.text = str(int(val))
		Save.save_data()
		Sfx.apply_settings())
	s.drag_ended.connect(func(_changed: bool) -> void: Sfx.play("perfect"))


func _check(parent: Control, text: String, key: String) -> void:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = bool(Save.settings[key])
	c.add_theme_font_size_override("font_size", 20)
	c.toggled.connect(func(on: bool) -> void:
		Save.settings[key] = on
		Save.save_data()
		Sfx.apply_settings()
		Sfx.play("click"))
	parent.add_child(c)


func _back() -> void:
	Sfx.play("click")
	get_tree().change_scene_to_file("res://scenes/menu/menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_back()
