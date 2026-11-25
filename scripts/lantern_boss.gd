extends Node2D

const FIRE_FRAGMENT_SCRIPT: Script = preload("res://scripts/fire_fragment.gd")
const BOSS_FIRE_FRAGMENT_SCRIPT: Script = preload("res://scripts/boss_fire_fragment.gd")
const MELEE_LANTERN_SCENE: PackedScene = preload("res://scenes/lantern_melee.tscn")
const RANGED_LANTERN_SCENE: PackedScene = preload("res://scenes/lantern_ranged.tscn")

const MAX_HEALTH: int = 12
const NORMAL_FRAGMENT_DROP_COUNT: int = 12

var animation_time: float = 0.0
var max_health: int = MAX_HEALTH
var health: float = float(MAX_HEALTH)
var boss_display_name: String = "LANTERN WARDEN"
var is_dying: bool = false
var training_dummy: bool = false
var hit_flash_timer: float = 0.0
var hit_flash_duration: float = 0.12
var hit_reaction_timer: float = 0.0
var hit_reaction_duration: float = 0.20
var hit_reaction_direction: Vector2 = Vector2.ZERO
var hit_area: Area2D

# Lantern Warden shield encounter timing.
const VULNERABILITY_DURATION: float = 2.0
const SHIELD_REFORM_DURATION: float = 0.75
const PUSHBACK_STRENGTH: float = 920.0

var shield_active: bool = true
var vulnerability_timer: float = 0.0
var shield_reform_timer: float = 0.0
var shield_break_timer: float = 0.0

var pushback_flash_timer: float = 0.0

# Warden attacks run continuously while its shield is active.
var rotating_cross_angle: float = 0.0
var volley_spawn_timer: float = 0.0
var fireball_chains: Array[Dictionary] = []
var quadrant_pattern_rotation: float = 0.0
var pushback_cycle_index: int = 0
var summon_wave_active: bool = false
var summon_wave_pending: bool = false
var summoned_lanterns_remaining: int = 0

const CROSS_TELEGRAPH: float = 0.9
const CROSS_START_RADIUS: float = 56.0
const CROSS_LENGTH: float = 820.0
const CROSS_BALL_SPACING: float = 24.0
const CROSS_BALL_RADIUS: float = 9.5
const CROSS_ROTATION_SPEED: float = 0.42

const VOLLEY_TELEGRAPH: float = 0.65
const VOLLEY_INTERVAL: float = 1.35
const VOLLEY_SPEED: float = 118.0
const VOLLEY_BALL_SPACING: float = 16.0
const VOLLEY_BALL_RADIUS: float = 8.5
const VOLLEY_MIN_BALLS: int = 1
const VOLLEY_MAX_BALLS: int = 3
const VOLLEY_MAX_RADIUS: float = 1600.0
const VOLLEY_START_RADIUS: float = 62.0
const VOLLEY_LANES_PER_QUADRANT: int = 3
const VOLLEY_LANE_ANGLE_SPREAD: float = 0.44
const PATTERN_ROTATION_PER_PUSHBACK: float = PI / 8.0
const ATTACK_CONTACT_RADIUS: float = 16.0

func _ready() -> void:
	add_to_group("bosses")
	add_to_group("enemies")
	_create_hitbox()


func _create_hitbox() -> void:
	# Kept as a monitorable boss hitbox for compatibility with existing
	# combat and inspection tools. Player attacks currently use the
	# "enemies" group and call take_damage() directly.
	hit_area = Area2D.new()
	hit_area.name = "BossHitbox"
	hit_area.collision_layer = 2
	hit_area.collision_mask = 0
	hit_area.monitoring = false
	hit_area.monitorable = true
	add_child(hit_area)

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	# Covers the complete visible lantern: crown, glass chamber, handles
	# and lower brass base. The drawing is offset downward by 40 px.
	shape.size = Vector2(170.0, 160.0)
	collision.shape = shape
	collision.position = Vector2(0.0, 21.0)
	hit_area.add_child(collision)


