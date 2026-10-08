class_name RecordsStore
extends RefCounted
## Guarda los cinco mejores resultados; los empates conservan el orden de llegada.

const MAX_RECORDS := 5
static var path := "user://records.cfg"


static func load_all() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return records
	var entries: Variant = config.get_value("records", "entries", [])
	if not entries is Array:
		return records
	for entry: Variant in entries:
		if not entry is Dictionary:
			continue
		if not entry.get("score") is int or not entry.get("kills") is int:
			continue
		if not entry.get("wave") is String or not entry.get("date") is String:
			continue
		if entry.score <= 0 or entry.kills < 0:
			continue
		## Insercion estable: un empate nunca adelanta un registro anterior.
		var index: int = 0
		while index < records.size() and records[index].score >= entry.score:
			index += 1
		records.insert(index, entry)
	if records.size() > MAX_RECORDS:
		records.resize(MAX_RECORDS)
	return records


static func best_score() -> int:
	var records := load_all()
	return 0 if records.is_empty() else int(records[0].score)


static func submit(score: int, kills: int, wave: String) -> int:
	if score <= 0:
		return 0
	var records := load_all()
	var index: int = 0
	while index < records.size() and records[index].score >= score:
		index += 1
	if index >= MAX_RECORDS:
		return 0
	records.insert(index, {
		"score": score, "kills": maxi(0, kills), "wave": wave,
		"date": Time.get_datetime_string_from_system(false, true)
	})
	if records.size() > MAX_RECORDS:
		records.resize(MAX_RECORDS)
	var config := ConfigFile.new()
	config.set_value("records", "entries", records)
	if config.save(path) != OK:
		push_warning("No se pudieron guardar los récords.")
		return 0
	return index + 1


static func clear() -> void:
	if FileAccess.file_exists(path):
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) != OK:
			push_warning("No se pudieron borrar los récords.")
