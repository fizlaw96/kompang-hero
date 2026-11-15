extends Control

const RESET_TEXT := "RESET ALL PROGRESS"

@onready var root: VBoxContainer = $Root
@onready var reset_button: Button = $Root/ResetButton


func _ready() -> void:
	$Root/Bar/BackButton.pressed.connect(_back)
	for key in ["master", "music", "sfx"]:
		_bind_slider(key)
	for key in ["music_on", "sfx_on", "assist", "reduce_flash", "hints"]:
		_bind_check(key)
	reset_button.pressed.connect(_on_reset)


func _bind_slider(key: String) -> void:
	var row: Control = root.get_node(key)
	var slider: HSlider = row.get_node("Slider")
	var value_label: Label = row.get_node("Value")
	slider.min_value = 0
	slider.max_value = 100
	slider.value = float(Save.settings[key])
	value_label.text = str(int(slider.value))
	slider.value_changed.connect(func(val: float) -> void:
		Save.settings[key] = int(val)
		value_label.text = str(int(val))
		Save.save_data()
		Sfx.apply_settings())
	slider.drag_ended.connect(func(_changed: bool) -> void: Sfx.play("perfect"))


func _bind_check(key: String) -> void:
	var check: CheckBox = root.get_node(key)
	check.button_pressed = bool(Save.settings[key])
	check.toggled.connect(func(on: bool) -> void:
		Save.settings[key] = on
		Save.save_data()
		Sfx.apply_settings()
		Sfx.play("click"))


func _on_reset() -> void:
	if reset_button.text == RESET_TEXT:
		reset_button.text = "PRESS AGAIN TO CONFIRM"
	else:
		Save.reset()
		reset_button.text = "PROGRESS ERASED"


func _back() -> void:
	Sfx.play("click")
	get_tree().change_scene_to_file("res://scenes/menu/menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_back()
