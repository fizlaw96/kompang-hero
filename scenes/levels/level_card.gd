extends Button

const Levels := preload("res://scripts/levels.gd")

var level := 1
var glowing := false

@onready var glow: Panel = $Glow
@onready var badge: Label = $Row/Badge
@onready var title: Label = $Row/Info/Name
@onready var sub: Label = $Row/Info/Sub
@onready var right: Label = $Row/Right


func _process(_delta: float) -> void:
	if glowing:
		glow.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 2.0)


func _style(col: Color, locked: bool, secret: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.65) if locked else col
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(4)
	sb.border_color = Color(0.75, 0.35, 1.0) if secret else Color(1, 1, 1, 0.55)
	if secret and not locked:
		sb.shadow_color = Color(0.8, 0.3, 1, 0.8)
		sb.shadow_size = 8
	return sb


func setup(lv: int) -> void:
	level = lv
	var d: Dictionary = Levels.LEVELS[lv - 1]
	var open := Save.is_unlocked(lv)
	var secret := lv == 4
	var sb := _style(d.color, not open, secret)
	var hover := _style(d.color.lightened(0.15), not open, secret)
	add_theme_stylebox_override("normal", sb)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", hover)
	add_theme_stylebox_override("focus", hover)
	add_theme_stylebox_override("disabled", sb)

	glowing = secret and Save.total_stars() < 9
	glow.visible = glowing
	if glowing:
		var gs := StyleBoxFlat.new()
		gs.bg_color = Color(0.7, 0.3, 1, 0.12)
		gs.set_corner_radius_all(0)
		glow.add_theme_stylebox_override("panel", gs)

	badge.text = "[LOCK]" if not open else str(lv)
	badge.add_theme_font_size_override("font_size", 32 if open else 16)
	title.text = "%s%s" % ["* SECRET - " if secret else "", d.name]
	title.add_theme_color_override("font_color", Color(1, 0.85, 1) if secret else Color.WHITE)
	if open:
		sub.text = "%s   |   %d BPM   |   Start cash %d" % [d.diff, int(Levels.LEVEL_CFG[lv].bpm), int(d.cash)]
	elif secret:
		sub.text = "Collect all 9 stars from Levels 1-3"
	else:
		sub.text = "Needs 1 star from Level %d" % (lv - 1)

	if secret and not open:
		right.text = "%d/9" % Save.total_stars()
	elif not secret:
		var got := Save.level_stars(lv)
		right.text = "*".repeat(got) + "-".repeat(3 - got)
	else:
		right.text = "PLAY"
