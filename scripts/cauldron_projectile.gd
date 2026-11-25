extends Node2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 440.0
var damage: float = 0.5
var lifetime: float = 2.2
var radius: float = 9.0
var max_travel_distance: float = -1.0
var travelled_distance: float = 0.0
var tint: Color = Color("#F5B65B")

func setup(shot_direction: Vector2, shot_damage: float, shot_speed: float, shot_tint: Color = Color("#F5B65B"), travel_limit: float = -1.0) -> void:
	direction = shot_direction.normalized()
	damage = shot_damage
	speed = shot_speed
	tint = shot_tint
	max_travel_distance = travel_limit

func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	var previous := global_position
	var travel_step: float = speed * delta
	global_position += direction * travel_step
	travelled_distance += travel_step
	if max_travel_distance > 0.0 and travelled_distance >= max_travel_distance:
		queue_free()
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.get("is_dying") == true:
			continue
		var target_position: Vector2 = enemy.global_position
		if enemy.has_method("get_attack_target_position"):
			target_position = enemy.get_attack_target_position(global_position)
		var closest := Geometry2D.get_closest_point_to_segment(target_position, previous, global_position)
		if closest.distance_to(target_position) <= radius + 15.0:
			if enemy.has_method("take_damage"):
				var health_before: float = float(enemy.get("health"))
				enemy.take_damage(damage, direction)
				var health_after: float = float(enemy.get("health"))
				if health_after < health_before:
					var players := get_tree().get_nodes_in_group("players")
					if not players.is_empty() and players[0].has_method("register_cauldron_hit"):
						players[0].register_cauldron_hit()
			queue_free()
			return
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius + 7.0, Color(tint.r, tint.g, tint.b, 0.18))
	draw_circle(Vector2.ZERO, radius, tint)
	draw_circle(Vector2.ZERO, radius * 0.48, Color("#FFF2C8"))
	draw_circle(-direction * 10.0, 3.0, Color(tint.r, tint.g, tint.b, 0.5))
