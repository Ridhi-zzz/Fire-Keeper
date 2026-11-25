
extends Node2D


class BossHeartDisplay extends Control:
	var current_health: int = 0
	var maximum_health: int = 0
	var heart_color: Color = Color("#E95D68")

	func set_health(current: int, maximum: int) -> void:
		current_health = maxi(current, 0)
		maximum_health = maxi(maximum, 0)
		custom_minimum_size = Vector2(0, 28)
		queue_redraw()

	func _draw() -> void:
		var heart_count: int = ceili(float(maximum_health) / 2.0)
		var heart_width: float = 23.0
		var spacing: float = 29.0
		var total_width: float = maxf(0.0, float(heart_count - 1) * spacing + heart_width)
		var start_x: float = (size.x - total_width) * 0.5

		for i in range(heart_count):
			var x: float = start_x + float(i) * spacing
			var y: float = 2.0
			var value: int = clampi(current_health - i * 2, 0, 2)
			var heart := PackedVector2Array([
				Vector2(x + 11, y + 21),
				Vector2(x + 1, y + 10),
				Vector2(x, y + 5),
				Vector2(x + 3, y + 1),
				Vector2(x + 7, y),
				Vector2(x + 11, y + 5),
				Vector2(x + 16, y),
				Vector2(x + 20, y + 1),
				Vector2(x + 23, y + 5),
				Vector2(x + 22, y + 10)
			])
			draw_colored_polygon(heart, Color("#34343D"))
			if value == 2:
				draw_colored_polygon(heart, heart_color)
			elif value == 1:
				draw_colored_polygon(PackedVector2Array([
					Vector2(x + 11, y + 21),
					Vector2(x + 1, y + 10),
					Vector2(x, y + 5),
					Vector2(x + 3, y + 1),
					Vector2(x + 7, y),
					Vector2(x + 11, y + 5)
				]), heart_color)
			draw_polyline(
				PackedVector2Array([
					heart[0], heart[1], heart[2], heart[3], heart[4],
					heart[5], heart[6], heart[7], heart[8], heart[9], heart[0]
				]),
				Color("#F5C0B9"),
				1.1
			)


