extends CanvasLayer
## Menu de pausa construido por codigo; permanece activo con el arbol pausado.

signal restart_requested
signal menu_requested

var player: MainCharacter
var spawner: Node
var game_over_screen: CanvasLayer
var _summary: Label
var _continue_button: Button


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.65)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	center.add_child(box)
	var title := Label.new()
	title.text = "PAUSA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.35))
	box.add_child(title)
	_summary = Label.new()
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.add_theme_font_size_override("font_size", 18)
	box.add_child(_summary)
	_continue_button = _add_button(box, "Continuar", _resume)
	_add_button(box, "Reiniciar", func() -> void: restart_requested.emit())
	_add_button(box, "Menú principal", func() -> void: menu_requested.emit())


func _add_button(box: VBoxContainer, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 56)
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(action)
	box.add_child(button)
	return button


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause") or event.is_echo():
		return
	if not is_instance_valid(player) or player.is_dead:
		return
	if is_instance_valid(game_over_screen) and game_over_screen.visible:
		return
	get_viewport().set_input_as_handled()
	if visible:
		_resume()
	else:
		_summary.text = "Puntaje: %d\n%s" % [spawner.score(), spawner.wave_label()]
		visible = true
		get_tree().paused = true
		_continue_button.grab_focus()


func _resume() -> void:
	_continue_button.release_focus()
	visible = false
	get_tree().paused = false
