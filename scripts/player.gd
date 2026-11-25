
extends CharacterBody2D

signal stats_changed(fire_fragments: int, health: int)
signal player_died

@export var move_speed: float = 220.0
@export var max_health: int = 10
@export var knockback_strength: float = 220.0

var health: int
var fire_fragments: int = 0
var facing_direction: Vector2 = Vector2.DOWN
var invulnerability_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO

# Hit and contact reactions.
var hit_reaction_timer: float = 0.0
var hit_reaction_duration: float = 0.22
var hit_reaction_strength: float = 1.0
var reaction_time: float = 0.0

# Attack settings.
var attack_range: float = 100.0
var attack_angle: float = 35.0
var attack_damage: int = 1
var attack_cooldown: float = 0.45

# Slash animation.
var attack_animation_duration: float = 0.22
var attack_visual_timer: float = 0.0
var cooldown_timer: float = 0.0
var attack_direction: Vector2 = Vector2.RIGHT

# Q: Dash / dodge.
@export var dash_speed: float = 325.0
@export var dash_duration: float = 0.18
@export var dash_cooldown: float = 2.0
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_velocity: Vector2 = Vector2.ZERO
var dash_direction: Vector2 = Vector2.DOWN

# E: Special fire burst.
@export var special_damage: int = 2
@export var special_radius: float = 115.0
const SPECIAL_CHARGE_REQUIRED: int = 20
var special_charge: int = 0
var special_charge_required: int = SPECIAL_CHARGE_REQUIRED
var special_visual_timer: float = 0.0
const SPECIAL_VISUAL_DURATION := 0.42
const CAULDRON_PROJECTILE_SCRIPT = preload("res://scripts/cauldron_projectile.gd")
const TEAL_SWEEP_SCRIPT = preload("res://scripts/cauldron_teal_sweep.gd")

var cauldron_id: String = "default"
var magazine_ammo: int = 0
var magazine_size: int = 0
var is_reloading: bool = false
var reload_timer: float = 0.0
var reload_duration: float = 2.0
var dash_charges: int = 1
var dash_charge_max: int = 1
var dash_recharge_timer: float = 0.0

# Run-only reward upgrades.
var run_buffs: Dictionary = {}
var crit_chance: float = 0.0
var bonus_dash_charges: int = 0
var dash_cooldown_reduction: float = 0.0
var movement_speed_bonus: float = 0.0
var fire_burst_hit_reduction: int = 0
var combustion_kill_counter: int = 0
var ember_shield_bonus: float = 0.0
var afterburn_enabled: bool = false
var afterburn_hit_ids: Dictionary = {}
var volatile_flame_bonus: int = 0
var double_drop_chance: float = 0.0
var soul_conversion_enabled: bool = false
var soul_conversion_quarters: int = 0
var pickup_magnet_enabled: bool = false
var overloaded_chamber: bool = false
var ranged_triple_spread: bool = false
var ranged_twin_shot: bool = false
var dash_base_max: int = 1



func _ready() -> void:
	cauldron_id = GameData.equipped_cauldron
	_apply_cauldron_setup()
	dash_base_max = dash_charge_max
	fire_fragments = GameData.fire_fragments
	if cauldron_id == "broken":
		max_health = 4
	else:
		max_health += GameData.permanent_health_bonus
	attack_damage += GameData.permanent_damage_bonus
	health = max_health

	for upgrade_id in GameData.take_pending_temp_upgrades():
		match upgrade_id:
			"temp_damage":
				attack_damage = maxi(1, roundi(attack_damage * 1.2))
			"temp_attack_speed":
				attack_cooldown *= 0.85
			"temp_movement":
				move_speed *= 1.15
			"temp_health":
				if cauldron_id != "broken":
					max_health += 2
					health += 2

	add_to_group("players")
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 15.0
	collision.shape = shape
	add_child(collision)
	var camera := Camera2D.new()
	camera.enabled = true
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	add_child(camera)
	stats_changed.emit(fire_fragments, health)