class GameHUD extends Control:
	var fire_amount: int = 0
	var health_units: int = 10
	var max_health_units: int = 10
	var dash_cooldown: float = 0.0
	var dash_max_cooldown: float = 1.1
	var dash_charges: int = 1
	var dash_charge_max: int = 1
	var special_charge: int = 0
	var special_charge_required: int = 20
	var cauldron_status: String = ""

	func update_values(
		new_fire: int,
		new_health: int,
		new_max_health: int,
		new_dash_cooldown: float,
		new_dash_max: float,
		new_dash_charges: int,
		new_dash_charge_max: int,
		new_special_charge: int,
		new_special_charge_required: int,
		new_cauldron_status: String
	) -> void:
		fire_amount = new_fire
		health_units = new_health
		max_health_units = new_max_health
		dash_cooldown = new_dash_cooldown
		dash_max_cooldown = new_dash_max
		dash_charges = new_dash_charges
		dash_charge_max = new_dash_charge_max
		special_charge = new_special_charge
		special_charge_required = new_special_charge_required
		cauldron_status = new_cauldron_status
		queue_redraw()

	func _draw() -> void:
		# Fire Fragment icon, matching the in-world pickup's crystal shape.
		draw_circle(Vector2(29, 29), 15.0, Color(1.0, 0.48, 0.08, 0.16))
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(29, 15), Vector2(38, 24),
				Vector2(34, 38), Vector2(24, 38), Vector2(20, 24)
			]),
			Color("#F59E42")
		)
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(29, 19), Vector2(33, 26),
				Vector2(30, 33), Vector2(26, 30), Vector2(25, 25)
			]),
			Color("#FFF0AE")
		)

		draw_string(
			ThemeDB.fallback_font,
			Vector2(52, 36),
			str(fire_amount),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			23,
			Color("#FFF0C4")
		)

		# Health is stored in half-heart units. Draw enough hearts
		# to include permanent and temporary health upgrades.
		var heart_count: int = ceili(float(max_health_units) / 2.0)
		for i in range(heart_count):
			var x: float = 22.0 + float(i) * 31.0
			var y: float = 54.0
			var value: int = clampi(health_units - i * 2, 0, 2)

			var heart := PackedVector2Array([
				Vector2(x + 10, y + 18),
				Vector2(x + 1, y + 9),
				Vector2(x, y + 5),
				Vector2(x + 2, y + 1),
				Vector2(x + 6, y),
				Vector2(x + 10, y + 4),
				Vector2(x + 14, y),
				Vector2(x + 18, y + 1),
				Vector2(x + 20, y + 5),
				Vector2(x + 19, y + 9)
			])

			draw_colored_polygon(heart, Color("#34343D"))

			if value == 2:
				draw_colored_polygon(heart, Color("#E95D68"))
			elif value == 1:
				draw_colored_polygon(
					PackedVector2Array([
						Vector2(x + 10, y + 18),
						Vector2(x + 1, y + 9),
						Vector2(x, y + 5),
						Vector2(x + 2, y + 1),
						Vector2(x + 6, y),
						Vector2(x + 10, y + 4)
					]),
					Color("#E95D68")
				)

			draw_polyline(
				PackedVector2Array([
					heart[0], heart[1], heart[2], heart[3], heart[4],
					heart[5], heart[6], heart[7], heart[8], heart[9], heart[0]
				]),
				Color("#F5C0B9"),
				1.2
			)

		if cauldron_status != "":
			draw_string(
				ThemeDB.fallback_font,
				Vector2(22, 137),
				cauldron_status,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				14,
				Color("#77E4D4")
			)

		# Ability cooldown indicators along the bottom-left.
		var viewport_size := get_viewport_rect().size
		var ability_y: float = viewport_size.y - 24.0

		_draw_ability(
			Vector2(22, ability_y - 16),
			"Q",
			"DASH",
			dash_cooldown,
			dash_max_cooldown,
			Color("#77CDE0")
		)

		# Numeric dash-charge indicator for upgraded dash capacity.
		draw_string(
			ThemeDB.fallback_font,
			Vector2(58, ability_y - 7),
			"%d / %d" % [dash_charges, dash_charge_max],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			13,
			Color("#A9E8F2")
		)

		_draw_charge_ability(
			Vector2(174, ability_y - 16),
			"E",
			"FIRE BURST",
			special_charge,
			special_charge_required,
			Color("#F59E42")
		)

	func _draw_charge_ability(
		position: Vector2,
		key: String,
		label: String,
		charge: int,
		required: int,
		accent: Color
	) -> void:
		var ready: bool = charge >= required
		var ratio: float = 0.0

		if required > 0:
			ratio = clampf(float(charge) / float(required), 0.0, 1.0)

		draw_rect(
			Rect2(position, Vector2(28, 28)),
			Color("#20262D")
		)
		draw_rect(
			Rect2(position, Vector2(28, 28)),
			accent if ready else Color("#59616A"),
			false,
			2.0
		)

		draw_string(
			ThemeDB.fallback_font,
			position + Vector2(8, 20),
			key,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			17,
			Color.WHITE
		)

		var status_text: String = "READY" if ready else str(charge) + "/" + str(required) + " HITS"
		draw_string(
			ThemeDB.fallback_font,
			position + Vector2(36, 19),
			label + "  " + status_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14,
			Color("#FFF0C4") if ready else Color("#A7ADB3")
		)

		draw_rect(
			Rect2(position + Vector2(36, 23), Vector2(120, 4)),
			Color("#343A40")
		)
		draw_rect(
			Rect2(position + Vector2(36, 23), Vector2(120.0 * ratio, 4)),
			accent
		)

	func _draw_ability(
		position: Vector2,
		key: String,
		label: String,
		cooldown: float,
		max_cooldown: float,
		accent: Color
	) -> void:
		var ready: bool = cooldown <= 0.0
		var ratio: float = 1.0

		if max_cooldown > 0.0:
			ratio = 1.0 - clampf(cooldown / max_cooldown, 0.0, 1.0)

		draw_rect(
			Rect2(position, Vector2(28, 28)),
			Color("#20262D")
		)
		draw_rect(
			Rect2(position, Vector2(28, 28)),
			accent if ready else Color("#59616A"),
			false,
			2.0
		)

		draw_string(
			ThemeDB.fallback_font,
			position + Vector2(8, 20),
			key,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			17,
			Color.WHITE
		)

		draw_string(
			ThemeDB.fallback_font,
			position + Vector2(36, 19),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14,
			Color("#FFF0C4") if ready else Color("#A7ADB3")
		)

		draw_rect(
			Rect2(position + Vector2(36, 23), Vector2(94, 4)),
			Color("#343A40")
		)
		draw_rect(
			Rect2(position + Vector2(36, 23), Vector2(94.0 * ratio, 4)),
			accent
		)

const PLAYER_SCENE = preload("res://scenes/player.tscn")
const WAVE_MANAGER_SCRIPT = preload("res://scripts/wave_manager.gd")
const WORKSHOP_SCENE = preload("res://scenes/workshop_panel.tscn")

var player: Node2D
var wave_manager: Node

var hud_display: GameHUD
var progress_label: Label
var boss_health_panel: PanelContainer
var boss_name_label: Label
var boss_heart_display: BossHeartDisplay

var defeat_overlay: Control
var buff_overlay: Control
var completion_overlay: Control
var workshop_panel_instance: Control
var workshop_canvas: CanvasLayer

var game_over: bool = false
var run_summary_overlay: Control
var run_elapsed_seconds: float = 0.0
var run_start_fire_fragments: int = 0
var run_start_boss_fragments: int = 0
var run_summary_shown: bool = false
var pause_overlay: Control
var pause_button: Button

var selected_buffs: Array[Dictionary] = []

