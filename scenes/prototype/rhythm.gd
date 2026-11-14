extends Control

# Notes travel in from the left and right edges toward CENTER.
# Judging uses distance in pixels from the note's centre to CENTER's centre (not milliseconds).
# Charts come from an osu!mania 2K map (column 0 = left / D, column 1 = right / K).
# Hold notes become purple SPAM notes: mash the key until the bar has passed through the circle.

const OsuParser := preload("res://scenes/prototype/osu_parser.gd")

const NOTE_SPEED := 320.0        # px / second
const PERFECT_RATIO := 0.3       # perfect window = this fraction of the circle radius
const GOOD_EARLY_RATIO := 1.5    # GOOD window before the centre, in circle radii
const GOOD_LATE_RATIO := 2.0     # GOOD window after the centre; a note only misses once it passes this
const LEAD_IN := 2.0             # seconds of silence before song time 0
const SPAM_WINDOW := 1.0         # anti-spam: seconds of press history to look at
const SPAM_FREE_PRESSES := 5     # presses allowed inside the window before penalties start
const SPAM_PENALTY := 75         # score lost for each press beyond that
const ROLL_TAPS_PER_SEC := 4.0   # taps per second needed to clear a spam note
const ROLL_TAP_SCORE := 50
const ROLL_BONUS := 500

const COLOR_LEFT := Color(0.3, 0.85, 0.4)
const COLOR_RIGHT := Color(1.0, 0.7, 0.35)
const COLOR_ROLL := Color(0.65, 0.3, 0.95)

# Used when no .osu map is found.
const FALLBACK_PATTERN := [-1, 1, -1, 0, 1, 1, -1, -1, 1, 0, -1, 1]
const FALLBACK_GAP := 0.6

@onready var bar: Panel = $Panel
@onready var center_panel: Panel = $Panel/CENTER
@onready var template: Panel = $Panel/N0TE

var good_early := 61.0
var good_late := 82.0
var perfect_dist := 12.0
var press_times: Array[float] = []

var chart: Array[Dictionary] = []   # {time, side, end}; end = -1 for tap notes
var next_spawn := 0
var notes: Array[Dictionary] = []   # active note nodes
var start_ticks := 0
var song_time := -LEAD_IN
var audio_player: AudioStreamPlayer
var audio_started := false
var finished := false
var map_title := "Built-in pattern"

var score := 0
var combo := 0
var judge_label: Label
var info_label: Label
var flash_amount := 0.0
var flash_color := Color.WHITE


func _ready() -> void:
	template.visible = false
	var radius := center_panel.size.x * 0.5
	good_early = radius * GOOD_EARLY_RATIO
	good_late = radius * GOOD_LATE_RATIO
	perfect_dist = radius * PERFECT_RATIO

	judge_label = _make_label(52, 60)
	info_label = _make_label(28, 130)
	_make_key_hint("D", Vector2(-48, 22))
	_make_key_hint("K", Vector2(center_panel.size.x + 20, 22))

	_load_chart()
	_update_info()
	start_ticks = Time.get_ticks_msec()


func _load_chart() -> void:
	var map_path := _find_map()
	if not map_path.is_empty():
		var parsed := OsuParser.parse(map_path)
		if parsed.ok:
			for n in parsed.notes:
				chart.append({"time": n.time, "side": -1 if n.column == 0 else 1, "end": n.end})
			map_title = parsed.title
			var audio_path := map_path.get_base_dir().path_join(parsed.audio)
			var stream := _load_audio(audio_path)
			if stream:
				audio_player = AudioStreamPlayer.new()
				audio_player.stream = stream
				add_child(audio_player)
			else:
				push_warning("No playable audio at '%s' (mp3/ogg only); playing silent." % audio_path)
			return
		push_warning("Map '%s' rejected: %s" % [map_path, parsed.error])

	for i in FALLBACK_PATTERN.size() * 2:
		var side: int = FALLBACK_PATTERN[i % FALLBACK_PATTERN.size()]
		if side != 0:
			chart.append({"time": 1.0 + i * FALLBACK_GAP, "side": side, "end": -1.0})
	var roll_start: float = 1.0 + FALLBACK_PATTERN.size() * 2 * FALLBACK_GAP + 1.0
	chart.append({"time": roll_start, "side": 1, "end": roll_start + 2.0})