func _apply_cauldron_setup() -> void:
	magazine_ammo = 0
	magazine_size = 0
	is_reloading = false
	reload_timer = 0.0
	dash_charges = 1
	dash_charge_max = 1
	dash_recharge_timer = 0.0
	match cauldron_id:
		"ranged":
			magazine_size = 6
			magazine_ammo = magazine_size
		"shotgun":
			magazine_size = 2
			magazine_ammo = magazine_size
		"thinner":
			dash_charge_max = 2
			dash_charges = 2
			dash_cooldown = 2.0


func set_cauldron_for_test(new_cauldron_id: String) -> void:
	cauldron_id = new_cauldron_id
	_apply_cauldron_setup()
	if cauldron_id == "broken":
		max_health = 4
		health = mini(health, max_health)
	elif max_health < 10 + GameData.permanent_health_bonus:
		max_health = 10 + GameData.permanent_health_bonus
		health = mini(health, max_health)
	stats_changed.emit(fire_fragments, health)
	queue_redraw()


func get_cauldron_status() -> String:
	if cauldron_id == "ranged":
		return "AMMO  %d / 6%s" % [magazine_ammo, "  ·  RELOADING" if is_reloading else ""]
	if cauldron_id == "shotgun":
		return "BURSTS  %d / 2%s" % [magazine_ammo, "  ·  RELOADING" if is_reloading else ""]
	if cauldron_id == "thinner":
		return "DASH CHARGES  %d / 2" % dash_charges
	return "CAULDRON  " + cauldron_id.to_upper()


func _begin_reload() -> void:
	if cauldron_id != "ranged" and cauldron_id != "shotgun":
		return
	if is_reloading or magazine_ammo >= magazine_size:
		return
	is_reloading = true
	reload_timer = reload_duration


func _update_reload(delta: float) -> void:
	if not is_reloading:
		return
	reload_timer = maxf(0.0, reload_timer - delta)
	if reload_timer <= 0.0:
		is_reloading = false
		magazine_ammo = magazine_size


func _spawn_cauldron_projectile(direction: Vector2, damage: float, tint: Color, speed: float = 440.0, max_distance: float = -1.0) -> void:
	var shot = CAULDRON_PROJECTILE_SCRIPT.new()
	get_tree().current_scene.add_child(shot)
	shot.z_index = z_index + 2
	shot.global_position = global_position + Vector2(0.0, -8.0)
	shot.setup(direction, damage, speed, tint, max_distance)


func register_cauldron_hit() -> void:
	special_charge = mini(special_charge_required, special_charge + 1)


func _on_melee_enemy_hit(enemy: Node) -> void:
	if cauldron_id != "spiky" or not is_instance_valid(enemy):
		return
	if not enemy.has_method("take_damage") or enemy.get("is_dying") == true:
		return
	var direction: Vector2 = (enemy.global_position - global_position).normalized()
	enemy.take_damage(0.5, direction)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			_start_dash()
		elif event.keycode == KEY_E:
			_perform_special_attack()
		elif event.keycode == KEY_R:
			_begin_reload()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		perform_attack()


func _start_dash() -> void:
	if dash_timer > 0.0:
		return
	if cauldron_id == "thinner":
		if dash_charges <= 0:
			return
		dash_charges -= 1
		dash_recharge_timer = dash_cooldown
	elif dash_charges <= 0:
		return
	else:
		dash_charges -= 1
		dash_recharge_timer = maxf(0.1, dash_cooldown - dash_cooldown_reduction)

	var requested_direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	if requested_direction == Vector2.ZERO:
		requested_direction = facing_direction

	if requested_direction == Vector2.ZERO:
		requested_direction = Vector2.DOWN

	# Store the direction on the player so _draw() can orient the dash trail.
	afterburn_hit_ids.clear()
	dash_direction = requested_direction.normalized()
	dash_velocity = dash_direction * dash_speed
	knockback_velocity = Vector2.ZERO
	dash_timer = dash_duration
	dash_cooldown_timer = maxf(0.1, dash_cooldown - dash_cooldown_reduction)

	# Invulnerability lasts for the complete dash window.
	invulnerability_timer = maxf(invulnerability_timer, dash_duration)