var buff_pool: Array[Dictionary] = [
	{"id":"crit","name":"CRITICAL CHANCE","description":"+20% critical chance. Critical hits deal double damage.","max":3,"category":"OFFENSE","icon":"CRIT"},
	{"id":"extra_dash","name":"EXTRA DASH","description":"Gain one additional dash charge.","max":3,"category":"MOBILITY","icon":"DASH"},
	{"id":"dash_cooldown","name":"QUICK RECOVERY","description":"Dash cooldown reduced by 0.2 seconds.","max":3,"category":"MOBILITY","icon":"CD"},
	{"id":"movement","name":"LIGHT FEET","description":"Movement speed increased by 8%.","max":3,"category":"MOBILITY","icon":"SPD"},
	{"id":"burst_charge","name":"HOTTER FLAME","description":"Fire Burst needs 2 fewer hits to charge.","max":5,"category":"OFFENSE","icon":"FIRE"},
	{"id":"kindling","name":"KINDLING","description":"Immediately restore 2 hearts.","max":999,"category":"RECOVERY","icon":"HP","heal":true},
	{"id":"overloaded","name":"OVERLOADED CHAMBER","description":"Shotgun: one burst per magazine, +1 damage per pellet, recoil, and a 5% misfire chance.","max":1,"category":"SHOTGUN","cauldron":"shotgun"},
	{"id":"triple_spread","name":"TRIPLE SPREAD","description":"Ranged: fire 3 projectiles in a cone; each consumes one bullet.","max":1,"category":"RANGED","cauldron":"ranged","exclusive":"twin_shot"},
	{"id":"twin_shot","name":"TWIN SHOT","description":"Ranged: fire 2 parallel projectiles; consumes 2 bullets per trigger pull.","max":1,"category":"RANGED","cauldron":"ranged","exclusive":"triple_spread"},
	{"id":"combustion","name":"COMBUSTION","description":"Every 5 kills trigger an explosion dealing 1 damage to nearby enemies.","max":3,"category":"OFFENSE"},
	{"id":"ember_shield","name":"EMBER SHIELD","description":"+0.35 seconds of invulnerability after taking damage.","max":2,"category":"DEFENSE"},
	{"id":"afterburn","name":"AFTERBURN","description":"Dashing leaves a fire trail that deals 1 damage to enemies.","max":2,"category":"OFFENSE"},
	{"id":"volatile","name":"VOLATILE FLAMES","description":"Fire Burst deals +1 damage.","max":3,"category":"OFFENSE"},
	{"id":"double_drop","name":"DOUBLE TROUBLE","description":"15% chance for normal enemies to drop double Fire Fragments.","max":1,"category":"ECONOMY"},
	{"id":"soul_conversion","name":"SOUL CONVERSION","description":"Fire Fragments heal 1/4 heart while injured; currency only at full health.","max":1,"category":"RECOVERY"},
	{"id":"magnet","name":"EMBER MAGNET","description":"Attract nearby Fire Fragment and health pickups from farther away.","max":1,"category":"UTILITY"}
]


func _ready() -> void:
	randomize()
	run_elapsed_seconds = 0.0
	run_start_fire_fragments = GameData.fire_fragments
	run_start_boss_fragments = GameData.boss_fire_fragments
	run_summary_shown = false
	# Keep the arena floor on the base drawing layer.
	# Characters are sorted separately by their Y position.

	# Create player.
	player = PLAYER_SCENE.instantiate()
	player.position = Vector2.ZERO
	add_child(player)

	player.stats_changed.connect(_update_hud)
	player.player_died.connect(show_defeat_screen)

	# Create wave manager.
	wave_manager = WAVE_MANAGER_SCRIPT.new()
	add_child(wave_manager)

	wave_manager.setup(player, self)

	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.room_cleared.connect(_on_room_cleared)
	wave_manager.run_completed.connect(_on_run_completed)

	# Create interfaces.
	create_hud()
	create_defeat_screen()
	create_buff_screen()
	create_completion_screen()
	create_run_summary_screen()
	create_pause_screen()

	_update_hud(player.fire_fragments, player.health)

	# Start the first room.
	wave_manager.start_run()

	queue_redraw()


func _process(delta: float) -> void:
	if not game_over and not wave_manager.run_finished and not get_tree().paused:
		run_elapsed_seconds += delta
	_update_character_draw_order()

	if is_instance_valid(hud_display) and is_instance_valid(player):
		hud_display.update_values(
			player.fire_fragments,
			player.health,
			player.max_health,
			player.dash_cooldown_timer,
			player.dash_cooldown,
			player.dash_charges,
			player.dash_charge_max,
			player.special_charge,
			player.special_charge_required,
			player.get_cauldron_status()
		)

	_update_boss_health_bar()


