extends Node2D

var points: Array[Vector2] = []
var lifetime: float = 1.15
var age: float = 0.0
var hit_ids: Dictionary = {}
var damage: float = 1.0
var hit_radius: float = 34.0

func begin(start_position: Vector2) -> void:
	points.append(start_position)
	z_index = 80

func add_point(world_position: Vector2) -> void:
	if points.is_empty() or points[-1].distance_to(world_position) >= 8.0:
		points.append(world_position)
	queue_redraw()

func _process(delta: float) -> void:
	age += delta
	lifetime -= delta
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy is Node2D or enemy.get("is_dying") == true:
			continue
		var enemy_id := enemy.get_instance_id()
		if hit_ids.has(enemy_id):
			continue
		for point in points:
			if enemy.global_position.distance_to(point) <= hit_radius and enemy.has_method("take_damage"):
				hit_ids[enemy_id] = true
				enemy.take_damage(damage, (enemy.global_position - point).normalized())
				break
	if lifetime <= 0.0:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	if points.size() < 2:
		return
	var alpha := clampf(lifetime / 0.35, 0.0, 1.0) * minf(1.0, age * 8.0)
	for i in range(points.size() - 1):
		var a := to_local(points[i])
		var b := to_local(points[i + 1])
		draw_line(a, b, Color(1.0, 0.20, 0.025, 0.22 * alpha), 27.0, true)
		draw_line(a, b, Color(1.0, 0.48, 0.06, 0.65 * alpha), 16.0, true)
		draw_line(a, b, Color(1.0, 0.88, 0.35, 0.95 * alpha), 5.0, true)
	for point in points:
		draw_circle(to_local(point), 8.0, Color(1.0, 0.34, 0.035, 0.5 * alpha))
