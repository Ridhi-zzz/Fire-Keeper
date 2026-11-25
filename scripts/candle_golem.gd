
extends CharacterBody2D

const FIRE_FRAGMENT_SCRIPT = preload("res://scripts/fire_fragment.gd")
const BOSS_FRAGMENT_SCRIPT = preload("res://scripts/boss_fire_fragment.gd")
const FIRE_PROJECTILE_SCRIPT = preload("res://scripts/fire_projectile.gd")
const HEALTH_PICKUP_SCRIPT = preload("res://scripts/health_pickup.gd")
const CANDLE_SCENE = preload("res://scenes/candle.tscn")

@export var max_health: int = 12
@export var fragment_drop_count: int = 6

# Boss behaviour settings.
@export var ai_enabled: bool = true
@export var move_speed: float = 82.0
@export var preferred_distance: float = 155.0
@export var summon_minion_limit: int = 3

var target: Node2D = null
var behaviour_wait: float = 1.8
var slam_cooldown: float = 2.0
var burst_cooldown: float = 3.0
var eruption_cooldown: float = 4.0
var summon_cooldown: float = 6.0
var active_attack_cooldown: float = 0.0

var health: float
var flame_time: float = 0.0
var hit_flash_timer: float = 0.0

var is_dying: bool = false
var death_timer: float = 0.0

# Ground slam.
var slam_active: bool = false
var slam_elapsed: float = 0.0
var slam_duration: float = 1.25
var slam_impact_done: bool = false
var shockwave_timer: float = 0.0
var impact_flash_timer: float = 0.0
var previous_shockwave_radius: float = 25.0
var slam_hit_player: bool = false

# Radiant burst.
var burst_active: bool = false
var burst_elapsed: float = 0.0
var cardinal_burst_fired: bool = false
var diagonal_burst_fired: bool = false
var burst_flash_timer: float = 0.0

# Attack 3: purple wax eruption.
var eruption_active: bool = false
var eruption_elapsed: float = 0.0
var eruption_hazards: Array[Dictionary] = []
var eruption_flash_timer: float = 0.0

# Attack 4: summon candle minions.
var summon_active: bool = false
var summon_elapsed: float = 0.0
var summon_markers: Array[Dictionary] = []
var summon_flash_timer: float = 0.0
var summons_spawned: bool = false

const GROUND_EFFECT_OFFSET := Vector2(0, 28)

const SHOCKWAVE_DURATION := 0.55
const SHOCKWAVE_START_RADIUS := 25.0
const SHOCKWAVE_MAX_RADIUS := 125.0
const SLAM_DAMAGE := 1

const BURST_CARDINAL_TIME := 0.82
const BURST_DIAGONAL_TIME := 1.38
const BURST_RECOVERY_TIME := 1.95
const BURST_PROJECTILE_SPEED := 230.0
const BURST_PROJECTILE_DAMAGE := 1

const ERUPTION_CHARGE_TIME := 1.15
const ERUPTION_RECOVERY_TIME := 1.55
const ERUPTION_DAMAGE := 1
const ERUPTION_BLAST_RADIUS := 39.0

const SUMMON_CHARGE_TIME := 1.25
const SUMMON_RECOVERY_TIME := 1.75
const SUMMON_COUNT := 3


func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	add_to_group("bosses")

	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 29.0
	collision.shape = shape
	add_child(collision)