func _update_character_draw_order() -> void:
	# Keep every character above the floor, even when it moves
	# into the upper half of the arena (negative Y positions).
	# Characters farther down the screen are drawn in front.
	var players := get_tree().get_nodes_in_group("players")
	var enemies := get_tree().get_nodes_in_group("enemies")
	var pickups := get_tree().get_nodes_in_group("pickups")

	for character in players:
		if is_instance_valid(character) and character is Node2D:
			character.z_index = clampi(
				1000 + roundi(character.global_position.y),
				1,
				2000
			)

	for character in enemies + pickups:
		if is_instance_valid(character) and character is Node2D:
			character.z_index = clampi(
				1000 + roundi(character.global_position.y),
				1,
				2000
			)


func create_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 2
	add_child(canvas)

	hud_display = GameHUD.new()
	hud_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(hud_display)

	progress_label = Label.new()
	progress_label.position = Vector2(20, 92)
	progress_label.add_theme_font_size_override("font_size", 18)
	progress_label.add_theme_color_override(
		"font_color",
		Color("#FFB66A")
	)
	canvas.add_child(progress_label)


	# Boss health display, centered along the top of the screen.
	boss_health_panel = PanelContainer.new()
	boss_health_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_health_panel.position = Vector2(-190, 18)
	boss_health_panel.custom_minimum_size = Vector2(380, 66)
	boss_health_panel.visible = false
	boss_health_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(boss_health_panel)

	var boss_box := VBoxContainer.new()
	boss_box.add_theme_constant_override("separation", 4)
	boss_health_panel.add_child(boss_box)

	boss_name_label = Label.new()
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.add_theme_font_size_override("font_size", 16)
	boss_name_label.add_theme_color_override("font_color", Color("#FFE0A0"))
	boss_box.add_child(boss_name_label)

	boss_heart_display = BossHeartDisplay.new()
	boss_heart_display.custom_minimum_size = Vector2(350, 28)
	boss_heart_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_box.add_child(boss_heart_display)

	pause_button = Button.new()
	pause_button.text = "||"
	pause_button.tooltip_text = "Pause"
	pause_button.custom_minimum_size = Vector2(48, 42)
	pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_button.position = Vector2(-66, 18)
	pause_button.pressed.connect(_toggle_pause)
	canvas.add_child(pause_button)


func _update_boss_health_bar() -> void:
	if not is_instance_valid(boss_health_panel):
		return

	var active_boss: Node = null
	for boss in get_tree().get_nodes_in_group("bosses"):
		if not is_instance_valid(boss) or boss.get("is_dying") == true:
			continue
		var current_health = boss.get("health")
		var maximum_health = boss.get("max_health")
		if current_health == null or maximum_health == null:
			continue
		if int(current_health) <= 0 or int(maximum_health) <= 0:
			continue
		active_boss = boss
		break

	if active_boss == null:
		boss_health_panel.visible = false
		return

	var current: int = int(active_boss.get("health"))
	var maximum: int = int(active_boss.get("max_health"))
	var display_name := "BOSS"
	var boss_name_value = active_boss.get("boss_display_name")
	if boss_name_value != null and str(boss_name_value) != "":
		display_name = str(boss_name_value)
	elif active_boss.name == "CandleGolem":
		display_name = "CANDLE GOLEM"

	boss_name_label.text = display_name
	boss_heart_display.set_health(current, maximum)
	boss_health_panel.visible = true


func _update_hud(fire_amount: int, current_health: int) -> void:
	if is_instance_valid(hud_display):
		hud_display.update_values(
			fire_amount,
			current_health,
			player.max_health,
			player.dash_cooldown_timer,
			player.dash_cooldown,
			player.dash_charges,
			player.dash_charge_max,
			player.special_charge,
			player.special_charge_required,
			player.get_cauldron_status()
		)


func _on_wave_started(
	room_number: int,
	wave_number: int,
	enemy_count: int
) -> void:
	if not is_instance_valid(progress_label):
		return

	if wave_number == 3 and (room_number == 4 or room_number == 8):
		var boss_title: String = "CANDLE GOLEM" if room_number == 4 else "LANTERN WARDEN"
		progress_label.text = "ROOM " + str(room_number) + "     BOSS: " + boss_title
	else:
		progress_label.text = (
			"ROOM " + str(room_number)
			+ "     WAVE " + str(wave_number) + "/3"
			+ "     ENEMIES: " + str(enemy_count)
		)


func _on_room_cleared(room_number: int) -> void:
	show_buff_screen(room_number)


func create_buff_screen() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 5
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	buff_overlay = Control.new()
	buff_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	buff_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	buff_overlay.visible = false
	canvas.add_child(buff_overlay)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.025, 0.03, 0.04, 0.96)
	buff_overlay.add_child(background)
	var outer := VBoxContainer.new()
	outer.name = "BuffLayout"
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = 36
	outer.offset_right = -36
	outer.offset_top = 42
	outer.offset_bottom = -42
	outer.add_theme_constant_override("separation", 22)
	buff_overlay.add_child(outer)
	var heading := Label.new()
	heading.text = "ROOM CLEARED"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 34)
	heading.add_theme_color_override("font_color", Color("#FFAD62"))
	outer.add_child(heading)
	var subtitle := Label.new()
	subtitle.text = "Choose one blessing. Time stands still while you decide."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", Color("#E5D8C0"))
	outer.add_child(subtitle)
	var cards := HBoxContainer.new()
	cards.name = "Cards"
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 18)
	outer.add_child(cards)


