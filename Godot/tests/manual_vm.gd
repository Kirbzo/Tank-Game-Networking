extends SceneTree
## Manual terminal driver for the actual alpha lobby; no player joining.
## -- host | observer [ip=HOST_IPV4] [id=SESSION_ID]
var lobby: Control
var wanted_id := ""

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	lobby = load("res://lobby.tscn").instantiate()
	root.add_child(lobby)
	await process_frame
	lobby.discovery.games_changed.connect(show_games)
	print("Join disabled: ", lobby.join_button.disabled, "; Exit disabled: ", lobby.exit_button.disabled)
	for argument in args:
		if argument.begins_with("id="):
			wanted_id = argument.trim_prefix("id=")
		if argument.begins_with("ip="):
			lobby.network_address.text = argument.trim_prefix("ip=")
			lobby.network_address.text_submitted.emit(lobby.network_address.text)
			print(lobby.network_status.text)
	if args.has("host"):
		lobby.host_button.pressed.emit()
		if lobby.discovery.hosted_game.is_empty():
			printerr(lobby.feedback.text)
			quit(1)
			return
		print("HOST ID AND PORT: ", JSON.stringify(lobby.discovery.hosted_game))
	show_games()
	print("Keep this terminal running. Press Ctrl+C to stop this lobby process.")

func show_games() -> void:
	print("--- CURRENT LOBBY LIST ---")
	if lobby.game_list.item_count == 0:
		print("No games available.")
	for index in range(lobby.game_list.item_count):
		print(lobby.game_list.get_item_text(index))
	if not wanted_id.is_empty():
		lobby.game_id.text = wanted_id
		lobby.identify_game(wanted_id)
		print(lobby.feedback.text)
