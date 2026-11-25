
extends CharacterBody2D

const FIRE_FRAGMENT_SCRIPT = preload("res://scripts/fire_fragment.gd")
const FIRE_PROJECTILE_SCRIPT = preload("res://scripts/fire_projectile.gd")
const HEALTH_PICKUP_SCRIPT = preload("res://scripts/health_pickup.gd")

enum AttackStyle {
	MELEE,
	RANGED
}

@export var attack_style: AttackStyle = AttackStyle.MELEE

@export var move_speed: float = 75.0
@export var max_health: int = 3
@export var attack_damage: int = 1

@export var attack_distance: float = 34.0
@export var ranged_attack_distance: float = 190.0
@export var ranged_keep_distance: float = 125.0

@export var attack_cooldown: float = 1.5
@export var attack_windup: float = 0.45

var health: float
var target: Node2D = null
var training_dummy: bool = false

var knockback_velocity: Vector2 = Vector2.ZERO

var flame_time: float = 0.0
var hit_flash_timer: float = 0.0
var blink_timer: float = 0.0
var blink_wait: float = 2.5

var attack_cooldown_timer: float = 0.8
var windup_timer: float = 0.0
var is_winding_up: bool = false
var attack_direction: Vector2 = Vector2.DOWN
var attack_visual_timer: float = 0.0

# Ranged candles occasionally dash away when the player gets too close.
var dodge_timer: float = 0.0
var dodge_cooldown_timer: float = 0.0
var dodge_duration: float = 0.18
var dodge_cooldown: float = 2.4
var dodge_speed: float = 360.0
var dodge_direction: Vector2 = Vector2.ZERO

var is_dying: bool = false
var death_timer: float = 0.0


func _ready() -> void:
	health = max_health
	add_to_group("enemies")

	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 13.0
	collision.shape = shape
	add_child(collision)

	blink_wait = randf_range(1.5, 4.0)


func set_target(new_target: Node2D) -> void:
	target = new_target


func _process(delta: float) -> void:
	flame_time += delta

	if is_dying:
		death_timer -= delta
		scale = Vector2.ONE * (0.7 + maxf(death_timer, 0.0) * 0.8)
		modulate.a = clampf(death_timer / 0.4, 0.0, 1.0)

		if death_timer <= 0.0:
			queue_free()

		queue_redraw()
		return

	attack_visual_timer = maxf(0.0, attack_visual_timer - delta)
	hit_flash_timer = maxf(0.0, hit_flash_timer - delta)
	hit_flash_timer = maxf(0.0, hit_flash_timer - delta)

	if blink_timer > 0.0:
		blink_timer = maxf(0.0, blink_timer - delta)
	else:
		blink_wait -= delta

		if blink_wait <= 0.0:
			blink_timer = 0.14
			blink_wait = randf_range(2.0, 4.5)

	queue_redraw()


func _physics_process(delta: float) -> void:
	if is_dying:
		velocity = Vector2.ZERO
		return

	attack_cooldown_timer = maxf(0.0, attack_cooldown_timer - delta)
	dodge_cooldown_timer = maxf(0.0, dodge_cooldown_timer - delta)

	var chase_velocity: Vector2 = Vector2.ZERO
	var player_direction: Vector2 = Vector2.ZERO
	var player_distance: float = INF

	if is_instance_valid(target):
		var to_player: Vector2 = target.global_position - global_position
		player_distance = to_player.length()
		player_direction = to_player.normalized()

	# A ranged candle makes a quick evasive dash when the player closes in.
	# It never cancels an attack that is already winding up.
	if attack_style == AttackStyle.RANGED and not is_winding_up and dodge_timer <= 0.0:
		if player_distance < 92.0 and dodge_cooldown_timer <= 0.0:
			_start_ranged_dodge(player_direction)

	if dodge_timer > 0.0:
		dodge_timer = maxf(0.0, dodge_timer - delta)
		chase_velocity = dodge_direction * dodge_speed
	elif is_instance_valid(target):
		if is_winding_up:
			windup_timer -= delta

			if windup_timer <= 0.0:
				if attack_style == AttackStyle.MELEE:
					perform_melee_attack()
				else:
					perform_ranged_attack()

		elif attack_cooldown_timer <= 0.0:
			if attack_style == AttackStyle.MELEE:
				if player_distance <= attack_distance:
					begin_attack(player_direction)
			else:
				# Keep firing even when the player gets inside preferred range.
				# The dodge creates space; it must not make the candle helpless.
				if player_distance <= ranged_attack_distance:
					begin_attack(player_direction)

		if not is_winding_up:
			if attack_style == AttackStyle.MELEE:
				if player_distance > attack_distance * 0.75:
					chase_velocity = player_direction * move_speed
			else:
				if player_distance > ranged_keep_distance + 15.0:
					chase_velocity = player_direction * move_speed
				elif player_distance < ranged_keep_distance - 15.0:
					chase_velocity = -player_direction * move_speed * 0.75

	if training_dummy:
		chase_velocity = Vector2.ZERO
		dodge_timer = 0.0
	velocity = chase_velocity + knockback_velocity

	knockback_velocity = knockback_velocity.move_toward(
		Vector2.ZERO,
		550.0 * delta
	)

	move_and_slide()
	_keep_inside_arena()


