extends Node2D

const PLAYER_SCENE = preload("res://scenes/player.tscn")
const CANDLE_SCENE = preload("res://scenes/candle.tscn")
const MELEE_LANTERN_SCENE = preload("res://scenes/lantern_melee.tscn")
const RANGED_LANTERN_SCENE = preload("res://scenes/lantern_ranged.tscn")
const CANDLE_GOLEM_SCENE = preload("res://scenes/candle_golem.tscn")
const LANTERN_BOSS_SCENE = preload("res://scenes/lantern_boss.tscn")

const CAULDRON_OPTIONS := [
	{"id":"default", "label":"1  HEARTH"},
	{"id":"spiky", "label":"2  SPIKY"},
	{"id":"ranged", "label":"3  RANGED"},
	{"id":"teal", "label":"4  TEAL"},
	{"id":"shotgun", "label":"5  SHOTGUN"},
	{"id":"thinner", "label":"6  THINNER"},
	{"id":"broken", "label":"7  BROKEN"}
]

var player: Node2D
var stats_label: Label
var instruction_label: Label
var cauldron_status_label: Label
var boss_name_label: Label
var boss_heart_display: Control
var selector_buttons: Array[Button] = []


func _ready() -> void:
	randomize()
	player = PLAYER_SCENE.instantiate()
	player.position = Vector2(0, 170)
	add_child(player)
	player.stats_changed.connect(_update_stats)
	_create_test_dummies()
	_create_test_hud()
	queue_redraw()


func _create_test_dummies() -> void:
	# Each normal enemy archetype is represented by a stationary training dummy.
	# They still wind up and attack, making Spiky Cauldron testable.
	var candle_melee = CANDLE_SCENE.instantiate()
	candle_melee.add_to_group("test_dummies")
	candle_melee.name = "CandleMeleeDummy"
	candle_melee.set("attack_style", 0)
	candle_melee.set("training_dummy", true)
	candle_melee.position = Vector2(-250, -40)
	candle_melee.set_target(player)
	add_child(candle_melee)
	_add_dummy_label(candle_melee, "MELEE CANDLE")

	var candle_ranged = CANDLE_SCENE.instantiate()
	candle_ranged.add_to_group("test_dummies")
	candle_ranged.name = "CandleRangedDummy"
	candle_ranged.set("attack_style", 1)
	candle_ranged.set("training_dummy", true)
	candle_ranged.position = Vector2(-120, -210)
	candle_ranged.set_target(player)
	add_child(candle_ranged)
	_add_dummy_label(candle_ranged, "RANGED CANDLE")

	var melee_lantern = MELEE_LANTERN_SCENE.instantiate()
	melee_lantern.add_to_group("test_dummies")
	melee_lantern.name = "MeleeLanternDummy"
	melee_lantern.set("training_dummy", true)
	melee_lantern.position = Vector2(120, -210)
	melee_lantern.set_target(player)
	add_child(melee_lantern)
	_add_dummy_label(melee_lantern, "MELEE LANTERN")

	var ranged_lantern = RANGED_LANTERN_SCENE.instantiate()
	ranged_lantern.add_to_group("test_dummies")
	ranged_lantern.name = "RangedLanternDummy"
	ranged_lantern.set("training_dummy", true)
	ranged_lantern.position = Vector2(250, -40)
	ranged_lantern.set_target(player)
	add_child(ranged_lantern)
	_add_dummy_label(ranged_lantern, "RANGED LANTERN")

	var golem = CANDLE_GOLEM_SCENE.instantiate()
	golem.add_to_group("test_dummies")
	golem.name = "CandleGolemDummy"
	golem.set("ai_enabled", false)
	golem.position = Vector2(-390, 130)
	add_child(golem)
	_add_dummy_label(golem, "CANDLE GOLEM")

	var warden = LANTERN_BOSS_SCENE.instantiate()
	warden.add_to_group("test_dummies")
	warden.name = "LanternBossPreview"
	warden.set("training_dummy", true)
	warden.position = Vector2(390, 130)
	add_child(warden)
	_add_dummy_label(warden, "LANTERN WARDEN")


func _add_dummy_label(dummy: Node2D, label_text: String) -> void:
	var label := Label.new()
	label.text = label_text
	label.position = Vector2(-62.0, -62.0)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("#D6DCE0"))
	dummy.add_child(label)


func _reset_test_dummies() -> void:
	for dummy in get_tree().get_nodes_in_group("test_dummies"):
		if is_instance_valid(dummy):
			dummy.queue_free()
	call_deferred("_create_test_dummies")


