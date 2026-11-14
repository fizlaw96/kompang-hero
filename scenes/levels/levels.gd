extends Control

const Levels := preload("res://scripts/levels.gd")

var t := 0.0
var ladder: VBoxContainer
var bridges: Array[ColorRect] = []
var stars_label: Label
var cash_label: Label
var cards: Array[Button] = []


func _ready() -> void:
	_build()
	_refresh()


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	for i in 40:
		draw_rect(Rect2(0, size.y * i / 40.0, size.x, size.y / 40.0 + 1), Color(0.16, 0.06, 0.36).lerp(Color(0.48, 0.12, 0.56), float(i) / 39.0))
	if Save.total_stars() >= 9:
		return
	# Faint pulse behind the locked secret level to hint at it.
	var card := cards[3] if cards.size() == 4 else null
	if card:
		var c := card.global_position + card.size * 0.5
		draw_circle(c - global_position, card.size.x * (0.7 + 0.05 * sin(t * 2.0)), Color(0.7, 0.3, 1, 0.07))


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
	bar.add_theme_constant_override("separation", 12)
	root.add_child(bar)
	var back := _button("< BACK", 18)
	back.pressed.connect(func() -> void: _go("res://scenes/menu/menu.tscn"))
	bar.add_child(back)
	var title := Label.new()
	title.text = "SELECT LEVEL"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.25))
	bar.add_child(title)
	var shop := _button("SHOP", 22)
	shop.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	shop.pressed.connect(func() -> void: _go("res://scenes/shop/shop.tscn"))
	bar.add_child(shop)

	var info := HBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 40)
	root.add_child(info)
	cash_label = Label.new()
	cash_label.add_theme_font_size_override("font_size", 24)
	info.add_child(cash_label)
	stars_label = Label.new()
	stars_label.add_theme_font_size_override("font_size", 28)
	stars_label.add_theme_color_override("font_color", Color(1, 0.85, 0.25))
	info.add_child(stars_label)

	ladder = VBoxContainer.new()
	ladder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ladder.alignment = BoxContainer.ALIGNMENT_CENTER
	ladder.add_theme_constant_override("separation", 0)
	root.add_child(ladder)

	cards.resize(4)
	bridges.resize(3)
	# Climb from the bottom (Level 1) to the top (Level 4).
	for lv in range(4, 0, -1):
		var card := Button.new()
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 76)
		card.focus_mode = Control.FOCUS_ALL
		card.pressed.connect(func() -> void: _on_level(lv))
		var wrap := CenterContainer.new()
		wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ladder.add_child(wrap)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wrap.add_child(card)
		card.custom_minimum_size.x = 640
		cards[lv - 1] = card
		if lv > 1:
			var bridge := ColorRect.new()
			bridge.custom_minimum_size = Vector2(10, 14)
			var bw := CenterContainer.new()
			bw.add_child(bridge)
			ladder.add_child(bw)
			bridges[lv - 2] = bridge


func _style(col: Color, locked: bool, secret: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.6) if locked else col
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(4)
	sb.border_color = Color(0.75, 0.35, 1.0) if secret else Color(1, 1, 1, 0.35)
	if secret and not locked:
		sb.shadow_color = Color(0.8, 0.3, 1, 0.8)
		sb.shadow_size = 24
	return sb


func _refresh() -> void:
	cash_label.text = "CASH  %d" % Save.wallet
	stars_label.text = "%d/9 Stars" % Save.total_stars()
	for i in 4:
		var lv := i + 1
		var d: Dictionary = Levels.LEVELS[i]
		var card := cards[i]
		var open := Save.is_unlocked(lv)
		var secret := lv == 4
		var sb := _style(d.color, not open, secret)
		var hover := _style(d.color.lightened(0.15), not open, secret)
		card.add_theme_stylebox_override("normal", sb)
		card.add_theme_stylebox_override("hover", hover)
		card.add_theme_stylebox_override("pressed", hover)
		card.add_theme_stylebox_override("focus", hover)
		card.add_theme_stylebox_override("disabled", sb)
		card.text = ""
		for c in card.get_children():
			c.queue_free()

		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 18)
		card.add_child(row)
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 18
		row.offset_right = -18

		var badge := _label("[LOCK]" if not open else str(lv), 30 if open else 18, Color(1, 1, 1, 0.9))
		badge.custom_minimum_size = Vector2(64, 0)
		row.add_child(badge)

		var info := VBoxContainer.new()
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		info.add_theme_constant_override("separation", 0)
		row.add_child(info)
		info.add_child(_label("%s%s" % ["* SECRET - " if secret else "", d.name], 26, Color(1, 0.85, 1) if secret else Color.WHITE))
		var sub := ""
		if open:
			sub = "%s   |   %d BPM   |   Start cash %d" % [d.diff, int(Levels.LEVEL_CFG[lv].bpm), int(d.cash)]
		elif secret:
			sub = "Collect all 9 stars from Levels 1-3"
		else:
			sub = "Needs 1 star from Level %d" % (lv - 1)
		info.add_child(_label(sub, 15, Color(1, 1, 1, 0.8)))

		var right := ""
		if secret and not open:
			right = "%d/9" % Save.total_stars()
		elif not secret:
			var got := Save.level_stars(lv)
			right = "*".repeat(got) + "-".repeat(3 - got)
		else:
			right = "PLAY"
		var rl := _label(right, 30, Color(1, 0.85, 0.25))
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rl.custom_minimum_size = Vector2(110, 0)
		row.add_child(rl)

	for i in 3:
		bridges[i].color = Color(1, 0.85, 0.3) if Save.is_unlocked(i + 2) else Color(1, 1, 1, 0.2)


func _label(text: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	return l


func _on_level(lv: int) -> void:
	if not Save.is_unlocked(lv):
		Sfx.play("miss")
		return
	Sfx.play("click")
	Save.current_level = lv
	Save.story_ending = ""
	get_tree().change_scene_to_file("res://scenes/story/story.tscn")


func _button(text: String, fs: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", fs)
	b.custom_minimum_size = Vector2(0, 44)
	return b


func _go(path: String) -> void:
	Sfx.play("click")
	get_tree().change_scene_to_file(path)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_go("res://scenes/menu/menu.tscn")
