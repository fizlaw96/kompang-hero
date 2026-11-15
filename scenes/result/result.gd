extends Control

const Levels := preload("res://scripts/levels.gd")

var res: Dictionary
var secret_shown := false
var unlocked_secret := false
var earn := 0

@onready var dim: ColorRect = $Dim
@onready var title: Label = $Card/Margin/V/Title
@onready var note: Label = $Card/Margin/V/Note
@onready var grid: GridContainer = $Card/Margin/V/Grid
@onready var star_nodes: Array[Label] = [$Card/Margin/V/Stars/Star0, $Card/Margin/V/Stars/Star1, $Card/Margin/V/Stars/Star2]
@onready var retry_button: Button = $Card/Margin/V/Buttons/RetryButton
@onready var levels_button: Button = $Card/Margin/V/Buttons/LevelsButton
@onready var ending_button: Button = $Card/Margin/V/Buttons/EndingButton
@onready var next_button: Button = $Card/Margin/V/Buttons/ContinueButton
@onready var secret_panel: ColorRect = $SecretPanel
@onready var secret_ok: Button = $SecretPanel/Box/OkButton


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

	_fill()
	Sfx.play("fail" if res.failed else "win")
	_animate_stars()


func _fill() -> void:
	if res.failed:
		dim.color = Color(0.25, 0.05, 0.08, 0.7)
		title.text = "BOMB HIT!" if res.reason == "bomb" else "OUT OF CASH!"
		title.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	note.text = "Level failed - 0 stars. Try again!" if res.failed else "Cash left over is paid into your wallet (20%)."

	for s in star_nodes:
		s.pivot_offset = Vector2(24, 60)

	var values := [
		str(res.score), str(res.mistakes), str(res.combo),
		"%d / %d" % [res.cash, res.start_cash], "+%d" % earn,
		"%d / 3" % res.stars, "%d / 9" % Save.total_stars(),
	]
	for i in values.size():
		(grid.get_child(i * 2 + 1) as Label).text = values[i]

	retry_button.pressed.connect(func() -> void:
		Save.current_level = int(res.level)
		_go(Levels.game_scene(int(res.level))))
	levels_button.pressed.connect(func() -> void: _go("res://scenes/levels/levels.tscn"))

	if res.level == 4:
		ending_button.visible = true
		var ending := "bad" if res.failed else "good"
		ending_button.pressed.connect(func() -> void:
			Save.story_ending = ending
			_go("res://scenes/story/story.tscn"))
		if not res.failed:
			ending_button.grab_focus()

	var next := _next_target()
	if next.size() == 1:
		next_button.visible = true
		next_button.pressed.connect(func() -> void:
			Save.current_level = next[0]
			Save.story_ending = ""
			_go("res://scenes/story/story.tscn"))
		next_button.grab_focus()
	elif not (res.level == 4 and not res.failed):
		retry_button.grab_focus()

	secret_ok.pressed.connect(func() -> void:
		Save.secret_seen = true
		Save.save_data()
		_go("res://scenes/levels/levels.tscn"))


func _next_target() -> Array:
	if res.failed:
		return []
	if res.level < 4 and Save.is_unlocked(res.level + 1):
		return [res.level + 1]
	return []


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


func _show_secret() -> void:
	if secret_shown:
		return
	secret_shown = true
	secret_panel.visible = true
	secret_panel.modulate.a = 0.0
	create_tween().tween_property(secret_panel, "modulate:a", 1.0, 0.6)
	Sfx.play("unlock")
	secret_ok.grab_focus()
