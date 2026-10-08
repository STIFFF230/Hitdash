class_name RecordsStore
extends RefCounted
## Guarda los cinco mejores resultados; los empates conservan el orden de llegada.

const MAX_RECORDS := 5
const MAX_NAME_LENGTH := 12
static var path := "user://records.cfg"


static func clean_name(raw: String) -> String:
	var cleaned: String = ""
	for character: String in raw.strip_edges():
		var code: int = character.unicode_at(0)
		if code < 32 or (code >= 127 and code <= 159) or code == 0x2028 or code == 0x2029:
			continue
		if character == " " and cleaned.ends_with(" "):
			continue
		cleaned += character
	cleaned = cleaned.left(MAX_NAME_LENGTH).strip_edges()
	return "Jugador" if cleaned.is_empty() else cleaned


static func last_name() -> String:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return ""
	var saved: Variant = config.get_value("player", "last_name", "")
	return clean_name(saved) if saved is String and not saved.is_empty() else ""


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
		entry = entry.duplicate()
		entry["name"] = clean_name(entry.name) if entry.get("name") is String else "Jugador"
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


static func best_entry() -> Dictionary:
	var records := load_all()
	return {} if records.is_empty() else records[0]


static func rank_for(score: int) -> int:
	if score <= 0:
		return 0
	var records := load_all()
	var index: int = 0
	while index < records.size() and records[index].score >= score:
		index += 1
	return index + 1 if index < MAX_RECORDS else 0


static func submit(player_name: String, score: int, kills: int, wave: String) -> int:
	if score <= 0:
		return 0
	var records := load_all()
	var index: int = 0
	while index < records.size() and records[index].score >= score:
		index += 1
	if index >= MAX_RECORDS:
		return 0
	records.insert(index, {
		"name": clean_name(player_name), "score": score, "kills": maxi(0, kills), "wave": wave,
		"date": Time.get_datetime_string_from_system(false, true)
	})
	if records.size() > MAX_RECORDS:
		records.resize(MAX_RECORDS)
	var config := ConfigFile.new()
	config.set_value("player", "last_name", clean_name(player_name))
	config.set_value("records", "entries", records)
	if config.save(path) != OK:
		push_warning("No se pudieron guardar los récords.")
		return 0
	return index + 1


static func clear() -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		config.clear()
	if config.has_section("records"):
		config.erase_section("records")
	if config.save(path) != OK:
		push_warning("No se pudieron borrar los récords.")
