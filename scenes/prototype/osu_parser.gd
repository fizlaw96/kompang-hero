extends RefCounted

# Minimal osu!mania (.osu) reader. Only 2K maps are accepted.
# Returns {ok, error, title, audio, keys, notes:[{time (s), column, end (s, or -1 for taps)}]}.

static func parse(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {"ok": false, "error": "Could not read '%s'" % path}
	text = text.trim_prefix("﻿")

	var section := ""
	var sections := {"General": {}, "Metadata": {}, "Difficulty": {}}
	var raw_objects: Array[String] = []

	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("//"):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			section = line.substr(1, line.length() - 2)
			continue
		if section == "HitObjects":
			raw_objects.append(line)
		elif sections.has(section):
			var idx := line.find(":")
			if idx > 0:
				sections[section][line.substr(0, idx).strip_edges()] = line.substr(idx + 1).strip_edges()

	var general: Dictionary = sections["General"]
	var difficulty: Dictionary = sections["Difficulty"]
	var metadata: Dictionary = sections["Metadata"]

	var mode := int(general.get("Mode", "0"))
	if mode != 3:
		return {"ok": false, "error": "Not an osu!mania map (Mode %d, expected 3)" % mode}
	var keys := roundi(float(difficulty.get("CircleSize", "0")))
	if keys != 2:
		return {"ok": false, "error": "Only 2K maps are supported (this map is %dK)" % keys}

	var notes: Array[Dictionary] = []
	for line in raw_objects:
		var p := line.split(",")
		if p.size() < 5:
			continue
		var x := int(p[0])
		var time_ms := int(p[2])
		var flags := int(p[3])
		var column := clampi(int(floor(x * keys / 512.0)), 0, keys - 1)
		var end := -1.0
		# Hold notes (flag 128) store "endTime:hitSample" in the last field.
		if (flags & 128) != 0 and p.size() > 5:
			var end_ms := int(p[5].split(":")[0])
			if end_ms > time_ms:
				end = end_ms / 1000.0
		notes.append({"time": time_ms / 1000.0, "column": column, "end": end})

	notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.time < b.time)
	if notes.is_empty():
		return {"ok": false, "error": "Map has no hit objects"}

	var title: String = metadata.get("Title", path.get_file())
	var version: String = metadata.get("Version", "")
	if not version.is_empty():
		title += " [%s]" % version
	return {"ok": true, "error": "", "title": title, "audio": general.get("AudioFilename", ""), "keys": keys, "notes": notes}
