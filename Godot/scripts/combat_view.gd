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
var sound: Node

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
		add_child(bullet)
		bullet.set_physics_process(false)
		bullets[id] = bullet
	elif kind == "impact":
		impacts.append({"position": data.position, "life": 0.2})
		impact_confirmed.emit(data.position)
	elif kind == "remove" and bullets.has(id):
		bullets[id].queue_free()
		bullets.erase(id)

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
		animals[i].sprite.flip_h = sample.heading.x < 0
		animals[i].sprite.position.y = sin(sample.gait * 2.0) * 1.5
		animals[i].queue_redraw()

func _process(delta: float) -> void:
	# Cosmetic travel only; lifetime and collision removal always come from the host.
	for bullet in bullets.values():
		bullet.position += bullet.direction * Bullet.SPEED * minf(delta, 0.05)
	for burst in impacts:
		burst.life -= delta
	impacts = impacts.filter(func(burst): return burst.life > 0)
	queue_redraw()

func _draw() -> void:
	for burst in impacts:
		draw_circle(burst.position, 5 + (0.2 - burst.life) * 40, Color(0.9, 0.98, 1.0, burst.life * 5))
