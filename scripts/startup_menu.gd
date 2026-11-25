extends Control

const GAME_SCENE := "res://scenes/main.tscn"
const WORKSHOP_SCENE := preload("res://scenes/workshop_panel.tscn")

var splash_timer: float = 2.7
var showing_splash: bool = true
var content: VBoxContainer
var workshop_instance: Control
var background_art: Control


func _ready() -> void:
	AudioManager.play_music("menu")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background()
	if GameData.open_workshop_on_menu:
		GameData.open_workshop_on_menu = false
		_show_main_menu()
		_open_workshop()
	else:
		_show_splash()


func _process(delta: float) -> void:
	if showing_splash:
		splash_timer -= delta
		if splash_timer <= 0.0:
			_show_main_menu()


func _build_background() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#11171D")
	add_child(background)

	background_art = Control.new()
	background_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_art.draw.connect(_draw_background_art)
	add_child(background_art)


func _draw_background_art() -> void:
	var size := get_viewport_rect().size
	# A soft ember halo behind the title.
	background_art.draw_circle(
		Vector2(size.x * 0.5, size.y * 0.43),
		minf(size.x, size.y) * 0.34,
		Color(0.72, 0.25, 0.07, 0.07)
	)
	background_art.draw_circle(
		Vector2(size.x * 0.5, size.y * 0.43),
		minf(size.x, size.y) * 0.23,
		Color(0.95, 0.42, 0.08, 0.045)
	)
	for i in range(34):
		var x := fposmod(float(i) * 173.0 + 47.0, size.x)
		var y := fposmod(float(i) * 97.0 + 31.0, size.y)
		var radius := 1.0 + float(i % 3) * 0.6
		background_art.draw_circle(
			Vector2(x, y),
			radius,
			Color(1.0, 0.62, 0.27, 0.10 + float(i % 4) * 0.025)
		)


func _show_splash() -> void:
	showing_splash = true
	_clear_content()

	content = VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	content.position = Vector2(-260, -210)
	content.size = Vector2(520, 420)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	add_child(content)

	var logo := CauldronLogo.new()
	logo.custom_minimum_size = Vector2(220, 170)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(logo)

	var title := Label.new()
	title.text = "FIRE KEEPER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color("#FFE0A0"))
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "KEEP THE FLAME ALIVE"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color("#D18A4B"))
	content.add_child(subtitle)

	var hint := Label.new()
	hint.text = "Click to continue"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color("#89939A"))
	content.add_child(hint)


func _show_main_menu() -> void:
	showing_splash = false
	_clear_content()

	content = VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	content.position = Vector2(-190, -245)
	content.size = Vector2(380, 490)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 14)
	add_child(content)

	var logo := CauldronLogo.new()
	logo.custom_minimum_size = Vector2(180, 130)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(logo)

	var title := Label.new()
	title.text = "FIRE KEEPER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color("#FFE0A0"))
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "A LITTLE FLAME. A VERY BIG DUNGEON."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color("#C58B5C"))
	content.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	content.add_child(spacer)

	_add_menu_button("START GAME", _start_game)
	_add_menu_button("WORKSHOP", _open_workshop)
	_add_menu_button("CONTROLS", _show_controls)
	_add_menu_button("AUDIO SETTINGS", _show_audio_settings)

	var footer := Label.new()
	footer.text = "WASD TO MOVE  ·  KEEP YOUR FIRE BURNING"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color("#727E87"))
	content.add_child(footer)


func _show_audio_settings() -> void:
	_clear_content()
	content = VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	content.position = Vector2(-270, -220)
	content.size = Vector2(540, 440)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 18)
	add_child(content)

	var title := Label.new()
	title.text = "AUDIO SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#FFE0A0"))
	content.add_child(title)

	_add_audio_slider("MASTER VOLUME", AudioManager.master_volume, AudioManager.set_master_volume)
	_add_audio_slider("MUSIC VOLUME", AudioManager.music_volume, AudioManager.set_music_volume)
	_add_audio_slider("SOUND EFFECTS", AudioManager.sfx_volume, AudioManager.set_sfx_volume)

	var back := Button.new()
	back.text = "BACK TO MENU"
	back.custom_minimum_size = Vector2(240, 48)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_show_main_menu)
	content.add_child(back)


func _add_audio_slider(label_text: String, initial_value: float, setter: Callable) -> void:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 5)
	content.add_child(group)

	var heading := Label.new()
	heading.text = "%s  —  %d%%" % [label_text, roundi(initial_value * 100.0)]
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", Color("#F59E42"))
	group.add_child(heading)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = initial_value
	slider.custom_minimum_size = Vector2(420, 28)
	slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(value: float) -> void:
		setter.call(value)
		heading.text = "%s  —  %d%%" % [label_text, roundi(value * 100.0)]
	)
	group.add_child(slider)


func _show_controls() -> void:
	_clear_content()

	content = VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	content.position = Vector2(-300, -245)
	content.size = Vector2(600, 490)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 14)
	add_child(content)

	var title := Label.new()
	title.text = "CONTROLS & CURRENCIES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#FFE0A0"))
	content.add_child(title)

	_add_info_line("WASD / ARROW KEYS", "Move the cauldron around the arena.")
	_add_info_line("LEFT MOUSE BUTTON", "Attack in the direction of your cursor.")
	_add_info_line("Q", "Dash. Briefly evade danger; recharges over time. Thinner Cauldron stores two charges.")
	_add_info_line("E", "Fire Burst. Charge it by landing 20 successful hits.")
	_add_info_line("R", "Reload the Ranged or Shotgun Cauldron, even before the magazine is empty.")
	_add_info_line("FIRE FRAGMENTS", "Dropped by enemies. Spend 200 to unlock a special cauldron in the Workshop.")
	_add_info_line("BOSS FIRE FRAGMENTS", "Rare boss rewards. You can collect and view them in the Workshop, but they have no use yet.")
	_add_info_line("ROOM REWARDS", "Clear a room to choose one of three run upgrades. Your choice lasts until the run ends.")

	var back := Button.new()
	back.text = "BACK TO MENU"
	back.custom_minimum_size = Vector2(240, 48)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_show_main_menu)
	content.add_child(back)


