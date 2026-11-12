extends Node
## Milestone 1: client menus enter the existing persistent rectangle-room lobby.

@onready var client_menu: Node2D = $MooozeTanks
@onready var lobby: Control = $AlphaLobby
var online := false

func _ready() -> void:
	lobby.hide()
	# Offline pause must not suspend discovery or an online connection.
	lobby.process_mode = Node.PROCESS_MODE_ALWAYS
	client_menu.host_requested.connect(host_game)
	client_menu.join_requested.connect(show_available_games)

func show_available_games() -> void:
	if online:
		return
	online = true
	get_tree().paused = false
	# CanvasLayer visibility and ALWAYS children do not inherit Node2D hiding.
	client_menu.ui.hide()
	client_menu.hide()
	client_menu.set_process(false)
	client_menu.set_process_unhandled_input(false)
	for voice in client_menu.sound.voices.values():
		voice.stop()
	client_menu.sound.process_mode = Node.PROCESS_MODE_DISABLED
	lobby.show()
	lobby.game_id.grab_focus()

func host_game() -> void:
	if online:
		return
	show_available_games()
	# A failure remains on the visible lobby with host_game's existing message.
	lobby.host_game()
