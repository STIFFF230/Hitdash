extends Node2D
## Genera enemigos en posiciones aleatorias dentro de un area, manteniendo
## una distancia minima respecto al jugador.
##
## La dificultad avanza por oleadas: se empieza solo con orcos y, segun
## sube el numero de bajas, entran los slimes de lava (cuerpo a cuerpo que
## se enfurecen al ser golpeados), los vampiros (enemigos a distancia) y
## los enemigos salen mas reforzados. Pasada la ultima oleada el juego
## sigue en modo infinito, subiendo un escalon cada `kills_to_advance`.

signal level_cleared(finished_index: int)

signal wave_changed(index: int, display_name: String, endless_level: int)
signal kills_changed(kills: int)
signal score_changed(score: int)

@export_group("Escenas de enemigos")
@export var orc_scene: PackedScene = preload("res://Entities/Enemies/orcs/orc_1.tscn")
@export var vampire_1_scene: PackedScene = preload("res://Entities/Enemies/vampire_1.tscn")
@export var vampire_2_scene: PackedScene = preload("res://Entities/Enemies/vampire_2.tscn")
@export var vampire_3_scene: PackedScene = preload("res://Entities/Enemies/vampire_3.tscn")
## Slime de lava: cuerpo a cuerpo que se enfurece (mas rapido y agresivo) al recibir dano.
@export var slime_3_scene: PackedScene = preload("res://Entities/Enemies/slimes/slime_3.tscn")

@export_group("Generacion")
## Rectangulo (en coordenadas globales) donde pueden aparecer.
@export var spawn_area: Rect2 = Rect2(64, 64, 1024, 520)
## Distancia minima al jugador para no aparecer encima de el.
@export var min_distance_to_player: float = 220.0
## Escala aplicada a cada enemigo generado.
@export var enemy_scale: Vector2 = Vector2(2.8, 2.8)
## Total de enemigos a generar en toda la partida. -1 = infinito.
@export var total_to_spawn: int = -1

@export_group("Puntaje")
@export var score_growth: float = 0.1

@export_group("Oleadas")
@export var transitions_enabled: bool = true
## Si se deja vacio se usan las oleadas por defecto definidas en el codigo.
@export var waves: Array[WaveConfig] = []
## Cuanto se refuerzan los enemigos por cada escalon del modo infinito.
@export var endless_growth: float = 1.12

@export_group("Modo trailer (solo para grabar)")
## Activalo SOLO mientras se graba el trailer. Para la entrega debe quedar en false.
@export var trailer_mode: bool = false
## Multiplica el dano de TODOS los enemigos. 1.0 = normal, 0.5 = la mitad.
@export_range(0.05, 1.0, 0.05) var trailer_damage_scale: float = 0.5
## Divide las bajas necesarias por oleada, para llegar antes a la 6.
@export_range(1, 10, 1) var trailer_kills_divisor: int = 1

@onready var _timer: Timer = $SpawnTimer

var _player: Node2D = null
var _spawned_total: int = 0
var _score: int = 0
var _kills: int = 0
var _kills_this_wave: int = 0
var _wave_index: int = 0
var _endless_level: int = 0
var _awaiting_transition: bool = false


func _ready() -> void:
	randomize()
	_player = get_tree().get_first_node_in_group("Player")

	if waves.is_empty():
		waves = _default_waves()

	_timer.one_shot = false
	if not _timer.timeout.is_connected(_on_spawn_timer_timeout):
		_timer.timeout.connect(_on_spawn_timer_timeout)

	_apply_wave_settings()
	_timer.start()
	# Se avisa del estado inicial en el proximo frame, cuando el HUD ya escucha.
	call_deferred("_announce_wave")


