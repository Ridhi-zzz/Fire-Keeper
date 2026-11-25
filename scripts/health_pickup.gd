extends Node2D

var float_time: float = 0.0
var bob_offset: float = 0.0
var collected: bool = false

@export var pickup_distance: float = 28.0


func _ready() -> void:
	add_to_group("pickups")


func _process(delta: float) -> void:
	float_time += delta
	bob_offset = sin(float_time * 3.5) * 3.0

	if collected:
		return

	var players := get_tree().get_nodes_in_group("players")

	for player in players:
		if not is_instance_valid(player):
			continue

		var effective_distance: float = pickup_distance
		if bool(player.get("pickup_magnet_enabled")):
			effective_distance = 220.0
		if global_position.distance_to(player.global_position) <= effective_distance:
			if player.health < player.max_health and player.has_method("heal_half_heart"):
				player.heal_half_heart()
				collected = true
				queue_free()
				return

	queue_redraw()


func _draw() -> void:
	var center := Vector2(0, bob_offset)

	# Soft glow, kept subtle so this remains a rare pickup.
	draw_circle(center, 14.0, Color(1.0, 0.20, 0.28, 0.12))

	# Full heart silhouette used as the dark backing.
	var heart := PackedVector2Array([
		center + Vector2(0, 11),
		center + Vector2(-12, 0),
		center + Vector2(-13, -5),
		center + Vector2(-10, -11),
		center + Vector2(-5, -12),
		center + Vector2(0, -7),
		center + Vector2(5, -12),
		center + Vector2(10, -11),
		center + Vector2(13, -5),
		center + Vector2(12, 0)
	])

	draw_colored_polygon(heart, Color("#3B3038"))

	# Only the LEFT half is filled: this is visibly a half-heart,
	# not a full heart with a highlight.
	draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(0, 9),
			center + Vector2(-10, 0),
			center + Vector2(-11, -5),
			center + Vector2(-8, -9),
			center + Vector2(-5, -10),
			center + Vector2(0, -6)
		]),
		Color("#F06A78")
	)

	# Thin center split makes the half-heart shape unmistakable.
	draw_line(
		center + Vector2(0, -6),
		center + Vector2(0, 9),
		Color("#FFE0D8"),
		1.5
	)

	# Outer heart contour.
	draw_polyline(
		PackedVector2Array([
			heart[0], heart[1], heart[2], heart[3], heart[4],
			heart[5], heart[6], heart[7], heart[8], heart[9], heart[0]
		]),
		Color("#DFA1A7"),
		1.3
	)