func _get_eligible_buffs() -> Array[Dictionary]:
	var eligible: Array[Dictionary] = []
	for buff in buff_pool:
		var buff_id := str(buff["id"])
		if player.get_run_buff_count(buff_id) >= int(buff["max"]):
			continue
		if buff.has("cauldron") and str(buff["cauldron"]) != player.cauldron_id:
			continue
		if buff.has("exclusive") and player.get_run_buff_count(str(buff["exclusive"])) > 0:
			continue
		if buff.has("heal") and player.health >= player.max_health:
			continue
		eligible.append(buff)
	return eligible


func show_buff_screen(room_number: int) -> void:
	if game_over:
		return
	var eligible := _get_eligible_buffs()
	selected_buffs.clear()

	# Guarantee the cauldron-specific choice at the first reward,
	# immediately after Room 1 and before Room 2 begins.
	if room_number == 1 and player.cauldron_id == "ranged":
		for guaranteed_id in ["triple_spread", "twin_shot"]:
			for buff in eligible:
				if str(buff["id"]) == guaranteed_id:
					selected_buffs.append(buff)
					break
	elif room_number == 1 and player.cauldron_id == "shotgun":
		for buff in eligible:
			if str(buff["id"]) == "overloaded":
				selected_buffs.append(buff)
				break

	var remaining: Array[Dictionary] = []
	for buff in eligible:
		var already_selected := false
		for chosen in selected_buffs:
			if str(chosen["id"]) == str(buff["id"]):
				already_selected = true
				break
		if not already_selected:
			remaining.append(buff)
	remaining.shuffle()
	while selected_buffs.size() < 3 and not remaining.is_empty():
		selected_buffs.append(remaining.pop_back())
	if selected_buffs.is_empty():
		wave_manager.continue_after_buff()
		return
	var cards := buff_overlay.find_child("Cards", true, false)
	for child in cards.get_children():
		child.queue_free()
	for i in range(selected_buffs.size()):
		var buff: Dictionary = selected_buffs[i]
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(220, 280)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#242B32")
		style.border_color = Color("#A96A3D")
		style.set_border_width_all(2)
		style.set_corner_radius_all(12)
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 18
		style.content_margin_bottom = 18
		card.add_theme_stylebox_override("panel", style)
		cards.add_child(card)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 12)
		card.add_child(content)
		var category := Label.new()
		category.text = str(buff["category"])
		category.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		category.add_theme_font_size_override("font_size", 12)
		category.add_theme_color_override("font_color", Color("#E9A45E"))
		content.add_child(category)
		var icon_label := Label.new()
		icon_label.text = str(buff.get("icon", "UP"))
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.add_theme_font_size_override("font_size", 42)
		icon_label.add_theme_color_override("font_color", Color("#FFD18B"))
		content.add_child(icon_label)
		var title := Label.new()
		title.text = str(buff["name"])
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.add_theme_font_size_override("font_size", 17)
		title.add_theme_color_override("font_color", Color("#FFF0D0"))
		content.add_child(title)
		var description := Label.new()
		description.text = str(buff["description"])
		description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.size_flags_vertical = Control.SIZE_EXPAND_FILL
		description.add_theme_font_size_override("font_size", 14)
		description.add_theme_color_override("font_color", Color("#D0D0C8"))
		content.add_child(description)
		var count: int = int(player.get_run_buff_count(str(buff["id"])))
		var stack := Label.new()
		stack.text = "NEW" if count == 0 else "STACK %d / %d" % [count + 1, int(buff["max"])]
		stack.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack.add_theme_color_override("font_color", Color("#E8B66A"))
		content.add_child(stack)
		var choose := Button.new()
		choose.text = "CHOOSE"
		choose.custom_minimum_size = Vector2(0, 44)
		choose.pressed.connect(_choose_buff.bind(i))
		content.add_child(choose)
	buff_overlay.visible = true
	get_tree().paused = true


func _choose_buff(index: int) -> void:
	if index < 0 or index >= selected_buffs.size():
		return
	apply_buff(selected_buffs[index])
	buff_overlay.visible = false
	get_tree().paused = false
	wave_manager.continue_after_buff()


func apply_buff(buff: Dictionary) -> void:
	player.apply_run_buff(str(buff["id"]))


