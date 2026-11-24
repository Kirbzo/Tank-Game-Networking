extends SceneTree
## Isolated two-player authority/snapshot microbenchmark; not graphical FPS acceptance.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var world = load("res://tank_world.gd").new()
	world.add_player(1)
	world.add_player(42)
	var combat = load("res://combat_world.gd").new()
	combat.tanks = world
	root.add_child(combat)
	combat.set_physics_process(false)
	for animal in combat.moose:
		animal.set_physics_process(false)
	var samples: Array[int] = []
	var largest := 0
	var raw_largest := 0
	for i in range(2400):
		var start := Time.get_ticks_usec()
		if combat.has_method("refresh_collision_bodies"):
			combat.refresh_collision_bodies()
		world.accept_input(1, Vector2.RIGHT if i % 120 < 60 else Vector2.LEFT, i * 16)
		world.accept_input(42, Vector2.LEFT if i % 120 < 60 else Vector2.RIGHT, i * 16, i + 1)
		world.step(1.0 / 60.0, i * 16)
		combat._physics_process(1.0 / 60.0)
		if i % 3 == 0:
			var raw := var_to_bytes(combat.snapshot())
			var packed := raw.compress(FileAccess.COMPRESSION_DEFLATE)
			largest = maxi(largest, packed.size())
			raw_largest = maxi(raw_largest, raw.size())
			if bytes_to_var(packed.decompress_dynamic(65536, FileAccess.COMPRESSION_DEFLATE)) != combat.snapshot():
				printerr("FAIL: compressed snapshot round trip")
				quit(1)
				return
		samples.append(Time.get_ticks_usec() - start)
	samples.sort()
	print("BENCH ", JSON.stringify({"physics_hz": Engine.physics_ticks_per_second, "fps_cap": Engine.max_fps, "samples": samples.size(), "median_us": samples[1200], "p95_us": samples[2280], "max_us": samples[-1], "snapshot_bytes": largest, "raw_snapshot_bytes": raw_largest}))
	if largest > 8192 or samples[2280] > 16000:
		printerr("FAIL: snapshot budget or physics-frame budget exceeded")
		quit(1)
		return
	print("PASS isolated authority and compressed snapshot budgets")
	quit()
