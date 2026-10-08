extends CanvasLayer
## Menu principal y tabla persistente, construidos por codigo.

var _home: VBoxContainer
var _records: VBoxContainer
var _rows: VBoxContainer
var _best: Label
var _play_button: Button
var _back_button: Button
var _clear_button: Button
var _confirm_clear: bool = false


func _ready() -> void:
	get_tree().paused = false
	_build_ui()
	_refresh_records()
	_play_button.grab_focus()


func _build_ui() -> void:
	var floor_sprite := Sprite2D.new()
	floor_sprite.texture = preload("res://sprites/background/floor_bricks.png")
	floor_sprite.position = Vector2(586, 320)
	floor_sprite.scale = Vector2(0.36577296, 0.47778586)
	add_child(floor_sprite)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.65)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_home = VBoxContainer.new()
	_home.add_theme_constant_override("separation", 20)
	center.add_child(_home)
	_add_label(_home, "HITDASH", 80, true)
	_best = _add_label(_home, "", 24)
	_play_button = _add_button(_home, "Jugar", _play)
	_add_button(_home, "Récords", _show_records)
	_add_button(_home, "Salir", func() -> void: get_tree().quit())

	_records = VBoxContainer.new()
	_records.add_theme_constant_override("separation", 20)
	center.add_child(_records)
	_records.visible = false
	_add_label(_records, "Récords", 48, true)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 16)
	_records.add_child(_rows)
	_back_button = _add_button(_records, "Volver", _show_home)
	_clear_button = _add_button(_records, "Borrar récords", _clear_records)

	var footer := Label.new()
	footer.text = "WASD mover · Espacio dash · J / clic atacar · Esc pausa"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 18)
	footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -40
	footer.offset_bottom = -12
	add_child(footer)


func _add_label(box: VBoxContainer, text: String, font_size: int, gold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	if gold:
		label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.35))
	box.add_child(label)
	return label


func _add_button(box: VBoxContainer, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 56)
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(action)
	box.add_child(button)
	return button


func _refresh_records() -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var records := RecordsStore.load_all()
	_best.text = "Mejor puntaje: %d" % RecordsStore.best_score()
	if not records.is_empty():
		_best.text += " · " + str(records[0].name)
	if records.is_empty():
		_add_label(_rows, "Aún no hay récords. ¡A jugar!", 22)
	for index: int in records.size():
		var entry: Dictionary = records[index]
		_add_label(_rows, "%d.  %s · %d pts · %d bajas · %s · %s" % [
			index + 1, entry.name, entry.score, entry.kills, entry.wave, entry.date.left(10)
		], 18)


func _play() -> void:
	get_tree().change_scene_to_file("res://Scenes/arena.tscn")


func _show_records() -> void:
	_refresh_records()
	_home.visible = false
	_records.visible = true
	_back_button.grab_focus()


func _show_home() -> void:
	_confirm_clear = false
	_clear_button.text = "Borrar récords"
	_records.visible = false
	_home.visible = true
	_play_button.grab_focus()


func _clear_records() -> void:
	if not _confirm_clear:
		_confirm_clear = true
		_clear_button.text = "¿Seguro?"
		return
	RecordsStore.clear()
	_confirm_clear = false
	_clear_button.text = "Borrar récords"
	_refresh_records()


func _unhandled_input(event: InputEvent) -> void:
	if _records.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_show_home()
