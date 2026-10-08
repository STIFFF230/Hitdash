extends Node2D
## Escena de combate: conecta al jugador con el HUD, el generador
## de enemigos y la pantalla de Game Over.

@onready var hud = $HUD
@onready var game_over_screen = $GameOverScreen
@onready var spawner = $EnemySpawner
@onready var pause_menu: CanvasLayer = $PauseMenu

var player: MainCharacter = null


func _ready() -> void:
	spawner.wave_changed.connect(hud.update_wave)
	spawner.kills_changed.connect(hud.update_kills)
	spawner.score_changed.connect(hud.update_score)
	hud.set_best(RecordsStore.best_score())
	pause_menu.restart_requested.connect(_on_restart_requested)
	pause_menu.menu_requested.connect(_on_menu_requested)
	pause_menu.spawner = spawner
	pause_menu.game_over_screen = game_over_screen

	player = _find_player()
	pause_menu.player = player
	if player == null:
		push_warning("Arena: no se encontro al MainCharacter en el grupo 'Player'.")
		return

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
	var rank := _save_record()
	game_over_screen.show_screen(spawner.score(), spawner.kills(), spawner.wave_label(), rank)


func _save_record() -> int:
	if spawner.trailer_active() or spawner.score() <= 0:
		return 0
	return RecordsStore.submit(spawner.score(), spawner.kills(), spawner.wave_label())


func _on_restart_requested() -> void:
	_save_record()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu_requested() -> void:
	_save_record()
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
