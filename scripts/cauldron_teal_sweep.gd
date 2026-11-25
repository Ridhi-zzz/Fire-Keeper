extends Node2D

var facing: Vector2 = Vector2.RIGHT
var elapsed: float = 0.0
var duration: float = 0.42
var damage: float = 1.0
var already_hit: Array[Node] = []
var ball_count: int = 3
var spacing: float = 23.0

func setup(direction: Vector2, hit_damage: float) -> void:
	facing = direction.normalized()
	damage = hit_damage

func _process(delta: float) -> void:
	elapsed += delta
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var sweep_angle := lerpf(-deg_to_rad(82.0), deg_to_rad(82.0), progress)
	var chain_direction := facing.rotated(sweep_angle)
	# The fireball blade rotates around the exact centre of the player.
	var start := global_position
	var finish := start + chain_direction * spacing * float(ball_count - 1)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or already_hit.has(enemy) or enemy.get("is_dying") == true:
			continue
		var target_position: Vector2 = enemy.global_position
		if enemy.has_method("get_attack_target_position"):
			target_position = enemy.get_attack_target_position(global_position)
		var closest := Geometry2D.get_closest_point_to_segment(target_position, start, finish)
		if closest.distance_to(target_position) <= 22.0:
			if enemy.has_method("take_damage"):
				var health_before: float = float(enemy.get("health"))
				enemy.take_damage(damage, chain_direction)
				var health_after: float = float(enemy.get("health"))
				if health_after < health_before:
					var players := get_tree().get_nodes_in_group("players")
					if not players.is_empty() and players[0].has_method("register_cauldron_hit"):
						players[0].register_cauldron_hit()
				already_hit.append(enemy)
	if elapsed >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var direction := facing.rotated(lerpf(-deg_to_rad(82.0), deg_to_rad(82.0), progress))
	# Local origin is the player centre, so the whole chain pivots around the player.
	var start := Vector2.ZERO
	var finish := start + direction * spacing * float(ball_count - 1)
	draw_line(start, finish, Color("#35DCCB", 0.65), 14.0, true)
	draw_line(start, finish, Color("#B8FFF5", 0.95), 5.0, true)
	for i in range(ball_count):
		var point := start + direction * spacing * float(i)
		draw_circle(point, 13.0, Color("#35DCCB", 0.20))
		draw_circle(point, 8.5, Color("#43E6D4"))
		draw_circle(point, 4.2, Color("#E2FFFA"))