func _create_test_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 5
	add_child(canvas)

	var title := Label.new()
	title.text = "FIRE KEEPER  ·  CAULDRON TEST ARENA"
	title.position = Vector2(20, 12)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("#FFE0A0"))
	canvas.add_child(title)

	stats_label = Label.new()
	stats_label.position = Vector2(20, 42)
	stats_label.add_theme_font_size_override("font_size", 16)
	stats_label.add_theme_color_override("font_color", Color("#FFF0C4"))
	canvas.add_child(stats_label)

	cauldron_status_label = Label.new()
	cauldron_status_label.position = Vector2(20, 67)
	cauldron_status_label.add_theme_font_size_override("font_size", 15)
	cauldron_status_label.add_theme_color_override("font_color", Color("#77E4D4"))
	canvas.add_child(cauldron_status_label)

	instruction_label = Label.new()
	instruction_label.text = "WASD Move  ·  Mouse Aim / Click Attack  ·  Q Dash  ·  E Fire Burst  ·  R Reload  ·  1–7 Switch Cauldron  ·  H Heal  ·  T Reset Dummies"
	instruction_label.position = Vector2(20, 94)
	instruction_label.add_theme_font_size_override("font_size", 13)
	instruction_label.add_theme_color_override("font_color", Color("#C5C9CE"))
	canvas.add_child(instruction_label)

	var selector_panel := PanelContainer.new()
	selector_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	selector_panel.offset_left = 16
	selector_panel.offset_right = -16
	selector_panel.offset_top = -64
	selector_panel.offset_bottom = -12
	canvas.add_child(selector_panel)

	var selector := HBoxContainer.new()
	selector.add_theme_constant_override("separation", 5)
	selector_panel.add_child(selector)

	for option in CAULDRON_OPTIONS:
		var button := Button.new()
		button.text = option["label"]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 42)
		button.pressed.connect(_select_cauldron.bind(str(option["id"])))
		selector.add_child(button)
		selector_buttons.append(button)

	boss_name_label = Label.new()
	boss_name_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_name_label.position = Vector2(-160, 12)
	boss_name_label.size = Vector2(320, 24)
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.add_theme_font_size_override("font_size", 15)
	boss_name_label.add_theme_color_override("font_color", Color("#FFE0A0"))
	canvas.add_child(boss_name_label)

	var boss_health_label := Label.new()
	boss_health_label.name = "BossDummyHealth"
	boss_health_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_health_label.position = Vector2(-160, 36)
	boss_health_label.size = Vector2(320, 24)
	boss_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_health_label.add_theme_color_override("font_color", Color("#F5C0B9"))
	canvas.add_child(boss_health_label)

	_update_stats(player.fire_fragments, player.health)
	_update_cauldron_status()


func _process(_delta: float) -> void:
	_update_character_sorting()
	if is_instance_valid(player):
		_update_stats(player.fire_fragments, player.health)
		_update_cauldron_status()
	_update_boss_health_display()


func _update_character_sorting() -> void:
	for group_name in ["players", "enemies"]:
		for character in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(character) and character is Node2D:
				character.z_index = clampi(100 + roundi(character.global_position.y), 0, 200)


func _select_cauldron(cauldron_id: String) -> void:
	if is_instance_valid(player) and player.has_method("set_cauldron_for_test"):
		player.set_cauldron_for_test(cauldron_id)
	_update_cauldron_status()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/startup_menu.tscn")
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_7:
		var index := int(event.keycode - KEY_1)
		_select_cauldron(str(CAULDRON_OPTIONS[index]["id"]))
	elif event.keycode == KEY_H:
		player.health = player.max_health
		player.stats_changed.emit(player.fire_fragments, player.health)
	elif event.keycode == KEY_T:
		_reset_test_dummies()


func _update_stats(fire_amount: int, current_health: int) -> void:
	if not is_instance_valid(stats_label):
		return
	stats_label.text = "HP: %d / %d     FIRE FRAGMENTS: %d     BOSS FRAGMENTS: %d" % [
		current_health, player.max_health, fire_amount, GameData.boss_fire_fragments
	]


func _update_cauldron_status() -> void:
	if is_instance_valid(cauldron_status_label) and is_instance_valid(player):
		cauldron_status_label.text = player.get_cauldron_status()


func _update_boss_health_display() -> void:
	var warden := get_node_or_null("LanternBossPreview")
	var label := get_tree().current_scene.find_child("BossDummyHealth", true, false) as Label
	if not is_instance_valid(label):
		return
	if warden == null:
		label.text = ""
		return
	label.text = "LANTERN WARDEN  ·  %s / %s" % [str(warden.get("health")), str(warden.get("max_health"))]


func _draw() -> void:
	var tile_width: float = 80.0
	var tile_height: float = 40.0
	for x in range(-12, 13):
		for y in range(-12, 13):
			var center := Vector2((x - y) * tile_width / 2.0, (x + y) * tile_height / 2.0)
			var tile := PackedVector2Array([
				center + Vector2(0, -tile_height / 2.0),
				center + Vector2(tile_width / 2.0, 0),
				center + Vector2(0, tile_height / 2.0),
				center + Vector2(-tile_width / 2.0, 0)
			])
			var tile_color := Color("#252B31") if (x + y) % 2 else Color("#2B3239")
			draw_colored_polygon(tile, tile_color)
			draw_polyline(PackedVector2Array([tile[0], tile[1], tile[2], tile[3], tile[0]]), Color("#39434B"), 1.0)
