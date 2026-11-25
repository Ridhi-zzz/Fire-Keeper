extends Node2D

var target: Node2D = null
var damage: int = 1
var speed: float = 260.0
var direction: Vector2 = Vector2.DOWN
var lifetime: float = 3.0
var projectile_time: float = 0.0

# Regular candle shots home in on the player.
# Boss burst shots travel in a fixed straight line.
var straight_mode: bool = false
var projectile_color: Color = Color("#A477FF")


func setup(
	new_target: Node2D,
	new_damage: int,
	new_speed: float,
	initial_direction: Vector2
) -> void:
	target = new_target
	damage = new_damage
	speed = new_speed
	direction = initial_direction.normalized()
	straight_mode = false
	projectile_color = Color("#A477FF")


func setup_straight(
	new_target: Node2D,
	new_damage: int,
	new_speed: float,
	initial_direction: Vector2,
	new_color: Color = Color("#F59E42")
) -> void:
	target = new_target
	damage = new_damage
	speed = new_speed
	direction = initial_direction.normalized()
	straight_mode = true
	projectile_color = new_color


func _process(delta: float) -> void:
	projectile_time += delta
	lifetime -= delta

	if lifetime <= 0.0:
		queue_free()
		return

	if not straight_mode:
		if not is_instance_valid(target):
			queue_free()
			return

		# Regular candle projectile: steer towards the player's current position.
		var desired_direction := (
			target.global_position - global_position
		).normalized()

		direction = direction.lerp(
			desired_direction,
			2.5 * delta
		).normalized()

	# Straight mode never changes its direction.
	var previous_position := global_position
	global_position += direction * speed * delta

	# Check whether the projectile reached the player.
	if is_instance_valid(target):
		var closest_point := Geometry2D.get_closest_point_to_segment(
			target.global_position,
			previous_position,
			global_position
		)

		if closest_point.distance_to(target.global_position) <= 17.0:
			if target.has_method("take_damage"):
				target.take_damage(
					damage,
					direction
				)

			queue_free()
			return

	queue_redraw()


func _draw() -> void:
	# Soft glow.
	draw_circle(
		Vector2.ZERO,
		11.0,
		Color(projectile_color.r, projectile_color.g, projectile_color.b, 0.20)
	)

	# Main fireball.
	draw_circle(
		Vector2.ZERO,
		6.5,
		projectile_color
	)

	# Bright centre.
	draw_circle(
		Vector2.ZERO,
		3.2,
		Color("#FFF0C4")
	)

	# Trailing embers.
	var trail_direction := -direction

	draw_circle(
		trail_direction * 8.0,
		3.0,
		Color(projectile_color.r, projectile_color.g, projectile_color.b, 0.65)
	)

	draw_circle(
		trail_direction * 14.0,
		2.0,
		Color(projectile_color.r, projectile_color.g, projectile_color.b, 0.35)
	)
