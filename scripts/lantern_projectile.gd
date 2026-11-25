extends Node2D

var target: Node2D = null
var damage: int = 1
var speed: float = 245.0
var direction: Vector2 = Vector2.DOWN
var lifetime: float = 3.0
var age: float = 0.0
var projectile_color := Color("#B77BFF")


func setup(new_target: Node2D, new_damage: int, new_speed: float, fixed_direction: Vector2) -> void:
	target = new_target
	damage = new_damage
	speed = new_speed
	direction = fixed_direction.normalized()


func _process(delta: float) -> void:
	age += delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return

	# This projectile never changes direction after it is launched.
	var previous_position := global_position
	global_position += direction * speed * delta

	if is_instance_valid(target):
		var closest := Geometry2D.get_closest_point_to_segment(
			target.global_position, previous_position, global_position
		)
		if closest.distance_to(target.global_position) <= 19.0:
			if target.has_method("take_damage"):
				target.take_damage(damage, direction)
			queue_free()
			return

	queue_redraw()


func _draw() -> void:
	var pulse := 1.0 + sin(age * 16.0) * 0.12
	draw_circle(Vector2.ZERO, 13.0 * pulse, Color("#A66BFF", 0.16))
	draw_circle(Vector2.ZERO, 8.0 * pulse, Color("#B77BFF"))
	draw_circle(Vector2.ZERO, 4.0, Color("#F1DFFF"))
	draw_circle(-direction * 8.0, 3.0, Color("#CFA8FF", 0.7))
	draw_circle(-direction * 14.0, 2.0, Color("#CFA8FF", 0.35))
