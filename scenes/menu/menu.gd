extends Control

var t := 0.0

@onready var play_button: Button = $Box/PlayButton
@onready var blue: TextureRect = $BlueDrummer
@onready var red: TextureRect = $RedDrummer


func _ready() -> void:
	$Stats.text = "CASH  %d        STARS  %d/9" % [Save.wallet, Save.total_stars()]
	play_button.pressed.connect(_go.bind("res://scenes/levels/levels.tscn"))
	$Box/SettingsButton.pressed.connect(_go.bind("res://scenes/settings/settings.tscn"))
	$Box/HelpButton.pressed.connect(_go.bind("res://scenes/help/help.tscn"))
	$Box/QuitButton.pressed.connect(func() -> void: get_tree().quit())
	for d: TextureRect in [blue, red]:
		d.pivot_offset = Vector2(d.size.x * 0.5, d.size.y)
	play_button.grab_focus()


func _process(delta: float) -> void:
	t += delta
	var pulse := pow(1.0 - fposmod(t * 2.0, 1.0), 3.0)
	blue.scale = Vector2(1.0, 1.0 + pulse * 0.05)
	red.scale = Vector2(1.0, 1.0 + pulse * 0.05)


func _go(path: String) -> void:
	Sfx.play("click")
	get_tree().change_scene_to_file(path)
