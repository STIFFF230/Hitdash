extends Node2D
## Escena de combate: conecta al jugador con el HUD, el generador
## de enemigos y la pantalla de Game Over.

@onready var level_transition: LevelTransition = $LevelTransition
@onready var hud = $HUD
@onready var game_over_screen = $GameOverScreen
@onready var spawner = $EnemySpawner
@onready var pause_menu: CanvasLayer = $PauseMenu

var player: MainCharacter = null
var _final_score: int = 0
var _final_kills: int = 0
var _final_wave: String = ""


func _ready() -> void:
	spawner.wave_changed.connect(hud.update_wave)
	spawner.kills_changed.connect(hud.update_kills)
	spawner.score_changed.connect(hud.update_score)
	var best: Dictionary = RecordsStore.best_entry()
	hud.set_best(int(best.get("score", 0)), str(best.get("name", "")))
	game_over_screen.name_submitted.connect(_on_name_submitted)
	pause_menu.restart_requested.connect(_on_restart_requested)
	pause_menu.menu_requested.connect(_on_menu_requested)
	pause_menu.spawner = spawner
	pause_menu.game_over_screen = game_over_screen

	player = _find_player()
	pause_menu.player = player
	if player == null:
		push_warning("Arena: no se encontro al MainCharacter en el grupo 'Player'.")
		return

	level_transition.player = player
	level_transition.spawner = spawner
	spawner.level_cleared.connect(level_transition.begin)
	level_transition.finished.connect(spawner.start_next_level)
	player.upgrades_changed.connect(hud.update_upgrades)
	player.health_changed.connect(hud.update_health)
	player.died.connect(_on_player_died)

	# Estado inicial del HUD (la senal inicial del jugador ya se
	# emitio antes de conectar, por eso lo inicializamos a mano).
	hud.setup(player.max_health)


func _find_player() -> MainCharacter:
	for node in get_tree().get_nodes_in_group("Player"):
		if node is MainCharacter:
			return node
	return null


func _on_player_died() -> void:
	_final_score = spawner.score()
	_final_kills = spawner.kills()
	_final_wave = spawner.wave_label()
	var rank: int = 0 if spawner.trailer_active() or _final_score <= 0 else RecordsStore.rank_for(_final_score)
	game_over_screen.show_screen(_final_score, _final_kills, _final_wave, rank)


func _on_name_submitted(player_name: String) -> void:
	var rank: int = RecordsStore.submit(player_name, _final_score, _final_kills, _final_wave)
	game_over_screen.show_saved_name(player_name, rank)


func _on_restart_requested() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu_requested() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")


# --- Atajos para grabar el trailer --------------------------------------
# Solo responden con "Modo trailer" activado en el EnemySpawner.
#   F1 o 7 = vida al maximo
#   F2 o 8 = saltar a la siguiente oleada
#   F3 o 9 = invencible on / off
# Los numeros existen porque en Mac las teclas F piden Fn.

func _unhandled_input(event: InputEvent) -> void:
	if not spawner.trailer_active():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	match (event as InputEventKey).keycode:
		KEY_F1, KEY_7:
			if player != null:
				player.heal_full()
		KEY_F2, KEY_8:
			spawner.jump_to_wave(spawner.wave_index() + 1)
		KEY_F3, KEY_9:
			if player != null:
				player.debug_invincible = not player.debug_invincible
				print("[trailer] invencible: ", player.debug_invincible)