func _process(delta: float) -> void:
	flame_time += delta

	slam_cooldown = maxf(0.0, slam_cooldown - delta)
	burst_cooldown = maxf(0.0, burst_cooldown - delta)
	eruption_cooldown = maxf(0.0, eruption_cooldown - delta)
	summon_cooldown = maxf(0.0, summon_cooldown - delta)
	behaviour_wait = maxf(0.0, behaviour_wait - delta)
	active_attack_cooldown = maxf(0.0, active_attack_cooldown - delta)

	hit_flash_timer = maxf(0.0, hit_flash_timer - delta)
	impact_flash_timer = maxf(0.0, impact_flash_timer - delta)
	burst_flash_timer = maxf(0.0, burst_flash_timer - delta)

	# Ground slam timing.
	if slam_active:
		slam_elapsed += delta

		if slam_elapsed >= 0.55 and not slam_impact_done:
			slam_impact_done = true
			shockwave_timer = SHOCKWAVE_DURATION
			previous_shockwave_radius = SHOCKWAVE_START_RADIUS
			slam_hit_player = false
			impact_flash_timer = 0.18

		if slam_elapsed >= slam_duration:
			slam_active = false

	if shockwave_timer > 0.0:
		_update_shockwave_hitbox(delta)

	# Radiant burst timing.
	if burst_active:
		burst_elapsed += delta

		if burst_elapsed >= BURST_CARDINAL_TIME and not cardinal_burst_fired:
			cardinal_burst_fired = true
			burst_flash_timer = 0.16
			_fire_projectile_volley(false)

		if burst_elapsed >= BURST_DIAGONAL_TIME and not diagonal_burst_fired:
			diagonal_burst_fired = true
			burst_flash_timer = 0.16
			_fire_projectile_volley(true)

		if burst_elapsed >= BURST_RECOVERY_TIME:
			burst_active = false

	# Wax eruption timing and falling hazard updates.
	if eruption_active:
		eruption_elapsed += delta

		if eruption_elapsed >= ERUPTION_CHARGE_TIME and eruption_hazards.is_empty():
			_create_eruption_hazards()
			eruption_flash_timer = 0.2

		if eruption_elapsed >= ERUPTION_RECOVERY_TIME:
			eruption_active = false

	_update_eruption_hazards(delta)

	# Candle summoning timing.
	if summon_active:
		summon_elapsed += delta

		if summon_elapsed >= SUMMON_CHARGE_TIME and not summons_spawned:
			summons_spawned = true
			_spawn_summoned_candles()
			summon_flash_timer = 0.25

		if summon_elapsed >= SUMMON_RECOVERY_TIME:
			summon_active = false
			summon_markers.clear()

	eruption_flash_timer = maxf(0.0, eruption_flash_timer - delta)
	summon_flash_timer = maxf(0.0, summon_flash_timer - delta)

	# Death animation.
	if is_dying:
		death_timer -= delta

		scale = Vector2.ONE * (
			0.75 + maxf(death_timer, 0.0) * 0.25
		)

		modulate = Color(
			1.0, 1.0, 1.0,
			clampf(death_timer / 0.65, 0.0, 1.0)
		)

		if death_timer <= 0.0:
			queue_free()
	else:
		if hit_flash_timer > 0.0:
			modulate = Color(1.0, 0.62, 0.43, 1.0)
		elif eruption_active or summon_active:
			modulate = Color(0.82, 0.72, 1.0, 1.0)
		else:
			modulate = Color.WHITE

	queue_redraw()


# --------------------------------------------------
# BOSS BEHAVIOUR
# --------------------------------------------------

func _physics_process(delta: float) -> void:
	if is_dying:
		velocity = Vector2.ZERO
		return

	if not ai_enabled:
		velocity = Vector2.ZERO
		return

	if not is_instance_valid(target):
		var players := get_tree().get_nodes_in_group("players")
		if not players.is_empty() and is_instance_valid(players[0]):
			target = players[0]

	if not is_instance_valid(target):
		velocity = Vector2.ZERO
		return

	if _is_performing_attack():
		velocity = Vector2.ZERO
		move_and_slide()
		_keep_inside_arena()
		return

	var to_player: Vector2 = target.global_position - global_position
	var distance: float = to_player.length()

	# Keep a little space so the Golem's attacks are readable.
	if distance > preferred_distance + 25.0:
		velocity = to_player.normalized() * move_speed
	elif distance < preferred_distance - 35.0:
		velocity = -to_player.normalized() * move_speed * 0.55
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	_keep_inside_arena()

	if behaviour_wait <= 0.0 and active_attack_cooldown <= 0.0:
		_choose_next_attack(distance)


func _keep_inside_arena() -> void:
	# The larger boss needs a wider safety margin than regular candles.
	var relative_position := global_position
	var horizontal_limit: float = 952.0
	var vertical_limit: float = 452.0
	var normalized_distance: float = (
		absf(relative_position.x) / horizontal_limit
		+ absf(relative_position.y) / vertical_limit
	)
	if normalized_distance > 1.0:
		global_position = relative_position / normalized_distance


func _is_performing_attack() -> bool:
	return (
		slam_active
		or burst_active
		or eruption_active
		or summon_active
		or shockwave_timer > 0.0
		or not eruption_hazards.is_empty()
	)


func _count_living_candles() -> int:
	var count: int = 0
	var enemies := get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy == self:
			continue
		if enemy.is_in_group("bosses"):
			continue
		if bool(enemy.get("is_dying")):
			continue
		count += 1

	return count