func _perform_special_attack() -> void:
	if special_charge < special_charge_required:
		return

	# Fire Burst consumes the entire meter.
	special_charge = 0
	special_visual_timer = SPECIAL_VISUAL_DURATION

	# Damage every enemy inside the burst radius.
	# Special attack damage does not recharge itself.
	var enemies := get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue

		var target_position: Vector2 = enemy.global_position
		if enemy.has_method("get_attack_target_position"):
			target_position = enemy.get_attack_target_position(global_position)

		var distance: float = global_position.distance_to(target_position)

		if distance <= special_radius and enemy.has_method("take_damage"):
			var direction: Vector2 = (target_position - global_position).normalized()
			if direction == Vector2.ZERO:
				direction = (enemy.global_position - global_position).normalized()
			var burst_damage: float = float(special_damage + volatile_flame_bonus)
			if crit_chance > 0.0 and randf() < crit_chance:
				burst_damage *= 2.0
			enemy.take_damage(burst_damage, direction)

	queue_redraw()


func _process(delta: float) -> void:
	cooldown_timer = maxf(0.0, cooldown_timer - delta)
	attack_visual_timer = maxf(0.0, attack_visual_timer - delta)
	invulnerability_timer = maxf(0.0, invulnerability_timer - delta)
	dash_cooldown_timer = maxf(0.0, dash_cooldown_timer - delta)
	if dash_charges < dash_charge_max:
		dash_recharge_timer = maxf(0.0, dash_recharge_timer - delta)
		if dash_recharge_timer <= 0.0:
			dash_charges += 1
			if dash_charges < dash_charge_max:
				dash_recharge_timer = maxf(0.1, dash_cooldown - dash_cooldown_reduction)
	special_visual_timer = maxf(0.0, special_visual_timer - delta)

	hit_reaction_timer = maxf(0.0, hit_reaction_timer - delta)
	reaction_time += delta
	_update_reload(delta)
	queue_redraw()


func _physics_process(delta: float) -> void:
	var direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	if direction != Vector2.ZERO:
		facing_direction = direction

	if dash_timer > 0.0:
		dash_timer = maxf(0.0, dash_timer - delta)
		if afterburn_enabled:
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if not is_instance_valid(enemy) or not enemy is Node2D or enemy.get("is_dying") == true:
					continue
				var enemy_id: int = enemy.get_instance_id()
				if not afterburn_hit_ids.has(enemy_id) and enemy.global_position.distance_to(global_position) <= 48.0 and enemy.has_method("take_damage"):
					afterburn_hit_ids[enemy_id] = true
					enemy.take_damage(1, dash_direction)
		velocity = dash_velocity
		move_and_slide()
		_keep_inside_arena()
		return

	var normal_velocity := direction * move_speed * (1.0 + movement_speed_bonus)

	# While being knocked back, reduce normal movement
	# so the impact is actually visible and felt.
	if knockback_velocity.length() > 10.0:
		velocity = normal_velocity * 0.30 + knockback_velocity
	else:
		velocity = normal_velocity

	knockback_velocity = knockback_velocity.move_toward(
		Vector2.ZERO,
		900.0 * delta
	)

	move_and_slide()
	_keep_inside_arena()


func _keep_inside_arena() -> void:
	# The floor is a diamond with approximate outer points at
	# (+/-1000, 0) and (0, +/-500). Keep the whole cauldron inside it.
	var relative_position := global_position
	var horizontal_limit: float = 978.0
	var vertical_limit: float = 478.0
	var normalized_distance: float = (
		absf(relative_position.x) / horizontal_limit
		+ absf(relative_position.y) / vertical_limit
	)
	if normalized_distance > 1.0:
		global_position = relative_position / normalized_distance


