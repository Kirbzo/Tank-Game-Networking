extends Node
## Milestone 1: client menus enter the existing persistent rectangle-room lobby.

@onready var client_menu: Node2D = $MooozeTanks
@onready var lobby: Control = $AlphaLobby
var online := false

func _ready() -> void:
	lobby.theme = client_menu.get_meta("ui_theme")
	lobby.hide()
	# Offline pause must not suspend discovery or an online connection.
	lobby.process_mode = Node.PROCESS_MODE_ALWAYS
	client_menu.host_requested.connect(host_game)
	client_menu.join_requested.connect(show_available_games)
	lobby.main_menu_requested.connect(show_main_menu)
	lobby.add_local_game_buttons(start_local_game)

func start_local_game(duel: bool) -> void:
	lobby.leave_game()
	show_main_menu()
	client_menu.start_game(true, duel)

func show_available_games() -> void:
	if online:
		return
	online = true
	get_tree().paused = false
	lobby.exiting = false
	lobby.get_child(0).show()
	lobby.host_button.disabled = lobby.discovery.bound_port == -1
	lobby.refresh_games()
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

func show_main_menu() -> void:
	online = false
	get_tree().paused = false
	lobby.hide()
	client_menu.show()
	client_menu.ui.show()
	client_menu.set_process(true)
	client_menu.set_process_unhandled_input(true)
	client_menu.sound.process_mode = Node.PROCESS_MODE_ALWAYS
	client_menu.show_menu()
