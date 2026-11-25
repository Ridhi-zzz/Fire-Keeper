extends CharacterBody2D

const LANTERN_PROJECTILE_SCRIPT = preload("res://scripts/lantern_projectile.gd")
const HEALTH_PICKUP_SCRIPT = preload("res://scripts/health_pickup.gd")
const FIRE_FRAGMENT_SCRIPT = preload("res://scripts/fire_fragment.gd")

enum LanternType {
	MELEE,
	RANGED
}

@export var lantern_type: LanternType = LanternType.MELEE
@export var move_speed: float = 68.0
@export var max_health: int = 4
@export var attack_damage: int = 1
@export var melee_notice_distance: float = 118.0
@export var melee_attack_range: float = 94.0
@export var ranged_notice_distance: float = 310.0
@export var ranged_keep_distance: float = 190.0
@export var attack_cooldown: float = 2.0
@export var attack_windup: float = 0.62

var health: float = 4.0
var target: Node2D = null
var training_dummy: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO
var animation_time: float = 0.0
var cooldown_timer: float = 1.0
var windup_timer: float = 0.0
var is_winding_up: bool = false
var attack_direction: Vector2 = Vector2.DOWN
var attack_visual_timer: float = 0.0
var hit_flash_timer: float = 0.0
var hit_reaction_timer: float = 0.0
var hit_reaction_duration: float = 0.19
var hit_reaction_direction: Vector2 = Vector2.ZERO

# Ranged lanterns use a short evasive dash when the player rushes them.
var dodge_timer: float = 0.0
var dodge_cooldown_timer: float = 0.0
var dodge_duration: float = 0.18
var dodge_cooldown: float = 2.2
var dodge_speed: float = 390.0
var dodge_direction: Vector2 = Vector2.ZERO

var is_dying: bool = false
var death_timer: float = 0.0
var attack_has_resolved: bool = false
var boss_summon_owner: Node2D = null
var boss_summon_notified: bool = false
var boss_summon_guaranteed_health_drop: bool = false


func _ready() -> void:
	health = max_health
	add_to_group("enemies")

	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 18.0
	collision.shape = shape
	add_child(collision)


func set_target(new_target: Node2D) -> void:
	target = new_target


func _process(delta: float) -> void:
	animation_time += delta
	hit_flash_timer = maxf(0.0, hit_flash_timer - delta)
	hit_reaction_timer = maxf(0.0, hit_reaction_timer - delta)
	attack_visual_timer = maxf(0.0, attack_visual_timer - delta)

	if is_dying:
		death_timer -= delta
		var fade := clampf(death_timer / 0.42, 0.0, 1.0)
		modulate.a = fade
		scale = Vector2.ONE * (0.72 + fade * 0.28)
		if death_timer <= 0.0:
			queue_free()

	queue_redraw()


func _physics_process(delta: float) -> void:
	if is_dying:
		velocity = Vector2.ZERO
		return

	cooldown_timer = maxf(0.0, cooldown_timer - delta)
	dodge_cooldown_timer = maxf(0.0, dodge_cooldown_timer - delta)
	var movement := Vector2.ZERO
	var distance := INF
	var toward := Vector2.ZERO

	if is_instance_valid(target):
		var to_target := target.global_position - global_position
		distance = to_target.length()
		toward = to_target.normalized()

	# Evasive movement is only for the ranged lantern. It does not interrupt
	# an attack wind-up, so it can still complete its three-shot volley.
	if lantern_type == LanternType.RANGED and not is_winding_up and dodge_timer <= 0.0:
		if distance < 112.0 and dodge_cooldown_timer <= 0.0:
			_start_ranged_dodge(toward)

	if dodge_timer > 0.0:
		dodge_timer = maxf(0.0, dodge_timer - delta)
		movement = dodge_direction * dodge_speed
	elif is_instance_valid(target):
		if is_winding_up:
			velocity = Vector2.ZERO
			windup_timer -= delta
			if windup_timer <= 0.0:
				if lantern_type == LanternType.MELEE:
					perform_melee_attack()
				else:
					perform_ranged_attack()
		elif cooldown_timer <= 0.0:
			if lantern_type == LanternType.MELEE:
				if distance <= melee_notice_distance:
					begin_attack(toward)
			else:
				# No minimum-distance restriction: if the player gets close,
				# the ranged lantern still gets to fire instead of going passive.
				if distance <= ranged_notice_distance:
					begin_attack(toward)

		if not is_winding_up:
			if lantern_type == LanternType.MELEE:
				if distance > melee_attack_range * 0.72:
					movement = toward * move_speed
			else:
				if distance > ranged_keep_distance + 18.0:
					movement = toward * move_speed
				elif distance < ranged_keep_distance - 25.0:
					movement = -toward * move_speed * 0.8

	if training_dummy:
		movement = Vector2.ZERO
		dodge_timer = 0.0
	velocity = movement + knockback_velocity
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 560.0 * delta)
	move_and_slide()
	_keep_inside_arena()


