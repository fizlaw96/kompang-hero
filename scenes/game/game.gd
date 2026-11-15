extends Control

# Main gameplay. Everything is drawn in _draw(). Judging is by pixel distance from a note to the circle centre.
# D hits left-lane notes, K hits right-lane notes (mouse/touch: left or right half of the screen).

const Levels := preload("res://scripts/levels.gd")
const OsuParser := preload("res://scripts/osu_parser.gd")
const GAME_FONT := preload("res://assets/fonts/PixelOperator8-Bold.ttf")

const PERFECT_RATIO := 0.3
const GOOD_EARLY_RATIO := 1.5
const GOOD_LATE_RATIO := 2.0
const BOMB_RATIO := 1.0
const SPAM_WINDOW := 1.0
const SPAM_FREE_PRESSES := 5
const SPAM_PENALTY := 75
const ROLL_TAPS_PER_SEC := 4.0
const ROLL_TAP_SCORE := 50
const ROLL_BONUS := 500
const FEVER_NEED := 15
const FEVER_BASE := 8.0
const PLAYER := 1
const COUNT_IN_BEATS := 3.0

const COL_LEFT := Color(0.3, 0.85, 0.4)
const COL_RIGHT := Color(1.0, 0.7, 0.35)
const COL_ROLL := Color(0.65, 0.3, 0.95)
const COL_BOMB := Color(0.9, 0.12, 0.12)

## Set per level scene (scenes/game/level_1.tscn ... level_4.tscn).
@export_group("Level")
@export_range(1, 4, 1) var level := 1

@export_group("Chart")
## Optional osu!mania 2K chart. Leave empty to use the generated chart for [member level].
## The .osu file's first uninherited timing point sets the scroll speed and music pitch.
@export_file("*.osu") var chart_file := ""

@export_group("Tutorial")
## Shown when the level opens; gameplay waits until START is pressed. Leave the title empty for no tutorial.
@export var tutorial_title := ""
@export_multiline var tutorial_text := ""
## Looping example animation shown in the tutorial popup.
@export_enum("none", "normal", "long", "bomb", "all") var tutorial_demo := "none"

@export_group("Music")
## Song for this level. Leave empty to use the built-in synth loop.
@export var music: AudioStream

var tutorial_open := false
var ref_score := 1
var cfg: Dictionary
var spb := 0.5
var notes: Array[Dictionary] = []
var end_time := 0.0
var song_time := 0.0
var music_started := false
var paused := false
var over := false
var over_timer := 0.0

var start_cash := 0
var cash := 0.0
var score := 0
var combo := 0
var max_combo := 0
var mistakes := 0
var charge := 0
var fever := false
var fever_end := 0.0
var fever_dur := 0.0
var failed := false
var fail_reason := ""

var hold: Dictionary = {}
var press_times: Array[float] = []
var hit_at := [-9.0, -9.0, -9.0, -9.0, -9.0, -9.0, -9.0, -9.0]
var scared := [-9.0, -9.0, -9.0, -9.0]
var clock := 0.0
var drummer_offsets: Array[Vector2] = []
var floats: Array[Dictionary] = []
var parts: Array[Dictionary] = []
var flash := 0.0
var flash_col := Color.WHITE
var ring_flash := 0.0
var ring_col := Color.WHITE
var explode_at := -9.0
var hints: Array[Dictionary] = []
var hint_idx := 0
var hint_text := ""
var hint_until := 0.0

var R := 60.0
var speed := 300.0
var good_early := 90.0
var good_late := 120.0
var perfect_dist := 18.0
var bomb_dist := 60.0
var pause_panel: Control

const STAGES := [
	preload("res://assets/Libraries/enviroment/without npc/tutorial-stage.png"),
	preload("res://assets/Libraries/enviroment/without npc/wedding-kampung-stage.png"),
	preload("res://assets/Libraries/enviroment/without npc/wedding-hall-stage.png"),
	preload("res://assets/Libraries/enviroment/without npc/port-klang-stage(secret level).png"),
]


