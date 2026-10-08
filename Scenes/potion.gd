class_name Potion
extends Node2D
## Una mejora por pasillo, con etiqueta ajena a la oscuridad del mundo.

signal picked(kind: String)

var kind: String = "health"
var available: bool = true
var _tint: Color
var _light: PointLight2D
var _label: Label
var _time: float = 0.0


func effect_text() -> String:
	match kind:
		"attack": return "Ataque +25%"
		"speed": return "Velocidad +15%"
	return "Vida +30"


func _ready() -> void:
	match kind:
		"attack": _tint = Color(1.0, 0.45, 0.12)
		"speed": _tint = Color(0.15, 0.9, 1.0)
		_: _tint = Color(1.0, 0.15, 0.22)
	_light = Door.make_light(_tint, 95.0)
	_light.energy = 1.4
	add_child(_light)
	var labels := CanvasLayer.new()
	labels.layer = 5
	add_child(labels)
	_label = Label.new()
	_label.text = effect_text()
	_label.position = global_position + Vector2(36, -17)
	_label.add_theme_font_size_override("font_size", 19)
	_label.add_theme_color_override("font_color", _tint.lightened(0.35))
	_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_child(_label)
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 512
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 17.0
	shape.shape = circle
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if available and body.is_in_group("Player"):
		available = false
		picked.emit(kind)


func dismiss() -> void:
	available = false
	_light.visible = false
	_label.hide()
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.25)
	fade.tween_callback(queue_free)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-24, 17, 48, 9), Color(0.32, 0.34, 0.4))
	draw_rect(Rect2(-19, 26, 38, 6), Color(0.2, 0.21, 0.26))
	var offset := Vector2(0, sin(_time * 2.5) * 3 - 2)
	draw_circle(offset, 13, _tint.lightened(0.4))
	draw_circle(offset + Vector2(0, 3), 10, _tint)
	draw_rect(Rect2(offset + Vector2(-5, -19), Vector2(10, 12)), _tint.lightened(0.5))
	draw_rect(Rect2(offset + Vector2(-6, -23), Vector2(12, 6)), Color(0.55, 0.32, 0.16))
	draw_line(offset + Vector2(-6, -5), offset + Vector2(-6, 2), Color(1, 1, 1, 0.8), 3)