func _default_waves() -> Array[WaveConfig]:
	var list: Array[WaveConfig] = []
	list.append(WaveConfig.create(
		"Oleada 1 - Orcos", 6,
		[orc_scene], [1.0],
		2.0, 6
	))
	list.append(WaveConfig.create(
		"Oleada 2 - Llegan los vampiros", 8,
		[orc_scene, vampire_1_scene], [1.0, 1.2],
		2.1, 5,
		1.05
	))
	list.append(WaveConfig.create(
		"Oleada 3 - Lava viviente", 9,
		[orc_scene, slime_3_scene], [1.5, 2.0],
		1.8, 8,
		1.2, 1.1
	))
	list.append(WaveConfig.create(
		"Oleada 4 - Aquelarre", 10,
		[orc_scene, vampire_1_scene, vampire_2_scene, slime_3_scene], [2.0, 2.0, 1.0, 1.5],
		1.6, 9,
		1.4, 1.2, 1.05
	))
	list.append(WaveConfig.create(
		"Oleada 5 - Nobleza vampirica", 12,
		[orc_scene, vampire_1_scene, vampire_2_scene, vampire_3_scene, slime_3_scene], [1.0, 1.0, 2.0, 1.0, 1.5],
		1.5, 10,
		1.6, 1.3, 1.1
	))
	list.append(WaveConfig.create(
		"Oleada 6 - Pesadilla", 14,
		[orc_scene, vampire_2_scene, vampire_3_scene, slime_3_scene], [1.0, 2.0, 2.0, 2.0],
		1.25, 12,
		2.0, 1.5, 1.15
	))
	return list


func current_wave() -> WaveConfig:
	if waves.is_empty():
		return null
	return waves[clampi(_wave_index, 0, waves.size() - 1)]


func wave_label() -> String:
	var wave := current_wave()
	if wave == null:
		return ""
	if _endless_level > 0:
		return "%s +%d" % [wave.display_name, _endless_level]
	return wave.display_name


func score() -> int:
	return _score


func kills() -> int:
	return _kills


func wave_index() -> int:
	return _wave_index


## El modo trailer solo funciona corriendo desde el editor, nunca en un export.
func trailer_active() -> bool:
	return trailer_mode and OS.is_debug_build()


## Bajas para pasar de oleada, ya con el divisor del modo trailer aplicado.
func _kills_needed(wave: WaveConfig) -> int:
	if trailer_active() and trailer_kills_divisor > 1:
		return maxi(1, ceili(float(wave.kills_to_advance) / float(trailer_kills_divisor)))
	return wave.kills_to_advance


## Salta directo a una oleada (0 = la primera). Solo para grabar el trailer.
func jump_to_wave(index: int) -> void:
	if _awaiting_transition or waves.is_empty():
		return
	_wave_index = clampi(index, 0, waves.size() - 1)
	_kills_this_wave = 0
	_endless_level = 0
	_awaiting_transition = false
	_apply_wave_settings()
	_announce_wave()
	_timer.start()


# --- Generacion ---------------------------------------------------------

func _on_spawn_timer_timeout() -> void:
	if _awaiting_transition:
		return
	if total_to_spawn >= 0 and _spawned_total >= total_to_spawn:
		_timer.stop()
		return
	var wave := current_wave()
	if wave == null:
		return
	if _alive_enemies() >= wave.max_alive:
		return
	_spawn_one(wave)


func _alive_enemies() -> int:
	return get_tree().get_nodes_in_group("Enemy").size()


func _spawn_one(wave: WaveConfig) -> void:
	var scene := _pick_scene(wave)
	if scene == null:
		return

	var enemy: Node2D = scene.instantiate()
	enemy.scale = enemy_scale
	_apply_wave_stats(enemy, wave)
	if enemy.has_signal("died"):
		enemy.connect("died", _on_enemy_died.bind(enemy))

	add_child(enemy)
	enemy.global_position = _pick_spawn_position()
	_spawned_total += 1


func _pick_scene(wave: WaveConfig) -> PackedScene:
	if wave.enemy_scenes.is_empty():
		return null
	if wave.weights.size() != wave.enemy_scenes.size():
		return wave.enemy_scenes[randi() % wave.enemy_scenes.size()]

	var total := 0.0
	for w in wave.weights:
		total += maxf(w, 0.0)
	if total <= 0.0:
		return wave.enemy_scenes[0]

	var roll := randf() * total
	var acc := 0.0
	for i in wave.enemy_scenes.size():
		acc += maxf(wave.weights[i], 0.0)
		if roll <= acc:
			return wave.enemy_scenes[i]
	return wave.enemy_scenes[wave.enemy_scenes.size() - 1]