@onready var background: TextureRect = $Background
@onready var drummers: Array[TextureRect] = _find_drummers()
@onready var idle_tex: Array[Texture2D] = _idle_textures()
@onready var villain_hit_tex: Texture2D = preload("res://scenes/game/hit_villain.tres")
@onready var miss_tex: Array[Texture2D] = [
	preload("res://scenes/game/miss_red.tres"), preload("res://scenes/game/miss_blue.tres"),
	preload("res://scenes/game/miss_brown.tres"), preload("res://scenes/game/miss_yellow.tres"),
]
@onready var hit_tex: Array[Texture2D] = [
	preload("res://scenes/game/hit_red.tres"), preload("res://scenes/game/hit_blue.tres"),
	preload("res://scenes/game/hit_brown.tres"), preload("res://scenes/game/hit_yellow.tres"),
]


func _find_drummers() -> Array[TextureRect]:
	var out: Array[TextureRect] = []
	for i in 8:
		var d := get_node_or_null("Drummer%d" % i) as TextureRect
		if d != null:
			out.append(d)
	return out


func _idle_textures() -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for d in drummers:
		out.append(d.texture)
	return out


func _ready() -> void:
	Save.current_level = level
	# Keep the drummer layout authored in the scene (a level scene can override it too).
	drummer_offsets.clear()
	for i in drummers.size():
		drummer_offsets.append(Vector2(drummers[i].offset_left, drummers[i].offset_top))
	# Level scenes set their own Background texture; this fallback keeps the base scene usable.
	if background.texture == null:
		background.texture = STAGES[level - 1]
	var chart := _load_chart()
	cfg = chart.cfg
	ref_score = Levels.reference_score(chart.notes)
	spb = 60.0 / float(chart.bpm)
	end_time = chart.end_time
	start_cash = int(Levels.LEVELS[level - 1].cash)
	cash = float(start_cash)

	var counters := {-1: 0, 1: 0}
	for n: Dictionary in chart.notes:
		var side: int = n.side
		n["owner"] = (0 if side < 0 else 2) + (counters[side] % 2)
		counters[side] += 1
		n["res"] = ""
		n["taps"] = 0
		n["need"] = maxi(3, int((float(n.end) - float(n.time)) * ROLL_TAPS_PER_SEC * 0.8)) if n.type == "long" else 0
		n["started"] = false
		n["anim"] = false
		notes.append(n)

	song_time = -spb * COUNT_IN_BEATS
	if level == 1:
		hints = [
			{"t": -spb * 2.0, "text": "Notes roll from the drummers toward the big circle", "dur": 3.0},
			{"t": 4.0 * spb, "text": "Press D for green (left) notes, K for orange (right)", "dur": 5.0},
			{"t": 20.0 * spb, "text": "Closer to the centre = better. Misses cost cash!", "dur": 3.5},
			{"t": 36.0 * spb, "text": "Chain hits to fill the FEVER meter", "dur": 3.5},
		]
	elif level == 2:
		hints = [{"t": 6.0 * spb, "text": "Purple LONG notes: mash the key until the bar passes!", "dur": 4.5}]
	elif level == 3:
		hints = [{"t": 6.0 * spb, "text": "RED BOMBS: do NOT press that lane when they reach the circle!", "dur": 4.5}]
	elif level == 4:
		hints = [{"t": -spb * 2.0, "text": "Everything at once. Good luck.", "dur": 3.0}]

	_build_pause()
	_layout()
	resized.connect(_layout)

	if not tutorial_title.is_empty():
		$Tutorial/Panel/Margin/Box/Title.text = tutorial_title
		$Tutorial/Panel/Margin/Box/Body.text = tutorial_text
		var demo: Control = $Tutorial/Panel/Margin/Box/Demo
		demo.visible = tutorial_demo != "none"
		if demo.visible:
			$Tutorial/Panel/Margin/Box/Demo/Anim.play(tutorial_demo)
		$Tutorial.visible = true
		tutorial_open = true
		$Tutorial/Panel/Margin/Box/StartButton.grab_focus()


func _close_tutorial() -> void:
	Sfx.play("click")
	$Tutorial.visible = false
	tutorial_open = false


func _load_chart() -> Dictionary:
	if chart_file.is_empty():
		return Levels.build_chart(level)
	var parsed := OsuParser.parse(chart_file)
	if not bool(parsed.get("ok", false)):
		push_warning("Chart '%s' rejected: %s. Using the generated chart for level %d." % [chart_file, parsed.get("error", "unknown error"), level])
		return Levels.build_chart(level)
	return _chart_from_osu(parsed)