func perform_attack() -> void:
	if cooldown_timer > 0.0:
		return
	if cauldron_id == "ranged" or cauldron_id == "shotgun":
		if is_reloading:
			return
		if magazine_ammo <= 0:
			_begin_reload()
			return
		attack_direction = (get_global_mouse_position() - global_position).normalized()
		if attack_direction == Vector2.ZERO:
			return
		if cauldron_id == "ranged":
			var ranged_damage: float = 0.5 * float(attack_damage)
			if crit_chance > 0.0 and randf() < crit_chance:
				ranged_damage *= 2.0
			if ranged_triple_spread:
				for angle_degrees in [-18.0, 0.0, 18.0]:
					_spawn_cauldron_projectile(attack_direction.rotated(deg_to_rad(angle_degrees)), ranged_damage, Color("#E8B65A"), 470.0)
				magazine_ammo -= 3
			elif ranged_twin_shot:
				for side_offset in [-7.0, 7.0]:
					var twin = CAULDRON_PROJECTILE_SCRIPT.new()
					get_tree().current_scene.add_child(twin)
					twin.global_position = global_position + Vector2(0.0, -8.0) + attack_direction.orthogonal() * side_offset
					twin.setup(attack_direction, ranged_damage, 470.0, Color("#E8B65A"))
				magazine_ammo -= 2
			else:
				_spawn_cauldron_projectile(attack_direction, ranged_damage, Color("#E8B65A"), 470.0)
				magazine_ammo -= 1
			cooldown_timer = 0.16
		else:
			if overloaded_chamber and randf() < 0.05:
				for enemy in get_tree().get_nodes_in_group("enemies"):
					if is_instance_valid(enemy) and enemy is Node2D and enemy.global_position.distance_to(global_position) <= 125.0 and enemy.has_method("take_damage"):
						enemy.take_damage(3, (enemy.global_position - global_position).normalized())
				take_damage(1, -attack_direction)
			else:
				var pellet_damage: float = (0.2 * float(attack_damage)) + (1.0 if overloaded_chamber else 0.0)
				if crit_chance > 0.0 and randf() < crit_chance:
					pellet_damage *= 2.0
				for angle_degrees in [-18.0, -9.0, 0.0, 9.0, 18.0]:
					var shot_direction := attack_direction.rotated(deg_to_rad(angle_degrees))
					_spawn_cauldron_projectile(shot_direction, pellet_damage, Color("#E17B45"), 430.0, 145.0)
			magazine_ammo -= 1
			cooldown_timer = 0.22
			if overloaded_chamber:
				knockback_velocity = -attack_direction * 420.0
		attack_visual_timer = attack_animation_duration
		queue_redraw()
		if magazine_ammo <= 0:
			_begin_reload()
		return

	attack_direction = (get_global_mouse_position() - global_position).normalized()
	if attack_direction == Vector2.ZERO:
		return
	cooldown_timer = attack_cooldown
	if cauldron_id != "teal":
		attack_visual_timer = attack_animation_duration
	if cauldron_id == "teal":
		var sweep = TEAL_SWEEP_SCRIPT.new()
		get_tree().current_scene.add_child(sweep)
		sweep.z_index = z_index + 2
		sweep.global_position = global_position
		sweep.setup(attack_direction, float(attack_damage))
		queue_redraw()
		return

	var damage_amount: float = float(attack_damage)
	if cauldron_id == "broken":
		damage_amount = float(attack_damage + 1)
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.get("is_dying") == true:
			continue
		var target_position: Vector2 = enemy.global_position
		if enemy.has_method("get_attack_target_position"):
			target_position = enemy.get_attack_target_position(global_position)
		var to_enemy: Vector2 = target_position - global_position
		if to_enemy.length_squared() < 0.001:
			to_enemy = enemy.global_position - global_position
		if to_enemy.length() > attack_range:
			continue
		var angle := absf(attack_direction.angle_to(to_enemy.normalized()))
		if angle <= deg_to_rad(attack_angle):
			_damage_enemy_and_charge(enemy, damage_amount, attack_direction)


func _damage_enemy_and_charge(enemy: Node, damage: float, direction: Vector2) -> void:
	if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
		return
	var health_before: float = float(enemy.get("health"))
	var final_damage: float = damage
	if crit_chance > 0.0 and randf() < crit_chance:
		final_damage *= 2.0
	enemy.take_damage(final_damage, direction)
	var health_after: float = float(enemy.get("health"))
	if health_after < health_before:
		special_charge = mini(special_charge_required, special_charge + 1)


func take_damage(
	amount: int,
	knockback_direction: Vector2 = Vector2.ZERO
) -> void:
	if invulnerability_timer > 0.0 or health <= 0:
		return

	health = maxi(0, health - amount * 2)
	invulnerability_timer = 0.65 + ember_shield_bonus

	stats_changed.emit(fire_fragments, health)

	if knockback_direction != Vector2.ZERO:
		apply_knockback(knockback_direction, knockback_strength)

	if health <= 0:
		health = 0
		print("Player defeated!")
		player_died.emit()


