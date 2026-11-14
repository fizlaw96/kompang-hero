extends Control

const COLOR_LEFT := Color(0.3, 0.85, 0.4)
const COLOR_RIGHT := Color(1.0, 0.7, 0.35)
const COLOR_ROLL := Color(0.65, 0.3, 0.95)
const BG_TOP := Color(0.16, 0.06, 0.36)
const BG_BOTTOM := Color(0.48, 0.12, 0.56)

var t := 0.0
var play_button: Button


func _ready() -> void:
	_build_ui()
	play_button.grab_focus()


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var size_ := get_rect().size
	# Gradient background in horizontal bands.
	var bands := 48
	for i in bands:
		var f := float(i) / float(bands - 1)
		draw_rect(Rect2(0, size_.y * i / bands, size_.x, size_.y / bands + 1), BG_TOP.lerp(BG_BOTTOM, f))

	var cy := size_.y * 0.8
	var cx := size_.x * 0.5
	var beat := fposmod(t * 2.0, 1.0)
	var pulse := pow(1.0 - beat, 3.0)
	var r := 54.0 + pulse * 8.0
	draw_circle(Vector2(cx, cy), r + 10.0, Color(1, 1, 1, 0.08 + pulse * 0.1))
	draw_arc(Vector2(cx, cy), r, 0.0, TAU, 64, Color(1, 1, 1, 0.85), 5.0, true)

	# Decorative notes sliding in from both sides, one pair every beat.
	var speed := size_.x * 0.5
	for k in 4:
		var age := (t * 2.0 + float(k)) / 2.0
		var d := fposmod(1.0 - age / 2.0, 1.0) * cx
		var alpha := clampf(d / 120.0, 0.0, 1.0)
		if d > r - 8.0:
			draw_circle(Vector2(cx - d, cy), 26.0, Color(COLOR_LEFT, alpha))
			draw_circle(Vector2(cx + d, cy), 26.0, Color(COLOR_RIGHT, alpha))
	var roll_d := fposmod(1.0 - t / 6.0, 1.0) * cx
	if roll_d > r:
		var pill := Rect2(cx + r, cy - 18.0, roll_d - r + 60.0, 36.0)
		draw_rect(pill, Color(COLOR_ROLL, 0.8))


func _build_ui() -> void:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.custom_minimum_size = Vector2(360, 0)
	box.offset_left = -180
	box.offset_right = 180
	box.offset_top = 60

	var title := Label.new()
	title.text = "KOMPANG HERO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	title.add_theme_color_override("font_outline_color", Color(0.2, 0.04, 0.3))
	title.add_theme_constant_override("outline_size", 12)
	box.add_child(title)

	var tag := Label.new()
	tag.text = "Join the band. Keep the rhythm."
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 20)
	box.add_child(tag)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	box.add_child(spacer)

	play_button = _make_button("PLAY", box)
	play_button.pressed.connect(func() -> void: _go("res://scenes/levels/levels.tscn"))
	var settings_button := _make_button("SETTINGS", box)
	settings_button.pressed.connect(func() -> void: _go("res://scenes/settings/settings.tscn"))
	var help_button := _make_button("HELP", box)
	help_button.pressed.connect(func() -> void: _go("res://scenes/help/help.tscn"))
	var quit_button := _make_button("QUIT", box)
	quit_button.pressed.connect(func() -> void: get_tree().quit())

	var stats := Label.new()
	stats.text = "CASH  %d        STARS  %d/9" % [Save.wallet, Save.total_stars()]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats.add_theme_font_size_override("font_size", 24)
	stats.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	add_child(stats)
	stats.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	stats.offset_top = 14
	stats.offset_right = -20


func _make_button(text: String, parent: Control) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_font_size_override("font_size", 26)
	b.focus_mode = Control.FOCUS_ALL
	parent.add_child(b)
	return b



func _go(path: String) -> void:
	Sfx.play("click")
	get_tree().change_scene_to_file(path)
