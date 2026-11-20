extends Node2D
## Presentation reuse of client 167b4f6 arena layout and winter drawing.
## Tank positions come from the network room; no offline scripts or damage run here.
const ICE = preload("res://assets/brick.svg")
const TREE = preload("res://assets/forest_tree.svg")
const TANK = preload("res://assets/tank.svg")
const TURRET = preload("res://assets/turret.svg")
var tank_markers: Dictionary = {}
var name_labels: Dictionary = {}
var members: Dictionary = {}
var ice_count := 0
var ice_sprites: Array[Sprite2D] = []
var contact_timers: Dictionary = {}
var muzzle_flashes: Array[Dictionary] = []
const TankVisual = preload("res://scripts/lan_tank_visual.gd")

func _ready() -> void:
	# Same arena coordinates as the imported offline client; decoration only.
	for center in preload("res://tank_world.gd").border_centers():
		add_brick(center, true)
	for center in preload("res://tank_world.gd").ice_centers():
		add_brick(center, false)

func apply_positions(positions: Dictionary) -> void:
	for peer in positions:
		if tank_markers.has(peer):
			tank_markers[peer].position = positions[peer]

func add_brick(at: Vector2, reinforced: bool) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = TREE if reinforced else ICE
	sprite.position = at + (Vector2(0, -8) if reinforced else Vector2.ZERO)
	add_child(sprite)
	if not reinforced:
		ice_count += 1
		ice_sprites.append(sprite)

func reset_ice() -> void:
	contact_timers.clear()
	muzzle_flashes.clear()
	for marker in tank_markers.values():
		marker.reset_visuals()
	for sprite in ice_sprites:
		sprite.show()
	ice_count = ice_sprites.size()

func remove_ice(id: int) -> void:
	if id >= 0 and id < ice_sprites.size() and ice_sprites[id].visible:
		ice_sprites[id].hide()
		ice_count -= 1

func apply_aims(aims: Dictionary) -> void:
	for peer in aims:
		if tank_markers.has(peer):
			tank_markers[peer].get_node("Turret").rotation = aims[peer].angle()

func set_members(names: Dictionary) -> void:
	members = names.duplicate()
	for peer in tank_markers.keys():
		if not members.has(peer):
			tank_markers[peer].free()
			tank_markers.erase(peer)
			name_labels[peer].free()
			name_labels.erase(peer)
	for peer in members:
		if tank_markers.has(peer):
			name_labels[peer].text = str(members[peer])
			continue
		var marker := TankVisual.new()
		marker.player_number = 1 if peer == 1 else 2
		marker.z_index = 3 # Client tanks remain visible over foliage/moose.
		marker.position = Vector2(208, 612) if peer == 1 else Vector2(1072, 612)
		add_child(marker)
		tank_markers[peer] = marker
		var label := Label.new()
		label.text = str(members[peer])
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Above tanks, moose, trees, bullets and explosions, below the room HUD.
		label.z_index = 100
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 4)
		add_child(label)
		name_labels[peer] = label
	update_name_labels()
	queue_redraw()

func update_name_labels() -> void:
	for peer in name_labels:
		var label: Label = name_labels[peer]
		var marker: Node2D = tank_markers[peer]
		label.visible = marker.visible
		label.reset_size()
		label.position = marker.position + Vector2(-label.size.x / 2.0, -64)

func _process(delta: float) -> void:
	update_name_labels()
	for peer in contact_timers:
		contact_timers[peer] = maxf(0, contact_timers[peer] - delta)
	for flash in muzzle_flashes:
		flash.life -= delta
	muzzle_flashes = muzzle_flashes.filter(func(flash): return flash.life > 0)
	# Snow is decorative; the session and all gameplay clocks are unaffected.
	queue_redraw()

func draw_holiday_border() -> void:
	var festive := [Color("#ef5360"), Color("#62d29a"), Color("#ffd66b"), Color("#67c9ff"), Color("#f5fbff")]
	for strip_y in [99.0, 773.0]:
		for i in range(47):
			var at := Vector2(65 + i * 25, strip_y + sin(i * 0.65) * 3)
			if i < 46:
				draw_line(at, Vector2(at.x + 25, strip_y + sin((i + 1) * 0.65) * 3), Color("#3e806b"), 2, true)
			var glow: Color = festive[i % 5]
			glow.a = 0.12
			draw_circle(at + Vector2(0, 4), 7, glow)
			draw_circle(at + Vector2(0, 4), 2.6, festive[i % 5])

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color("#193b50"))
	draw_rect(Rect2(62, 106, 1156, 648), Color("#d5e8f1"))
	for i in range(28):
		var at := Vector2(120 + (i * 173) % 1040, 165 + (i * 97) % 520)
		draw_circle(at, 22 + i % 5 * 9, Color(0.94, 0.98, 1.0, 0.28))
		draw_line(at + Vector2(-25, 13), at + Vector2(34, 9), Color(0.65, 0.79, 0.87, 0.24), 1.0, true)
	var snow_time := Time.get_ticks_msec() / 1000.0
	for i in range(170):
		var at := Vector2(70 + fposmod(i * 137 + sin(snow_time * 0.8 + i) * 22, 1136), 112 + fposmod(i * 83 + snow_time * (38 + i % 9 * 4), 634))
		var radius := 2.0 + (i % 4) * 0.6
		draw_circle(at + Vector2(0, 0.8), radius + 0.9, Color(0.28, 0.49, 0.66, 0.5))
		draw_circle(at, radius, Color(1.0, 1.0, 1.0, 0.95))
		if i % 5 == 0:
			draw_line(at - Vector2(5, 0), at + Vector2(5, 0), Color.WHITE, 1.2, true)
			draw_line(at - Vector2(0, 5), at + Vector2(0, 5), Color.WHITE, 1.2, true)
	draw_rect(Rect2(62, 106, 1156, 648), Color("#91bcd3"), false, 2)
	draw_holiday_border()
	draw_line(Vector2(64, 91), Vector2(1216, 91), Color("#a6dfff"), 2)
	for flash in muzzle_flashes:
		draw_circle(flash.position, 8, Color("#eefaff"))