func _process(delta: float) -> void:
	animation_time += delta
	hit_flash_timer = maxf(0.0, hit_flash_timer - delta)
	hit_reaction_timer = maxf(0.0, hit_reaction_timer - delta)
	shield_break_timer = maxf(0.0, shield_break_timer - delta)
	pushback_flash_timer = maxf(0.0, pushback_flash_timer - delta)

	if not shield_active and vulnerability_timer > 0.0:
		vulnerability_timer = maxf(0.0, vulnerability_timer - delta)
		if vulnerability_timer <= 0.0 and not is_dying:
			_finish_vulnerability_window()

	if shield_reform_timer > 0.0:
		shield_reform_timer = maxf(0.0, shield_reform_timer - delta)
		if shield_reform_timer <= 0.0 and not is_dying:
			shield_active = true
			rotating_cross_angle = 0.0
			volley_spawn_timer = 0.0
			fireball_chains.clear()
			if summon_wave_pending:
				summon_wave_pending = false
				_spawn_summoned_lantern_wave()

	if training_dummy:
		shield_active = false
		vulnerability_timer = 0.0
		shield_reform_timer = 0.0
	elif shield_active and not is_dying:
		_update_warden_attacks(delta)

	queue_redraw()



func _update_warden_attacks(delta: float) -> void:
	# The cross and the quadrant volleys are active at the same time.
	# They only run while the shield is up; _process() pauses this function
	# automatically during the vulnerability window.
	if animation_time > CROSS_TELEGRAPH:
		rotating_cross_angle = wrapf(
			rotating_cross_angle + CROSS_ROTATION_SPEED * delta,
			0.0,
			TAU
		)
		_check_rotating_cross_collision()

	if not summon_wave_active:
		if animation_time > VOLLEY_TELEGRAPH:
			volley_spawn_timer -= delta
			if volley_spawn_timer <= 0.0:
				_spawn_quadrant_volley()
				volley_spawn_timer = VOLLEY_INTERVAL

		_update_fireball_chains(delta)


func _get_player_nodes() -> Array:
	return get_tree().get_nodes_in_group("players")


func _damage_player_from_attack() -> void:
	for player_node in _get_player_nodes():
		if not is_instance_valid(player_node) or not player_node is Node2D:
			continue
		var away_direction: Vector2 = (
			player_node.global_position - (global_position + Vector2(0.0, 40.0))
		).normalized()
		if away_direction == Vector2.ZERO:
			away_direction = Vector2.DOWN
		if player_node.has_method("take_damage"):
			player_node.take_damage(1, away_direction)


func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment: Vector2 = finish - start
	var length_squared: float = segment.length_squared()
	if length_squared <= 0.001:
		return point.distance_to(start)
	var amount: float = clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	var closest: Vector2 = start + segment * amount
	return point.distance_to(closest)


func _check_rotating_cross_collision() -> void:
	for player_node in _get_player_nodes():
		if not is_instance_valid(player_node) or not player_node is Node2D:
			continue
		var player_local: Vector2 = to_local(player_node.global_position)
		var center := Vector2(0.0, 40.0)
		for arm_index in range(4):
			var angle: float = rotating_cross_angle + float(arm_index) * PI * 0.5
			var direction := Vector2.RIGHT.rotated(angle)
			var start := center + direction * CROSS_START_RADIUS
			var finish := center + direction * CROSS_LENGTH
			if _distance_to_segment(player_local, start, finish) <= ATTACK_CONTACT_RADIUS:
				_damage_player_from_attack()
				return


func _spawn_quadrant_volley() -> void:
	# Three straight, parallel fireball-chain lanes in each quadrant.
	# The complete four-quadrant formation keeps its orientation until pushback.
	for quadrant in range(4):
		var quadrant_center: float = (
			quadrant_pattern_rotation
			+ PI * 0.25
			+ float(quadrant) * PI * 0.5
		)
		for lane_index in range(VOLLEY_LANES_PER_QUADRANT):
			var lane_offset: float = float(lane_index - 1) * VOLLEY_LANE_ANGLE_SPREAD
			var lane_angle: float = quadrant_center + lane_offset
			var ball_count: int = randi_range(VOLLEY_MIN_BALLS, VOLLEY_MAX_BALLS)
			fireball_chains.append({
				"base_angle": lane_angle,
				"age": 0.0,
				"ball_count": ball_count
			})


