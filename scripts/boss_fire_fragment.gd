
extends Node2D

@export var pickup_distance: float = 38.0
@export var collection_speed: float = 500.0

var float_time: float = 0.0
var collected: bool = false
var collection_target: Node2D = null


func _process(delta: float) -> void:
	float_time += delta

	if collected:
		if not is_instance_valid(collection_target):
			queue_free()
			return

		global_position = global_position.move_toward(
			collection_target.global_position,
			collection_speed * delta
		)

		scale = scale.lerp(Vector2.ZERO, 7.0 * delta)

		if global_position.distance_to(
			collection_target.global_position
		) < 10.0:
			queue_free()

		queue_redraw()
		return

	# Look for the player.
	var players: Array[Node] = get_tree().get_nodes_in_group("players")

	for player in players:
		if not is_instance_valid(player):
			continue

		if global_position.distance_to(player.global_position) <= pickup_distance:
			collect(player)
			break

	queue_redraw()


func collect(player: Node2D) -> void:
	if collected:
		return

	collected = true
	collection_target = player

	# Keep this currency separate from ordinary Fire Fragments.
	GameData.add_boss_fire_fragments(1)
	var current_amount: int = GameData.boss_fire_fragments
	player.set_meta("boss_fire_fragments", current_amount)
	print("Boss Fire Fragments collected: ", current_amount)


func _draw() -> void:
	var bob: float = sin(float_time * 2.8) * 5.0
	var pulse: float = sin(float_time * 4.0) * 0.12 + 1.0
	var rotation_amount: float = sin(float_time * 1.5) * 0.08

	if collected:
		draw_circle(
			Vector2.ZERO,
			20.0,
			Color(1.0, 0.58, 0.12, 0.25)
		)
		return

	# Ground glow.
	draw_circle(
		Vector2(0, 12),
		22.0 * pulse,
		Color(1.0, 0.43, 0.06, 0.10)
	)

	draw_circle(
		Vector2(0, 12),
		14.0 * pulse,
		Color(1.0, 0.68, 0.16, 0.16)
	)

	# Outer magical glow.
	draw_circle(
		Vector2(0, bob),
		23.0 * pulse,
		Color(1.0, 0.45, 0.08, 0.16)
	)

	draw_circle(
		Vector2(0, bob),
		16.0 * pulse,
		Color(1.0, 0.68, 0.18, 0.20)
	)

	# Small orbiting embers.
	for i in range(4):
		var angle: float = float(i) * TAU / 4.0 + float_time * 0.8
		var ember_position: Vector2 = Vector2.RIGHT.rotated(angle) * 25.0
		ember_position.y += bob

		draw_circle(
			ember_position,
			2.5,
			Color("#FFB34F")
		)

	# Main fragment outline.
	var outer_points := PackedVector2Array([
		Vector2(0, -22),
		Vector2(15, -7),
		Vector2(12, 12),
		Vector2(0, 21),
		Vector2(-12, 12),
		Vector2(-15, -7)
	])

	var inner_points := PackedVector2Array([
		Vector2(0, -16),
		Vector2(9, -5),
		Vector2(7, 9),
		Vector2(0, 15),
		Vector2(-7, 9),
		Vector2(-9, -5)
	])

	draw_set_transform(Vector2(0, bob), rotation_amount, Vector2.ONE)

	draw_colored_polygon(
		outer_points,
		Color("#9C3E19")
	)

	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0, -19),
			Vector2(12, -6),
			Vector2(9, 10),
			Vector2(0, 18),
			Vector2(-9, 10),
			Vector2(-12, -6)
		]),
		Color("#F28B2F")
	)

	draw_colored_polygon(
		inner_points,
		Color("#FFD36A")
	)

	# Bright central core.
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0, -10),
			Vector2(5, -3),
			Vector2(4, 7),
			Vector2(0, 11),
			Vector2(-4, 7),
			Vector2(-5, -3)
		]),
		Color("#FFF5C4")
	)

	draw_circle(
		Vector2(-3, -7),
		2.0,
		Color.WHITE
	)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
