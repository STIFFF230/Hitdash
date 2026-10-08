class_name LevelTransition
extends Node2D
## Transicion dentro de la arena; todos los tiempos respetan la pausa.

signal finished

enum State { IDLE, DOOR, CORRIDOR, ARRIVAL }
const DARK: Color = Color(0.03, 0.03, 0.05)
var state: State = State.IDLE
var player: MainCharacter
var spawner: Node
var _floor: Node2D
var _boundaries: StaticBody2D
var _boundary_layer: int
var _darkness: CanvasModulate
var _player_light: PointLight2D
var _door: Door
var _exit: Door
var _corridor: Node2D
var _potions: Array[Potion] = []
var _chosen: bool = false
var _busy: bool = false
var _overlay: ColorRect
var _dark_tween: Tween
var _floating: Label


func _ready() -> void:
	_floor = get_parent().get_node("FloorBricks")
	_boundaries = get_parent().get_node("ScreenBoundaries")
	_boundary_layer = _boundaries.collision_layer
	_darkness = CanvasModulate.new()
	add_child(_darkness)
	var layer := CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color.BLACK
	_overlay.modulate.a = 0.0
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_overlay)


func begin(_level_index: int) -> void:
	if state != State.IDLE or not is_instance_valid(player) or player.is_dead:
		return
	state = State.DOOR
	## Invalida cualquier proteccion temporizada de la llegada anterior.
	player._invulnerability_generation += 1
	player.transition_invulnerable = true
	spawner.clear_enemies()
	get_parent().get_node("HUD").show_message("¡Nivel superado!")
	_player_light = Door.make_light(Color(0.8, 0.85, 1.0), 150.0)
	player.add_child(_player_light)
	_player_light.scale = Vector2.ONE / player.global_scale
	_dark_tween = create_tween()
	_dark_tween.tween_property(_darkness, "color", DARK, 1.0)
	## La creacion de areas se difiere fuera del callback fisico de la baja.
	call_deferred("_create_door")


func _create_door() -> void:
	if not is_instance_valid(player):
		return
	_door = Door.new()
	var candidates: Array[float] = []
	for x: int in range(80, 1073):
		if Vector2(x, 235).distance_to(player.global_position) >= 350.0:
			candidates.append(float(x))
	_door.position = Vector2(candidates.pick_random(), 235)
	add_child(_door)
	_door.entered.connect(_enter_corridor)


func _fade(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_overlay, "modulate:a", alpha, 0.4)
	await tween.finished


func _enter_corridor() -> void:
	if state != State.DOOR or _busy:
		return
	_busy = true
	await _fade(1.0)
	if not is_instance_valid(player):
		return
	_door.queue_free()
	_floor.hide()
	_boundaries.collision_layer = 0
	_build_corridor()
	_place_player(Vector2(85, 324))
	state = State.CORRIDOR
	await _fade(0.0)
	_busy = false


func _build_corridor() -> void:
	_chosen = false
	_potions.clear()
	_corridor = Node2D.new()
	add_child(_corridor)
	var floor_polygon := Polygon2D.new()
	floor_polygon.polygon = PackedVector2Array([Vector2(40, 200), Vector2(1112, 200), Vector2(1112, 448), Vector2(40, 448)])
	floor_polygon.color = Color(0.38, 0.39, 0.43)
	floor_polygon.z_index = -2
	_corridor.add_child(floor_polygon)
	_add_wall(Vector2(576, 184), Vector2(1104, 32))
	_add_wall(Vector2(576, 464), Vector2(1104, 32))
	_add_wall(Vector2(24, 324), Vector2(32, 312))
	_add_wall(Vector2(1128, 324), Vector2(32, 312))
	var kinds: Array[String] = ["health", "attack", "speed"]
	for i: int in kinds.size():
		var potion := Potion.new()
		potion.kind = kinds[i]
		potion.position = Vector2(560, 250 + i * 74)
		_corridor.add_child(potion)
		potion.picked.connect(_pick_upgrade)
		_potions.append(potion)
	_exit = Door.new()
	_exit.position = Vector2(1065, 324)
	_exit.active = false
	_corridor.add_child(_exit)
	_exit.entered.connect(_arrive)


func _add_wall(center: Vector2, dimensions: Vector2) -> void:
	var body := StaticBody2D.new()
	## Capa 2 adicional: el dash del jugador solo colisiona con ella.
	body.collision_layer = 3
	body.collision_mask = 0
	body.position = center
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = dimensions
	shape.shape = rectangle
	body.add_child(shape)
	_corridor.add_child(body)
	var stone := Polygon2D.new()
	var half: Vector2 = dimensions / 2.0
	stone.polygon = PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	stone.color = Color(0.22, 0.23, 0.28)
	body.add_child(stone)


func _pick_upgrade(kind: String) -> void:
	if state != State.CORRIDOR or _chosen or not is_instance_valid(player):
		return
	_chosen = true
	player.apply_upgrade(kind)
	var text: String = ""
	for potion: Potion in _potions:
		if potion.kind == kind:
			text = potion.effect_text()
		potion.dismiss()
	_exit.set_active(true)
	var layer := CanvasLayer.new()
	layer.layer = 6
	_corridor.add_child(layer)
	_floating = Label.new()
	_floating.text = text
	_floating.position = player.global_position + Vector2(-65, -65)
	_floating.add_theme_font_size_override("font_size", 24)
	_floating.add_theme_color_override("font_color", Door.GOLD)
	_floating.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_floating)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_floating, "position:y", _floating.position.y - 40, 1.3)
	tween.tween_property(_floating, "modulate:a", 0.0, 1.3)


func _place_player(destination: Vector2) -> void:
	player.is_dashing = false
	player.velocity = Vector2.ZERO
	player.global_position = destination


func _arrive() -> void:
	if state != State.CORRIDOR or not _chosen or _busy:
		return
	_busy = true
	state = State.ARRIVAL
	await _fade(1.0)
	if not is_instance_valid(player):
		return
	_corridor.queue_free()
	_potions.clear()
	_floor.show()
	_boundaries.collision_layer = _boundary_layer
	_place_player(Vector2(576, 340))
	_dark_tween.kill()
	_dark_tween = create_tween()
	_dark_tween.tween_property(_darkness, "color", Color.WHITE, 0.4)
	_player_light.queue_free()
	await _fade(0.0)
	## Proteccion completa desde el momento en que vuelve el combate.
	player.grant_invulnerability(1.5)
	_busy = false
	state = State.IDLE
	finished.emit()