func _choose_next_attack(distance: float) -> void:
	var available_attacks: Array[String] = []

	if slam_cooldown <= 0.0 and distance <= 145.0:
		available_attacks.append("slam")

	if burst_cooldown <= 0.0:
		available_attacks.append("burst")

	if eruption_cooldown <= 0.0 and distance >= 75.0:
		available_attacks.append("eruption")

	if summon_cooldown <= 0.0 and _count_living_candles() <= summon_minion_limit:
		available_attacks.append("summon")

	if available_attacks.is_empty():
		behaviour_wait = 0.45
		return

	# Summoning is less frequent than the three direct attacks.
	var chosen_attack: String = ""

	if available_attacks.size() == 1:
		chosen_attack = available_attacks[0]
	elif available_attacks.has("summon") and randf() < 0.30:
		chosen_attack = "summon"
	else:
		var normal_attacks: Array[String] = []
		for attack_name in available_attacks:
			if attack_name != "summon":
				normal_attacks.append(attack_name)
		chosen_attack = normal_attacks.pick_random()

	match chosen_attack:
		"slam":
			start_ground_slam()
		"burst":
			start_radiant_burst()
		"eruption":
			start_wax_eruption()
		"summon":
			start_candle_summon()

	behaviour_wait = 0.7
	active_attack_cooldown = 0.8


# ATTACK 1: GROUND SLAM
# --------------------------------------------------

func start_ground_slam() -> void:
	AudioManager.play_sfx("boss_warn", 0.8)
	if is_dying or slam_active or burst_active or eruption_active or summon_active:
		return

	slam_active = true
	slam_elapsed = 0.0
	slam_impact_done = false
	slam_hit_player = false
	slam_cooldown = 6.0
	active_attack_cooldown = 1.0


func _update_shockwave_hitbox(delta: float) -> void:
	var progress: float = 1.0 - (
		shockwave_timer / SHOCKWAVE_DURATION
	)

	var current_radius: float = lerpf(
		SHOCKWAVE_START_RADIUS,
		SHOCKWAVE_MAX_RADIUS,
		progress
	)

	if not slam_hit_player:
		var players := get_tree().get_nodes_in_group("players")
		var shockwave_center: Vector2 = (
			global_position + GROUND_EFFECT_OFFSET
		)

		for player in players:
			if not is_instance_valid(player):
				continue

			var distance: float = (
				player.global_position - shockwave_center
			).length()

			var inside_initial_area: bool = (
				distance <= SHOCKWAVE_START_RADIUS
			)

			var wave_reached_player: bool = (
				distance > previous_shockwave_radius
				and distance <= current_radius
			)

			if inside_initial_area or wave_reached_player:
				if player.has_method("take_damage"):
					var knockback_direction: Vector2 = (
						player.global_position - shockwave_center
					).normalized()

					if knockback_direction == Vector2.ZERO:
						knockback_direction = Vector2.UP

					player.take_damage(
						SLAM_DAMAGE,
						knockback_direction
					)

					slam_hit_player = true
					break

	previous_shockwave_radius = current_radius
	shockwave_timer = maxf(0.0, shockwave_timer - delta)


# --------------------------------------------------
# ATTACK 2: RADIANT BURST
# --------------------------------------------------

func start_radiant_burst() -> void:
	AudioManager.play_sfx("boss_warn", 0.75)
	if is_dying or slam_active or burst_active or eruption_active or summon_active:
		return

	burst_active = true
	burst_elapsed = 0.0
	cardinal_burst_fired = false
	diagonal_burst_fired = false
	burst_cooldown = 7.0
	active_attack_cooldown = 1.0


func _fire_projectile_volley(diagonal: bool) -> void:
	var scene := get_tree().current_scene

	if scene == null:
		return

	var directions: Array[Vector2]

	if diagonal:
		directions = [
			Vector2(-1, -1).normalized(),
			Vector2(1, -1).normalized(),
			Vector2(-1, 1).normalized(),
			Vector2(1, 1).normalized()
		]
	else:
		directions = [
			Vector2.UP,
			Vector2.DOWN,
			Vector2.LEFT,
			Vector2.RIGHT
		]

	var players := get_tree().get_nodes_in_group("players")
	var target: Node2D = null

	if not players.is_empty() and is_instance_valid(players[0]):
		target = players[0]

	for direction in directions:
		var projectile = FIRE_PROJECTILE_SCRIPT.new()
		scene.add_child(projectile)

		projectile.global_position = global_position + direction * 34.0
		projectile.setup_straight(
			target,
			BURST_PROJECTILE_DAMAGE,
			BURST_PROJECTILE_SPEED,
			direction,
			Color("#F59E42")
		)


# --------------------------------------------------
# ATTACK 3: PURPLE WAX ERUPTION
# --------------------------------------------------

func start_wax_eruption() -> void:
	AudioManager.play_sfx("boss_warn", 0.7)
	if is_dying or slam_active or burst_active or eruption_active or summon_active:
		return

	eruption_active = true
	eruption_elapsed = 0.0
	eruption_hazards.clear()
	eruption_cooldown = 9.0
	active_attack_cooldown = 1.0


