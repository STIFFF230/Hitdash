extends Node2D
## Escena de combate: conecta al jugador con el HUD, el generador
## de enemigos y la pantalla de Game Over.

@onready var hud = $HUD
@onready var game_over_screen = $GameOverScreen
@onready var spawner = $EnemySpawner

var player: MainCharacter = null


func _ready() -> void:
	spawner.wave_changed.connect(hud.update_wave)
	spawner.kills_changed.connect(hud.update_kills)

	player = _find_player()
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
	game_over_screen.show_screen()

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