## Aplica los multiplicadores de la oleada sobre las estadisticas base del
## enemigo. Debe llamarse ANTES de add_child(), porque _ready() del enemigo
## usa max_health para construir su barra de vida.
func _apply_wave_stats(enemy: Node, wave: WaveConfig) -> void:
	var boost: float = pow(endless_growth, _endless_level)

	var damage_factor: float = wave.damage_multiplier * boost
	if trailer_active():
		damage_factor *= trailer_damage_scale

	_scale_stat(enemy, "max_health", wave.health_multiplier * boost)
	_scale_stat(enemy, "attack_damage", damage_factor)
	_scale_stat(enemy, "speed", wave.speed_multiplier)

	# El enemigo nace con la vida llena ya reforzada.
	if "max_health" in enemy and "health" in enemy:
		enemy.set("health", enemy.get("max_health"))


func _scale_stat(enemy: Node, property: String, factor: float) -> void:
	if not (property in enemy):
		return
	enemy.set(property, float(enemy.get(property)) * factor)


func _pick_spawn_position() -> Vector2:
	for i in 16:
		var candidate := Vector2(
			randf_range(spawn_area.position.x, spawn_area.end.x),
			randf_range(spawn_area.position.y, spawn_area.end.y)
		)
		if _player == null or not is_instance_valid(_player):
			return candidate
		if candidate.distance_to(_player.global_position) >= min_distance_to_player:
			return candidate
	return spawn_area.get_center()


# --- Progresion de oleadas ----------------------------------------------

func _on_enemy_died(enemy: Node) -> void:
	if _awaiting_transition:
		return
	var value: int = int(enemy.get("score_value")) if "score_value" in enemy else 10
	_score += roundi(value * (1.0 + score_growth * (_wave_index + _endless_level)))
	score_changed.emit(_score)
	_kills += 1
	_kills_this_wave += 1
	kills_changed.emit(_kills)

	var wave := current_wave()
	if wave == null:
		return
	if _kills_this_wave >= _kills_needed(wave):
		_advance_wave()


func _advance_wave() -> void:
	if transitions_enabled and _wave_index < waves.size() - 1:
		_awaiting_transition = true
		_timer.stop()
		level_cleared.emit(_wave_index)
		return
	_kills_this_wave = 0
	if _wave_index < waves.size() - 1:
		_wave_index += 1
	else:
		# Ya no quedan oleadas nuevas: modo infinito, todo mas duro.
		_endless_level += 1
	_apply_wave_settings()
	_announce_wave()


func _apply_wave_settings() -> void:
	var wave := current_wave()
	if wave == null:
		return
	_timer.wait_time = wave.spawn_interval


func _announce_wave() -> void:
	wave_changed.emit(_wave_index, wave_label(), _endless_level)
	kills_changed.emit(_kills)
	score_changed.emit(_score)


func start_next_level() -> void:
	if not _awaiting_transition:
		return
	_wave_index += 1
	_kills_this_wave = 0
	_awaiting_transition = false
	_apply_wave_settings()
	_announce_wave()
	_timer.start()


func clear_enemies() -> void:
	for enemy: Node in get_tree().get_nodes_in_group("Enemy"):
		enemy.remove_from_group("Enemy")
		enemy.set_physics_process(false)
		## Impide callbacks de animacion y ataques pendientes durante el fundido.
		if "is_dead" in enemy:
			enemy.set("is_dead", true)
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		if enemy is CollisionObject2D:
			enemy.set_deferred("collision_layer", 0)
			enemy.set_deferred("collision_mask", 0)
		var area := enemy.get_node_or_null("AttackArea") as Area2D
		if area != null:
			area.set_deferred("monitoring", false)
		var fade := create_tween()
		fade.tween_property(enemy, "modulate:a", 0.0, 0.4)
		fade.tween_callback(enemy.queue_free)
	for projectile: Node in get_tree().get_nodes_in_group("Projectile"):
		projectile.queue_free()