func _update_fireball_chains(delta: float) -> void:
	var player_nodes := _get_player_nodes()
	for chain_index in range(fireball_chains.size() - 1, -1, -1):
		var chain: Dictionary = fireball_chains[chain_index]
		var age: float = float(chain["age"]) + delta
		chain["age"] = age
		fireball_chains[chain_index] = chain

		var base_angle: float = float(chain["base_angle"])
		var current_angle: float = base_angle + rotating_cross_angle
		var direction: Vector2 = Vector2.RIGHT.rotated(current_angle)
		var ball_count: int = int(chain["ball_count"])
		var chain_hit: bool = false

		for ball_index in range(ball_count):
			var distance: float = (
				VOLLEY_START_RADIUS
				+ age * VOLLEY_SPEED
				- float(ball_index) * VOLLEY_BALL_SPACING
			)
			if distance < VOLLEY_START_RADIUS:
				continue

			var ball_position: Vector2 = Vector2(0.0, 40.0) + direction * distance
			for player_node in player_nodes:
				if not is_instance_valid(player_node) or not player_node is Node2D:
					continue
				var player_local: Vector2 = to_local(player_node.global_position)
				if player_local.distance_to(ball_position) <= ATTACK_CONTACT_RADIUS:
					_damage_player_from_attack()
					chain_hit = true
					break
			if chain_hit:
				break

		var leading_distance: float = VOLLEY_START_RADIUS + age * VOLLEY_SPEED
		if chain_hit or leading_distance >= VOLLEY_MAX_RADIUS:
			fireball_chains.remove_at(chain_index)


func _draw_quadrant_volley_telegraph() -> void:
	if animation_time >= VOLLEY_TELEGRAPH:
		return
	var pulse: float = 0.5 + 0.5 * sin(animation_time * 9.0)
	draw_circle(
		Vector2(0.0, 40.0),
		48.0 + pulse * 7.0,
		Color(0.30, 0.96, 0.90, 0.10 + pulse * 0.08)
	)


func _draw_quadrant_fireball_chains() -> void:
	for chain in fireball_chains:
		var base_angle: float = float(chain["base_angle"])
		var direction: Vector2 = Vector2.RIGHT.rotated(base_angle + rotating_cross_angle)
		var age: float = float(chain["age"])
		var ball_count: int = int(chain["ball_count"])
		for ball_index in range(ball_count):
			var distance: float = (
				VOLLEY_START_RADIUS
				+ age * VOLLEY_SPEED
				- float(ball_index) * VOLLEY_BALL_SPACING
			)
			if distance < VOLLEY_START_RADIUS:
				continue
			var point: Vector2 = Vector2(0.0, 40.0) + direction * distance
			if ball_index > 0:
				var previous_point: Vector2 = point - direction * VOLLEY_BALL_SPACING
				draw_line(point, previous_point, Color("#35DCCB", 0.48), 8.0, true)
				draw_line(point, previous_point, Color("#A8FFF4", 0.60), 2.0, true)
			draw_circle(point, VOLLEY_BALL_RADIUS + 5.0, Color("#35DCCB", 0.18))
			draw_circle(point, VOLLEY_BALL_RADIUS, Color("#43E6D4"))
			draw_circle(point, VOLLEY_BALL_RADIUS * 0.50, Color("#E2FFFA"))


func _draw_fireball_chain(start: Vector2, direction: Vector2, ball_count: int, spacing: float, ball_radius: float) -> void:
	var finish: Vector2 = start + direction * float(ball_count - 1) * spacing
	draw_line(start, finish, Color("#35DCCB", 0.50), ball_radius * 1.35, true)
	draw_line(start, finish, Color("#A8FFF4", 0.72), 2.8, true)
	for i in range(ball_count):
		var point: Vector2 = start + direction * float(i) * spacing
		var size: float = ball_radius if i == 0 or i == ball_count - 1 else ball_radius * 0.92
		draw_circle(point, size + 5.0, Color("#35DCCB", 0.18))
		draw_circle(point, size, Color("#43E6D4"))
		draw_circle(point, size * 0.50, Color("#E2FFFA"))


