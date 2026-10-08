class_name Door
extends Node2D
## Portal de piedra con luz y deteccion fisica del jugador.

signal entered

const GOLD: Color = Color(0.95, 0.8, 0.35)
var active: bool = true
var _light: PointLight2D
var _time: float = 0.0


static func make_light(tint: Color, radius: float) -> PointLight2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	var light := PointLight2D.new()
	light.texture = texture
	light.texture_scale = radius / 128.0
	light.color = tint
	return light


func _ready() -> void:
	## La superficie del portal permanece visible incluso lejos del jugador.
	var material_unlit := CanvasItemMaterial.new()
	material_unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = material_unlit
	_light = make_light(GOLD, 220.0)
	add_child(_light)
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 512
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(64, 90)
	shape.shape = rectangle
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	set_active(active)


func set_active(value: bool) -> void:
	active = value
	if _light != null:
		_light.visible = value
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if active and body.is_in_group("Player"):
		entered.emit()


func _process(delta: float) -> void:
	_time += delta
	_light.energy = 1.15 + sin(_time * 2.2) * 0.18


func _draw() -> void:
	var stone := Color(0.28, 0.29, 0.34)
	draw_rect(Rect2(-45, -20, 90, 85), stone)
	draw_circle(Vector2(0, -20), 45, stone)
	var glow: Color = GOLD if active else Color(0.075, 0.08, 0.1)
	draw_rect(Rect2(-31, -20, 62, 82), glow)
	draw_circle(Vector2(0, -20), 31, glow)
	for x: float in [-39.0, 39.0]:
		for y: float in [0.0, 22.0, 44.0]:
			draw_line(Vector2(x - 6, y), Vector2(x + 6, y), Color(0.12, 0.13, 0.16), 2)
	draw_arc(Vector2(0, -20), 38, PI, TAU, 24, Color(0.5, 0.48, 0.4), 3)