func _chart_from_osu(parsed: Dictionary) -> Dictionary:
	var m: Dictionary = Levels.LEVEL_CFG[level]
	var bpm := float(parsed.get("bpm", m.bpm))
	var out_notes: Array[Dictionary] = []
	var last := 0.0
	for src: Dictionary in parsed.notes:
		var is_long := float(src.end) > 0.0
		var end := float(src.end) if is_long else -1.0
		out_notes.append({
			"time": float(src.time),
			"side": -1 if int(src.column) == 0 else 1,
			"type": "long" if is_long else ("bomb" if bool(src.get("bomb", false)) else "normal"),
			"end": end,
		})
		last = maxf(last, end if is_long else float(src.time))
	return {
		"bpm": bpm,
		"notes": out_notes,
		"end_time": last + (60.0 / bpm) * 4.0,
		"cfg": m,
	}


func _layout() -> void:
	var lv_up := int(Save.upgrades.circle)
	var grow := 1.0 + 0.15 * float(lv_up)
	R = minf(size.y * 0.12, size.x * 0.085) * grow
	if Save.settings.assist:
		grow *= 1.0
	good_early = R * GOOD_EARLY_RATIO * (1.4 if Save.settings.assist else 1.0)
	good_late = R * GOOD_LATE_RATIO * (1.4 if Save.settings.assist else 1.0)
	perfect_dist = R * PERFECT_RATIO
	bomb_dist = R * BOMB_RATIO
	speed = (size.x * 0.5) / (3.6 * spb)


func _drummer_x(i: int) -> float:
	return size.x * [0.09, 0.27, 0.73, 0.91][i]


func _build_pause() -> void:
	pause_panel = ColorRect.new()
	(pause_panel as ColorRect).color = Color(0.04, 0.0, 0.1, 0.8)
	pause_panel.visible = false
	add_child(pause_panel)
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	pause_panel.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(280, 0)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	box.add_child(title)
	for item: Array in [["RESUME", _toggle_pause], ["RESTART", _restart], ["QUIT TO LEVELS", _quit]]:
		var b := Button.new()
		b.text = item[0]
		b.custom_minimum_size = Vector2(0, 52)
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(item[1])
		box.add_child(b)


func _toggle_pause() -> void:
	if over:
		return
	paused = not paused
	pause_panel.visible = paused
	Sfx.pause_music(paused)
	Sfx.play("click")


func _restart() -> void:
	Sfx.stop_music()
	get_tree().reload_current_scene()


