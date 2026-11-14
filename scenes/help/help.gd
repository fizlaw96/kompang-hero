extends Control

const COL_LEFT := Color(0.3, 0.85, 0.4)
const COL_RIGHT := Color(1.0, 0.7, 0.35)
const COL_ROLL := Color(0.65, 0.3, 0.95)
const COL_BOMB := Color(0.9, 0.12, 0.12)

const PAGES := [
	["The Rhythm Circle", "circle", "Notes slide in from the drummers toward the big circle. The closer a note is to the centre when you press, the better the hit. You have extra room when you are late, and pressing early never costs you."],
	["Normal Notes", "normal", "Green notes come from the left (press D). Orange notes come from the right (press K). Tap once as they reach the circle. PERFECT gives big points, GOOD gives less. A missed note costs cash."],
	["Long Notes - Level 2+", "long", "A stretched purple note means MASH! When its head reaches the circle, tap that lane's key rapidly until the whole bar has passed. Too slow counts as a mistake."],
	["Bomb Notes - Level 3+", "bomb", "Red bombs with a warning ring: do NOT press that lane! Hitting a bomb fails the level instantly. Letting a bomb pass is perfectly safe."],
	["FEVER Mode", "fever", "Hit 15 notes in a row to fill the FEVER meter. In FEVER your streak cannot be lost and your score is doubled. It lasts a few seconds. The Extended Fever upgrade makes it longer."],
	["Cash and Stars", "stars", "Each level starts with cash. Every mistake costs cash and 0 cash fails the level. For 3 stars you need to keep most of your cash AND score high - a score of 0 earns no stars. 1 star unlocks the next level, and collecting 9 stars unlocks a secret level. Leftover cash is added to your wallet."],
	["Shop and Controls", "shop", "Spend your wallet on a Bigger Circle, Extended Fever and Bomb Shields. Controls: D = left, K = right (or click/touch the left and right halves of the screen). Esc or P pauses. Don't spam - too many presses cost score."],
]

var page := 0
var t := 0.0
var title_l: Label
var body_l: Label
var page_l: Label
var prev_b: Button
var next_b: Button
var art: Control


func _ready() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 40
	root.offset_right = -40
	root.offset_top = 16
	root.offset_bottom = -16

	var bar := HBoxContainer.new()
	root.add_child(bar)
	var back := Button.new()
	back.text = "< BACK"
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(_back)
	bar.add_child(back)
	var h := Label.new()
	h.text = "HOW TO PLAY"
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_size_override("font_size", 38)
	h.add_theme_color_override("font_color", Color(1, 0.85, 0.25))
	bar.add_child(h)
	page_l = Label.new()
	page_l.add_theme_font_size_override("font_size", 22)
	bar.add_child(page_l)

	art = Control.new()
	art.custom_minimum_size = Vector2(0, 220)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.draw.connect(_draw_art)
	root.add_child(art)

	title_l = Label.new()
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_l.add_theme_font_size_override("font_size", 30)
	title_l.add_theme_color_override("font_color", Color(1, 0.85, 0.25))
	root.add_child(title_l)
	body_l = Label.new()
	body_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_l.custom_minimum_size = Vector2(0, 90)
	body_l.add_theme_font_size_override("font_size", 19)
	root.add_child(body_l)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	root.add_child(row)
	prev_b = _btn("< PREV", row)
	prev_b.pressed.connect(func() -> void: _go(-1))
	next_b = _btn("NEXT >", row)
	next_b.pressed.connect(func() -> void: _go(1))
	_show()


func _btn(text: String, parent: Control) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 48)
	b.add_theme_font_size_override("font_size", 20)
	parent.add_child(b)
	return b


func _go(d: int) -> void:
	page = clampi(page + d, 0, PAGES.size() - 1)
	Sfx.play("click")
	_show()


func _show() -> void:
	title_l.text = PAGES[page][0]
	body_l.text = PAGES[page][2]
	page_l.text = "%d/%d" % [page + 1, PAGES.size()]
	prev_b.disabled = page == 0
	next_b.disabled = page == PAGES.size() - 1


func _back() -> void:
	Sfx.play("click")
	get_tree().change_scene_to_file("res://scenes/menu/menu.tscn")


func _process(delta: float) -> void:
	t += delta
	queue_redraw()
	art.queue_redraw()


func _draw() -> void:
	for i in 40:
		draw_rect(Rect2(0, size.y * i / 40.0, size.x, size.y / 40.0 + 1), Color(0.16, 0.06, 0.36).lerp(Color(0.48, 0.12, 0.56), float(i) / 39.0))


