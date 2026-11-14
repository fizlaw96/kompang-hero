extends Control

const Story := preload("res://scripts/story.gd")
const CHARS_PER_SEC := 45.0

var data: Dictionary
var outro := false
var page := 0
var shown := 0.0
var t := 0.0
var place_l: Label
var text_l: Label
var hint_l: Label
var next_b: Button


func _ready() -> void:
	outro = Save.story_ending != ""
	data = Story.ENDINGS[Save.story_ending] if outro else Story.INTRO[Save.current_level]

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 20)
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 60
	root.offset_right = -60
	root.offset_top = 30
	root.offset_bottom = -30

	var top := HBoxContainer.new()
	root.add_child(top)
	var skip := Button.new()
	skip.text = "SKIP"
	skip.add_theme_font_size_override("font_size", 18)
	skip.pressed.connect(_finish)
	top.add_child(skip)
	place_l = Label.new()
	place_l.text = (("THE END  -  " if Save.story_ending == "good" else "GAME OVER  -  ") if outro else "LEVEL %d  -  " % Save.current_level) + String(data.place).to_upper()
	place_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	place_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	place_l.add_theme_font_size_override("font_size", 26)
	place_l.add_theme_color_override("font_color", Color(1, 0.85, 0.25))
	top.add_child(place_l)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(skip.get_minimum_size().x, 0)
	top.add_child(spacer)

	text_l = Label.new()
	text_l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_l.add_theme_font_size_override("font_size", 32)
	root.add_child(text_l)

	hint_l = Label.new()
	hint_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_l.modulate = Color(1, 1, 1, 0.6)
	root.add_child(hint_l)

	next_b = Button.new()
	next_b.add_theme_font_size_override("font_size", 22)
	next_b.custom_minimum_size = Vector2(220, 52)
	next_b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	next_b.pressed.connect(_advance)
	root.add_child(next_b)
	next_b.grab_focus()
	_show_page()


func _show_page() -> void:
	text_l.text = data.pages[page]
	text_l.visible_characters = 0
	shown = 0.0
	var last: bool = page == data.pages.size() - 1
	if outro:
		next_b.text = "FINISH" if last else "NEXT >"
	else:
		next_b.text = "PLAY!" if last else "NEXT >"
	hint_l.text = "%d / %d    (Space / Enter / click to continue)" % [page + 1, data.pages.size()]


func _advance() -> void:
	var total := text_l.get_total_character_count()
	if text_l.visible_characters < total:
		text_l.visible_characters = total
		shown = float(total)
		return
	Sfx.play("click")
	if page >= data.pages.size() - 1:
		_finish()
	else:
		page += 1
		_show_page()


func _finish() -> void:
	if outro:
		Save.story_ending = ""
		get_tree().change_scene_to_file("res://scenes/levels/levels.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/game/game.tscn")


func _process(delta: float) -> void:
	t += delta
	shown += delta * CHARS_PER_SEC
	text_l.visible_characters = mini(int(shown), text_l.get_total_character_count())
	queue_redraw()


func _draw() -> void:
	var lv := 4 if outro else Save.current_level
	var base: Color = load("res://scripts/levels.gd").LEVELS[lv - 1].color
	for i in 40:
		draw_rect(Rect2(0, size.y * i / 40.0, size.x, size.y / 40.0 + 1), base.darkened(0.7).lerp(base.darkened(0.35), float(i) / 39.0))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			get_viewport().set_input_as_handled()
			_advance()
		elif event.keycode == KEY_ESCAPE:
			_finish()