func _create_eruption_hazards() -> void:
	# Wax chunks land in a loose ring around the Golem.
	var hazard_count := 7

	for i in range(hazard_count):
		var angle: float = TAU * float(i) / float(hazard_count)
		angle += randf_range(-0.22, 0.22)

		var distance: float = randf_range(82.0, 142.0)
		var hazard_position := Vector2.RIGHT.rotated(angle) * distance

		eruption_hazards.append({
			"position": hazard_position,
			"fall_timer": randf_range(0.12, 0.38),
			"delay_timer": 0.72,
			"explode_timer": 0.0,
			"exploded": false,
			"hit_player": false,
			"seed": randf()
		})


func _update_eruption_hazards(delta: float) -> void:
	for i in range(eruption_hazards.size() - 1, -1, -1):
		var hazard: Dictionary = eruption_hazards[i]

		if not hazard["exploded"]:
			if hazard["fall_timer"] > 0.0:
				hazard["fall_timer"] = maxf(
					0.0,
					float(hazard["fall_timer"]) - delta
				)
			else:
				hazard["delay_timer"] = maxf(
					0.0,
					float(hazard["delay_timer"]) - delta
				)

				if hazard["delay_timer"] <= 0.0:
					hazard["exploded"] = true
					hazard["explode_timer"] = 0.24
					_check_eruption_damage(hazard)

		else:
			hazard["explode_timer"] = maxf(
				0.0,
				float(hazard["explode_timer"]) - delta
			)

			if hazard["explode_timer"] <= 0.0:
				eruption_hazards.remove_at(i)
				continue

		eruption_hazards[i] = hazard


func _check_eruption_damage(hazard: Dictionary) -> void:
	var players := get_tree().get_nodes_in_group("players")
	var blast_position: Vector2 = global_position + hazard["position"]

	for player in players:
		if not is_instance_valid(player):
			continue

		if player.global_position.distance_to(blast_position) <= ERUPTION_BLAST_RADIUS:
			if player.has_method("take_damage"):
				var knockback_direction: Vector2 = (
					player.global_position - blast_position
				).normalized()

				if knockback_direction == Vector2.ZERO:
					knockback_direction = Vector2.UP

				player.take_damage(ERUPTION_DAMAGE, knockback_direction)
				hazard["hit_player"] = true
				break


# --------------------------------------------------
# ATTACK 4: SUMMON CANDLE MINIONS
# --------------------------------------------------

func start_candle_summon() -> void:
	AudioManager.play_sfx("boss_shield", 0.7)
	if is_dying or slam_active or burst_active or eruption_active or summon_active:
		return

	summon_active = true
	summon_elapsed = 0.0
	summons_spawned = false
	summon_markers.clear()
	summon_cooldown = 13.0
	active_attack_cooldown = 1.0

	# Four possible spawn spots; use three for this attack.
	var spawn_positions: Array[Vector2] = [
		Vector2(-112, -52),
		Vector2(112, -52),
		Vector2(0, 132)
	]

	for spawn_position in spawn_positions:
		summon_markers.append({
			"position": spawn_position,
			"pulse": randf() * TAU
		})


func _spawn_summoned_candles() -> void:
	var scene := get_tree().current_scene

	if scene == null:
		return

	var players := get_tree().get_nodes_in_group("players")
	var target: Node2D = null

	if not players.is_empty() and is_instance_valid(players[0]):
		target = players[0]

	for i in range(summon_markers.size()):
		var marker: Dictionary = summon_markers[i]
		var candle = CANDLE_SCENE.instantiate()

		scene.add_child(candle)
		candle.global_position = global_position + marker["position"]

		# Two melee candles and one ranged candle.
		candle.attack_style = 1 if i == 2 else 0

		if is_instance_valid(target):
			candle.set_target(target)


# DAMAGE AND DEATH
# --------------------------------------------------

func take_damage(
	amount: float,
	knockback_direction: Vector2 = Vector2.ZERO
) -> void:
	if is_dying:
		return

	AudioManager.play_sfx("enemy_hit", 0.9)
	health = maxf(0.0, health - amount)
	hit_flash_timer = 0.19

	if health <= 0:
		die()