# Used when the player takes actual damage.
func apply_knockback(direction: Vector2, strength: float) -> void:
	if direction == Vector2.ZERO:
		return

	knockback_velocity = direction.normalized() * strength
	play_hit_reaction(1.0)


# Used for physical contact. No damage.
func apply_contact_knockback(direction: Vector2, strength: float) -> void:
	if direction == Vector2.ZERO:
		return

	knockback_velocity = direction.normalized() * strength
	play_hit_reaction(0.55)


func play_hit_reaction(intensity: float) -> void:
	hit_reaction_timer = hit_reaction_duration
	hit_reaction_strength = intensity


func apply_run_buff(buff_id: String) -> void:
	run_buffs[buff_id] = int(run_buffs.get(buff_id, 0)) + 1
	match buff_id:
		"crit":
			crit_chance = minf(0.60, crit_chance + 0.20)
		"extra_dash":
			dash_charge_max += 1
			dash_charges += 1
		"dash_cooldown":
			dash_cooldown_reduction += 0.2
		"movement":
			movement_speed_bonus += 0.08
		"burst_charge":
			special_charge_required = maxi(1, special_charge_required - 2)
			special_charge = mini(special_charge, special_charge_required)
		"overloaded":
			overloaded_chamber = true
			magazine_size = 1
			magazine_ammo = mini(magazine_ammo, 1)
		"triple_spread":
			ranged_triple_spread = true
		"twin_shot":
			ranged_twin_shot = true
		"combustion":
			pass
		"ember_shield":
			ember_shield_bonus += 0.35
		"afterburn":
			afterburn_enabled = true
		"volatile":
			volatile_flame_bonus += 1
		"double_drop":
			double_drop_chance = 0.15
		"soul_conversion":
			soul_conversion_enabled = true
		"magnet":
			pickup_magnet_enabled = true
		"kindling":
			health = mini(max_health, health + 4)
	queue_redraw()
	stats_changed.emit(fire_fragments, health)


func notify_enemy_killed(enemy_position: Vector2) -> void:
	if int(run_buffs.get("combustion", 0)) <= 0:
		return
	combustion_kill_counter += 1
	if combustion_kill_counter >= 5:
		combustion_kill_counter = 0
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy) and enemy is Node2D and enemy.global_position.distance_to(enemy_position) <= 105.0 and enemy.has_method("take_damage"):
				enemy.take_damage(1, (enemy.global_position - enemy_position).normalized())


func get_run_buff_count(buff_id: String) -> int:
	return int(run_buffs.get(buff_id, 0))


func collect_fire_fragment(amount: int) -> void:
	if soul_conversion_enabled and health < max_health:
		soul_conversion_quarters += amount
		if soul_conversion_quarters >= 2:
			soul_conversion_quarters -= 2
			health = mini(max_health, health + 1)
		stats_changed.emit(fire_fragments, health)
		return
	fire_fragments += amount
	GameData.add_fire_fragments(amount)
	stats_changed.emit(fire_fragments, health)


func heal_half_heart() -> void:
	if health <= 0 or health >= max_health:
		return

	health = mini(max_health, health + 1)
	stats_changed.emit(fire_fragments, health)


# Creates a curved blade.
# Beginning = thin.
# Ending = thick.
func make_sword_slash(
	center_angle: float,
	arc_width: float,
	radius: float,
	maximum_thickness: float,
	sample_count: int
) -> PackedVector2Array:

	var polygon := PackedVector2Array()

	for i in range(sample_count + 1):
		var t: float = float(i) / float(sample_count)

		var angle: float = (
			center_angle - arc_width * 0.5
			+ arc_width * t
		)

		var thickness: float = maximum_thickness * pow(t, 1.5)
		var outer_radius: float = radius + thickness * 0.5
		var point: Vector2 = Vector2.RIGHT.rotated(angle) * outer_radius

		polygon.append(point)

	for i in range(sample_count, -1, -1):
		var t: float = float(i) / float(sample_count)

		var angle: float = (
			center_angle - arc_width * 0.5
			+ arc_width * t
		)

		var thickness: float = maximum_thickness * pow(t, 1.5)
		var inner_radius: float = radius - thickness * 0.5
		var point: Vector2 = Vector2.RIGHT.rotated(angle) * inner_radius

		polygon.append(point)

	return polygon