func _start_ranged_dodge(player_direction: Vector2) -> void:
	if player_direction == Vector2.ZERO:
		return

	var side := -1.0 if randf() < 0.5 else 1.0
	dodge_direction = (-player_direction + player_direction.orthogonal() * side * 0.6).normalized()
	dodge_timer = dodge_duration
	dodge_cooldown_timer = dodge_cooldown
	velocity = dodge_direction * dodge_speed


func _keep_inside_arena() -> void:
	var p := global_position
	var normalized_distance := absf(p.x) / 978.0 + absf(p.y) / 478.0
	if normalized_distance > 1.0:
		global_position = p / normalized_distance


func begin_attack(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	attack_direction = direction.normalized()
	is_winding_up = true
	attack_has_resolved = false
	windup_timer = attack_windup
	velocity = Vector2.ZERO


func perform_melee_attack() -> void:
	is_winding_up = false
	cooldown_timer = attack_cooldown
	attack_visual_timer = 0.42
	attack_has_resolved = true

	if not is_instance_valid(target):
		return

	var offset := target.global_position - global_position
	if offset.length() > melee_attack_range:
		return

	var angle := absf(attack_direction.angle_to(offset.normalized()))
	# The lantern sweeps a broad 110-degree quadrant in front of itself.
	if angle <= deg_to_rad(55.0) and target.has_method("take_damage"):
		target.take_damage(attack_damage, attack_direction)
		if target.has_method("_on_melee_enemy_hit"):
			target._on_melee_enemy_hit(self)


func perform_ranged_attack() -> void:
	is_winding_up = false
	cooldown_timer = attack_cooldown
	attack_visual_timer = 0.30

	if not is_instance_valid(target):
		return

	# The middle shot is aimed once at the player's current position.
	# The two outer shots are fixed offsets, forming a three-shot cone.
	var centre_direction := (target.global_position - global_position).normalized()
	for angle_degrees in [-20.0, 0.0, 20.0]:
		var shot_direction := centre_direction.rotated(deg_to_rad(angle_degrees))
		var projectile = LANTERN_PROJECTILE_SCRIPT.new()
		get_tree().current_scene.add_child(projectile)
		projectile.global_position = global_position + Vector2(0.0, -9.0)
		projectile.setup(target, attack_damage, 245.0, shot_direction)


func take_damage(amount: float, knockback_direction: Vector2 = Vector2.ZERO) -> void:
	if is_dying:
		return

	health -= amount
	hit_flash_timer = 0.24
	hit_reaction_timer = hit_reaction_duration
	hit_reaction_direction = knockback_direction.normalized()
	knockback_velocity = knockback_direction.normalized() * 260.0

	if health <= 0:
		die()
	else:
		queue_redraw()


func die() -> void:
	if is_dying:
		return
	is_dying = true

	# Boss-summoned lanterns notify the Warden so it knows when all four
	# adds are defeated and projectile volleys can resume.
	if is_instance_valid(boss_summon_owner) and not boss_summon_notified:
		boss_summon_notified = true
		if boss_summon_owner.has_method("on_summon_defeated"):
			boss_summon_owner.on_summon_defeated(global_position)

	is_winding_up = false
	death_timer = 0.42
	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO

	var collision := get_node_or_null("CollisionShape2D")
	if collision is CollisionShape2D:
		collision.set_deferred("disabled", true)

	# Both lantern variants always drop two Fire Fragments.
	for fragment_index in range(2):
		var fragment = FIRE_FRAGMENT_SCRIPT.new()
		get_tree().current_scene.add_child(fragment)
		fragment.global_position = global_position + Vector2(randf_range(-12.0, 12.0), -8.0 + randf_range(-5.0, 5.0))

	var players_for_kills := get_tree().get_nodes_in_group("players")
	if not players_for_kills.is_empty() and is_instance_valid(players_for_kills[0]):
		if players_for_kills[0].has_method("notify_enemy_killed"):
			players_for_kills[0].notify_enemy_killed(global_position)

	# Double Trouble can double normal enemy currency drops.
	var players_for_drops := get_tree().get_nodes_in_group("players")
	if not players_for_drops.is_empty() and is_instance_valid(players_for_drops[0]):
		var drop_player = players_for_drops[0]
		if randf() < float(drop_player.get("double_drop_chance")):
			for fragment_index in range(2):
				var bonus_fragment = FIRE_FRAGMENT_SCRIPT.new()
				get_tree().current_scene.add_child(bonus_fragment)
				bonus_fragment.global_position = global_position + Vector2(randf_range(-18.0, 18.0), randf_range(-15.0, 5.0))

	# Guaranteed summon drops remain; Broken Cauldron adds a 35% chance
	# for every other enemy type, including these lanterns.
	var broken_equipped := false
	var players := get_tree().get_nodes_in_group("players")
	if not players.is_empty() and is_instance_valid(players[0]):
		broken_equipped = str(players[0].get("cauldron_id")) == "broken"
	var should_drop := boss_summon_guaranteed_health_drop
	if not should_drop and is_instance_valid(boss_summon_owner):
		should_drop = randf() < 0.35
	elif not should_drop and broken_equipped:
		should_drop = randf() < 0.35
	if should_drop:
		var health_pickup = HEALTH_PICKUP_SCRIPT.new()
		get_tree().current_scene.add_child(health_pickup)
		health_pickup.global_position = global_position + Vector2(0.0, -8.0)


func _draw() -> void:
	if is_dying:
		var progress := 1.0 - clampf(death_timer / 0.42, 0.0, 1.0)
		var flame_color := Color("#48E5D0") if lantern_type == LanternType.MELEE else Color("#B77BFF")
		for i in range(7):
			var angle := TAU * float(i) / 7.0
			var ember_pos := Vector2.RIGHT.rotated(angle) * progress * 26.0 + Vector2(0, -12)
			draw_circle(ember_pos, 3.0 * (1.0 - progress), flame_color)
		return

	var teal := lantern_type == LanternType.MELEE
	var flame_outer := Color("#43DCCB") if teal else Color("#A66BFF")
	var flame_inner := Color("#C6FFF4") if teal else Color("#E6CFFF")
	var glass_color := Color("#164E4B") if teal else Color("#38204F")
	var glass_highlight := Color("#4CE5D4") if teal else Color("#B47AFF")
	var metal_color := Color("#52636A")
	var metal_light := Color("#AAB8B8")
	var frame_glow := Color("#5AF0DB") if teal else Color("#C18BFF")

	var bob := sin(animation_time * 2.8) * 1.8
	var flicker := sin(animation_time * 13.0) * 1.5 + cos(animation_time * 19.0) * 0.8
	var flame_lift := 0.0
	var body_lean := 0.0
	var hit_progress := 0.0
	var dodge_progress := 0.0
	if lantern_type == LanternType.RANGED and dodge_timer > 0.0:
		dodge_progress = 1.0 - dodge_timer / dodge_duration
		body_lean = -dodge_direction.x * 0.24
		flame_lift = 5.0 + sin(dodge_progress * PI) * 3.0
	if hit_reaction_timer > 0.0:
		var elapsed := 1.0 - hit_reaction_timer / hit_reaction_duration
		hit_progress = sin(elapsed * PI)
		# A quick impact dip and rebound, matching the Candle's squash response.
		bob -= hit_progress * 3.0
		body_lean = -hit_reaction_direction.x * hit_progress * 0.10
		flame_lift += hit_progress * 4.0
	if is_winding_up:
		var windup_progress := 1.0 - clampf(windup_timer / attack_windup, 0.0, 1.0)
		# The lantern visibly braces: its body dips while the flame gathers.
		flame_lift = 3.0 + windup_progress * 8.0 + sin(animation_time * 22.0) * 1.5
		body_lean = sin(windup_progress * PI) * clampf(attack_direction.x, -1.0, 1.0) * -0.16
	elif lantern_type == LanternType.MELEE and attack_visual_timer > 0.0:
		var strike_progress := 1.0 - attack_visual_timer / 0.42
		# A quick forward snap gives the lantern its own attack animation.
		body_lean = sin(strike_progress * PI) * clampf(attack_direction.x, -1.0, 1.0) * 0.24
		flame_lift = sin(strike_progress * PI) * 10.0

	draw_circle(Vector2(0, 13), 22.0, Color(0.0, 0.0, 0.0, 0.28))

	var impact_scale := Vector2(
		1.0 + hit_progress * 0.10,
		1.0 - hit_progress * 0.16
	)
	var dodge_scale := Vector2(1.0 + dodge_progress * 0.05, 1.0 - dodge_progress * 0.08)
	draw_set_transform(Vector2(0, bob), body_lean, impact_scale * dodge_scale)

	# Hanging loop and top cap.
	draw_arc(Vector2(0, -25), 8.0, PI, TAU, 24, metal_light, 3.0)
	draw_rect(Rect2(-10, -23, 20, 5), metal_color)
	draw_rect(Rect2(-8, -24, 16, 2), metal_light)

	# Warm/cool glass chamber.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -19), Vector2(13, -19), Vector2(16, -10),
		Vector2(14, 13), Vector2(9, 19), Vector2(-9, 19),
		Vector2(-14, 13), Vector2(-16, -10)
	]), glass_color)

	draw_colored_polygon(PackedVector2Array([
		Vector2(-9, -12), Vector2(0, -16), Vector2(9, -12),
		Vector2(11, 9), Vector2(6, 14), Vector2(-7, 14),
		Vector2(-11, 8)
	]), Color(glass_highlight.r, glass_highlight.g, glass_highlight.b, 0.22))

	# Metal frame: four uprights and decorative bands.
	for x in [-15.0, 15.0]:
		draw_line(Vector2(x, -17), Vector2(x * 0.88, 17), metal_light, 3.0)
	draw_line(Vector2(-15, -17), Vector2(15, -17), metal_light, 3.0)
	draw_line(Vector2(-15, 16), Vector2(15, 16), metal_color, 4.0)
	draw_line(Vector2(-12, -5), Vector2(12, -5), metal_color, 2.0)

	# Small feet and side rivets.
	for x in [-11.0, 11.0]:
		draw_circle(Vector2(x, 4), 2.0, metal_light)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x * 0.75, 16), Vector2(x * 1.25, 16),
			Vector2(x * 1.35, 23), Vector2(x * 0.65, 23)
		]), metal_color)

	# Floating flame visible through the glass.
	draw_circle(Vector2(0, 3), 10.0 + flicker * 0.2, Color(flame_outer.r, flame_outer.g, flame_outer.b, 0.18))
	draw_colored_polygon(PackedVector2Array([
		Vector2(flicker * 0.35, -23 - absf(flicker) - flame_lift),
		Vector2(8, -10), Vector2(7, 1), Vector2(0, 8),
		Vector2(-7, 1), Vector2(-8, -10)
	]), flame_outer)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -18 - flame_lift * 0.5), Vector2(4, -8),
		Vector2(0, 1), Vector2(-4, -8)
	]), flame_inner)

	# Cute face, softly lit from within.
	var eye_color := Color("#E9FFF9") if teal else Color("#F7E9FF")
	if hit_flash_timer > 0.0:
		draw_circle(Vector2.ZERO, 22.0, Color(1.0, 1.0, 1.0, 0.35))
	draw_circle(Vector2(-5, 5), 1.8, eye_color)
	draw_circle(Vector2(5, 5), 1.8, eye_color)
	draw_arc(Vector2(0, 8), 3.0, 0.2, PI - 0.2, 12, eye_color, 1.2)

	# Attack telegraph: a glowing arc charges around the front.
	if is_winding_up:
		var base_angle := attack_direction.angle()
		var charge := 1.0 - windup_timer / attack_windup
		if lantern_type == LanternType.MELEE:
			# Melee lantern communicates its wind-up through its body and flame animation.
			pass
		else:
			for offset in [-20.0, 0.0, 20.0]:
				var shot_angle := base_angle + deg_to_rad(offset)
				var ray := Vector2.RIGHT.rotated(shot_angle)
				draw_line(ray * 24.0, ray * (44.0 + charge * 16.0), Color("#E8C8FF", 0.75), 2.5)

	# Straight teal firebar: four fireballs linked in one line, rotating from
	# the lantern like the classic rotating fireball obstacle.
	if lantern_type == LanternType.MELEE and attack_visual_timer > 0.0:
		var progress := 1.0 - attack_visual_timer / 0.42
		var base_angle := attack_direction.angle()
		# Rotate the entire straight chain through the frontal attack quadrant.
		var rotation_angle := lerpf(-deg_to_rad(82.0), deg_to_rad(82.0), progress)
		var chain_angle := base_angle + rotation_angle
		var direction := Vector2.RIGHT.rotated(chain_angle)
		var chain_start := 24.0
		var spacing := 19.0
		var fireball_count := 4
		var chain_end := chain_start + spacing * float(fireball_count - 1)

		# The connector is a straight, tapered teal energy line behind the fireballs.
		draw_line(
			direction * chain_start,
			direction * chain_end,
			Color("#35DCCB", 0.48),
			11.0,
			true
		)
		draw_line(
			direction * chain_start,
			direction * chain_end,
			Color("#A8FFF4", 0.8),
			4.0,
			true
		)

		for i in range(fireball_count):
			var point := direction * (chain_start + spacing * float(i))
			var size := 9.5 if i == 0 else 8.5
			draw_circle(point, size + 5.0, Color("#35DCCB", 0.18))
			draw_circle(point, size, Color("#43E6D4"))
			draw_circle(point, size * 0.52, Color("#E2FFFA"))
			# Tiny trailing sparks reinforce the sense of spinning fire.
			var tangent := Vector2(-direction.y, direction.x)
			draw_circle(point - tangent * 5.0, 2.2, Color("#B9FFF6", 0.7))

	# Impact sparks, in the same brief radial style used by the Candle Golem.
	if hit_flash_timer > 0.0:
		var flash_strength := hit_flash_timer / 0.24
		var spark_color := Color("#9BFFF2") if teal else Color("#E0C4FF")
		for i in range(8):
			var angle := TAU * float(i) / 8.0
			var direction := Vector2.RIGHT.rotated(angle)
			draw_line(
				direction * 20.0,
				direction * (27.0 + 5.0 * flash_strength),
				Color(spark_color.r, spark_color.g, spark_color.b, flash_strength),
				2.0
			)

	# Health pips.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in range(max_health):
		var pip_color := frame_glow if i < health else Color("#41464B")
		draw_rect(Rect2(Vector2(-10 + i * 5, -43), Vector2(3.5, 3.0)), pip_color)
