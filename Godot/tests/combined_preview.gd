extends SceneTree
## Optional graphical captures, kept in the ignored Godot cache directory.
func _initialize() -> void:
	run.call_deferred()

func capture(label: String) -> void:
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/combined-" + label + ".png")

func run() -> void:
	var startup: String = ProjectSettings.get_setting("application/run/main_scene")
	if startup != "res://application.tscn":
		printerr("FAIL: project startup is not the combined application")
		quit(1)
		return
	var app = load(startup).instantiate()
	root.add_child(app)
	current_scene = app
	await capture("menu")
	app.client_menu.show_play()
	await capture("play")
	app.show_available_games()
	await capture("lobby")
	app.lobby.host_game()
	await capture("room")
	app.lobby.active_room.leave_room()
	print("PASS combined graphical captures")
	quit()