func _draw_rotating_cross() -> void:
	var center := Vector2(0.0, 40.0)
	if animation_time <= CROSS_TELEGRAPH:
		var alpha: float = 0.22 + 0.48 * (animation_time / CROSS_TELEGRAPH)
		for arm_index in range(4):
			var angle: float = rotating_cross_angle + float(arm_index) * PI * 0.5
			var direction := Vector2.RIGHT.rotated(angle)
			draw_line(
				center + direction * CROSS_START_RADIUS,
				center + direction * CROSS_LENGTH,
				Color(0.58, 1.0, 0.94, alpha),
				3.0,
				true
			)
		return

	var ball_count: int = int(floor((CROSS_LENGTH - CROSS_START_RADIUS) / CROSS_BALL_SPACING)) + 1
	for arm_index in range(4):
		var angle: float = rotating_cross_angle + float(arm_index) * PI * 0.5
		var direction := Vector2.RIGHT.rotated(angle)
		_draw_fireball_chain(
			center + direction * CROSS_START_RADIUS,
			direction,
			ball_count,
			CROSS_BALL_SPACING,
			CROSS_BALL_RADIUS
		)


func _finish_vulnerability_window() -> void:
	# The Warden creates distance after every vulnerability window.
	_push_player_back()
	pushback_cycle_index += 1
	quadrant_pattern_rotation = wrapf(
		quadrant_pattern_rotation + PATTERN_ROTATION_PER_PUSHBACK,
		0.0,
		TAU
	)

	# Encounter rhythm: bullet phase, bullet phase, add phase, repeat.
	# The add phase replaces the projectile volleys, not the rotating cross.
	summon_wave_pending = (pushback_cycle_index % 3 == 0)
	if summon_wave_pending:
		volley_spawn_timer = 0.0
		fireball_chains.clear()

	pushback_flash_timer = 0.48
	shield_reform_timer = SHIELD_REFORM_DURATION


func _spawn_summoned_lantern_wave() -> void:
	var players := get_tree().get_nodes_in_group("players")
	if players.is_empty() or not players[0] is Node2D:
		summon_wave_active = false
		return

	var player_target: Node2D = players[0] as Node2D
	summon_wave_active = true
	summoned_lanterns_remaining = 0

	# Two melee and two ranged lanterns spawn around the Warden.
	var spawn_offsets: Array[Vector2] = [
		Vector2(-230.0, -110.0),
		Vector2(230.0, -110.0),
		Vector2(-230.0, 150.0),
		Vector2(230.0, 150.0)
	]

	for i in range(4):
		var lantern_scene: PackedScene = (
			MELEE_LANTERN_SCENE if i < 2 else RANGED_LANTERN_SCENE
		)
		var lantern := lantern_scene.instantiate() as Node2D
		if lantern == null:
			continue

		lantern.position = spawn_offsets[i]
		lantern.set("boss_summon_owner", self)
		# Guarantee at least two health pickups from this wave.
		lantern.set("boss_summon_guaranteed_health_drop", i < 2)
		if lantern.has_method("set_target"):
			lantern.set_target(player_target)
		add_child(lantern)
		summoned_lanterns_remaining += 1

	if summoned_lanterns_remaining <= 0:
		summon_wave_active = false


func on_summon_defeated(_death_position: Vector2) -> void:
	if not summon_wave_active:
		return

	summoned_lanterns_remaining = maxi(0, summoned_lanterns_remaining - 1)
	if summoned_lanterns_remaining <= 0:
		summon_wave_active = false
		volley_spawn_timer = 0.0


func _push_player_back() -> void:
	var players := get_tree().get_nodes_in_group("players")
	for player_node in players:
		if not is_instance_valid(player_node) or not player_node is Node2D:
			continue

		var away_direction: Vector2 = (
			player_node.global_position - global_position
		).normalized()
		if away_direction == Vector2.ZERO:
			away_direction = Vector2.DOWN

		# Contact knockback changes velocity only; it never calls take_damage().
		if player_node.has_method("apply_contact_knockback"):
			player_node.apply_contact_knockback(away_direction, PUSHBACK_STRENGTH)
		elif player_node.has_method("apply_knockback"):
			player_node.apply_knockback(away_direction, PUSHBACK_STRENGTH)


func get_attack_target_position(from_position: Vector2) -> Vector2:
	# Player attacks are distance/cone based, not physics-hitbox based.
	# Return the closest point on the Warden's full visible silhouette.
	# These bounds include the crown, body, side handles and lower plinth.
	var bob: float = sin(animation_time * 1.8) * 2.5
	var top_left := global_position + Vector2(-85.0, -52.0 + bob)
	var bottom_right := global_position + Vector2(85.0, 140.0 + bob)

	var closest := Vector2(
		clampf(from_position.x, top_left.x, bottom_right.x),
		clampf(from_position.y, top_left.y, bottom_right.y)
	)

	# If the player is already inside the bounds, use the Warden's centre
	# so the attack still has a meaningful direction for the cone check.
	if closest.distance_squared_to(from_position) < 0.001:
		return global_position + Vector2(0.0, 40.0 + bob)

	return closest