func _find_map() -> String:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		return args[0]
	var dir := DirAccess.open("res://maps")
	if dir:
		var files := dir.get_files()
		files.sort()
		for f in files:
			if f.get_extension().to_lower() == "osu":
				return "res://maps/" + f
	return ""


func _load_audio(path: String) -> AudioStream:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	match path.get_extension().to_lower():
		"mp3":
			var mp3 := AudioStreamMP3.new()
			mp3.data = bytes
			return mp3
		"ogg":
			return AudioStreamOggVorbis.load_from_buffer(bytes)
	return null


func _make_label(font_size: int, top: float) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = top
	label.offset_bottom = top + font_size + 16
	return label


func _make_key_hint(text: String, pos: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 28)
	center_panel.add_child(label)
	label.position = pos


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_D:
			_try_hit(-1)
		elif event.physical_keycode == KEY_K:
			_try_hit(1)
		elif event.physical_keycode == KEY_R:
			get_tree().reload_current_scene()
		elif event.physical_keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/menu/menu.tscn")


func _process(delta: float) -> void:
	var cx := bar.size.x * 0.5
	var cy := bar.size.y * 0.5
	var half := template.size * 0.5

	song_time = (Time.get_ticks_msec() - start_ticks) / 1000.0 - LEAD_IN
	if audio_player and not audio_started and song_time >= 0.0:
		audio_player.play()
		audio_started = true

	var lead := (cx + half.x) / NOTE_SPEED
	while next_spawn < chart.size() and chart[next_spawn].time - song_time <= lead:
		_spawn_note(chart[next_spawn])
		next_spawn += 1

	for i in range(notes.size() - 1, -1, -1):
		var n := notes[i]
		var remove := _update_roll(n, cx, cy, half) if n.roll else _update_tap(n, cx, cy, half)
		if remove:
			n.node.queue_free()
			notes.remove_at(i)

	if not finished and next_spawn >= chart.size() and notes.is_empty():
		finished = true
		_update_info()

	flash_amount = maxf(0.0, flash_amount - delta * 5.0)
	center_panel.self_modulate = Color.WHITE.lerp(flash_color, flash_amount)
	judge_label.modulate.a = maxf(0.0, judge_label.modulate.a - delta * 1.5)


func _update_tap(n: Dictionary, cx: float, cy: float, half: Vector2) -> bool:
	n.offset = (n.time - song_time) * NOTE_SPEED
	var node: Panel = n.node
	node.position = Vector2(cx + n.side * n.offset - half.x, cy - half.y)
	if not n.missed and n.offset < -good_late:
		n.missed = true
		node.modulate.a = 0.35
		combo = 0
		_show_judge("MISS", Color(1.0, 0.35, 0.35))
		_update_info()
	return n.offset < -(cx + half.x)


func _update_roll(n: Dictionary, cx: float, cy: float, half: Vector2) -> bool:
	var head: float = (n.time - song_time) * NOTE_SPEED
	var tail: float = (n.end - song_time) * NOTE_SPEED
	if tail < 0.0:
		if n.taps >= n.need:
			score += ROLL_BONUS
			combo += 1
			_show_judge("ROLL COMPLETE  +%d" % ROLL_BONUS, COLOR_ROLL.lightened(0.4))
			_flash(COLOR_ROLL, 1.0)
		else:
			combo = 0
			_show_judge("ROLL FAILED  %d / %d" % [n.taps, n.need], Color(1.0, 0.35, 0.35))
		_update_info()
		return true

	n.active = head <= good_early
	# Once the head reaches the circle it stays there while the tail keeps coming in.
	var near := maxf(head, 0.0)
	var left_x := cx + minf(n.side * near, n.side * tail) - half.x
	var node: Panel = n.node
	node.position = Vector2(left_x, cy - half.y)
	node.size = Vector2(absf(tail - near) + half.x * 2.0, template.size.y)

	var progress := clampf(float(n.taps) / float(n.need), 0.0, 1.0)
	var style: StyleBoxFlat = n.style
	style.bg_color = COLOR_ROLL.lerp(Color(1.0, 0.8, 1.0), progress)
	(n.label as Label).text = "%d / %d" % [n.taps, n.need]
	return false


