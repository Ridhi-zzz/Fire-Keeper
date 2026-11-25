
extends Node2D

var float_time: float = 0.0
var bob_offset: float = 0.0
var collected: bool = false
var collection_target: Node2D = null

@export var fragment_value: int = 1
@export var pickup_distance: float = 30.0


func _process(delta: float) -> void:
	float_time += delta

	if collected:
		if not is_instance_valid(collection_target):
			queue_free()
			return

		# Fly towards the cauldron when collected.
		global_position = global_position.move_toward(
			collection_target.global_position,
			450.0 * delta
		)

		scale = scale.lerp(Vector2.ZERO, 9.0 * delta)

		if global_position.distance_to(
			collection_target.global_position
		) < 8.0:
			queue_free()

		queue_redraw()
		return

	# Gentle floating and bobbing.
	bob_offset = sin(float_time * 3.0) * 4.0

	# Check whether the player is close enough to collect it.
	var players: Array[Node] = get_tree().get_nodes_in_group("players")

	for player in players:
		if not is_instance_valid(player):
			continue

		var effective_pickup_distance: float = pickup_distance
		if bool(player.get("pickup_magnet_enabled")):
			effective_pickup_distance = 220.0
		var distance: float = global_position.distance_to(player.global_position)
		if distance <= effective_pickup_distance:
			collect(player)
			break

	queue_redraw()


func collect(player: Node2D) -> void:
	if collected:
		return

	collected = true
	collection_target = player

	if player.has_method("collect_fire_fragment"):
		player.collect_fire_fragment(fragment_value)


func _draw() -> void:
	if collected:
		# Shrinking glow while flying to the player.
		draw_circle(
			Vector2.ZERO,
			11.0,
			Color(1.0, 0.55, 0.12, 0.15)
		)
		return

	var bob_position := Vector2(0, bob_offset)

	# Ground glow.
	draw_circle(
		Vector2(0, 8),
		12.0,
		Color(1.0, 0.48, 0.08, 0.12)
	)

	draw_circle(
		Vector2(0, 8),
		7.0,
		Color(1.0, 0.65, 0.16, 0.18)
	)

	# Fragment glow.
	draw_circle(
		bob_position,
		10.0,
		Color(1.0, 0.48, 0.08, 0.18)
	)

	# Main fragment shape.
	draw_colored_polygon(
		PackedVector2Array([
			bob_position + Vector2(0, -10),
			bob_position + Vector2(7, -2),
			bob_position + Vector2(4, 8),
			bob_position + Vector2(-4, 8),
			bob_position + Vector2(-7, -2)
		]),
		Color("#F59E42")
	)

	# Bright inner core.
	draw_colored_polygon(
		PackedVector2Array([
			bob_position + Vector2(0, -6),
			bob_position + Vector2(3, -1),
			bob_position + Vector2(1, 4),
			bob_position + Vector2(-2, 3),
			bob_position + Vector2(-3, -1)
		]),
		Color("#FFF0AE")
	)

	# Small highlight.
	draw_circle(
		bob_position + Vector2(-2, -3),
		1.5,
		Color.WHITE
	)