func take_damage(amount: float, attack_direction: Vector2 = Vector2.ZERO) -> void:
	if amount <= 0 or is_dying or health <= 0:
		return
	AudioManager.play_sfx("boss_shield" if shield_active else "enemy_hit", 0.9)

	# The first hit only shatters the shield. It never reduces boss health
	# and therefore does not consume damage-upgrade/special-charge progress.
	if shield_active and not training_dummy:
		shield_active = false
		vulnerability_timer = VULNERABILITY_DURATION
		shield_reform_timer = 0.0
		shield_break_timer = 0.72
		volley_spawn_timer = 0.0
		fireball_chains.clear()
		hit_flash_timer = hit_flash_duration
		_set_hit_reaction_direction(attack_direction)
		return

	# During the exposed two-second window, normal damage applies.
	health = maxf(0.0, health - amount)
	hit_flash_timer = hit_flash_duration
	hit_reaction_timer = hit_reaction_duration
	_set_hit_reaction_direction(attack_direction)

	if health <= 0:
		_defeat_boss()


func _set_hit_reaction_direction(attack_direction: Vector2) -> void:
	# The player passes a direction pointing from the player toward the boss.
	if attack_direction.length_squared() > 0.001:
		hit_reaction_direction = attack_direction.normalized()
	else:
		hit_reaction_direction = Vector2.UP


func _defeat_boss() -> void:
	if is_dying:
		return

	is_dying = true
	boss_display_name = "LANTERN WARDEN DEFEATED"

	if is_instance_valid(hit_area):
		hit_area.monitorable = false

	_drop_boss_rewards()
	queue_free()


func _drop_boss_rewards() -> void:
	var drop_parent: Node = get_tree().current_scene
	if drop_parent == null:
		drop_parent = get_parent()
	if drop_parent == null:
		push_warning("Lantern Warden could not find a parent for its reward drops.")
		return

	# Twelve individual normal fragments, scattered around the Warden.
	for i in range(NORMAL_FRAGMENT_DROP_COUNT):
		var fragment := FIRE_FRAGMENT_SCRIPT.new() as Node2D
		drop_parent.add_child(fragment)
		fragment.global_position = global_position + Vector2.RIGHT.rotated(
			TAU * float(i) / float(NORMAL_FRAGMENT_DROP_COUNT)
			+ randf_range(-0.16, 0.16)
		) * randf_range(24.0, 48.0)

	# One separate Boss Fire Fragment, using the existing boss-currency pickup.
	var boss_fragment := BOSS_FIRE_FRAGMENT_SCRIPT.new() as Node2D
	drop_parent.add_child(boss_fragment)
	boss_fragment.global_position = global_position + Vector2(0.0, -20.0)

	var broken_equipped := false
	var players := get_tree().get_nodes_in_group("players")
	if not players.is_empty() and is_instance_valid(players[0]):
		broken_equipped = str(players[0].get("cauldron_id")) == "broken"
	if broken_equipped and randf() < 0.35:
		var health_pickup = preload("res://scripts/health_pickup.gd").new()
		drop_parent.add_child(health_pickup)
		health_pickup.global_position = global_position + Vector2(0.0, -34.0)



func _shield_ellipse_points(center_y: float, radius_x: float, radius_y: float, count: int = 48) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle: float = TAU * float(i) / float(count)
		points.append(Vector2(cos(angle) * radius_x, center_y + sin(angle) * radius_y))
	return points


func _draw_active_shield_back(bob: float) -> void:
	var pulse: float = 0.5 + 0.5 * sin(animation_time * 2.6)
	var center_y: float = 18.0 + bob
	draw_colored_polygon(
		_shield_ellipse_points(center_y, 91.0, 103.0),
		Color(0.18, 0.88, 0.86, 0.055 + pulse * 0.025)
	)
	draw_colored_polygon(
		_shield_ellipse_points(center_y, 83.0, 94.0),
		Color(0.38, 0.98, 0.91, 0.025 + pulse * 0.018)
	)


