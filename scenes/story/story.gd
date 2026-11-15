extends Control

const Story := preload("res://scripts/story.gd")
const Levels := preload("res://scripts/levels.gd")
const CHARS_PER_SEC := 45.0

var data: Dictionary
var outro := false
var page := 0
var shown := 0.0

@onready var background: TextureRect = $Background
@onready var dim: ColorRect = $Dim
@onready var place_l: Label = $Root/Top/PlaceLabel
@onready var text_l: Label = $Root/TextLabel
@onready var hint_l: Label = $Root/HintLabel
@onready var next_b: Button = $Root/NextButton


func _ready() -> void:
	outro = Save.story_ending != ""
	data = Story.ENDINGS[Save.story_ending] if outro else Story.INTRO[Save.current_level]

	var lv := 4 if outro else Save.current_level
	var base: Color = Levels.LEVELS[lv - 1].color
	dim.color = Color(base.darkened(0.7), 0.7)

	$Root/Top/SkipButton.pressed.connect(_finish)
	next_b.pressed.connect(_advance)
	place_l.text = (("THE END  -  " if Save.story_ending == "good" else "GAME OVER  -  ") if outro else "LEVEL %d  -  " % Save.current_level) + String(data.place).to_upper()
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
	shown += delta * CHARS_PER_SEC
	text_l.visible_characters = mini(int(shown), text_l.get_total_character_count())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			get_viewport().set_input_as_handled()
			_advance()
		elif event.keycode == KEY_ESCAPE:
			_finish()
