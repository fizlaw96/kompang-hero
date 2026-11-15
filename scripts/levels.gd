extends RefCounted

# Static level/shop data and deterministic chart generation.

const LEVELS := [
	{"name": "Level 1: The Stolen Gig", "diff": "Easy / Tutorial", "cash": 500, "color": Color(0.2, 0.7, 0.5)},
	{"name": "Level 2: Famous", "diff": "Medium", "cash": 1000, "color": Color(0.25, 0.5, 0.9)},
	{"name": "Level 3: The Kidnapping", "diff": "Hard", "cash": 2000, "color": Color(0.85, 0.4, 0.2)},
	{"name": "Level 4: Rescue at the Port", "diff": "Extreme (Secret)", "cash": 10000, "color": Color(0.5, 0.15, 0.7)},
]

# One chart per level. penalty = cash lost per mistake, density = note chance per slot,
# half = also allow off-beat notes, long/bomb = chance of that note type per beat slot.
const LEVEL_CFG := {
	1: {"name": "Tutorial", "bpm": 90, "bars": 18, "penalty": 30, "density": 0.6, "half": true, "long": 0.0, "bomb": 0.0, "seed": 12},
	2: {"name": "Long Notes", "bpm": 102, "bars": 20, "penalty": 70, "density": 0.65, "half": true, "long": 0.18, "bomb": 0.0, "seed": 22},
	3: {"name": "Bomb Notes", "bpm": 118, "bars": 20, "penalty": 160, "density": 0.7, "half": true, "long": 0.0, "bomb": 0.18, "seed": 32},
	4: {"name": "Expert", "bpm": 140, "bars": 28, "penalty": 450, "density": 0.82, "half": true, "long": 0.18, "bomb": 0.18, "seed": 42},
}

const SHOP := [
	{"id": "circle", "icon": "O", "name": "Bigger Rhythm Circle", "desc": "Enlarges the target circle, widening every timing window.",
		"prices": [300, 700, 1400], "max": 3},
	{"id": "fever", "icon": "F", "name": "Extended Fever", "desc": "FEVER MODE lasts longer, so your streak stays protected.",
		"prices": [400, 900, 1800], "max": 3},
	{"id": "shield", "icon": "S", "name": "Bomb Shield", "desc": "Blocks one accidental bomb hit, then is used up. Stackable.",
		"prices": [250], "max": 9999},
]


# Scene entry point for a level. Each level has its own scene so it can carry its own
# stage art, exported chart, or cutscene setup; gameplay itself lives in scenes/game/game.tscn.
static func game_scene(level: int) -> String:
	return "res://scenes/game/level_%d.tscn" % clampi(level, 1, LEVELS.size())


static func shop_effect(id: String, lv: int) -> String:
	match id:
		"circle": return "+%d%% target size and timing windows" % (lv * 15)
		"fever": return "+%d s fever duration" % (lv * 3)
		"shield": return "Absorbs 1 bomb hit per shield"
	return ""


# Stars need both cash left and score. No score (or a failed run) means 0 stars.
static func stars_for(cash_left: int, start_cash: int, mistakes: int, failed: bool, score: int, ref_score: int) -> int:
	if failed or score <= 0:
		return 0
	var kept := float(cash_left) / float(start_cash)
	var ratio := float(score) / float(maxi(1, ref_score))
	var by_cash := 1
	if kept >= 0.8 and mistakes <= 6:
		by_cash = 3
	elif kept >= 0.5:
		by_cash = 2
	var by_score := 1
	if ratio >= 0.6:
		by_score = 3
	elif ratio >= 0.35:
		by_score = 2
	return mini(by_cash, by_score)


# Score a flawless-timing run would roughly earn before combo/fever multipliers.
static func reference_score(notes: Array) -> int:
	var total := 0
	for n in notes:
		if n.type == "normal":
			total += 300
		elif n.type == "long":
			total += 500 + 50 * maxi(3, int((float(n.end) - float(n.time)) * 4.0 * 0.8))
	return total


# Returns {bpm, notes:[{time, side(-1/1), type:"normal"|"long"|"bomb", end}], end_time, cfg}.
static func build_chart(level: int) -> Dictionary:
	var m: Dictionary = LEVEL_CFG[level]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(m.seed) * 97 + level
	var spb := 60.0 / float(m.bpm)
	var lead := 4.0
	var total := float(m.bars) * 4.0
	var notes: Array[Dictionary] = []
	var beat := lead
	var side := -1
	var last_bomb := -99.0
	while beat < lead + total - 2.0:
		var bar := int((beat - lead) / 4.0)
		var pos := fposmod(beat - lead, 4.0)
		var on_beat := absf(pos - roundf(pos)) < 0.001
		var ramp := minf(1.0, 0.55 + float(bar) / float(m.bars) * 0.6)
		var step := 1.0
		if level == 1 and bar < 4:
			if on_beat and (pos == 0.0 or pos == 2.0):
				notes.append({"time": beat * spb, "side": side, "type": "normal", "end": -1.0})
				side = -side
		else:
			step = 0.5 if bool(m.half) else 1.0
			var eligible: bool = on_beat or (bool(m.half) and bar >= 2)
			if eligible and rng.randf() < float(m.density) * (1.0 if on_beat else 0.55) * ramp:
				var roll := rng.randf()
				if float(m.long) > 0.0 and bar >= 1 and on_beat and roll < float(m.long):
					var len := 2.0 if rng.randf() < 0.5 else 3.0
					notes.append({"time": beat * spb, "side": side, "type": "long", "end": (beat + len) * spb})
					side = -side
					beat += len + step
					continue
				elif float(m.bomb) > 0.0 and bar >= 1 and beat - last_bomb > 2.5 and roll > 1.0 - float(m.bomb):
					notes.append({"time": beat * spb, "side": side, "type": "bomb", "end": -1.0})
					last_bomb = beat
					side = -side
				else:
					notes.append({"time": beat * spb, "side": side, "type": "normal", "end": -1.0})
					side = -side
		beat += step
	# Guarantee each advertised special type appears at least once.
	for kind in ["long", "bomb"]:
		if float(m[kind]) > 0.0:
			var found := false
			for n in notes:
				if n.type == kind:
					found = true
			if not found:
				var cands: Array[Dictionary] = []
				for n in notes:
					if n.type == "normal" and n.time > (lead + 8.0) * spb and absf(n.time / spb - roundf(n.time / spb)) < 0.001:
						cands.append(n)
				if not cands.is_empty():
					var pick: Dictionary = cands[cands.size() / 2]
					pick.type = kind
					if kind == "long":
						pick.end = pick.time + 2.0 * spb
	# Drop notes that would overlap a long note.
	notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.time < b.time)
	var i := 0
	while i < notes.size():
		if notes[i].type == "long" and i + 1 < notes.size() and notes[i + 1].time < notes[i].end + 0.5 * spb:
			notes.remove_at(i + 1)
			continue
		i += 1
	return {"bpm": m.bpm, "notes": notes, "end_time": (lead + total + 2.0) * spb, "cfg": m}