func create_defeat_screen() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)

	defeat_overlay = Control.new()
	defeat_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	defeat_overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	defeat_overlay.visible = false
	canvas.add_child(defeat_overlay)

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	background.color = Color(0.02, 0.025, 0.035, 0.85)
	defeat_overlay.add_child(background)

	var container := VBoxContainer.new()
	container.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER
	)
	container.position = Vector2(-190, -155)
	container.size = Vector2(380, 310)
	container.add_theme_constant_override("separation", 20)
	defeat_overlay.add_child(container)

	var heading := Label.new()
	heading.text = "CAULDRON EXTINGUISHED"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override(
		"font_color",
		Color("#FF9955")
	)
	container.add_child(heading)

	var subtitle := Label.new()
	subtitle.text = "Your fire has faded..."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override(
		"font_color",
		Color("#E5D8C0")
	)
	container.add_child(subtitle)

	var restart_button := Button.new()
	restart_button.text = "TRY AGAIN"
	restart_button.custom_minimum_size = Vector2(200, 50)
	restart_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart_button.pressed.connect(restart_game)
	container.add_child(restart_button)

	var workshop_button := Button.new()
	workshop_button.text = "WORKSHOP"
	workshop_button.custom_minimum_size = Vector2(200, 50)
	workshop_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	workshop_button.pressed.connect(_return_to_menu_with_workshop)
	container.add_child(workshop_button)

	var menu_button := Button.new()
	menu_button.text = "MAIN MENU"
	menu_button.custom_minimum_size = Vector2(200, 50)
	menu_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_button.pressed.connect(_return_to_main_menu)
	container.add_child(menu_button)


func _return_to_main_menu() -> void:
	get_tree().paused = false
	GameData.open_workshop_on_menu = false
	get_tree().change_scene_to_file("res://scenes/startup_menu.tscn")


func _return_to_menu_with_workshop() -> void:
	get_tree().paused = false
	GameData.open_workshop_on_menu = true
	get_tree().change_scene_to_file("res://scenes/startup_menu.tscn")


func _open_workshop_from_defeat() -> void:
	if is_instance_valid(workshop_panel_instance):
		return
	workshop_canvas = CanvasLayer.new()
	workshop_canvas.layer = 20
	workshop_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(workshop_canvas)

	workshop_panel_instance = WORKSHOP_SCENE.instantiate()
	workshop_canvas.add_child(workshop_panel_instance)
	workshop_panel_instance.closed.connect(_close_workshop_panel)


func _close_workshop_panel() -> void:
	if is_instance_valid(workshop_canvas):
		workshop_canvas.queue_free()
	workshop_canvas = null
	workshop_panel_instance = null


func show_defeat_screen() -> void:
	if game_over:
		return

	game_over = true
	pause_overlay.visible = false
	pause_button.visible = false
	defeat_overlay.visible = false
	completion_overlay.visible = false
	show_run_summary(false)
	get_tree().paused = true


func create_completion_screen() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)

	completion_overlay = Control.new()
	completion_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	completion_overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	completion_overlay.visible = false
	canvas.add_child(completion_overlay)

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	background.color = Color(0.02, 0.025, 0.035, 0.88)
	completion_overlay.add_child(background)

	var container := VBoxContainer.new()
	container.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER
	)
	container.position = Vector2(-180, -100)
	container.size = Vector2(360, 200)
	container.add_theme_constant_override("separation", 20)
	completion_overlay.add_child(container)

	var heading := Label.new()
	heading.text = "DUNGEON CLEARED!"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override(
		"font_color",
		Color("#FF9955")
	)
	container.add_child(heading)

	var subtitle := Label.new()
	subtitle.text = "Your flame burns bright."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	container.add_child(subtitle)

	var restart_button := Button.new()
	restart_button.text = "PLAY AGAIN"
	restart_button.custom_minimum_size = Vector2(200, 50)
	restart_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart_button.pressed.connect(restart_game)
	container.add_child(restart_button)


func _on_run_completed() -> void:
	game_over = true
	pause_overlay.visible = false
	pause_button.visible = false
	defeat_overlay.visible = false
	completion_overlay.visible = false
	show_run_summary(true)
	get_tree().paused = true


func create_pause_screen() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 15
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)

	pause_overlay = Control.new()
	pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.visible = false
	canvas.add_child(pause_overlay)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.02, 0.03, 0.88)
	pause_overlay.add_child(shade)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-190, -175)
	panel.size = Vector2(380, 350)
	pause_overlay.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	panel.add_child(layout)

	var heading := Label.new()
	heading.text = "PAUSED"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 32)
	heading.add_theme_color_override("font_color", Color("#FFB66A"))
	layout.add_child(heading)

	_add_pause_menu_button(layout, "RESUME", _resume_game)
	_add_pause_menu_button(layout, "RESTART RUN", _confirm_pause_restart)
	_add_pause_menu_button(layout, "WORKSHOP", _return_to_menu_with_workshop)
	_add_pause_menu_button(layout, "MAIN MENU", _return_to_main_menu)