func die() -> void:
	if is_dying:
		return

	is_dying = true
	velocity = Vector2.ZERO
	slam_active = false
	burst_active = false
	eruption_active = false
	summon_active = false
	eruption_hazards.clear()
	summon_markers.clear()
	shockwave_timer = 0.0
	death_timer = 0.65

	var collision := get_node_or_null("CollisionShape2D")

	if collision is CollisionShape2D:
		collision.set_deferred("disabled", true)

	drop_fire_fragments()
	var broken_equipped := false
	var players := get_tree().get_nodes_in_group("players")
	if not players.is_empty() and is_instance_valid(players[0]):
		broken_equipped = str(players[0].get("cauldron_id")) == "broken"
	if broken_equipped and randf() < 0.35:
		var health_pickup = HEALTH_PICKUP_SCRIPT.new()
		get_tree().current_scene.add_child(health_pickup)
		health_pickup.global_position = global_position + Vector2(0.0, -12.0)


func drop_fire_fragments() -> void:
	var scene := get_tree().current_scene

	if scene == null:
		return

	for i in range(fragment_drop_count):
		var fragment = FIRE_FRAGMENT_SCRIPT.new()
		scene.add_child(fragment)

		var angle: float = (
			TAU * float(i) / float(fragment_drop_count)
			+ randf_range(-0.18, 0.18)
		)

		var drop_distance: float = randf_range(20.0, 32.0)

		fragment.global_position = (
			global_position
			+ Vector2.RIGHT.rotated(angle) * drop_distance
		)

	var boss_fragment = BOSS_FRAGMENT_SCRIPT.new()
	scene.add_child(boss_fragment)
	boss_fragment.global_position = global_position + Vector2(0, -18)


# --------------------------------------------------
# DRAWING HELPERS
# --------------------------------------------------

func _draw_polygon(
	points: PackedVector2Array,
	fill_color: Color
) -> void:
	draw_colored_polygon(points, fill_color)


func _make_ellipse(
	radius_x: float,
	radius_y: float,
	samples: int = 48
) -> PackedVector2Array:
	var points := PackedVector2Array()

	for i in range(samples + 1):
		var angle := TAU * float(i) / float(samples)

		points.append(Vector2(
			cos(angle) * radius_x,
			sin(angle) * radius_y
		))

	return points


func _draw_arm(
	side: float,
	breathing: float,
	lift: float,
	raise_amount: float
) -> void:
	var shoulder := Vector2(
		side * 30.0,
		-18.0 + breathing - lift
	)

	var rotation_amount := -side * raise_amount * 1.0

	draw_set_transform(shoulder, rotation_amount, Vector2.ONE)

	var arm_points := PackedVector2Array([
		Vector2(-3, -12),
		Vector2(side * 15, -5),
		Vector2(side * 20, 15),
		Vector2(side * 10, 23),
		Vector2(0, 8)
	])

	_draw_polygon(arm_points, Color("#D9C89F"))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --------------------------------------------------
