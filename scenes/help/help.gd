extends Control

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

@onready var art: Control = $Root/Art
@onready var title_l: Label = $Root/PageTitle
@onready var body_l: Label = $Root/Body
@onready var page_l: Label = $Root/Bar/PageLabel
@onready var prev_b: Button = $Root/Nav/PrevButton
@onready var next_b: Button = $Root/Nav/NextButton
@onready var target: Control = $Root/Art/Target
@onready var glow: Control = $Root/Art/Glow
@onready var ring: Control = $Root/Art/Ring
@onready var green0: Control = $Root/Art/Green0
@onready var orange0: Control = $Root/Art/Orange0
@onready var green1: Control = $Root/Art/Green1
@onready var roll: Control = $Root/Art/Roll
@onready var roll_label: Control = $Root/Art/RollLabel
@onready var bomb_l: Control = $Root/Art/BombL
@onready var bomb_r: Control = $Root/Art/BombR
@onready var key_d: Control = $Root/Art/KeyD
@onready var key_k: Control = $Root/Art/KeyK
@onready var msg: Label = $Root/Art/Msg
@onready var msg2: Label = $Root/Art/Msg2
@onready var fever_bg: Control = $Root/Art/FeverBarBg
@onready var fever_bar: Control = $Root/Art/FeverBarBg/FeverBar
@onready var props: Array[Control] = [glow, ring, green0, orange0, green1, roll, roll_label, bomb_l, bomb_r, key_d, key_k, msg, msg2, fever_bg]


func _ready() -> void:
	$Root/Bar/BackButton.pressed.connect(_back)
	prev_b.pressed.connect(_go.bind(-1))
	next_b.pressed.connect(_go.bind(1))
	_show()


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
	_animate_art()


func _put(node: Control, center: Vector2) -> void:
	node.position = center - node.size * 0.5


func _say(label: Label, text: String, center_y: float, col: Color, fs := 26) -> void:
	label.visible = true
	label.text = text
	label.add_theme_color_override("font_color", col)
	label.add_theme_font_size_override("font_size", fs)
	label.size = Vector2(art.size.x, fs * 1.5)
	label.position = Vector2(0.0, center_y - label.size.y * 0.5)


func _animate_art() -> void:
	var c := art.size * 0.5
	var ph := fposmod(t * 0.5, 1.0)
	var reach := minf(art.size.x * 0.4, 360.0)
	var d := reach * (1.0 - ph)
	for n in props:
		n.visible = false
	_put(target, c)
	match PAGES[page][1]:
		"circle":
			ring.visible = true
			_put(ring, c)
			ring.scale = Vector2.ONE * (1.0 + (1.0 - ph) * 0.9)
			green0.visible = true
			orange0.visible = true
			_put(green0, c + Vector2(-d, 0))
			_put(orange0, c + Vector2(d, 0))
		"normal":
			var notes: Array[Control] = [green0, orange0, green1]
			for k in 3:
				var dd := reach * fposmod(1.0 - ph + float(k) / 3.0, 1.0)
				notes[k].visible = true
				_put(notes[k], c + Vector2(-dd if k % 2 == 0 else dd, 0))
			key_d.visible = true
			key_k.visible = true
			_put(key_d, c + Vector2(-reach - 40, 0))
			_put(key_k, c + Vector2(reach + 40, 0))
		"long":
			var tail := reach * 1.6 * (1.0 - ph)
			var head := maxf(0.0, d)
			roll.visible = true
			roll.size = Vector2(maxf(tail - head, 0.0) + 50.0, 50.0)
			roll.position = Vector2(c.x + head - 25.0, c.y - 25.0)
			roll_label.visible = true
			_put(roll_label, Vector2(c.x + head + (tail - head) * 0.5, c.y))
		"bomb":
			var pl := 0.5 + 0.5 * sin(t * 12.0)
			for bomb: Control in [bomb_l, bomb_r]:
				bomb.visible = true
				bomb.scale = Vector2.ONE * (1.0 + pl * 0.12)
			_put(bomb_l, c + Vector2(-d, 0))
			_put(bomb_r, c + Vector2(d, 0))
			_say(msg, "DO NOT PRESS!", c.y + 100.0, Color(1, 0.4, 0.4))
		"fever":
			glow.visible = true
			_put(glow, c)
			glow.modulate.a = 0.8 + 0.4 * sin(t * 6.0)
			fever_bg.visible = true
			fever_bg.position = Vector2(c.x - 140.0, 20.0)
			fever_bar.size.x = 280.0 * ph
			_say(msg, "FEVER x2", c.y, Color(1, 0.95, 0.4))
		"stars":
			_say(msg, "* * *", c.y - 30.0, Color(1, 0.85, 0.25), 56)
			_say(msg2, "CASH 500 -> 420 left", c.y + 40.0, Color.WHITE)
		"shop":
			_say(msg, "CIRCLE      FEVER      SHIELD", c.y, Color(1, 0.9, 0.4), 34)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_back()
		elif event.keycode == KEY_RIGHT:
			_go(1)
		elif event.keycode == KEY_LEFT:
			_go(-1)