func _add_info_line(heading_text: String, body_text: String) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	content.add_child(row)

	var heading := Label.new()
	heading.text = heading_text
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", Color("#F59E42"))
	row.add_child(heading)

	var body := Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color("#D5D8DA"))
	row.add_child(body)


func _add_menu_button(button_text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(280, 52)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(action)
	content.add_child(button)


func _start_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)




func _open_workshop() -> void:
	workshop_instance = WORKSHOP_SCENE.instantiate()
	add_child(workshop_instance)
	workshop_instance.closed.connect(_close_workshop)


func _close_workshop() -> void:
	if is_instance_valid(workshop_instance):
		workshop_instance.queue_free()
	workshop_instance = null


func _clear_content() -> void:
	if is_instance_valid(content):
		content.queue_free()
	content = null


func _input(event: InputEvent) -> void:
	if showing_splash and event is InputEventMouseButton and event.pressed:
		_show_main_menu()


class CauldronLogo extends Control:
	var animation_time: float = 0.0

	func _process(delta: float) -> void:
		animation_time += delta
		queue_redraw()

	func _draw() -> void:
		var bob := sin(animation_time * 2.2) * 3.0
		var center := Vector2(size.x * 0.5, size.y * 0.60 + bob)
		var cauldron_id: String = GameData.equipped_cauldron
		var flame_color := Color("#F59E42")
		if cauldron_id == "teal":
			flame_color = Color("#55D5C5")
		elif cauldron_id == "ranged":
			flame_color = Color("#E8B65A")
		elif cauldron_id == "thinner":
			flame_color = Color("#8EC7D9")
		elif cauldron_id == "broken":
			flame_color = Color("#B7A6D9")

		draw_circle(center + Vector2(0, 16), 62, Color(1.0, 0.38, 0.08, 0.10))
		draw_circle(center + Vector2(0, 16), 43, Color(1.0, 0.55, 0.12, 0.10))

		# Flame rising from the pot.
		draw_colored_polygon(
			PackedVector2Array([
				center + Vector2(-18, -34),
				center + Vector2(-13, -63),
				center + Vector2(1, -91 + sin(animation_time * 4.0) * 4.0),
				center + Vector2(15, -61),
				center + Vector2(19, -34)
			]),
			flame_color
		)
		draw_colored_polygon(
			PackedVector2Array([
				center + Vector2(-8, -35),
				center + Vector2(-5, -57),
				center + Vector2(3, -72 + sin(animation_time * 4.0) * 3.0),
				center + Vector2(10, -52),
				center + Vector2(9, -35)
			]),
			Color("#FFE39A")
		)

		# Cauldron silhouette changes to match the equipped vessel.
		var half_width := 42.0
		var body_color := Color("#343E47")
		if cauldron_id == "thinner":
			half_width = 31.0
		elif cauldron_id == "teal":
			body_color = Color("#31534F")
		elif cauldron_id == "broken":
			body_color = Color("#4A4147")
		elif cauldron_id == "shotgun":
			body_color = Color("#51443B")
		elif cauldron_id == "ranged":
			body_color = Color("#4B4540")
		draw_colored_polygon(
			PackedVector2Array([
				center + Vector2(-half_width, -27),
				center + Vector2(half_width, -27),
				center + Vector2(half_width - 8, 24),
				center + Vector2(20, 38),
				center + Vector2(-20, 38),
				center + Vector2(-half_width + 8, 24)
			]),
			body_color
		)
		draw_colored_polygon(
			PackedVector2Array([
				center + Vector2(-46, -32),
				center + Vector2(46, -32),
				center + Vector2(41, -22),
				center + Vector2(-41, -22)
			]),
			Color("#7B858A")
		)
		if cauldron_id == "spiky":
			for side in [-1.0, 1.0]:
				for i in range(3):
					var y := -8.0 + float(i) * 13.0
					draw_line(center + Vector2(side * 34.0, y), center + Vector2(side * 49.0, y + 2.0), Color("#C8B8B1"), 4.0)
		elif cauldron_id == "ranged":
			draw_rect(Rect2(center + Vector2(-7, -4), Vector2(14, 20)), Color("#242A30"))
		elif cauldron_id == "shotgun":
			draw_rect(Rect2(center + Vector2(-17, -43), Vector2(10, 24)), Color("#6C6257"))
			draw_rect(Rect2(center + Vector2(7, -43), Vector2(10, 24)), Color("#6C6257"))
		elif cauldron_id == "broken":
			draw_polyline(PackedVector2Array([center + Vector2(8, -23), center + Vector2(1, -7), center + Vector2(11, 2), center + Vector2(4, 17)]), Color("#E4D3C4"), 2.5)
		elif cauldron_id == "teal":
			for i in range(3):
				var angle := TAU * float(i) / 3.0
				draw_circle(center + Vector2.RIGHT.rotated(angle) * 55.0, 4.5, flame_color)

		draw_circle(center + Vector2(-12, -4), 4, Color("#FFE49A"))
		draw_circle(center + Vector2(12, -4), 4, Color("#FFE49A"))
		draw_line(center + Vector2(-9, 13), center + Vector2(9, 13), Color("#151A1F"), 3.0)