# MAIN DRAW
# --------------------------------------------------

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

	var breathing: float = sin(flame_time * 2.8) * 1.5
	var flame_flicker: float = sin(flame_time * 13.0) * 2.5
	var flame_sway: float = sin(flame_time * 5.0) * 2.0
	var charge_pose: float = 0.0
	var purple_charge: bool = false

	if burst_active and burst_elapsed < BURST_CARDINAL_TIME:
		charge_pose = smoothstep(0.0, 0.48, burst_elapsed)

	if eruption_active:
		charge_pose = smoothstep(0.0, 0.72, eruption_elapsed)
		purple_charge = true

	if summon_active:
		charge_pose = smoothstep(0.0, 0.78, summon_elapsed)
		purple_charge = true

	# Ground slam pose.
	var windup: float = 0.0
	var body_offset: float = 0.0
	var body_scale := Vector2.ONE

	if slam_active:
		if slam_elapsed < 0.55:
			windup = smoothstep(0.0, 0.55, slam_elapsed)
			body_offset = windup * 7.0

			body_scale = Vector2(
				1.0 - windup * 0.04,
				1.0 - windup * 0.10
			)
		else:
			var impact_progress: float = clampf(
				(slam_elapsed - 0.55) / 0.18,
				0.0,
				1.0
			)

			var squash: float = sin(impact_progress * PI)

			body_scale = Vector2(
				1.0 + squash * 0.15,
				1.0 - squash * 0.23
			)

			body_offset = squash * 7.0

	# Ground effects.
	draw_set_transform(GROUND_EFFECT_OFFSET, 0.0, Vector2.ONE)

	# Ground shadow.
	draw_colored_polygon(
		_make_ellipse(34.0, 13.0),
		Color(0.03, 0.03, 0.04, 0.32)
	)

	# Ground slam warning.
	if slam_active and slam_elapsed < 0.55:
		var warning_pulse := sin(slam_elapsed * 24.0) * 3.0
		var warning_alpha := 0.25 + windup * 0.35

		draw_colored_polygon(
			_make_ellipse(
				57.0 + warning_pulse,
				22.0 + warning_pulse * 0.4
			),
			Color(1.0, 0.35, 0.06, warning_alpha * 0.35)
		)

		draw_polyline(
			_make_ellipse(
				57.0 + warning_pulse,
				22.0 + warning_pulse * 0.4
			),
			Color(1.0, 0.62, 0.19, warning_alpha),
			3.0
		)

	# Ground slam shockwave.
	if shockwave_timer > 0.0:
		var wave_progress := 1.0 - (
			shockwave_timer / SHOCKWAVE_DURATION
		)

		var wave_radius := lerpf(
			SHOCKWAVE_START_RADIUS,
			SHOCKWAVE_MAX_RADIUS,
			wave_progress
		)

		var wave_alpha := 1.0 - wave_progress

		draw_polyline(
			_make_ellipse(wave_radius, wave_radius * 0.42),
			Color(1.0, 0.52, 0.12, wave_alpha),
			5.0
		)

		draw_polyline(
			_make_ellipse(
				wave_radius * 0.82,
				wave_radius * 0.34
			),
			Color(1.0, 0.83, 0.39, wave_alpha * 0.65),
			2.0
		)

	# Radiant burst charge glow.
	if burst_active and burst_elapsed < BURST_CARDINAL_TIME:
		var charge_progress: float = burst_elapsed / BURST_CARDINAL_TIME
		var charge_pulse: float = sin(flame_time * 18.0) * 3.0
		var charge_radius: float = 48.0 + charge_progress * 12.0 + charge_pulse

		draw_colored_polygon(
			_make_ellipse(charge_radius, charge_radius * 0.48),
			Color(1.0, 0.48, 0.08, 0.10 + charge_progress * 0.12)
		)

		draw_polyline(
			_make_ellipse(charge_radius, charge_radius * 0.48),
			Color(1.0, 0.70, 0.25, 0.35 + charge_progress * 0.45),
			2.5
		)

		# Small light rays make the charge readable from a distance.
		for ray_index in range(8):
			var ray_angle: float = TAU * float(ray_index) / 8.0
			var ray_direction := Vector2.RIGHT.rotated(ray_angle)
			draw_line(
				ray_direction * 42.0,
				ray_direction * (49.0 + charge_progress * 8.0 + charge_pulse),
				Color(1.0, 0.72, 0.30, 0.35 + charge_progress * 0.45),
				2.0
			)

	# Brief flash each time a volley fires.
	if burst_flash_timer > 0.0:
		var burst_flash_alpha: float = burst_flash_timer / 0.16
		draw_colored_polygon(
			_make_ellipse(48.0, 23.0),
			Color(1.0, 0.78, 0.35, burst_flash_alpha * 0.32)
		)

	# Purple charge aura for the wax eruption and candle summon.
	if purple_charge:
		var purple_progress: float = 0.0

		if eruption_active:
			purple_progress = clampf(
				eruption_elapsed / ERUPTION_CHARGE_TIME,
				0.0,
				1.0
			)
		elif summon_active:
			purple_progress = clampf(
				summon_elapsed / SUMMON_CHARGE_TIME,
				0.0,
				1.0
			)

		var purple_pulse: float = sin(flame_time * 16.0) * 3.0
		var purple_radius: float = 49.0 + purple_progress * 15.0 + purple_pulse

		draw_colored_polygon(
			_make_ellipse(purple_radius, purple_radius * 0.48),
			Color(0.53, 0.30, 0.88, 0.13 + purple_progress * 0.12)
		)

		draw_polyline(
			_make_ellipse(purple_radius, purple_radius * 0.48),
			Color(0.76, 0.55, 1.0, 0.45 + purple_progress * 0.4),
			3.0
		)

	# Falling wax chunks and their delayed blast markers.
	for hazard in eruption_hazards:
		var hazard_position: Vector2 = hazard["position"]
		var fall_timer: float = hazard["fall_timer"]
		var exploded: bool = hazard["exploded"]

		if not exploded:
			# Purple floor marker shows where the chunk will land.
			draw_set_transform(
				GROUND_EFFECT_OFFSET + hazard_position,
				0.0,
				Vector2.ONE
			)

			draw_colored_polygon(
				_make_ellipse(19.0, 9.0),
				Color(0.58, 0.34, 0.90, 0.22)
			)

			draw_polyline(
				_make_ellipse(19.0, 9.0),
				Color(0.79, 0.62, 1.0, 0.75),
				2.0
			)

			if fall_timer > 0.0:
				var fall_height: float = 24.0 + fall_timer * 95.0
				draw_set_transform(
					hazard_position + Vector2(0, -fall_height),
					float(hazard["seed"]) * 3.0,
					Vector2.ONE
				)

				draw_colored_polygon(
					PackedVector2Array([
						Vector2(0, -12),
						Vector2(9, -3),
						Vector2(6, 9),
						Vector2(-5, 11),
						Vector2(-10, 0)
					]),
					Color("#A477D6")
				)
				draw_circle(Vector2(-2, -2), 3.0, Color("#E5D4FF"))

			else:
				var blink: float = 0.5 + 0.5 * sin(flame_time * 18.0 + float(hazard["seed"]) * 20.0)
				draw_polyline(
					_make_ellipse(24.0 + blink * 4.0, 11.0 + blink * 2.0),
					Color(0.85, 0.66, 1.0, 0.45 + blink * 0.45),
					2.5
				)

			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		else:
			var explosion_progress: float = 1.0 - float(hazard["explode_timer"]) / 0.24
			var explosion_radius: float = lerpf(10.0, ERUPTION_BLAST_RADIUS, explosion_progress)
			var explosion_alpha: float = 1.0 - explosion_progress

			draw_set_transform(GROUND_EFFECT_OFFSET + hazard_position, 0.0, Vector2.ONE)

			draw_colored_polygon(
				_make_ellipse(explosion_radius, explosion_radius * 0.48),
				Color(0.65, 0.36, 0.95, explosion_alpha * 0.28)
			)

			draw_polyline(
				_make_ellipse(explosion_radius, explosion_radius * 0.48),
				Color(0.86, 0.70, 1.0, explosion_alpha),
				4.0
			)

			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Summon circles show where the new candles will appear.
	if summon_active and not summons_spawned:
		for marker in summon_markers:
			var marker_position: Vector2 = marker["position"]
			var marker_pulse: float = sin(flame_time * 12.0 + float(marker["pulse"])) * 3.0

			draw_set_transform(
				GROUND_EFFECT_OFFSET + marker_position,
				0.0,
				Vector2.ONE
			)

			draw_colored_polygon(
				_make_ellipse(22.0 + marker_pulse, 11.0 + marker_pulse * 0.4),
				Color(0.58, 0.34, 0.90, 0.18)
			)

			draw_polyline(
				_make_ellipse(22.0 + marker_pulse, 11.0 + marker_pulse * 0.4),
				Color(0.82, 0.65, 1.0, 0.8),
				2.5
			)

			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if eruption_flash_timer > 0.0 or summon_flash_timer > 0.0:
		var special_flash: float = maxf(eruption_flash_timer, summon_flash_timer)
		var special_alpha: float = special_flash / 0.25

		draw_colored_polygon(
			_make_ellipse(62.0, 30.0),
			Color(0.75, 0.55, 1.0, special_alpha * 0.3)
		)

	# Reset drawing transform before drawing the Golem.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Body and limbs.
	draw_set_transform(
		Vector2(0, body_offset),
		0.0,
		body_scale
	)

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

	# Arms.
	_draw_arm(-1.0, breathing, windup * 15.0, windup)
	_draw_arm(1.0, breathing, windup * 15.0, windup)

	draw_set_transform(
		Vector2(0, body_offset),
		0.0,
		body_scale
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

	# Wax drips.
	_draw_polygon(
		PackedVector2Array([
			Vector2(-29, -31 + breathing),
			Vector2(-38, -25 + breathing),
			Vector2(-34, -12),
			Vector2(-26, -17)
		]),
		Color("#D8C69F")
	)

	_draw_polygon(
		PackedVector2Array([
			Vector2(27, -37 + breathing),
			Vector2(37, -28 + breathing),
			Vector2(33, -14),
			Vector2(25, -20)
		]),
		Color("#D8C69F")
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
		Color("#F0E5C9")
	)

	# During Radiant Burst charge, the Golem closes its eyes and
	# crosses both arms over its chest before releasing the projectiles.
	if charge_pose > 0.0:
		var arm_pose: float = charge_pose
		var arm_color := Color("#D9C89F")
		var arm_highlight := Color("#F0E2C1")

		# Left forearm sweeps diagonally across the chest.
		var left_arm_start := Vector2(-31.0, -18.0 + breathing)
		var left_arm_end := Vector2(13.0, 8.0 + breathing)
		var left_arm_rest := Vector2(-27.0, -10.0 + breathing)
		var left_start := left_arm_rest.lerp(left_arm_start, arm_pose)
		var left_end := Vector2(-9.0, 7.0 + breathing).lerp(left_arm_end, arm_pose)
		draw_line(left_start, left_end, arm_color, 11.0, true)
		draw_line(left_start + Vector2(0, -2), left_end + Vector2(0, -2), arm_highlight, 3.0, true)
		draw_circle(left_end, 6.0, arm_color)

		# Right forearm crosses over the first arm in the opposite direction.
		var right_arm_start := Vector2(31.0, -18.0 + breathing)
		var right_arm_end := Vector2(-13.0, 8.0 + breathing)
		var right_arm_rest := Vector2(27.0, -10.0 + breathing)
		var right_start := right_arm_rest.lerp(right_arm_start, arm_pose)
		var right_end := Vector2(9.0, 7.0 + breathing).lerp(right_arm_end, arm_pose)
		draw_line(right_start, right_end, arm_color, 11.0, true)
		draw_line(right_start + Vector2(0, -2), right_end + Vector2(0, -2), arm_highlight, 3.0, true)
		draw_circle(right_end, 6.0, arm_color)

	# Face: eyes close during the charge, then reopen after the first volley.
	var eye_color := Color("#49372A")

	if hit_flash_timer > 0.0:
		eye_color = Color("#8C302A")

	if charge_pose > 0.35:
		var closed_eye_color := eye_color
		draw_line(
			Vector2(-14, -12 + breathing),
			Vector2(-7, -10 + breathing),
			closed_eye_color,
			2.8,
			true
		)
		draw_line(
			Vector2(7, -10 + breathing),
			Vector2(14, -12 + breathing),
			closed_eye_color,
			2.8,
			true
		)
	else:
		draw_circle(Vector2(-10, -12 + breathing), 3.2, eye_color)
		draw_circle(Vector2(10, -12 + breathing), 3.2, eye_color)

	draw_line(
		Vector2(-5, 1 + breathing),
		Vector2(5, 1 + breathing),
		Color("#49372A"),
		2.0
	)

	# Forehead crack.
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
		Vector2(0, -61 + breathing),
		Color("#49372A"),
		3.0
	)

	# Outer flame.
	var flame_boost := 0.0

	if slam_active and slam_elapsed < 0.55:
		flame_boost = windup * 5.0

	if burst_active and burst_elapsed < BURST_CARDINAL_TIME:
		flame_boost = (burst_elapsed / BURST_CARDINAL_TIME) * 13.0

	if eruption_active:
		flame_boost = (eruption_elapsed / ERUPTION_CHARGE_TIME) * 17.0

	if summon_active:
		flame_boost = (summon_elapsed / SUMMON_CHARGE_TIME) * 15.0

	var outer_flame_color := Color("#F59E42")
	var inner_flame_color := Color("#FFE7A0")

	if purple_charge:
		outer_flame_color = Color("#A477E8")
		inner_flame_color = Color("#E7D5FF")

	_draw_polygon(
		PackedVector2Array([
			Vector2(flame_sway, -59 + breathing),
			Vector2(-12 - flame_boost * 0.3, -68 + breathing),
			Vector2(-10 + flame_flicker * 0.3 - flame_boost * 0.2, -81 + breathing),
			Vector2(-3 + flame_sway, -91 + breathing - flame_flicker - flame_boost),
			Vector2(5 + flame_sway, -79 + breathing),
			Vector2(13 + flame_boost * 0.3, -68 + breathing),
			Vector2(9 + flame_sway, -59 + breathing)
		]),
		outer_flame_color
	)

	# Bright inner flame.
	_draw_polygon(
		PackedVector2Array([
			Vector2(flame_sway * 0.4, -62 + breathing),
			Vector2(-5, -69 + breathing),
			Vector2(-2 + flame_sway * 0.3, -81 + breathing - flame_flicker * 0.4),
			Vector2(4, -69 + breathing),
			Vector2(5 + flame_sway * 0.4, -62 + breathing)
		]),
		inner_flame_color
	)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Ground slam impact sparks.
	if impact_flash_timer > 0.0:
		var flash_strength: float = impact_flash_timer / 0.18

		for i in range(12):
			var angle: float = TAU * float(i) / 12.0
			var direction: Vector2 = Vector2.RIGHT.rotated(angle)

			draw_line(
				direction * 35.0,
				direction * (52.0 + 12.0 * flash_strength),
				Color(1.0, 0.72, 0.35, flash_strength),
				3.0
			)

	# Hit sparks.
	if hit_flash_timer > 0.0:
		var flash_strength: float = hit_flash_timer / 0.19

		for i in range(8):
			var angle: float = TAU * float(i) / 8.0
			var direction: Vector2 = Vector2.RIGHT.rotated(angle)

			draw_line(
				direction * 37.0,
				direction * (45.0 + 5.0 * flash_strength),
				Color(1.0, 0.72, 0.35, flash_strength),
				2.0
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
