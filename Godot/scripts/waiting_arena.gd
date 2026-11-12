extends Node2D
## Presentation reuse of client 167b4f6 arena layout and winter drawing.
## Tank positions come from the network room; no offline scripts or damage run here.
const ICE = preload("res://assets/brick.svg")
const TREE = preload("res://assets/forest_tree.svg")
const TANK = preload("res://assets/tank.svg")
const TURRET = preload("res://assets/turret.svg")
var tank_markers: Dictionary = {}
var members: Dictionary = {}
var ice_count := 0

func _ready() -> void:
	# Same arena coordinates as the imported offline client; decoration only.
	for col in range(24):
		add_brick(Vector2(88 + col * 48, 132), true)
		add_brick(Vector2(88 + col * 48, 732), true)
	for row in range(1, 15):
		add_brick(Vector2(88, 132 + row * 40), true)
		add_brick(Vector2(1192, 132 + row * 40), true)
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

func set_members(names: Dictionary) -> void:
	members = names.duplicate()
	for peer in tank_markers.keys():
		if not members.has(peer):
			tank_markers[peer].free()
			tank_markers.erase(peer)
	for peer in members:
		if tank_markers.has(peer):
			continue
		var marker := Node2D.new()
		marker.position = Vector2(208, 612) if peer == 1 else Vector2(1072, 612)
		var chassis := Sprite2D.new()
		chassis.texture = TANK
		marker.add_child(chassis)
		var turret := Sprite2D.new()
		turret.texture = TURRET
		turret.position = Vector2(12, 0)
		marker.add_child(turret)
		if peer != 1:
			marker.modulate = Color(1.8, 0.65, 1.0)
		add_child(marker)
		tank_markers[peer] = marker
	queue_redraw()

func _process(_delta: float) -> void:
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
	for peer in tank_markers:
		var label := str(members[peer])
		var font := ThemeDB.fallback_font
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var at: Vector2 = tank_markers[peer].position + Vector2(-width / 2, -42)
		# White labels keep the existing named-room presentation on pale snow.
		draw_rect(Rect2(at + Vector2(-6, -22), Vector2(width + 12, 30)), Color(0.04, 0.12, 0.16, 0.85))
		draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
