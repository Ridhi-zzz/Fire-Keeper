
extends CharacterBody2D

const FIRE_FRAGMENT_SCRIPT = preload("res://scripts/fire_fragment.gd")

@export var max_health: int = 12

var health: int
var flame_time: float = 0.0
var hit_flash_timer: float = 0.0

var is_dying: bool = false
var death_timer: float = 0.0


func _ready() -> void:
	health = max_health
	add_to_group("enemies")

	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 29.0
	collision.shape = shape
	add_child(collision)


func _process(delta: float) -> void:
	flame_time += delta

	if hit_flash_timer > 0.0:
		hit_flash_timer = maxf(0.0, hit_flash_timer - delta)

	if is_dying:
		death_timer -= delta
		scale = Vector2.ONE * (0.75 + maxf(death_timer, 0.0) * 0.25)
		modulate.a = clampf(death_timer / 0.65, 0.0, 1.0)

		if death_timer <= 0.0:
			queue_free()

	queue_redraw()


func take_damage(
	amount: int,
	knockback_direction: Vector2 = Vector2.ZERO
) -> void:
	if is_dying:
		return

	health -= amount
	hit_flash_timer = 0.16

	if health <= 0:
		die()


func die() -> void:
	if is_dying:
		return

	is_dying = true
	death_timer = 0.65

	var collision := get_node_or_null("CollisionShape2D")
	if collision is CollisionShape2D:
		collision.set_deferred("disabled", true)

	var fragment = FIRE_FRAGMENT_SCRIPT.new()
	get_tree().current_scene.add_child(fragment)
	fragment.global_position = global_position


func _draw_polygon(
	points: PackedVector2Array,
	fill_color: Color,
	outline_color: Color = Color("#29252A"),
	outline_width: float = 3.0
) -> void:
	draw_colored_polygon(points, fill_color)

	var outline_points := points.duplicate()
	outline_points.append(points[0])

	draw_polyline(
		outline_points,
		outline_color,
		outline_width,
		true
	)


func _draw() -> void:
	if is_dying:
		var progress: float = 1.0 - death_timer / 0.65

		for i in range(10):
			var angle: float = TAU * float(i) / 10.0
			var distance: float = progress * 48.0
			var ember_position: Vector2 = (
				Vector2.RIGHT.rotated(angle) * distance
				+ Vector2(0, -20)
			)

			draw_circle(
				ember_position,
				4.0 * (1.0 - progress),
				Color(1.0, 0.48, 0.12, 1.0 - progress)
			)

		return

	# Idle breathing and flame movement.
	var breathing: float = sin(flame_time * 2.8) * 1.5
	var flame_flicker: float = sin(flame_time * 13.0) * 3.0
	var flame_flicker_2: float = cos(flame_time * 19.0) * 2.0

	# Ground shadow.
	draw_ellipse_placeholder()

	# Feet.
	_draw_polygon(
		PackedVector2Array([
			Vector2(-25, 24),
			Vector2(-4, 24),
			Vector2(-7, 37),
			Vector2(-27, 35)
		]),
		Color("#B9A982")
	)

	_draw_polygon(
		PackedVector2Array([
			Vector2(4, 24),
			Vector2(25, 24),
			Vector2(27, 35),
			Vector2(7, 37)
		]),
		Color("#B9A982")
	)

	# Arms, slightly chunky and uneven.
	_draw_polygon(
		PackedVector2Array([
			Vector2(-30, -28 + breathing),
			Vector2(-48, -18 + breathing),
			Vector2(-53, 3),
			Vector2(-43, 11),
			Vector2(-31, -4)
		]),
		Color("#D9C89F")
	)

	_draw_polygon(
		PackedVector2Array([
			Vector2(30, -28 + breathing),
			Vector2(48, -18 + breathing),
			Vector2(53, 3),
			Vector2(43, 11),
			Vector2(31, -4)
		]),
		Color("#D9C89F")
	)

	# Main wax body.
	_draw_polygon(
		PackedVector2Array([
			Vector2(-30, -43 + breathing),
			Vector2(-23, -52 + breathing),
			Vector2(20, -52 + breathing),
			Vector2(31, -39 + breathing),
			Vector2(34, 12),
			Vector2(24, 27),
			Vector2(-24, 27),
			Vector2(-34, 12)
		]),
		Color("#E7D8B5")
	)

	# Wax drips on the sides.
	_draw_polygon(
		PackedVector2Array([
			Vector2(-29, -31 + breathing),
			Vector2(-38, -25 + breathing),
			Vector2(-34, -12),
			Vector2(-26, -17)
		]),
		Color("#D8C69F"),
		Color("#29252A"),
		2.0
	)

	_draw_polygon(
		PackedVector2Array([
			Vector2(27, -37 + breathing),
			Vector2(37, -28 + breathing),
			Vector2(33, -14),
			Vector2(25, -20)
		]),
		Color("#D8C69F"),
		Color("#29252A"),
		2.0
	)

	# Front wax patch.
	_draw_polygon(
		PackedVector2Array([
			Vector2(-20, -36 + breathing),
			Vector2(18, -36 + breathing),
			Vector2(22, 8),
			Vector2(13, 19),
			Vector2(-15, 19),
			Vector2(-22, 7)
		]),
		Color("#F0E5C9"),
		Color("#B8A887"),
		1.5
	)

	# Face.
	var eye_color := Color("#49372A")

	if hit_flash_timer > 0.0:
		eye_color = Color("#8C302A")

	draw_circle(Vector2(-10, -12 + breathing), 3.2, eye_color)
	draw_circle(Vector2(10, -12 + breathing), 3.2, eye_color)

	draw_line(
		Vector2(-5, 1 + breathing),
		Vector2(5, 1 + breathing),
		Color("#49372A"),
		2.0
	)

	# Small wax crack on the forehead.
	draw_line(
		Vector2(0, -31 + breathing),
		Vector2(-4, -25 + breathing),
		Color("#B9A17A"),
		1.5
	)

	draw_line(
		Vector2(-4, -25 + breathing),
		Vector2(1, -21 + breathing),
		Color("#B9A17A"),
		1.5
	)

	# Flame stem.
	draw_line(
		Vector2(0, -51 + breathing),
		Vector2(0, -62 + breathing),
		Color("#49372A"),
		3.0
	)

	# Large outer flame.
	_draw_polygon(
		PackedVector2Array([
			Vector2(flame_flicker_2, -65 + breathing - flame_flicker),
			Vector2(13 + flame_flicker_2, -82 + breathing),
			Vector2(12, -69 + breathing),
			Vector2(5, -61 + breathing),
			Vector2(-8, -63 + breathing),
			Vector2(-13, -75 + breathing)
		]),
		Color("#F59E42"),
		Color("#49372A"),
		2.5
	)

	# Inner flame.
	_draw_polygon(
		PackedVector2Array([
			Vector2(flame_flicker_2 * 0.4, -77 + breathing - flame_flicker * 0.5),
			Vector2(6, -68 + breathing),
			Vector2(2, -62 + breathing),
			Vector2(-3, -66 + breathing)
		]),
		Color("#FFE7A0"),
		Color("#E88B32"),
		1.0
	)

	# Health segments.
	for i in range(max_health):
		var bar_color := Color("#EF665B")

		if i >= health:
			bar_color = Color("#514A49")

		draw_rect(
			Rect2(
				Vector2(-30 + i * 5.2, -101),
				Vector2(4.0, 4.0)
			),
			bar_color
		)


func draw_ellipse_placeholder() -> void:
	draw_circle(
		Vector2(0, 30),
		31.0,
		Color(0.03, 0.03, 0.04, 0.32)
	)