func _draw_active_shield_front(bob: float) -> void:
	var pulse: float = 0.5 + 0.5 * sin(animation_time * 2.6)
	var center_y: float = 18.0 + bob
	var outer := _shield_ellipse_points(center_y, 91.0, 103.0)
	var inner := _shield_ellipse_points(center_y, 84.0, 96.0)
	var outer_closed := outer.duplicate()
	outer_closed.append(outer[0])
	var inner_closed := inner.duplicate()
	inner_closed.append(inner[0])

	draw_polyline(outer_closed, Color(0.35, 0.96, 0.91, 0.62 + pulse * 0.18), 2.2, true)
	draw_polyline(inner_closed, Color(0.66, 1.0, 0.96, 0.20 + pulse * 0.12), 1.0, true)

	for i in range(8):
		var angle: float = TAU * float(i) / 8.0 - PI * 0.5 + animation_time * 0.10
		var node_position := Vector2(cos(angle) * 91.0, center_y + sin(angle) * 103.0)
		var diamond := PackedVector2Array([
			node_position + Vector2(0.0, -5.0),
			node_position + Vector2(4.0, 0.0),
			node_position + Vector2(0.0, 5.0),
			node_position + Vector2(-4.0, 0.0)
		])
		draw_circle(node_position, 7.0, Color(0.20, 0.92, 0.90, 0.10 + pulse * 0.05))
		draw_colored_polygon(diamond, Color(0.66, 1.0, 0.94, 0.70 + pulse * 0.20))

	for i in range(3):
		var start_angle: float = animation_time * (0.42 if i % 2 == 0 else -0.34) + TAU * float(i) / 3.0
		var arc_points := PackedVector2Array()
		for step in range(9):
			var t: float = float(step) / 8.0
			var angle: float = start_angle + t * 0.52
			arc_points.append(Vector2(cos(angle) * 87.0, center_y + sin(angle) * 99.0))
		draw_polyline(arc_points, Color(0.70, 1.0, 0.96, 0.48 + pulse * 0.18), 2.0, true)


func _draw_shield_break_effect(bob: float) -> void:
	if shield_break_timer <= 0.0:
		return

	var progress: float = 1.0 - shield_break_timer / 0.72
	var alpha: float = 1.0 - progress
	var center := Vector2(0.0, 18.0 + bob)
	# Expanding circular fracture flash.
	draw_arc(
		center,
		lerpf(30.0, 116.0, progress),
		0.0,
		TAU,
		64,
		Color(0.62, 1.0, 0.96, alpha * 0.85),
		lerpf(5.0, 1.0, progress),
		true
	)

	# Large angular glass-energy fragments burst outward and fade.
	for i in range(12):
		var angle: float = TAU * float(i) / 12.0 + 0.13
		var direction := Vector2.RIGHT.rotated(angle)
		var distance: float = lerpf(24.0, 112.0, progress)
		var fragment_center: Vector2 = center + direction * distance
		var tangent: Vector2 = direction.rotated(PI * 0.5)
		var fragment := PackedVector2Array([
			fragment_center + direction * 7.0,
			fragment_center + tangent * 3.0,
			fragment_center - direction * 9.0,
			fragment_center - tangent * 2.0
		])
		draw_colored_polygon(fragment, Color(0.48, 1.0, 0.94, alpha * 0.9))
		draw_line(
			fragment_center - direction * 7.0,
			fragment_center + direction * 7.0,
			Color(0.86, 1.0, 0.98, alpha),
			1.5
		)


func _draw_pushback_pulse(bob: float) -> void:
	if pushback_flash_timer <= 0.0:
		return

	var progress: float = 1.0 - pushback_flash_timer / 0.48
	var radius: float = lerpf(24.0, 150.0, progress)
	var alpha: float = 1.0 - progress
	draw_arc(
		Vector2(0.0, 18.0 + bob),
		radius,
		0.0,
		TAU,
		64,
		Color(0.48, 1.0, 0.94, alpha * 0.85),
		lerpf(8.0, 1.5, progress),
		true
	)