func _start_ranged_dodge(player_direction: Vector2) -> void:
	if player_direction == Vector2.ZERO:
		return

	# Mostly retreat, with a sideways angle so the dash is readable and
	# doesn't simply retrace the same line every time.
	var side := -1.0 if randf() < 0.5 else 1.0
	dodge_direction = (-player_direction + player_direction.orthogonal() * side * 0.55).normalized()
	dodge_timer = dodge_duration
	dodge_cooldown_timer = dodge_cooldown
	velocity = dodge_direction * dodge_speed


func _keep_inside_arena() -> void:
	# Keep the candle's full body inside the diamond floor.
	var relative_position := global_position
	var horizontal_limit: float = 984.0
	var vertical_limit: float = 484.0
	var normalized_distance: float = (
		absf(relative_position.x) / horizontal_limit
		+ absf(relative_position.y) / vertical_limit
	)
	if normalized_distance > 1.0:
		global_position = relative_position / normalized_distance


func begin_attack(direction: Vector2) -> void:
	is_winding_up = true
	windup_timer = attack_windup
	attack_direction = direction
	velocity = Vector2.ZERO


func perform_melee_attack() -> void:
	AudioManager.play_sfx("projectile", 0.55)
	is_winding_up = false
	attack_cooldown_timer = attack_cooldown
	attack_visual_timer = 0.18

	if not is_instance_valid(target):
		return

	var distance := global_position.distance_to(target.global_position)

	if distance <= attack_distance + 18.0:
		var direction := (
			target.global_position - global_position
		).normalized()

		if target.has_method("take_damage"):
			target.take_damage(attack_damage, direction)
		if target.has_method("_on_melee_enemy_hit"):
			target._on_melee_enemy_hit(self)


func perform_ranged_attack() -> void:
	is_winding_up = false
	attack_cooldown_timer = attack_cooldown
	attack_visual_timer = 0.25

	if not is_instance_valid(target):
		return

	var projectile = FIRE_PROJECTILE_SCRIPT.new()

	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + Vector2(0, -10)

	projectile.setup(
		target,
		attack_damage,
		260.0,
		attack_direction
	)


func take_damage(
	amount: float,
	knockback_direction: Vector2 = Vector2.ZERO
) -> void:
	if is_dying:
		return

	AudioManager.play_sfx("enemy_hit", 0.65)
	health -= amount
	hit_flash_timer = 0.14
	blink_timer = 0.24

	knockback_velocity = knockback_direction.normalized() * 260.0

	if health <= 0:
		die()
	else:
		queue_redraw()


func die() -> void:
	if is_dying:
		return

	AudioManager.play_sfx("enemy_death", 0.7)
	is_dying = true
	is_winding_up = false
	death_timer = 0.4

	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO

	var collision := get_node_or_null("CollisionShape2D")

	if collision is CollisionShape2D:
		collision.set_deferred("disabled", true)

	var fragment = FIRE_FRAGMENT_SCRIPT.new()
	get_tree().current_scene.add_child(fragment)
	fragment.global_position = global_position

	var players_for_drops := get_tree().get_nodes_in_group("players")
	if not players_for_drops.is_empty() and is_instance_valid(players_for_drops[0]):
		var drop_player = players_for_drops[0]
		if randf() < float(drop_player.get("double_drop_chance")):
			var bonus_fragment = FIRE_FRAGMENT_SCRIPT.new()
			get_tree().current_scene.add_child(bonus_fragment)
			bonus_fragment.global_position = global_position + Vector2(12.0, -6.0)
		if drop_player.has_method("notify_enemy_killed"):
			drop_player.notify_enemy_killed(global_position)

	# Broken Cauldron gives every defeated enemy a 35% health-drop chance.
	var broken_equipped := false
	var players := get_tree().get_nodes_in_group("players")
	if not players.is_empty() and is_instance_valid(players[0]):
		broken_equipped = str(players[0].get("cauldron_id")) == "broken"
	if randf() < (0.35 if broken_equipped else 0.05):
		var health_pickup = HEALTH_PICKUP_SCRIPT.new()
		get_tree().current_scene.add_child(health_pickup)
		health_pickup.global_position = global_position + Vector2(0, -8)