func _draw() -> void:

	# --------------------------------
	# SWORD SWING
	# --------------------------------

	if attack_visual_timer > 0.0 and cauldron_id != "ranged" and cauldron_id != "shotgun" and cauldron_id != "teal":
		var progress: float = 1.0 - (
			attack_visual_timer / attack_animation_duration
		)

		var swing_arc: float = deg_to_rad(100.0)

		var swing_offset: float = lerpf(
			-swing_arc * 0.5,
			swing_arc * 0.5,
			progress
		)

		var center_angle: float = (
			attack_direction.angle() + swing_offset
		)

		var slash_alpha: float = 1.0 - progress * 0.3

		var glow := make_sword_slash(
			center_angle, deg_to_rad(65.0), 39.0, 32.0, 32
		)

		draw_colored_polygon(
			glow,
			Color(1.0, 0.20, 0.015, slash_alpha * 0.3)
		)

		var blade := make_sword_slash(
			center_angle, deg_to_rad(65.0), 39.0, 24.0, 32
		)

		draw_colored_polygon(
			blade,
			Color(1.0, 0.43, 0.055, slash_alpha)
		)

		var highlight := make_sword_slash(
			center_angle, deg_to_rad(65.0), 39.0, 10.0, 32
		)

		draw_colored_polygon(
			highlight,
			Color(1.0, 0.86, 0.48, slash_alpha)
		)

	# --------------------------------
	# DASH / INVULNERABILITY EFFECT
	# --------------------------------

	if dash_timer > 0.0:
		var dash_progress: float = 1.0 - (dash_timer / dash_duration)
		var dash_strength: float = sin(dash_progress * PI)
		var dash_fade: float = clampf(dash_timer / dash_duration, 0.0, 1.0)

		# Bright motion streaks behind the cauldron.
		var trail_direction: Vector2 = -dash_direction
		var trail_side: Vector2 = dash_direction.orthogonal()
		for i in range(3):
			var trail_offset: float = 15.0 + float(i) * 9.0
			var side_offset: float = (float(i) - 1.0) * 8.0
			var trail_start: Vector2 = trail_direction * trail_offset + trail_side * side_offset
			var trail_end: Vector2 = trail_start + trail_direction * (17.0 + dash_strength * 9.0)
			draw_line(
				trail_start,
				trail_end,
				Color(0.45, 0.95, 1.0, 0.68 * dash_fade),
				3.0 - float(i) * 0.45,
				true
			)

		# A clear protective halo surrounds the whole cauldron while invincible.
		draw_circle(
			Vector2.ZERO,
			31.0 + dash_strength * 4.0,
			Color(0.20, 0.82, 1.0, 0.12 * dash_fade)
		)
		draw_arc(
			Vector2.ZERO,
			30.0 + dash_strength * 4.0,
			0.0,
			TAU,
			48,
			Color(0.55, 0.96, 1.0, 0.95 * dash_fade),
			3.0,
			true
		)
		draw_arc(
			Vector2.ZERO,
			36.0 + dash_strength * 5.0,
			dash_direction.angle() - 1.9,
			dash_direction.angle() + 1.9,
			32,
			Color(1.0, 0.88, 0.48, 0.9 * dash_fade),
			2.5,
			true
		)

		# Small bright sparks orbit the dash path.
		for i in range(6):
			var angle: float = TAU * float(i) / 6.0 + dash_progress * 1.8
			var spark_direction: Vector2 = Vector2.RIGHT.rotated(angle)
			var spark_position: Vector2 = spark_direction * (34.0 + dash_strength * 5.0)
			draw_circle(
				spark_position,
				2.0 + dash_strength,
				Color(0.72, 1.0, 1.0, 0.9 * dash_fade)
			)

	# --------------------------------
	# SPECIAL FIRE BURST
	# --------------------------------

	if special_visual_timer > 0.0:
		var progress: float = 1.0 - (
			special_visual_timer / SPECIAL_VISUAL_DURATION
		)
		var radius: float = lerpf(25.0, special_radius, progress)
		var alpha: float = 1.0 - progress

		draw_circle(
			Vector2.ZERO,
			radius,
			Color(1.0, 0.38, 0.06, alpha * 0.10)
		)
		draw_arc(
			Vector2.ZERO,
			radius,
			0.0,
			TAU,
			64,
			Color(1.0, 0.58, 0.12, alpha),
			7.0
		)
		draw_arc(
			Vector2.ZERO,
			radius * 0.82,
			0.0,
			TAU,
			64,
			Color(1.0, 0.88, 0.48, alpha * 0.8),
			3.0
		)

		for i in range(8):
			var angle: float = TAU * float(i) / 8.0
			var direction: Vector2 = Vector2.RIGHT.rotated(angle)
			draw_line(
				direction * (radius * 0.72),
				direction * radius,
				Color(1.0, 0.72, 0.25, alpha),
				4.0
			)

	# --------------------------------
	# CAULDRON REACTION
	# --------------------------------

	var reaction_progress: float = 0.0

	if hit_reaction_timer > 0.0:
		reaction_progress = hit_reaction_timer / hit_reaction_duration

	var shake: float = sin(reaction_time * 65.0) * 3.0
	var reaction_offset := Vector2.ZERO
	var reaction_rotation: float = 0.0
	var reaction_scale := Vector2.ONE

	if reaction_progress > 0.0:
		var intensity: float = hit_reaction_strength * reaction_progress

		reaction_offset.x = shake * intensity
		reaction_rotation = sin(reaction_time * 55.0) * 0.09 * intensity

		reaction_scale.x = 1.0 + 0.12 * intensity
		reaction_scale.y = 1.0 - 0.14 * intensity

	draw_set_transform(
		reaction_offset,
		reaction_rotation,
		reaction_scale
	)

	# --------------------------------
	# CAULDRON BODY
	# --------------------------------

	draw_ellipse(
		Vector2(0, 13),
		23.0,
		10.0,
		Color(0.08, 0.07, 0.09, 0.35)
	)

	var body := PackedVector2Array()
	if cauldron_id == "thinner":
		body = PackedVector2Array([
			Vector2(-15, -8), Vector2(15, -8),
			Vector2(13, 14), Vector2(8, 22),
			Vector2(-8, 22), Vector2(-13, 14)
		])
	elif cauldron_id == "shotgun":
		body = PackedVector2Array([
			Vector2(-22, -8), Vector2(22, -8),
			Vector2(19, 15), Vector2(12, 23),
			Vector2(-12, 23), Vector2(-19, 15)
		])
	else:
		body = PackedVector2Array([
			Vector2(-20, -8), Vector2(20, -8),
			Vector2(17, 15), Vector2(10, 22),
			Vector2(-10, 22), Vector2(-17, 15)
		])

	var pot_body_color := Color("#343B42")
	match cauldron_id:
		"spiky":
			pot_body_color = Color("#48434A")
		"ranged":
			pot_body_color = Color("#51483D")
		"teal":
			pot_body_color = Color("#31534F")
		"shotgun":
			pot_body_color = Color("#51443B")
		"broken":
			pot_body_color = Color("#4A4147")
	if GameData.selected_skin == "copper" and cauldron_id == "default":
		pot_body_color = Color("#8B5638")
	draw_colored_polygon(body, pot_body_color)

	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-22, -10),
			Vector2(22, -10),
			Vector2(19, -4),
			Vector2(-19, -4)
		]),
		Color("#69747C")
	)

	var rim_color := Color("#F59E42")
	if GameData.selected_skin == "copper":
		rim_color = Color("#E9A16B")

	if dash_timer > 0.0:
		var dash_glow: float = sin((1.0 - dash_timer / dash_duration) * PI)
		rim_color = rim_color.lerp(Color("#A8F7FF"), 0.82 + dash_glow * 0.18)

	if reaction_progress > 0.0:
		rim_color = Color("#FFD078").lerp(
			Color("#FF6B35"),
			reaction_progress * hit_reaction_strength
		)

	draw_ellipse(
		Vector2(0, -8),
		17.0,
		5.0,
		rim_color
	)

	draw_circle(Vector2(-5, -9), 3.0, Color("#FFD77A"))
	draw_circle(Vector2(6, -10), 2.0, Color("#FFF0AE"))

	draw_circle(Vector2(-20, 2), 5.0, Color("#8B969D"))
	draw_circle(Vector2(20, 2), 5.0, Color("#8B969D"))

	match cauldron_id:
		"spiky":
			# Heavy iron spikes around the rim and lower sides.
			for side in [-1.0, 1.0]:
				for i in range(3):
					var spike_y := -3.0 + float(i) * 9.0
					draw_colored_polygon(PackedVector2Array([
						Vector2(side * 16.0, spike_y - 5.0),
						Vector2(side * 31.0, spike_y),
						Vector2(side * 16.0, spike_y + 5.0)
					]), Color("#D7D0C8"))
				draw_line(Vector2(side * 17.0, -7.0), Vector2(side * 23.0, 12.0), Color("#8C9298"), 2.0)
		"ranged":
			# A raised brass sight and forward-facing arcane barrel.
			draw_rect(Rect2(-7.0, -25.0, 14.0, 19.0), Color("#252B31"))
			draw_rect(Rect2(-4.0, -28.0, 8.0, 13.0), Color("#A77A43"))
			draw_circle(Vector2(0.0, -25.0), 5.0, Color("#FFE08A"))
			draw_circle(Vector2(0.0, -25.0), 2.5, Color("#FFF6D1"))
		"teal":
			# Glassy core, bright runes and a floating teal crown.
			draw_arc(Vector2.ZERO, 26.0, PI, TAU, 24, Color("#69F4E2"), 2.0)
			for i in range(3):
				var orbit_angle := TAU * float(i) / 3.0 + reaction_time * 1.5
				draw_circle(Vector2.RIGHT.rotated(orbit_angle) * 31.0, 4.5, Color("#55DCCB"))
			draw_circle(Vector2(0.0, -29.0), 4.0, Color("#8FFFF0"))
			draw_line(Vector2(-9.0, 5.0), Vector2(-5.0, 15.0), Color("#6BE9D9"), 2.0)
			draw_line(Vector2(9.0, 5.0), Vector2(5.0, 15.0), Color("#6BE9D9"), 2.0)
		"shotgun":
			# Broad reinforced body with two unmistakable double-barrel muzzles.
			draw_rect(Rect2(-16.0, -27.0, 10.0, 20.0), Color("#51473D"))
			draw_rect(Rect2(6.0, -27.0, 10.0, 20.0), Color("#51473D"))
			draw_rect(Rect2(-14.0, -29.0, 6.0, 15.0), Color("#D4A36B"))
			draw_rect(Rect2(8.0, -29.0, 6.0, 15.0), Color("#D4A36B"))
			draw_circle(Vector2(-11.0, -29.0), 3.0, Color("#24282D"))
			draw_circle(Vector2(11.0, -29.0), 3.0, Color("#24282D"))
			draw_line(Vector2(-19.0, 5.0), Vector2(19.0, 5.0), Color("#B18A5F"), 3.0)
		"thinner":
			# Slim profile, twin side fins and a visible second-dash charge.
			draw_line(Vector2(-16.0, -3.0), Vector2(-23.0, 11.0), Color("#A7D8E2"), 3.0)
			draw_line(Vector2(16.0, -3.0), Vector2(23.0, 11.0), Color("#A7D8E2"), 3.0)
			for i in range(dash_charges):
				draw_circle(Vector2(-5.0 + float(i) * 10.0, -19.0), 3.5, Color("#A8F4FF"))
		"broken":
			draw_polyline(PackedVector2Array([
				Vector2(5.0, -8.0), Vector2(-1.0, 1.0),
				Vector2(6.0, 7.0), Vector2(1.0, 17.0)
			]), Color("#F1D9C6"), 2.5)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-20.0, -8.0), Vector2(-13.0, -8.0),
				Vector2(-17.0, -2.0)
			]), Color("#20252A"))
			draw_line(Vector2(-13.0, 13.0), Vector2(-5.0, 19.0), Color("#D9C6B9"), 2.0)

	draw_polyline(
		PackedVector2Array([
			Vector2(-20, -8),
			Vector2(-17, 15),
			Vector2(-10, 22),
			Vector2(10, 22),
			Vector2(17, 15),
			Vector2(20, -8)
		]),
		Color("#171C22"),
		2.0
	)

	draw_circle(
		facing_direction * 27.0,
		3.0,
		Color("#FFE49A")
	)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