func _add_pause_menu_button(parent: VBoxContainer, caption: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(230, 44)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(callback)
	parent.add_child(button)


func _toggle_pause() -> void:
	if game_over or buff_overlay.visible or run_summary_overlay.visible:
		return
	if get_tree().paused:
		_resume_game()
	else:
		pause_overlay.visible = true
		pause_button.text = ">"
		pause_button.tooltip_text = "Resume"
		get_tree().paused = true


func _resume_game() -> void:
	pause_overlay.visible = false
	get_tree().paused = false
	if is_instance_valid(pause_button):
		pause_button.text = "||"
		pause_button.tooltip_text = "Pause"


func _confirm_pause_restart() -> void:
	get_tree().paused = false
	get_tree().call_deferred("reload_current_scene")


func create_run_summary_screen() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)

	run_summary_overlay = Control.new()
	run_summary_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	run_summary_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	run_summary_overlay.visible = false
	canvas.add_child(run_summary_overlay)

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.025, 0.03, 0.04, 0.94)
	run_summary_overlay.add_child(background)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-270, -260)
	panel.size = Vector2(540, 520)
	run_summary_overlay.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(layout)

	var heading := Label.new()
	heading.name = "SummaryHeading"
	heading.text = "RUN SUMMARY"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", Color("#FFB66A"))
	layout.add_child(heading)

	var result := Label.new()
	result.name = "SummaryResult"
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.add_theme_font_size_override("font_size", 18)
	layout.add_child(result)

	var stats := Label.new()
	stats.name = "SummaryStats"
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.add_theme_font_size_override("font_size", 17)
	stats.add_theme_color_override("font_color", Color("#E5D8C0"))
	stats.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(stats)

	var buff_label := Label.new()
	buff_label.name = "SummaryBuffs"
	buff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buff_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	buff_label.add_theme_font_size_override("font_size", 14)
	buff_label.add_theme_color_override("font_color", Color("#D6A66D"))
	layout.add_child(buff_label)

	var retry := Button.new()
	retry.text = "PLAY AGAIN"
	retry.custom_minimum_size = Vector2(220, 44)
	retry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	retry.pressed.connect(restart_game)
	layout.add_child(retry)

	var workshop := Button.new()
	workshop.text = "WORKSHOP"
	workshop.custom_minimum_size = Vector2(220, 44)
	workshop.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	workshop.pressed.connect(_return_to_menu_with_workshop)
	layout.add_child(workshop)

	var menu := Button.new()
	menu.text = "MAIN MENU"
	menu.custom_minimum_size = Vector2(220, 44)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu.pressed.connect(_return_to_main_menu)
	layout.add_child(menu)


func show_run_summary(victory: bool) -> void:
	if run_summary_shown:
		return
	run_summary_shown = true
	var minutes: int = int(run_elapsed_seconds) / 60
	var seconds: int = int(run_elapsed_seconds) % 60
	var rooms_reached: int = wave_manager.current_room
	if victory:
		rooms_reached = wave_manager.TOTAL_ROOMS
	var earned_fire: int = maxi(0, GameData.fire_fragments - run_start_fire_fragments)
	var earned_boss: int = maxi(0, GameData.boss_fire_fragments - run_start_boss_fragments)
	var result_label := run_summary_overlay.find_child("SummaryResult", true, false) as Label
	var stats_label := run_summary_overlay.find_child("SummaryStats", true, false) as Label
	var buffs_label := run_summary_overlay.find_child("SummaryBuffs", true, false) as Label
	var heading := run_summary_overlay.find_child("SummaryHeading", true, false) as Label
	if heading != null:
		heading.text = "DUNGEON CONQUERED" if victory else "RUN SUMMARY"
	if result_label != null:
		result_label.text = "The flame endured." if victory else "Your flame has faded..."
	if stats_label != null:
		stats_label.text = (
			"Rooms reached: %d / %d\n" % [rooms_reached, wave_manager.TOTAL_ROOMS]
			+ "Time survived: %02d:%02d\n" % [minutes, seconds]
			+ "Fire Fragments earned: %d\n" % earned_fire
			+ "Boss Fire Fragments earned: %d\n" % earned_boss
			+ "Cauldron: %s" % str(player.cauldron_id).replace("_", " ").to_upper()
		)
	if buffs_label != null:
		var acquired: Array[String] = []
		for buff_id in player.run_buffs.keys():
			var count: int = int(player.run_buffs[buff_id])
			if count > 0:
				acquired.append("%s ×%d" % [str(buff_id).replace("_", " ").to_upper(), count])
		buffs_label.text = "RUN UPGRADES\n" + (", ".join(acquired) if not acquired.is_empty() else "No upgrades collected")
	run_summary_overlay.visible = true


func restart_game() -> void:
	get_tree().paused = false
	get_tree().call_deferred("reload_current_scene")


func _draw() -> void:
	_draw_dungeon_backdrop()

	# Isometric arena floor.
	var tile_width = 80.0
	var tile_height = 40.0

	for x in range(-12, 13):
		for y in range(-12, 13):
			var center := Vector2(
				(x - y) * tile_width / 2.0,
				(x + y) * tile_height / 2.0
			)

			var tile := PackedVector2Array([
				center + Vector2(0, -tile_height / 2),
				center + Vector2(tile_width / 2, 0),
				center + Vector2(0, tile_height / 2),
				center + Vector2(-tile_width / 2, 0)
			])

			var tile_color := Color("#252B31")

			if (x + y) % 2 == 0:
				tile_color = Color("#2B3239")

			draw_colored_polygon(tile, tile_color)

			draw_polyline(
				PackedVector2Array([
					tile[0],
					tile[1],
					tile[2],
					tile[3],
					tile[0]
				]),
				Color("#39434B"),
				1.0
			)


