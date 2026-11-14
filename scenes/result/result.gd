extends Control

const Levels := preload("res://scripts/levels.gd")

var res: Dictionary
var t := 0.0
var star_nodes: Array[Label] = []
var secret_panel: Control
var secret_shown := false
var unlocked_secret := false
var earn := 0
var next_button: Button
var retry_button: Button


func _ready() -> void:
	res = Save.last_result
	if res.is_empty():
		get_tree().change_scene_to_file.call_deferred("res://scenes/levels/levels.tscn")
		return

	var prev_total := Save.total_stars()
	if not res.failed:
		Save.set_stars(res.level, res.stars)
		earn = roundi(float(res.cash) * 0.2)
		Save.wallet += earn
	unlocked_secret = prev_total < 9 and Save.total_stars() >= 9 and not Save.secret_seen
	Save.save_data()
	# Consume the result so reloading/reentering this scene can't pay out twice.
	Save.last_result = {}

	_build()
	Sfx.play("fail" if res.failed else "win")
	_animate_stars()


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var top := Color(0.16, 0.06, 0.36) if not res.get("failed", false) else Color(0.25, 0.05, 0.08)
	var bottom := Color(0.48, 0.12, 0.56) if not res.get("failed", false) else Color(0.5, 0.1, 0.12)
	for i in 40:
		draw_rect(Rect2(0, size.y * i / 40.0, size.x, size.y / 40.0 + 1), top.lerp(bottom, float(i) / 39.0))


func _build() -> void:
	var card := PanelContainer.new()
	add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.custom_minimum_size = Vector2(540, 0)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	var m := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 24)
	card.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	m.add_child(v)

	var title := Label.new()
	if res.failed:
		title.text = "BOMB HIT!" if res.reason == "bomb" else "OUT OF CASH!"
	else:
		title.text = "LEVEL COMPLETE!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(1, 0.4, 0.4) if res.failed else Color(1, 0.85, 0.25))
	v.add_child(title)

	var stars := HBoxContainer.new()
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.add_theme_constant_override("separation", 14)
	v.add_child(stars)
	for i in 3:
		var s := Label.new()
		s.text = "*"
		s.add_theme_font_size_override("font_size", 96)
		s.add_theme_color_override("font_color", Color(0.3, 0.3, 0.35))
		s.pivot_offset = Vector2(24, 60)
		s.scale = Vector2.ONE
		stars.add_child(s)
		star_nodes.append(s)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	v.add_child(grid)
	var rows := [
		["Score", str(res.score)],
		["Mistakes", str(res.mistakes)],
		["Max combo", str(res.combo)],
		["Remaining cash", "%d / %d" % [res.cash, res.start_cash]],
		["Added to wallet", "+%d" % earn],
		["Stars this run", "%d / 3" % res.stars],
		["Total stars", "%d / 9" % Save.total_stars()],
	]
	for r: Array in rows:
		var a := Label.new()
		a.text = r[0]
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		a.add_theme_font_size_override("font_size", 20)
		grid.add_child(a)
		var b := Label.new()
		b.text = r[1]
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_color_override("font_color", Color(1, 0.85, 0.25))
		grid.add_child(b)

	var note := Label.new()
	note.text = "Level failed - 0 stars. Try again!" if res.failed else "Cash left over is paid into your wallet (20%)."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.modulate = Color(1, 1, 1, 0.8)
	v.add_child(note)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	retry_button = _btn("RETRY", row)
	retry_button.pressed.connect(func() -> void:
		Save.current_level = res_level
		_go("res://scenes/game/game.tscn"))
	var levels_btn := _btn("LEVELS", row)
	levels_btn.pressed.connect(func() -> void: _go("res://scenes/levels/levels.tscn"))
	if res.level == 4 and not res.failed:
		var fin := _btn("ENDING", row)
		fin.pressed.connect(func() -> void:
			Save.story_ending = "good"
			_go("res://scenes/story/story.tscn"))
		fin.grab_focus()
	if res.level == 4 and res.failed:
		var bad := _btn("ENDING", row)
		bad.pressed.connect(func() -> void:
			Save.story_ending = "bad"
			_go("res://scenes/story/story.tscn"))
	var next := _next_target()
	if next.size() == 1:
		next_button = _btn("CONTINUE", row)
		next_button.pressed.connect(func() -> void:
			Save.current_level = next[0]
			Save.story_ending = ""
			_go("res://scenes/story/story.tscn"))
		next_button.grab_focus()
	else:
		retry_button.grab_focus()
	_build_secret()


var res_level: int:
	get: return int(res.level)


func _next_target() -> Array:
	if res.failed:
		return []
	if res.level < 4 and Save.is_unlocked(res.level + 1):
		return [res.level + 1]
	return []


func _btn(text: String, parent: Control) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(140, 50)
	b.add_theme_font_size_override("font_size", 20)
	parent.add_child(b)
	return b


func _go(path: String) -> void:
	Sfx.play("click")
	get_tree().change_scene_to_file(path)


func _animate_stars() -> void:
	for i in 3:
		if i >= int(res.stars):
			continue
		var s := star_nodes[i]
		var tw := create_tween()
		s.scale = Vector2.ZERO
		tw.tween_interval(0.5 + 0.6 * float(i))
		tw.tween_callback(func() -> void:
			s.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
			Sfx.play("star", 1.0, 1.0 + 0.15 * float(i)))
		tw.tween_property(s, "scale", Vector2(1.4, 1.4), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "scale", Vector2.ONE, 0.15)
	if unlocked_secret:
		var tw2 := create_tween()
		tw2.tween_interval(0.5 + 0.6 * float(res.stars) + 0.6)
		tw2.tween_callback(_show_secret)


func _build_secret() -> void:
	secret_panel = ColorRect.new()
	(secret_panel as ColorRect).color = Color(0.1, 0, 0.18, 0.93)
	secret_panel.visible = false
	add_child(secret_panel)
	secret_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	secret_panel.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(520, 0)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	var h := Label.new()
	h.text = "SECRET LEVEL UNLOCKED!"
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_size_override("font_size", 44)
	h.add_theme_color_override("font_color", Color(1, 0.5, 0.95))
	h.add_theme_color_override("font_outline_color", Color(0.3, 0, 0.4))
	h.add_theme_constant_override("outline_size", 10)
	box.add_child(h)
	var p := Label.new()
	p.text = "All 9 stars collected!\nLevel 4 - EXPERT awaits the true masters."
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_theme_font_size_override("font_size", 24)
	box.add_child(p)
	var ok := _btn("TO LEVEL SELECT", box)
	ok.custom_minimum_size = Vector2(0, 56)
	ok.pressed.connect(func() -> void:
		Save.secret_seen = true
		Save.save_data()
		_go("res://scenes/levels/levels.tscn"))


func _show_secret() -> void:
	if secret_shown:
		return
	secret_shown = true
	secret_panel.visible = true
	secret_panel.modulate.a = 0.0
	create_tween().tween_property(secret_panel, "modulate:a", 1.0, 0.6)
	Sfx.play("unlock")
	(secret_panel.get_child(0).get_child(2) as Button).grab_focus()
