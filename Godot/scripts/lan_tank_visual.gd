extends "res://scripts/player.gd"
## Local Duel's renderer, driven only by replicated positions and confirmed events.
var previous_position := Vector2.ZERO
var effects_running := true

func _ready() -> void:
	super._ready()
	turret.name = "Turret"
	collision_layer = 0
	collision_mask = 0
	damage_enabled = false
	set_physics_process(false)
	# The arena owns the always-visible assigned username above this plate.
	user_id_label.hide()
	previous_position = position

func _process(delta: float) -> void:
	var travel := position - previous_position
	previous_position = position
	# Respawn/reconciliation teleports must not turn the chassis across the arena.
	if travel.length_squared() > 0.01 and travel.length_squared() < 10000.0:
		chassis.rotation = lerp_angle(chassis.rotation, travel.angle() + PI / 2.0, minf(delta * 14.0, 1.0))
	var nearby := false
	if travel.length_squared() > 0.01:
		for sprite in get_parent().ice_sprites + get_parent().border_sprites + get_parent().extra_ice_sprites.values():
			nearby = nearby or (sprite.visible and position.distance_squared_to(sprite.position) < VITALS_FADE_DISTANCE * VITALS_FADE_DISTANCE)
		for animal in get_tree().get_nodes_in_group("moose"):
			if animal.get_parent().get_parent() == get_parent():
				nearby = nearby or position.distance_squared_to(animal.position) < VITALS_FADE_DISTANCE * VITALS_FADE_DISTANCE
	vitals_display.modulate.a = move_toward(vitals_display.modulate.a, VITALS_FADED_ALPHA if nearby else 1.0, delta * 5.0)
	if effects_running:
		advance_vitals(delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	shot_flash = maxf(0.0, shot_flash - delta)
	modulate = Color.WHITE.lerp(Color(1.8, 0.55, 0.35), hit_flash / HIT_FLASH_TIME)
	queue_redraw()

func apply_vitals(values: Dictionary) -> void:
	if int(values.lives) != lives or not values.active:
		hit_flash = 0.0
		shot_flash = 0.0
		modulate = Color.WHITE
	elif int(values.health) < health:
		hit_flash = HIT_FLASH_TIME
	health = int(values.health)
	lives = int(values.lives)
	active = bool(values.active)
	visible = active
	respawn_protection = float(values.protection)
	moose_cooldown = float(values.get("contact", 0.0))
	heavy_time = float(values.get("heavy", 0.0))
	shield_time = float(values.get("shield", 0.0))
	speed_time = float(values.get("speed", 0.0))
	recovery_time = float(values.get("recovery", 0.0))
	update_vitals_display()

func reset_visuals() -> void:
	effects_running = true
	health = MAX_HEALTH
	lives = STARTING_LIVES
	active = true
	show()
	moose_cooldown = 0.0
	respawn_protection = 0.0
	clear_powerups()
	hit_flash = 0.0
	shot_flash = 0.0
	modulate = Color.WHITE
	chassis.rotation = 0.0
	previous_position = position
	update_vitals_display()
