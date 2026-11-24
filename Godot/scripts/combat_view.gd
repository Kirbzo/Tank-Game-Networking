extends Node2D
signal impact_confirmed(at: Vector2)
## Only host-confirmed objects are shown. No predicted shots or local hit decisions.
const Bullet = preload("res://scripts/bullet.gd")
const Moose = preload("res://scripts/moose.gd")
var bullets: Dictionary = {}
var animals: Array = []
var highest_shot := 0
var shots_seen := 0
var impacts: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var sound: Node
var state := "playing"

func _ready() -> void:
	sound = preload("res://scripts/sound.gd").new()
	add_child(sound)

func event(kind: String, data: Dictionary) -> void:
	var id: int = data.get("id", 0)
	if kind == "shot" and id > highest_shot:
		highest_shot = id
		shots_seen += 1
		sound.play("shoot")
		var bullet := Bullet.new()
		bullet.position = data.position
		bullet.direction = data.direction
		bullet.heavy = data.get("heavy", false)
		add_child(bullet)
		bullet.set_physics_process(false)
		bullets[id] = bullet
	elif kind == "impact":
		# Same count, motion, lifetime and shard drawing as Local Duel's burst().
		for i in range(12):
			particles.append({"position": data.position, "velocity": Vector2.from_angle(randf() * TAU) * randf_range(50, 190), "life": 0.5, "size": randf_range(2, 6)})
		impact_confirmed.emit(data.position)
	elif kind == "remove" and bullets.has(id):
		bullets[id].queue_free()
		bullets.erase(id)
	elif kind in ["tank_hit", "moose_angry", "moose_roar"]:
		sound.play(kind)
	elif kind == "powerup":
		var reveal := preload("res://scripts/powerup_reveal.gd").new()
		reveal.texture = preload("res://scripts/powerups.gd").ICONS[data.kind]
		reveal.position = data.position
		add_child(reveal)
	elif kind == "explosion":
		sound.last_played.erase("explosion")
		sound.play("explosion")
		var effect := preload("res://scripts/tank_explosion.gd").new()
		effect.position = data.position
		effect.game = self
		add_child(effect)

func clear_shots() -> void:
	for bullet in bullets.values():
		bullet.queue_free()
	bullets.clear()

func apply_snapshot(state: Dictionary) -> void:
	# Late snapshots cannot recreate a despawned shot or create an unconfirmed one.
	for id in state.shots:
		if bullets.has(id):
			bullets[id].position = state.shots[id]
	while animals.size() < state.moose.size():
		var animal := Moose.new()
		add_child(animal)
		animal.set_physics_process(false)
		animal.collision_layer = 0
		animal.collision_mask = 0
		animals.append(animal)
	for i in range(animals.size()):
		var sample: Dictionary = state.moose[i]
		animals[i].position = sample.position
		animals[i].heading = sample.heading
		animals[i].gait = sample.gait
		animals[i].anger_remaining = float(sample.get("anger", 0.0))
		animals[i].sprite.flip_h = sample.heading.x < 0
		animals[i].sprite.position = sample.get("sprite_position", Vector2(0, sin(sample.gait * 2.0) * 1.5))
		animals[i].sprite.rotation = float(sample.get("sprite_rotation", 0.0))
		animals[i].sprite.modulate = Color(1.4, 0.6, 0.45) if animals[i].anger_remaining > 0.0 else Color.WHITE
		animals[i].queue_redraw()

func _process(delta: float) -> void:
	# Cosmetic travel only; lifetime and collision removal always come from the host.
	for bullet in bullets.values():
		bullet.position += bullet.direction * Bullet.SPEED * minf(delta, 0.05)
	for burst in impacts:
		burst.life -= delta
	impacts = impacts.filter(func(burst): return burst.life > 0)
	for particle in particles:
		particle.position += particle.velocity * delta
		particle.life -= delta
	particles = particles.filter(func(particle): return particle.life > 0)
	queue_redraw()

func _draw() -> void:
	for particle in particles:
		draw_circle(particle.position, particle.size, Color(0.98, 1.0, 1.0, particle.life * 2))
		var shard := PackedVector2Array([particle.position + Vector2(0, -particle.size * 2), particle.position + Vector2(particle.size, 0), particle.position + Vector2(0, particle.size), particle.position + Vector2(-particle.size, 0)])
		draw_colored_polygon(shard, Color(0.35, 0.72, 0.95, particle.life * 1.5))
	for burst in impacts:
		draw_circle(burst.position, 5 + (0.2 - burst.life) * 40, Color(0.9, 0.98, 1.0, burst.life * 5))