func _spawn_note(entry: Dictionary) -> void:
	var roll: bool = entry.end >= 0.0
	var node := Panel.new()
	var style: StyleBoxFlat = template.get_theme_stylebox("panel").duplicate()
	if roll:
		style.bg_color = COLOR_ROLL
	else:
		style.bg_color = COLOR_LEFT if entry.side < 0 else COLOR_RIGHT
	node.add_theme_stylebox_override("panel", style)
	node.size = template.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(node)

	var label: Label = null
	if roll:
		label = Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", Color.WHITE)
		node.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	notes.append({
		"node": node, "style": style, "label": label,
		"side": entry.side, "time": entry.time, "end": entry.end, "roll": roll,
		"offset": INF, "missed": false, "active": false,
		"taps": 0, "need": maxi(2, int((entry.end - entry.time) * ROLL_TAPS_PER_SEC)),
	})


func _register_press() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	press_times.append(now)
	while press_times.size() > 0 and now - press_times[0] > SPAM_WINDOW:
		press_times.pop_front()
	if press_times.size() > SPAM_FREE_PRESSES:
		score = maxi(0, score - SPAM_PENALTY)
		combo = 0
		_show_judge("SPAM!  -%d" % SPAM_PENALTY, Color(1.0, 0.5, 0.2))
		_update_info()


func _active_roll_index(side: int) -> int:
	for i in notes.size():
		var n := notes[i]
		if n.roll and n.side == side and n.active:
			return i
	return -1


func _try_hit(side: int) -> void:
	# Presses during a spam note are the whole point, so they skip the anti-spam check.
	var ri := _active_roll_index(side)
	if ri >= 0:
		var r := notes[ri]
		r.taps += 1
		score += ROLL_TAP_SCORE
		_show_judge("SPAM  %d / %d" % [r.taps, r.need], COLOR_ROLL.lightened(0.3))
		_flash(COLOR_ROLL, 0.8)
		_update_info()
		return

	_register_press()
	var best := -1
	var best_dist := INF
	for i in notes.size():
		var n := notes[i]
		if n.roll or n.side != side or n.missed:
			continue
		# offset > 0 means the note hasn't reached the centre yet (early); < 0 means late.
		var limit := good_early if n.offset > 0.0 else good_late
		var d := absf(n.offset)
		if d <= limit and d < best_dist:
			best = i
			best_dist = d

	# Pressing early (no note in range yet) is harmless: no miss, no combo loss.
	if best < 0:
		_flash(Color(1, 1, 1), 0.4)
		return

	var perfect := best_dist <= perfect_dist
	combo += 1
	score += (300 if perfect else 100) * (1 + combo / 10)
	_show_judge("%s  %d px" % ["PERFECT" if perfect else "GOOD", roundi(best_dist)],
		Color(1.0, 0.9, 0.3) if perfect else Color(0.5, 1.0, 0.6))
	_flash(Color(1.0, 0.9, 0.3) if perfect else Color(0.5, 1.0, 0.6), 1.0)
	notes[best].node.queue_free()
	notes.remove_at(best)
	_update_info()


func _show_judge(text: String, color: Color) -> void:
	judge_label.text = text
	judge_label.add_theme_color_override("font_color", color)
	judge_label.modulate.a = 1.0


func _flash(color: Color, amount: float) -> void:
	flash_color = color
	flash_amount = amount


func _update_info() -> void:
	var text := "%s    Score %d    Combo %d" % [map_title, score, combo]
	if finished:
		text += "    FINISHED - press R to restart"
	else:
		text += "    (D = left, K = right)"
	info_label.text = text
