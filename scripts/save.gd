extends Node

# Autoload "Save": wallet, stars, upgrades, shields and settings, persisted to user://save.json.

const PATH := "user://save.json"

var wallet := 0
var stars := {}                      # level -> 0..3
var upgrades := {"circle": 0, "fever": 0}
var shields := 0
var secret_seen := false
# Transient (not saved): which level is being played and its outcome.
var current_level := 1
var story_ending := ""
var last_result := {}
var settings := {
	"master": 80, "music": 60, "sfx": 90,
	"music_on": true, "sfx_on": true,
	"assist": false, "reduce_flash": false, "hints": true,
}


func _ready() -> void:
	load_data()


func level_stars(level: int) -> int:
	return int(stars.get(str(level), 0))


func total_stars() -> int:
	return level_stars(1) + level_stars(2) + level_stars(3)


func set_stars(level: int, value: int) -> void:
	if value > level_stars(level):
		stars[str(level)] = value
		save_data()


func is_unlocked(level: int) -> bool:
	match level:
		1: return true
		2, 3: return level_stars(level - 1) >= 1
		4: return total_stars() >= 9
	return false


func save_data() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"wallet": wallet, "stars": stars, "upgrades": upgrades,
		"shields": shields, "secret_seen": secret_seen, "settings": settings,
	}))


func load_data() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	wallet = int(parsed.get("wallet", 0))
	stars = parsed.get("stars", {})
	shields = int(parsed.get("shields", 0))
	secret_seen = bool(parsed.get("secret_seen", false))
	for k in upgrades:
		upgrades[k] = int(parsed.get("upgrades", {}).get(k, 0))
	for k in settings:
		if parsed.get("settings", {}).has(k):
			settings[k] = parsed["settings"][k]


func reset() -> void:
	wallet = 0
	stars = {}
	upgrades = {"circle": 0, "fever": 0}
	shields = 0
	secret_seen = false
	save_data()