func _draw() -> void:
	if is_dying:
		var burst_progress: float = 1.0 - death_timer / 0.4

		for i in range(5):
			var angle := float(i) * TAU / 5.0
			var distance := burst_progress * 20.0
			var ember_position := (
				Vector2.RIGHT.rotated(angle) * distance
				+ Vector2(0, -15)
			)

			draw_circle(
				ember_position,
				2.5 * (1.0 - burst_progress),
				Color(1.0, 0.55, 0.12, 1.0 - burst_progress)
			)

		return

	if attack_visual_timer > 0.0:
		var duration := 0.25

		if attack_style == AttackStyle.MELEE:
			duration = 0.18

		var progress := 1.0 - attack_visual_timer / duration
		var puff_size := lerpf(11.0, 32.0, progress)
		var puff_alpha := 1.0 - progress

		if attack_style == AttackStyle.MELEE:
			for i in range(8):
				var angle := TAU * float(i) / 8.0
				var puff_position := Vector2.RIGHT.rotated(angle) * puff_size

				draw_circle(
					puff_position,
					lerpf(7.0, 3.0, progress),
					Color(1.0, 0.48, 0.16, puff_alpha * 0.75)
				)

			draw_circle(
				Vector2.ZERO,
				lerpf(17.0, 5.0, progress),
				Color(1.0, 0.72, 0.32, puff_alpha * 0.65)
			)
		else:
			draw_circle(
				Vector2(0, -12),
				lerpf(5.0, 13.0, progress),
				Color(0.55, 0.35, 1.0, puff_alpha)
			)

	draw_circle(Vector2(0, 10), 15.0, Color(0.05, 0.05, 0.06, 0.35))

	var body_offset := 0.0

	var squash := 1.0
	var body_rotation := 0.0

	if attack_style == AttackStyle.RANGED and dodge_timer > 0.0:
		var dodge_progress := 1.0 - dodge_timer / dodge_duration
		body_rotation = -dodge_direction.x * 0.22
		squash = 0.92 + sin(dodge_progress * PI) * 0.08
	elif is_winding_up:
		squash = 0.88 + sin(flame_time * 20.0) * 0.04

	draw_set_transform(
		Vector2(body_offset, 0),
		body_rotation,
		Vector2(1.0, squash)
	)

	var body_color := Color("#E7D8B5")
	if attack_style == AttackStyle.RANGED:
		body_color = Color("#AFA3CE")
	if hit_flash_timer > 0.0:
		body_color = Color.WHITE
	if hit_flash_timer > 0.0:
		body_color = Color.WHITE

	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-11, -7),
			Vector2(11, -7),
			Vector2(10, 8),
			Vector2(6, 15),
			Vector2(-7, 15),
			Vector2(-10, 8)
		]),
		body_color
	)

	draw_circle(Vector2(-7, 1), 3.0, Color("#D4C39F"))
	draw_circle(Vector2(7, -1), 2.5, Color("#D4C39F"))

	draw_line(
		Vector2(0, -7),
		Vector2(0, -13),
		Color("#49372A"),
		2.0
	)

	var flicker_a := sin(flame_time * 13.0) * 2.0
	var flicker_b := sin(flame_time * 21.0) * 1.5

	if is_winding_up:
		flicker_a += sin(flame_time * 45.0) * 4.0
		flicker_b += cos(flame_time * 38.0) * 3.0
		flicker_a += 4.0
		flicker_b += 2.0

	var flame_width := 7.0 + flicker_b
	var flame_height := 18.0 + flicker_a

	var outer_flame := Color("#F59E42")
	var inner_flame := Color("#FFE7A0")
	if hit_flash_timer > 0.0:
		outer_flame = Color.WHITE
		inner_flame = Color.WHITE
	if hit_flash_timer > 0.0:
		outer_flame = Color.WHITE
		inner_flame = Color.WHITE

	if attack_style == AttackStyle.RANGED:
		outer_flame = Color("#9875F5")
		inner_flame = Color("#DCCAFF")

	draw_colored_polygon(
		PackedVector2Array([
			Vector2(flicker_b, -10 - flame_height),
			Vector2(flame_width, -19),
			Vector2(flame_width * 0.8, -12),
			Vector2(0, -9),
			Vector2(-flame_width * 0.8, -12),
			Vector2(-flame_width, -19)
		]),
		outer_flame
	)

	draw_colored_polygon(
		PackedVector2Array([
			Vector2(flicker_b * 0.5, -22 + flicker_a * 0.4),
			Vector2(3, -16),
			Vector2(0, -12),
			Vector2(-3, -16)
		]),
		inner_flame
	)

	if blink_timer > 0.0 or is_winding_up:
		draw_line(Vector2(-6, 3), Vector2(-2, 3), Color("#49372A"), 2.0)
		draw_line(Vector2(2, 3), Vector2(6, 3), Color("#49372A"), 2.0)
	else:
		draw_circle(Vector2(-4, 3), 1.8, Color("#49372A"))
		draw_circle(Vector2(4, 3), 1.8, Color("#49372A"))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	for i in range(max_health):
		var bar_color := Color("#EF665B")

		if i >= health:
			bar_color = Color("#514A49")

		draw_rect(
			Rect2(Vector2(-10 + i * 8, -38), Vector2(6, 3)),
			bar_color
		)