func _draw_art() -> void:
	var w := art.size.x
	var h := art.size.y
	var c := Vector2(w * 0.5, h * 0.5)
	var r := minf(h * 0.3, 60.0)
	var nr := r * 0.42
	art.draw_rect(Rect2(0, 0, w, h), Color(0.08, 0.03, 0.2, 0.7))
	var kind: String = PAGES[page][1]
	var ph := fposmod(t * 0.5, 1.0)
	var reach := minf(w * 0.4, 360.0)
	art.draw_circle(c, r, Color(0.08, 0.04, 0.2, 0.7))
	art.draw_arc(c, r, 0.0, TAU, 48, Color.WHITE, 4.0, true)
	var d := reach * (1.0 - ph)
	match kind:
		"circle":
			art.draw_arc(c, r * (1.0 + (1.0 - ph) * 0.9), 0.0, TAU, 48, Color(1, 0.9, 0.35, 0.8), 3.0, true)
			_note(c + Vector2(-d, 0), nr, COL_LEFT)
			_note(c + Vector2(d, 0), nr, COL_RIGHT)
		"normal":
			for k in 3:
				var dd := reach * fposmod(1.0 - ph + float(k) / 3.0, 1.0)
				_note(c + Vector2(-dd if k % 2 == 0 else dd, 0), nr, COL_LEFT if k % 2 == 0 else COL_RIGHT)
			_label("D", c + Vector2(-reach - 40, 8), COL_LEFT)
			_label("K", c + Vector2(reach + 40, 8), COL_RIGHT)
		"long":
			var tail := reach * 1.6 * (1.0 - ph)
			var head := maxf(0.0, d)
			var sb := StyleBoxFlat.new()
			sb.bg_color = COL_ROLL
			sb.set_corner_radius_all(int(nr))
			sb.set_border_width_all(3)
			sb.border_color = Color.WHITE
			var x0 := c.x + head - nr
			art.draw_style_box(sb, Rect2(x0, c.y - nr, maxf(tail - head, 0.0) + nr * 2.0, nr * 2.0))
			_label("MASH!", c + Vector2(head + (tail - head) * 0.5 + 10, 8), Color.WHITE)
		"bomb":
			var pl := 0.5 + 0.5 * sin(t * 12.0)
			for s in [-1, 1]:
				var p: Vector2 = c + Vector2(s * d, 0)
				art.draw_circle(p, nr * (1.35 + pl * 0.2), Color(1, 0.15, 0.15, 0.3 + pl * 0.3))
				art.draw_circle(p, nr * 0.9, Color(0.07, 0.07, 0.07))
				art.draw_arc(p, nr * 0.9, 0.0, TAU, 24, COL_BOMB, 3.0, true)
				_label("!", p + Vector2(0, 8), COL_BOMB)
			_label("DO NOT PRESS!", c + Vector2(0, r * 1.8), Color(1, 0.4, 0.4))
		"fever":
			art.draw_circle(c, r * 1.8, Color(1, 0.85, 0.3, 0.2 + 0.1 * sin(t * 6.0)))
			art.draw_rect(Rect2(c.x - 140, 20, 280, 16), Color(0, 0, 0, 0.5))
			art.draw_rect(Rect2(c.x - 140, 20, 280 * ph, 16), Color(1, 0.6, 0.15))
			_label("FEVER x2", c + Vector2(0, 8), Color(1, 0.95, 0.4))
		"stars":
			_label("* * *", c + Vector2(0, -10), Color(1, 0.85, 0.25), 56)
			_label("CASH 500 -> 420 left", c + Vector2(0, 50), Color.WHITE)
		"shop":
			_label("CIRCLE      FEVER      SHIELD", c + Vector2(0, 8), Color(1, 0.9, 0.4), 34)


func _note(p: Vector2, r: float, col: Color) -> void:
	art.draw_circle(p, r, col)
	art.draw_arc(p, r, 0.0, TAU, 24, Color.WHITE, r * 0.16, true)


func _label(s: String, p: Vector2, col: Color, fs := 26) -> void:
	art.draw_string(ThemeDB.fallback_font, p - Vector2(art.size.x * 0.5, 0), s, HORIZONTAL_ALIGNMENT_CENTER, art.size.x, fs, col)
	pass


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_back()
		elif event.keycode == KEY_RIGHT:
			_go(1)
		elif event.keycode == KEY_LEFT:
			_go(-1)
