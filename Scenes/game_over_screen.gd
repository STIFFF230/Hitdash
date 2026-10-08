extends CanvasLayer
## Pantalla de "Has muerto". Pausa el juego y permite reiniciar
## con el boton o con Enter / Espacio.

signal name_submitted(player_name: String)

var _name_edit: LineEdit
var _name_help: Label
var _rank: int = 0
var _name_confirmed: bool = false
var _root: Control
var _restart_button: Button
var _summary: Label
var _rank_label: Label


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.65)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	center.add_child(box)

	var titulo := Label.new()
	titulo.text = "HAS MUERTO"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 64)
	titulo.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	box.add_child(titulo)

	_summary = Label.new()
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.add_theme_font_size_override("font_size", 18)
	box.add_child(_summary)
	_rank_label = Label.new()
	_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank_label.add_theme_font_size_override("font_size", 24)
	_rank_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.35))
	box.add_child(_rank_label)

	_name_edit = LineEdit.new()
	_name_edit.max_length = RecordsStore.MAX_NAME_LENGTH
	_name_edit.placeholder_text = "Tu nombre"
	_name_edit.custom_minimum_size = Vector2(260, 48)
	_name_edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	## Al enfocarse queda todo seleccionado: escribir reemplaza el ultimo nombre.
	_name_edit.select_all_on_focus = true
	_name_edit.add_theme_font_size_override("font_size", 24)
	_name_edit.text_submitted.connect(_confirm_name)
	box.add_child(_name_edit)
	_name_help = Label.new()
	_name_help.text = "Escribe tu nombre y pulsa Enter"
	_name_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_name_help)

	_restart_button = Button.new()
	_restart_button.text = "Reiniciar"
	_restart_button.custom_minimum_size = Vector2(220, 56)
	_restart_button.add_theme_font_size_override("font_size", 24)
	_restart_button.pressed.connect(_on_restart_pressed)
	box.add_child(_restart_button)
	var menu_button := Button.new()
	menu_button.text = "Menú principal"
	menu_button.custom_minimum_size = Vector2(220, 56)
	menu_button.add_theme_font_size_override("font_size", 24)
	menu_button.pressed.connect(_on_menu_pressed)
	box.add_child(menu_button)


func show_screen(score: int, kills: int, wave: String, rank: int) -> void:
	_rank = rank
	_name_confirmed = false
	_name_edit.visible = rank > 0
	_name_help.visible = rank > 0
	_name_edit.editable = true
	_name_edit.text = RecordsStore.last_name()
	_summary.text = "Puntaje: %d\nBajas: %d\nLlegaste a: %s" % [score, kills, wave]
	_rank_label.visible = rank > 0
	_rank_label.text = "¡NUEVO RÉCORD!" if rank == 1 else "Top %d de los récords" % rank
	visible = true
	get_tree().paused = true
	if rank > 0:
		_name_edit.grab_focus()
	else:
		_restart_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _name_edit.has_focus():
		return
	if event.is_action_pressed("ui_accept"):
		## Marcar el input como consumido ANTES de recargar la escena:
		## _on_restart_pressed() libera este nodo y get_viewport() pasa a ser null.
		get_viewport().set_input_as_handled()
		_on_restart_pressed()


func _confirm_name(_text: String = "") -> void:
	if _rank <= 0 or _name_confirmed:
		return
	_name_confirmed = true
	_name_edit.text = RecordsStore.clean_name(_name_edit.text)
	_name_edit.editable = false
	_name_help.visible = false
	name_submitted.emit(_name_edit.text)
	_restart_button.grab_focus()


func show_saved_name(player_name: String, rank: int) -> void:
	_rank_label.text = "Guardado como %s · puesto %d" % [player_name, rank] if rank > 0 else "No se pudo guardar el récord."


func _on_restart_pressed() -> void:
	_confirm_name()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	_confirm_name()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
