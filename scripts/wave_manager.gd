extends Node

signal wave_started(room_number: int, wave_number: int, enemy_count: int)
signal room_cleared(room_number: int)
signal run_completed

const CANDLE_SCENE: PackedScene = preload("res://scenes/candle.tscn")
const CANDLE_GOLEM_SCENE: PackedScene = preload("res://scenes/candle_golem.tscn")
const MELEE_LANTERN_SCENE: PackedScene = preload("res://scenes/lantern_melee.tscn")
const RANGED_LANTERN_SCENE: PackedScene = preload("res://scenes/lantern_ranged.tscn")
const LANTERN_BOSS_SCENE: PackedScene = preload("res://scenes/lantern_boss.tscn")

const TOTAL_ROOMS: int = 8
const WAVES_PER_ROOM: int = 3
const BOSS_ROOMS: Array[int] = [4, 8]

var player: Node2D
var arena: Node2D

var current_room: int = 1
var current_wave: int = 1

var waiting_for_buff: bool = false
var run_finished: bool = false
var wave_in_progress: bool = false


func setup(new_player: Node2D, new_arena: Node2D) -> void:
	player = new_player
	arena = new_arena


func start_run() -> void:
	current_room = clampi(GameData.test_room_override, 1, TOTAL_ROOMS) if GameData.test_room_override > 0 else 1
	current_wave = 1
	run_finished = false
	waiting_for_buff = false
	wave_in_progress = false
	start_current_wave()


func is_boss_wave() -> bool:
	return current_room in BOSS_ROOMS and current_wave == WAVES_PER_ROOM


func get_enemy_count() -> int:
	if is_boss_wave():
		if current_room == 4:
			return 5 # Candle Golem and four guards.
		return 1 # Lantern Warden handles its own summon phase.

	# Room 5 is the introduction to lantern-heavy encounters.
	# Start with four lanterns, then increase the group each wave.
	if current_room == 5:
		match current_wave:
			1:
				return 4 # 2 melee + 2 ranged lanterns.
			2:
				return 5
			_:
				return 6

	# Preserve the existing gradual increase for all other rooms.
	return 2 + current_wave + current_room - 1


func get_ranged_candle_count(enemy_count: int) -> int:
	if current_room <= 1:
		return 0

	# From Room 6 onward, any candles in the encounter are ranged.
	if current_room >= 6:
		return enemy_count

	var ranged_ratio: float = 0.25 + float(current_room - 2) * 0.08
	ranged_ratio = clampf(ranged_ratio, 0.25, 0.55)
	return mini(enemy_count, maxi(1, roundi(float(enemy_count) * ranged_ratio)))


func get_lantern_count(enemy_count: int) -> int:
	if current_room < 5:
		return 0

	# Room 5 is a lantern-only introduction: both melee and ranged.
	if current_room == 5:
		return enemy_count

	# Rooms 6-8 keep lanterns as the majority, with ranged candles
	# joining the mix as the secondary enemy type.
	return clampi(roundi(float(enemy_count) * 0.70), 2, enemy_count - 1)

func start_current_wave() -> void:
	if run_finished or waiting_for_buff or wave_in_progress:
		return

	wave_in_progress = true
	var enemy_count: int = get_enemy_count()

	wave_started.emit(current_room, current_wave, enemy_count)

	if is_boss_wave():
		if current_room == 4:
			spawn_candle_golem_encounter()
		else:
			spawn_lantern_warden_encounter()
	else:
		spawn_normal_wave(enemy_count)

	# Wait until every enemy in the encounter has been defeated.
	while true:
		await get_tree().process_frame
		if run_finished or not is_inside_tree():
			return
		if get_tree().get_nodes_in_group("enemies").is_empty():
			break

	wave_in_progress = false

	# Brief breathing room between encounters.
	await get_tree().create_timer(1.2).timeout

	if run_finished or waiting_for_buff:
		return

	if current_wave < WAVES_PER_ROOM:
		current_wave += 1
		start_current_wave()
	else:
		waiting_for_buff = true
		room_cleared.emit(current_room)


func spawn_normal_wave(amount: int) -> void:
	var lantern_count: int = get_lantern_count(amount)
	var candle_count: int = amount - lantern_count
	var ranged_candle_count: int = get_ranged_candle_count(candle_count)

	var spawn_types: Array[Dictionary] = []

	# Add the room's candle enemies.
	for i in range(candle_count):
		spawn_types.append({
			"scene": CANDLE_SCENE,
			"style": 1 if i < ranged_candle_count else 0,
			"is_lantern": false
		})

	# Add lantern enemies from Room 5 onward. Ensure the first
	# lantern encounter introduces both melee and ranged variants.
	var ranged_lantern_count: int = 0
	if lantern_count > 0:
		ranged_lantern_count = maxi(1, roundi(float(lantern_count) * 0.4))
		# Keep at least one melee lantern whenever there are two or more.
		if lantern_count >= 2:
			ranged_lantern_count = mini(ranged_lantern_count, lantern_count - 1)
		else:
			ranged_lantern_count = 1

	for i in range(lantern_count):
		spawn_types.append({
			"scene": RANGED_LANTERN_SCENE if i < ranged_lantern_count else MELEE_LANTERN_SCENE,
			"style": 0,
			"is_lantern": true
		})

	spawn_types.shuffle()

	for i in range(spawn_types.size()):
		var enemy_data: Dictionary = spawn_types[i]
		var enemy = (enemy_data["scene"] as PackedScene).instantiate()
		arena.add_child(enemy)

		if not bool(enemy_data["is_lantern"]):
			enemy.attack_style = int(enemy_data["style"])

		var angle: float = TAU * float(i) / float(spawn_types.size())
		var spawn_direction := Vector2.RIGHT.rotated(angle)
		var spawn_distance: float = randf_range(145.0, 205.0)
		enemy.global_position = player.global_position + spawn_direction * spawn_distance

		if enemy.has_method("set_target"):
			enemy.set_target(player)


func spawn_candle_golem_encounter() -> void:
	var boss = CANDLE_GOLEM_SCENE.instantiate()
	arena.add_child(boss)
	boss.global_position = Vector2.ZERO
	boss.ai_enabled = true

	# The Golem encounter retains its four candle guards.
	var guard_positions: Array[Vector2] = [
		Vector2(-150, -55),
		Vector2(150, -55),
		Vector2(-105, 115),
		Vector2(105, 115)
	]

	for i in range(guard_positions.size()):
		var candle = CANDLE_SCENE.instantiate()
		arena.add_child(candle)
		candle.attack_style = 1 if i >= 2 else 0
		candle.global_position = player.global_position + guard_positions[i]
		candle.set_target(player)


func spawn_lantern_warden_encounter() -> void:
	var boss = LANTERN_BOSS_SCENE.instantiate()
	arena.add_child(boss)
	boss.global_position = Vector2.ZERO


func continue_after_buff() -> void:
	if not waiting_for_buff or run_finished:
		return

	waiting_for_buff = false

	if current_room >= TOTAL_ROOMS:
		run_finished = true
		run_completed.emit()
		return

	current_room += 1
	current_wave = 1

	# Reset encounter state before beginning the next room.
	wave_in_progress = false
	await get_tree().create_timer(1.0).timeout
	start_current_wave()
