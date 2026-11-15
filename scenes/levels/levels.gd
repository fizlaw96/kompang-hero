extends Control


@onready var cash_label: Label = $Root/Info/CashLabel
@onready var stars_label: Label = $Root/Info/StarsLabel
@onready var cards: Array[Button] = [
	$Root/Ladder/Wrap1/Card, $Root/Ladder/Wrap2/Card, $Root/Ladder/Wrap3/Card, $Root/Ladder/Wrap4/Card,
]
@onready var bridges: Array[ColorRect] = [
	$Root/Ladder/Link2/Bridge, $Root/Ladder/Link3/Bridge, $Root/Ladder/Link4/Bridge,
]


func _ready() -> void:
	$Root/Bar/BackButton.pressed.connect(_go.bind("res://scenes/menu/menu.tscn"))
	$Root/Bar/ShopButton.pressed.connect(_go.bind("res://scenes/shop/shop.tscn"))
	for i in 4:
		cards[i].pressed.connect(_on_level.bind(i + 1))
	_refresh()


func _refresh() -> void:
	cash_label.text = "CASH  %d" % Save.wallet
	stars_label.text = "%d/9 Stars" % Save.total_stars()
	for i in 4:
		cards[i].call("setup", i + 1)
	for i in 3:
		bridges[i].color = Color(1, 0.85, 0.3) if Save.is_unlocked(i + 2) else Color(1, 1, 1, 0.2)


func _on_level(lv: int) -> void:
	if not Save.is_unlocked(lv):
		Sfx.play("miss")
		return
	Sfx.play("click")
	Save.current_level = lv
	Save.story_ending = ""
	get_tree().change_scene_to_file("res://scenes/story/story.tscn")


func _go(path: String) -> void:
	Sfx.play("click")
	get_tree().change_scene_to_file(path)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_go("res://scenes/menu/menu.tscn")