func _draw() -> void:
	var bob: float = sin(animation_time * 1.8) * 2.5
	var flame_flicker: float = sin(animation_time * 9.0) * 2.0 + cos(animation_time * 14.0) * 1.2

	# Original teal-and-brass Warden palette and silhouette are preserved.
	var brass := Color("#80613C")
	var brass_light := Color("#D8B77A")
	var brass_shadow := Color("#493B30")
	var glass := Color("#123C3C")
	var glass_light := Color("#286D68")
	var flame := Color("#42E5D0")
	var flame_hot := Color("#D1FFF5")
	var glow := Color("#38DCCB")

	# Ground shadow and subtle teal glow.
	draw_set_transform(Vector2(0, 57), 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, 68.0, Color(0.0, 0.0, 0.0, 0.30))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2.ZERO, 66.0, Color(glow.r, glow.g, glow.b, 0.035))

	if shield_active:
		_draw_active_shield_back(bob)

	# Draw the hazard chains before the Warden itself, so they emerge from
	# behind its silhouette instead of covering its face and glass chamber.
	if shield_active and not is_dying:
		_draw_rotating_cross()
		_draw_quadrant_volley_telegraph()
		_draw_quadrant_fireball_chains()

	var reaction_progress: float = 0.0
	if hit_reaction_timer > 0.0:
		var elapsed: float = 1.0 - (hit_reaction_timer / hit_reaction_duration)
		reaction_progress = sin(elapsed * PI)

	# Heavy impact response inspired by the Candle Golem: the Warden dips,
	# compresses vertically, widens, then springs back to its idle pose.
	var impact_offset := Vector2(0.0, reaction_progress * 5.0)
	var impact_rotation := -hit_reaction_direction.x * reaction_progress * 0.035
	var impact_scale := Vector2(
		1.0 + reaction_progress * 0.075,
		1.0 - reaction_progress * 0.13
	)
	draw_set_transform(
		Vector2(0, 40 + bob) + impact_offset,
		sin(animation_time * 1.15) * 0.025 + impact_rotation,
		impact_scale
	)

	# Ornate hanging crown and suspension loop.
	draw_arc(Vector2(0, -78), 19.0, PI, TAU, 32, brass_light, 5.0)
	draw_arc(Vector2(0, -78), 12.0, PI, TAU, 24, brass, 3.0)
	draw_line(Vector2(0, -62), Vector2(0, -49), brass_light, 5.0)

	# Crown-like roof.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-54, -48), Vector2(-43, -61), Vector2(-22, -68),
		Vector2(0, -75), Vector2(22, -68), Vector2(43, -61),
		Vector2(54, -48), Vector2(43, -39), Vector2(-43, -39)
	]), brass_shadow)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-48, -49), Vector2(-34, -59), Vector2(0, -70),
		Vector2(34, -59), Vector2(48, -49), Vector2(39, -42),
		Vector2(-39, -42)
	]), brass_light)
	draw_line(Vector2(-47, -47), Vector2(47, -47), Color("#F2D59A"), 3.0)

	for x in [-35.0, 0.0, 35.0]:
		draw_circle(Vector2(x, -59 if x != 0.0 else -70), 4.0, brass_shadow)
		draw_circle(Vector2(x, -60 if x != 0.0 else -71), 2.0, Color("#F5D99C"))

	# Main glass chamber.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-43, -40), Vector2(43, -40), Vector2(55, -22),
		Vector2(51, 30), Vector2(36, 47), Vector2(-36, 47),
		Vector2(-51, 30), Vector2(-55, -22)
	]), brass_shadow)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-37, -35), Vector2(37, -35), Vector2(47, -19),
		Vector2(43, 25), Vector2(31, 39), Vector2(-31, 39),
		Vector2(-43, 25), Vector2(-47, -19)
	]), glass)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-30, -29), Vector2(-8, -34), Vector2(-12, 33),
		Vector2(-30, 26), Vector2(-37, -15)
	]), Color(glass_light.r, glass_light.g, glass_light.b, 0.55))
	draw_colored_polygon(PackedVector2Array([
		Vector2(18, -30), Vector2(34, -24), Vector2(37, 20),
		Vector2(27, 31), Vector2(20, 10)
	]), Color("#4AB9A8", 0.18))

	# Brass frame.
	for x in [-44.0, 44.0]:
		draw_line(Vector2(x, -38), Vector2(x * 0.91, 39), brass_light, 6.0)
	draw_line(Vector2(-47, -35), Vector2(47, -35), brass_light, 6.0)
	draw_line(Vector2(-45, 39), Vector2(45, 39), brass, 7.0)
	draw_line(Vector2(-49, -9), Vector2(49, -9), brass, 4.0)

	# Symmetrical external handles.
	for side in [-1.0, 1.0]:
		draw_line(Vector2(side * 45, -13), Vector2(side * 57, -13), brass_shadow, 7.0)
		draw_arc(Vector2(side * 68, -2), 14.0, -PI * 0.43, PI * 0.43, 24, brass_shadow, 8.0)
		draw_arc(Vector2(side * 68, -2), 14.0, -PI * 0.43, PI * 0.43, 24, brass_light, 4.0)
		draw_line(Vector2(side * 57, 11), Vector2(side * 45, 11), brass_light, 5.0)
		draw_circle(Vector2(side * 49, -13), 3.5, brass_light)
		draw_circle(Vector2(side * 49, 11), 3.5, brass)

	# Original teal flame, contained inside the glass.
	draw_circle(Vector2(0, 2), 23.0 + flame_flicker * 0.2, Color(glow.r, glow.g, glow.b, 0.13))
	draw_colored_polygon(PackedVector2Array([
		Vector2(flame_flicker * 0.18, -30 - absf(flame_flicker) * 0.15),
		Vector2(14, -18), Vector2(21, -1), Vector2(17, 17),
		Vector2(9, 27), Vector2(0, 31), Vector2(-9, 27),
		Vector2(-17, 17), Vector2(-21, -1), Vector2(-14, -18)
	]), flame)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -23 - flame_flicker * 0.12), Vector2(9, -9),
		Vector2(12, 7), Vector2(6, 22), Vector2(0, 26),
		Vector2(-6, 22), Vector2(-12, 7), Vector2(-9, -9)
	]), flame_hot)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -11), Vector2(4, 1), Vector2(0, 15), Vector2(-4, 1)
	]), Color("#FFFFFF", 0.78))

	# Angrier face: narrowed eyes, slanted brows and a stern frown.
	var face_color := Color("#17413D")
	draw_circle(Vector2(-8.5, 1), 3.5, Color("#F2FFFA"))
	draw_circle(Vector2(8.5, 1), 3.5, Color("#F2FFFA"))
	draw_circle(Vector2(-8.5, 1), 1.5, face_color)
	draw_circle(Vector2(8.5, 1), 1.5, face_color)
	draw_line(Vector2(-14, -7), Vector2(-5, -4), face_color, 3.2)
	draw_line(Vector2(14, -7), Vector2(5, -4), face_color, 3.2)
	draw_arc(Vector2(0, 18), 6.0, PI + 0.18, TAU - 0.18, 18, face_color, 2.4)

	# Lower plinth and centre jewel.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-43, 40), Vector2(43, 40), Vector2(51, 51),
		Vector2(39, 59), Vector2(-39, 59), Vector2(-51, 51)
	]), brass_shadow)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-39, 42), Vector2(39, 42), Vector2(44, 50),
		Vector2(34, 55), Vector2(-34, 55), Vector2(-44, 50)
	]), brass_light)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 43), Vector2(9, 50), Vector2(0, 57), Vector2(-9, 50)
	]), flame)
	draw_circle(Vector2(0, 50), 3.0, flame_hot)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if shield_active:
		_draw_active_shield_front(bob)
	else:
		_draw_shield_break_effect(bob)

	_draw_pushback_pulse(bob)

	# Floating teal embers.
	for i in range(6):
		var angle := animation_time * 0.55 + TAU * float(i) / 6.0
		var radius := 72.0 + sin(animation_time * 2.0 + float(i)) * 4.0
		var ember := Vector2.RIGHT.rotated(angle) * radius + Vector2(0, -3)
		draw_circle(ember, 5.0, Color(glow.r, glow.g, glow.b, 0.16))
		draw_circle(ember, 2.2, flame_hot)

	# Stronger hit flash and radial impact sparks, matching the Candle Golem.
	if hit_flash_timer > 0.0:
		var flash_strength := hit_flash_timer / hit_flash_duration
		draw_circle(
			Vector2(0.0, 5.0),
			54.0,
			Color(1.0, 0.86, 0.62, flash_strength * 0.22)
		)
		for i in range(10):
			var angle := TAU * float(i) / 10.0
			var direction := Vector2.RIGHT.rotated(angle)
			draw_line(
				direction * 48.0,
				direction * (59.0 + 7.0 * flash_strength),
				Color(1.0, 0.72, 0.35, flash_strength),
				3.0
			)