func _quit() -> void:
	Sfx.stop_music()
	get_tree().change_scene_to_file("res://scenes/levels/levels.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if tutorial_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode
		if code == KEY_ESCAPE or code == KEY_P:
			_toggle_pause()
		elif paused or over:
			return
		elif code == KEY_D:
			_press(-1)
		elif code == KEY_K:
			_press(1)
	elif (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		if paused or over:
			return
		var x: float = event.position.x
		_press(-1 if x < size.x * 0.5 else 1)


func _process(delta: float) -> void:
	clock += delta
	if not paused and not tutorial_open:
		delta = minf(delta, 0.05)
		if not over:
			song_time += delta
			if not music_started and song_time >= 0.0:
				music_started = true
				Sfx.start_music(60.0 / spb, music)
			_update(delta)
		else:
			over_timer -= delta
			if over_timer <= 0.0:
				_goto_result()
		_tick_effects(delta)
	_update_drummers()
	queue_redraw()


func _update_drummers() -> void:
	var beat_phase := fposmod(song_time / spb, 1.0)
	for i in drummers.size():
		var d := drummers[i]
		var hit := exp(-(clock - float(hit_at[i])) * 8.0)
		var scare := i < 4 and float(scared[i]) > clock - 0.35
		var striking := clock - float(hit_at[i]) < 0.14
		var strike_tex: Texture2D = hit_tex[i] if i < 4 else villain_hit_tex
		d.texture = miss_tex[i] if scare else (strike_tex if striking else idle_tex[i])
		d.pivot_offset = Vector2(d.size.x * 0.5, d.size.y)
		d.scale = Vector2.ONE * (1.0 + hit * 0.08)
		var bob := sin(beat_phase * TAU) * 4.0 - hit * 8.0
		# Animate around the position authored in the scene instead of a hardcoded lane.
		var base := Vector2(
			d.anchor_left * size.x + drummer_offsets[i].x,
			d.anchor_top * size.y + drummer_offsets[i].y
		)
		d.position = base + Vector2(sin(clock * 90.0) * 5.0 if scare else 0.0, bob)
	var by := sin(clock * 6.0) * 4.0
	$Drummer1/YouLabel.position.y = -34.0 + by


func _mult() -> float:
	return (2.0 if fever else 1.0) * (1.0 + float(mini(4, combo / 10)) * 0.1)


func _update(delta: float) -> void:
	while hint_idx < hints.size() and song_time >= float(hints[hint_idx].t):
		hint_text = hints[hint_idx].text
		hint_until = clock + float(hints[hint_idx].dur)
		hint_idx += 1
	if fever and song_time >= fever_end:
		fever = false
		charge = 0

	for n in notes:
		var off: float = (float(n.time) - song_time) * speed
		if off > size.x:
			break
		if not n.anim and song_time >= float(n.time):
			n.anim = true
			if n.type == "bomb":
				if n.owner != PLAYER:
					scared[n.owner] = clock
			else:
				hit_at[n.owner] = clock
				if drummers.size() > 4:
					hit_at[n.owner + 4] = clock
				Sfx.play("mate", 0.7, 0.9 + 0.08 * float(n.owner))
		if n.res != "":
			continue
		if off < -good_late:
			if n.type == "normal" or (n.type == "long" and not n.started):
				n.res = "miss"
				_mistake("MISS")
			elif n.type == "bomb":
				n.res = "pass"
		if over:
			return

	if not hold.is_empty() and song_time >= float(hold.note.end):
		var h: Dictionary = hold
		hold = {}
		if h.note.taps >= h.note.need:
			h.note.res = "done"
			score += int(ROLL_BONUS * _mult())
			combo += 1
			max_combo = maxi(max_combo, combo)
			if not fever:
				charge += 3
				if charge >= FEVER_NEED:
					_start_fever()
			_float_text("ROLL COMPLETE!", Vector2(size.x * 0.5, _cy() - R * 1.6), Color(0.4, 1.0, 0.55), 1.0)
			_burst(Color(0.4, 1.0, 0.55), 24)
			Sfx.play("perfect")
		else:
			h.note.res = "miss"
			_mistake("TOO SLOW")

	if not over and song_time > end_time:
		_finish(false, "done")


func _tick_effects(delta: float) -> void:
	for p in parts:
		p.pos += p.vel * delta
		p.vel.y += 500.0 * delta
		p.life -= delta
	parts = parts.filter(func(p: Dictionary) -> bool: return p.life > 0.0)
	for f in floats:
		f.life -= delta
	floats = floats.filter(func(f: Dictionary) -> bool: return f.life > 0.0)
	flash = maxf(0.0, flash - delta * 2.2)
	ring_flash = maxf(0.0, ring_flash - delta * 3.5)


func _cy() -> float:
	return size.y * 0.78


func _float_text(text: String, pos: Vector2, col: Color, life: float, big := 1.0) -> void:
	floats.append({"text": text, "pos": pos, "col": col, "life": life, "max": life, "big": big})


func _burst(col: Color, count: int, spread := 260.0) -> void:
	for i in count:
		var a := randf() * TAU
		var v := (0.3 + randf()) * spread
		parts.append({"pos": Vector2(size.x * 0.5, _cy()), "vel": Vector2(cos(a), sin(a)) * v - Vector2(0, 60), "life": 0.6 + randf() * 0.4, "col": col})


func _mistake(label: String) -> void:
	if over:
		return
	var pen: int = int(cfg.penalty)
	cash -= pen
	mistakes += 1
	if not fever:
		combo = 0
		charge = 0
	_float_text("-%d" % pen, Vector2(110, 90), Color(1, 0.3, 0.3), 1.1)
	_float_text(label, Vector2(size.x * 0.5, _cy() - R * 1.6), Color(1, 0.4, 0.4), 0.8)
	flash = 0.6
	flash_col = Color(1, 0, 0)
	Sfx.play("miss")
	if cash <= 0.0:
		cash = 0.0
		_finish(true, "cash")


func _start_fever() -> void:
	fever = true
	fever_dur = FEVER_BASE + 3.0 * float(Save.upgrades.fever)
	fever_end = song_time + fever_dur
	flash = 1.0
	flash_col = Color(1, 0.85, 0.3)
	Sfx.play("fever")
	_float_text("FEVER!", Vector2(size.x * 0.5, size.y * 0.28), Color(1, 0.95, 0.4), 1.4, 1.8)
	_burst(Color(1, 0.85, 0.3), 40, 420.0)


func _register_hit(dist: float, owner_side: int) -> void:
	var perfect := dist <= perfect_dist
	combo += 1
	max_combo = maxi(max_combo, combo)
	score += int((300 if perfect else 100) * _mult())
	if not fever:
		charge += 1
		if charge >= FEVER_NEED:
			_start_fever()
	_float_text("PERFECT" if perfect else "GOOD", Vector2(size.x * 0.5, _cy() - R * 1.6), Color(1, 0.9, 0.3) if perfect else Color(0.5, 1, 0.6), 0.8)
	ring_flash = 1.0
	ring_col = Color(1, 0.9, 0.3) if perfect else Color(0.5, 1, 0.6)
	_burst(ring_col, 16 if perfect else 9)
	Sfx.play("perfect" if perfect else "hit")


func _active_roll(side: int) -> Dictionary:
	for n in notes:
		if n.type == "long" and n.side == side and n.started and n.res == "":
			return n
	return {}


func _press(side: int) -> void:
	if song_time < -spb:
		return
	hit_at[PLAYER] = clock
	var roll := _active_roll(side)
	if not roll.is_empty():
		roll.taps += 1
		score += ROLL_TAP_SCORE
		ring_flash = 0.8
		ring_col = COL_ROLL
		Sfx.play("pak", 0.6)
		return

	var now := clock
	press_times.append(now)
	while not press_times.is_empty() and now - press_times[0] > SPAM_WINDOW:
		press_times.pop_front()
	if press_times.size() > SPAM_FREE_PRESSES:
		score = maxi(0, score - SPAM_PENALTY)
		combo = 0
		_float_text("SPAM  -%d" % SPAM_PENALTY, Vector2(size.x * 0.5, _cy() - R * 1.6), Color(1, 0.5, 0.2), 0.7)

	var best: Dictionary = {}
	var best_dist := INF
	for n in notes:
		if n.res != "" or n.side != side or (n.type == "long" and n.started):
			continue
		var off: float = (float(n.time) - song_time) * speed
		var limit := bomb_dist if n.type == "bomb" else (good_early if off > 0.0 else good_late)
		var d := absf(off)
		if d <= limit and d < best_dist:
			best = n
			best_dist = d
	if best.is_empty():
		ring_flash = 0.4
		ring_col = Color.WHITE
		Sfx.play("pak", 0.35)
		return

	if best.type == "bomb":
		_hit_bomb(best)
	elif best.type == "long":
		best.started = true
		best.taps = 1
		hold = {"note": best}
		_register_hit(best_dist, side)
	else:
		best.res = "hit"
		_register_hit(best_dist, side)


func _hit_bomb(n: Dictionary) -> void:
	if int(Save.shields) > 0:
		Save.shields -= 1
		Save.save_data()
		n.res = "shield"
		_float_text("SHIELD!", Vector2(size.x * 0.5, _cy() - R * 1.6), Color(0.6, 0.9, 1), 1.1, 1.3)
		flash = 0.6
		flash_col = Color(0.4, 0.85, 1)
		_burst(Color(0.6, 0.9, 1), 24, 300.0)
		Sfx.play("shield")
		return
	n.res = "hit"
	explode_at = clock
	flash = 1.0
	flash_col = Color(1, 0.5, 0)
	_burst(Color(1, 0.5, 0.1), 60, 520.0)
	Sfx.play("bomb")
	_finish(true, "bomb")


func _finish(did_fail: bool, reason: String) -> void:
	if over:
		return
	over = true
	failed = did_fail
	fail_reason = reason
	hold = {}
	Sfx.stop_music()
	over_timer = 1.6 if reason == "bomb" else (1.0 if did_fail else 0.7)


func _goto_result() -> void:
	_goto_result_data()
	get_tree().change_scene_to_file("res://scenes/result/result.tscn")


func _goto_result_data() -> void:
	var cash_left := maxi(0, roundi(cash))
	Save.last_result = {
		"level": level, "failed": failed, "reason": fail_reason,
		"score": score, "mistakes": mistakes, "combo": max_combo,
		"cash": cash_left, "start_cash": start_cash,
		"stars": Levels.stars_for(cash_left, start_cash, mistakes, failed, score, ref_score),
	}


# ---------------------------------------------------------------- drawing

func _snap(v: float) -> int:
	# Pixel fonts stay crisp on a multiple-of-8 grid; round every drawn size to it.
	return maxi(8, int(roundf(v / 8.0)) * 8)


func _text(s: String, pos: Vector2, fs: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER, outline := true) -> void:
	var font: Font = GAME_FONT
	var w := size.x
	var p := pos
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		p.x -= w * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		p.x -= w
	if outline:
		draw_string_outline(font, p, s, align, w, fs, maxi(2, fs / 8), Color(0, 0, 0, 0.7))
	draw_string(font, p, s, align, w, fs, col)


func _draw() -> void:
	var W := size.x
	var H := size.y
	var cx := W * 0.5
	var cy := _cy()
	var beat_phase := fposmod(song_time / spb, 1.0)
	var pulse := pow(1.0 - beat_phase, 3.0)

	if fever:
		for k in 14:
			var a := float(k) / 14.0 * TAU + clock * 0.4
			var pts := PackedVector2Array([Vector2(cx, cy), Vector2(cx, cy) + Vector2(cos(a), sin(a)) * W, Vector2(cx, cy) + Vector2(cos(a + 0.12), sin(a + 0.12)) * W])
			draw_colored_polygon(pts, Color(1, 0.8, 0.3, 0.12 + pulse * 0.08) if k % 2 == 0 else Color(1, 0.35, 0.5, 0.1))

	draw_rect(Rect2(0, H * 0.58, W, H * 0.42), Color(1, 1, 1, 0.05))
	draw_rect(Rect2(0, cy - R * 0.6, W, R * 1.2), Color(0, 0, 0, 0.35))
	draw_line(Vector2(0, cy), Vector2(W, cy), Color(1, 1, 1, 0.25), 2.0)

	_draw_circle_target(Vector2(cx, cy), pulse)
	_draw_notes(cx, cy)

	for p in parts:
		draw_circle(p.pos, 2.0 + 4.0 * float(p.life), Color(p.col, clampf(float(p.life) * 1.5, 0.0, 1.0)))
	if clock - explode_at < 0.9:
		var k := (clock - explode_at) / 0.9
		draw_circle(Vector2(cx, cy), R * (0.5 + k * 3.2), Color(1, 0.55, 0.1, 0.8 * (1.0 - k)))
		draw_circle(Vector2(cx, cy), R * (0.3 + k * 1.8), Color(1, 1, 0.8, 0.9 * (1.0 - k)))

	for f in floats:
		var k := 1.0 - float(f.life) / float(f.max)
		_text(f.text, f.pos - Vector2(0, k * 60.0), _snap(R * 0.55 * float(f.big)), Color(f.col, 1.0 - k * k))
	_draw_hud(cx, cy)

	if flash > 0.0 and not Save.settings.reduce_flash:
		draw_rect(Rect2(0, 0, W, H), Color(flash_col, flash * 0.4))


func _draw_circle_target(c: Vector2, pulse: float) -> void:
	var r := R * (1.0 + pulse * 0.07)
	draw_circle(c, r * 1.7, Color(1, 0.85, 0.3, 0.2) if fever else Color(1, 1, 1, 0.08))
	draw_circle(c, r, Color(0.08, 0.04, 0.2, 0.7))
	draw_arc(c, r, 0.0, TAU, 64, Color(1, 0.85, 0.3) if fever else Color.WHITE, maxf(4.0, r * 0.09), true)
	draw_arc(c, r * perfect_dist / (R * PERFECT_RATIO) * 0.45, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 2.0, true)
	if ring_flash > 0.0:
		draw_arc(c, r * (1.0 + (1.0 - ring_flash) * 0.6), 0.0, TAU, 64, Color(ring_col, ring_flash), 6.0, true)
	var nxt := _next_target_note()
	if not nxt.is_empty():
		var k := clampf((float(nxt.time) - song_time) / spb, 0.0, 1.0)
		draw_arc(c, r * (1.0 + k * 0.9), 0.0, TAU, 64, Color(1, 0.9, 0.35, 0.9 - k * 0.6), 3.0, true)
	for n in notes:
		if n.type == "bomb" and n.res == "":
			var d := float(n.time) - song_time
			if d > -0.2 and d < spb * 1.5:
				draw_arc(c, r * 1.15, 0.0, TAU, 40, Color(1, 0.2, 0.2, 0.5 + 0.5 * sin(clock * 14.0)), 4.0, true)
				break
	if not hold.is_empty():
		var prog := clampf(float(hold.note.taps) / float(hold.note.need), 0.0, 1.0)
		draw_arc(c, r * 1.15, 0.0, TAU, 64, Color(0, 0, 0, 0.4), 8.0, true)
		draw_arc(c, r * 1.15, -PI * 0.5, -PI * 0.5 + prog * TAU, 64, Color(0.4, 1, 0.55) if prog >= 1.0 else Color(1, 0.7, 0.2), 8.0, true)
	_text("D" if true else "", c + Vector2(-R * 2.6, R * 0.15), _snap(R * 0.5), Color(1, 1, 1, 0.6))
	_text("K", c + Vector2(R * 2.6, R * 0.15), _snap(R * 0.5), Color(1, 1, 1, 0.6))


func _next_target_note() -> Dictionary:
	for n in notes:
		if n.res == "" and n.type != "bomb" and float(n.time) - song_time > -0.2:
			return n
	return {}


func _draw_notes(cx: float, cy: float) -> void:
	var nr := R * 0.42
	var dist: float = absf(_drummer_x(0) - cx)
	for n in notes:
		if n.res == "hit" or n.res == "shield" or n.res == "done":
			continue
		var side: int = n.side
		var off: float = (float(n.time) - song_time) * speed
		var fade := 1.0 if n.res == "" else 0.35
		if n.type == "long":
			var tail: float = (float(n.end) - song_time) * speed
			if tail < 0.0 or off - dist > nr * 2.0:
				continue
			var head := clampf(off, 0.0, dist) if n.started else minf(off, dist)
			var tl := clampf(tail, 0.0, dist)
			_draw_long(cx + side * head, cx + side * tl, cy, nr * 0.95, fade, n)
		else:
			if off > dist or off < -nr * 3.0:
				continue
			var x := cx + side * off
			var al := fade * clampf((dist - off) / (nr * 2.0), 0.0, 1.0)
			if n.type == "bomb":
				_draw_bomb(Vector2(x, cy), nr, al)
			else:
				_draw_normal(Vector2(x, cy), nr, al, COL_LEFT if side < 0 else COL_RIGHT)


func _draw_normal(p: Vector2, r: float, a: float, col: Color) -> void:
	draw_circle(p, r, Color(col, a))
	draw_arc(p, r, 0.0, TAU, 32, Color(1, 1, 1, a), r * 0.16, true)
	draw_arc(p, r * 0.45, 0.0, TAU, 24, Color(0, 0, 0, a * 0.35), r * 0.12, true)


func _draw_bomb(p: Vector2, r: float, a: float) -> void:
	var pl := 0.5 + 0.5 * sin(clock * 12.0)
	draw_circle(p, r * (1.35 + pl * 0.2), Color(1, 0.15, 0.15, (0.25 + pl * 0.3) * a))
	draw_circle(p, r * 0.9, Color(0.07, 0.07, 0.07, a))
	draw_arc(p, r * 0.9, 0.0, TAU, 32, Color(COL_BOMB, a), r * 0.16, true)
	draw_line(p + Vector2(r * 0.2, -r * 0.8), p + Vector2(r * 0.7, -r * 1.15), Color(0.85, 0.7, 0.4, a), r * 0.14)
	draw_circle(p + Vector2(r * 0.75, -r * 1.2), r * (0.16 + pl * 0.1), Color(1, 0.9, 0.3, a))
	_text("!", p + Vector2(0, r * 0.35), _snap(r * 1.1), Color(1, 0.2, 0.2, a), HORIZONTAL_ALIGNMENT_CENTER, false)


func _draw_long(x1: float, x2: float, y: float, r: float, a: float, n: Dictionary) -> void:
	var left := minf(x1, x2) - r
	var w := absf(x2 - x1) + r * 2.0
	var prog := clampf(float(n.taps) / float(maxi(1, n.need)), 0.0, 1.0) if n.started else 0.0
	var col := COL_ROLL.lerp(Color(1, 0.8, 1), prog)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, a)
	sb.set_corner_radius_all(int(r))
	sb.border_color = Color(1, 1, 1, a)
	sb.set_border_width_all(maxi(2, int(r * 0.14)))
	draw_style_box(sb, Rect2(left, y - r, w, r * 2.0))
	if not n.started:
		var hp := Vector2(x1, y)
		draw_circle(hp, r * 0.85, Color(1, 1, 1, a * 0.9))
		draw_arc(hp, r * 0.85, 0.0, TAU, 24, Color(COL_ROLL.darkened(0.2), a), r * 0.18, true)
	var label := "%d / %d" % [n.taps, n.need] if n.started else "MASH!"
	_text(label, Vector2((x1 + x2) * 0.5, y + r * 0.3), _snap(r * 0.9), Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, false)


func _draw_hud(cx: float, cy: float) -> void:
	var W := size.x
	var fs := _snap(clampf(W * 0.035, 16.0, 32.0))
	var low := cash < float(start_cash) * 0.25
	var pulse := 0.6 + 0.4 * sin(clock * 8.0)
	_text("CASH %s" % _commas(roundi(cash)), Vector2(16, 16 + fs), _snap(fs * 1.25), Color(1, 0.3, 0.3, pulse) if low else Color(1, 0.9, 0.4), HORIZONTAL_ALIGNMENT_LEFT)
	if low:
		_text("LOW CASH!", Vector2(16, 20 + fs * 2.2), _snap(fs * 0.75), Color(1, 0.3, 0.3), HORIZONTAL_ALIGNMENT_LEFT)
	_text(_commas(score), Vector2(cx, 16 + fs), _snap(fs * 1.15), Color.WHITE)
	if combo > 1:
		_text("%d COMBO%s" % [combo, "  x2" if fever else ""], Vector2(cx, 20 + fs * 2.1), _snap(fs * 0.75), Color(0.5, 1, 0.7) if combo >= 10 else Color(0.8, 0.75, 1))
	var mw := minf(W * 0.5, 360.0)
	var mx := cx - mw * 0.5
	var my := 24.0 + fs * 2.6
	var bh := 16.0
	draw_rect(Rect2(mx, my, mw, bh), Color(0, 0, 0, 0.5))
	var fp := clampf((fever_end - song_time) / maxf(0.01, fever_dur), 0.0, 1.0) if fever else clampf(float(charge) / float(FEVER_NEED), 0.0, 1.0)
	draw_rect(Rect2(mx, my, mw * fp, bh), Color(1, 0.95, 0.4) if fever else Color(1, 0.6, 0.15))
	for seg in range(1, int(mw / 16.0)):
		draw_rect(Rect2(mx + seg * 16.0, my, 2.0, bh), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(mx, my, mw, bh), Color.WHITE if fever else Color(1, 1, 1, 0.5), false, 4.0)
	_text("FEVER MODE!" if fever else "FEVER", Vector2(cx, my + bh + fs * 0.7), _snap(fs * 0.65), Color(1, 0.95, 0.4))
	_text("SHIELDS x%d" % int(Save.shields), Vector2(W - 16, 16 + fs), _snap(fs * 0.8), Color(0.6, 0.9, 1), HORIZONTAL_ALIGNMENT_RIGHT)
	_text("LEVEL %d  %s" % [level, cfg.name], Vector2(W - 16, 20 + fs * 1.9), _snap(fs * 0.6), Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_RIGHT)
	draw_rect(Rect2(0, 0, W * clampf(song_time / end_time, 0.0, 1.0), 4), Color(1, 1, 1, 0.3))
	if song_time < 0.0:
		var c := ceili(-song_time / spb)
		if c >= 1 and c <= 3:
			_text(str(c), Vector2(cx, size.y * 0.42), _snap(R * 1.6), Color(1, 1, 1, 0.9))
	if clock < hint_until and Save.settings.hints:
		_text(hint_text, Vector2(cx, size.y * 0.9), _snap(fs * 0.85), Color.WHITE)
	elif song_time > 0.0:
		_text("D = left   K = right   (or click / touch left and right halves)   Esc = pause", Vector2(cx, size.y - 8), _snap(fs * 0.5), Color(1, 1, 1, 0.45), HORIZONTAL_ALIGNMENT_CENTER, false)
	if low:
		draw_rect(Rect2(0, 0, W, size.y), Color(1, 0, 0, 0.1 * pulse), false, 14.0)


func _commas(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out