func _draw_dungeon_backdrop() -> void:
	# A large, fixed world-space dungeon surrounds the arena. It is intentionally
	# much larger than the playable floor so camera movement never reveals grey.
	# The arena itself is roughly 960 x 960 world units across its diamond bounds.
	var bounds := Rect2(Vector2(-4200.0, -3200.0), Vector2(8400.0, 6400.0))
	draw_rect(bounds, Color("#171D23"))

	# Large, low-contrast masonry blocks keep the background readable and cheap.
	# This is drawn once with the scene, not rebuilt every frame.
	var brick_w: float = 220.0
	var brick_h: float = 110.0
	var columns: int = ceili(bounds.size.x / brick_w) + 1
	var rows: int = ceili(bounds.size.y / brick_h) + 1

	for row in range(rows):
		var y: float = bounds.position.y + float(row) * brick_h
		var offset: float = brick_w * 0.5 if row % 2 == 1 else 0.0
		draw_line(
			Vector2(bounds.position.x, y),
			Vector2(bounds.end.x, y),
			Color(0.24, 0.29, 0.33, 0.30),
			1.5
		)
		for column in range(columns):
			var x: float = bounds.position.x + float(column) * brick_w + offset
			if x <= bounds.end.x:
				draw_line(
					Vector2(x, y),
					Vector2(x, minf(y + brick_h, bounds.end.y)),
					Color(0.24, 0.29, 0.33, 0.22),
					1.2
				)

	# The floor is drawn as a diamond with vertices at approximately
	# (0, -500), (1000, 0), (0, 500), and (-1000, 0).
	# Place one torch at the midpoint of each actual sloping edge.
	# These are fixed world-space positions; the camera moves past them naturally.
	# Offset each torch farther outward from the floor edge so the floor
	# cannot visually overlap its flame or wall mount.
	var sconce_positions: Array[Vector2] = [
		Vector2(520.0, -290.0),   # upper-right edge, pushed outward
		Vector2(520.0, 290.0),    # lower-right edge, pushed outward
		Vector2(-520.0, 290.0),   # lower-left edge, pushed outward
		Vector2(-520.0, -290.0)   # upper-left edge, pushed outward
	]
	for i in range(sconce_positions.size()):
		_draw_dungeon_sconce(sconce_positions[i], float(i))

	# A handful of fixed, low-contrast stone imperfections.
	for i in range(18):
		var crack_x: float = -3900.0 + float((i * 613) % 7600)
		var crack_y: float = -2900.0 + float((i * 397) % 5600)
		var crack_points := PackedVector2Array([
			Vector2(crack_x, crack_y),
			Vector2(crack_x + 9.0, crack_y + 6.0),
			Vector2(crack_x + 5.0, crack_y + 15.0),
			Vector2(crack_x + 18.0, crack_y + 23.0)
		])
		draw_polyline(crack_points, Color(0.07, 0.09, 0.11, 0.42), 1.3)


func _draw_dungeon_sconce(position: Vector2, seed: float) -> void:
	# A fixed per-sconce variation keeps the flames from looking identical.
	var flame_height: float = 11.0 + fposmod(seed * 1.7, 2.5)
	var glow_radius: float = 31.0 + fposmod(seed * 2.1, 3.0)

	draw_circle(position + Vector2(0, -8), glow_radius, Color(1.0, 0.39, 0.10, 0.035))
	draw_circle(position + Vector2(0, -8), glow_radius * 0.55, Color(1.0, 0.48, 0.14, 0.055))

	# Iron wall bracket and shallow bowl.
	draw_rect(Rect2(position.x - 7, position.y + 1, 14, 8), Color("#252B30"))
	draw_rect(Rect2(position.x - 9, position.y + 7, 18, 3), Color("#59616A"))
	draw_line(position + Vector2(0, 2), position + Vector2(0, -7), Color("#74716A"), 3.0)
	draw_circle(position + Vector2(0, -7), 4.5, Color("#A45A2B"))

	# Two nested flame silhouettes give each torch a warm, fixed flame.
	var outer := PackedVector2Array([
		position + Vector2(0, -5 - flame_height),
		position + Vector2(-5, -8),
		position + Vector2(-2, -12),
		position + Vector2(3, -8),
		position + Vector2(5, -13),
		position + Vector2(3, -5)
	])
	draw_colored_polygon(outer, Color(1.0, 0.40, 0.10, 0.92))
	var inner := PackedVector2Array([
		position + Vector2(0, -7 - flame_height * 0.62),
		position + Vector2(-2.5, -9),
		position + Vector2(1, -12),
		position + Vector2(2.5, -8)
	])
	draw_colored_polygon(inner, Color("#FFD88A"))
