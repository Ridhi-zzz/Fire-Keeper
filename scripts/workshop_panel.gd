extends Control

signal closed

const CAULDRONS := [
	{"id":"default", "name":"Hearth Cauldron", "description":"The original flame keeper. Balanced, dependable, and always available.", "ability":"Standard melee attack and the familiar Fire Burst.", "cost":0, "accent":Color("#F59E42")},
	{"id":"spiky", "name":"Spiky Cauldron", "description":"Turn close-quarters aggression against your enemies.", "ability":"Melee attackers take half a heart of damage when they hit you.", "cost":200, "accent":Color("#C5A6A0")},
	{"id":"ranged", "name":"Ranged Cauldron", "description":"Keep your distance and make every shot count.", "ability":"Six mouse-aimed shots per magazine. Half damage per shot; 2-second reload.", "cost":200, "accent":Color("#E8B65A")},
	{"id":"teal", "name":"Teal Cauldron", "description":"A rotating ring of flame keeps danger at bay.", "ability":"Sweeping three-fireball attack inspired by the melee lantern.", "cost":200, "accent":Color("#55D5C5")},
	{"id":"shotgun", "name":"Shotgun Cauldron", "description":"A heavier answer for anything standing in front of you.", "ability":"Two mouse-aimed bursts per magazine. Each burst deals 1 damage; 2-second reload.", "cost":200, "accent":Color("#E17B45")},
	{"id":"thinner", "name":"Thinner Cauldron", "description":"Less bulk, more room to get out of trouble.", "ability":"Starts with two dash charges.", "cost":200, "accent":Color("#8EC7D9")},
	{"id":"broken", "name":"Broken Cauldron", "description":"A fragile vessel with a dangerously strong flame.", "ability":"Two-heart maximum, cannot increase max health, 35% enemy health-drop chance, and 2 base damage.", "cost":200, "accent":Color("#B7A6D9")}
]

var status_label: Label
var small_currency_label: Label
var large_currency_label: Label
var items_container: VBoxContainer
var carousel_preview: CauldronPreview
var cauldron_name_label: Label
var cauldron_description_label: Label
var cauldron_ability_label: Label
var cauldron_action_button: Button
var cauldron_index: int = 0
var message_timer: float = 0.0
var reset_confirmation: ConfirmationDialog


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cauldron_index = _find_cauldron_index(GameData.equipped_cauldron)
	_build_interface()
	_refresh()


func _process(delta: float) -> void:
	if message_timer > 0.0:
		message_timer -= delta
		if message_timer <= 0.0 and is_instance_valid(status_label):
			status_label.text = ""


func _build_interface() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.025, 0.03, 0.04, 0.97)
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(650, 0)
	center.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)

	var header := HBoxContainer.new()
	outer.add_child(header)

	var title := Label.new()
	title.text = "THE WORKSHOP"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#FFB66A"))
	header.add_child(title)

	var back_button := Button.new()
	back_button.text = "BACK"
	back_button.custom_minimum_size = Vector2(90, 38)
	back_button.pressed.connect(_on_back_pressed)
	header.add_child(back_button)

	var subtitle := Label.new()
	subtitle.text = "Choose the vessel that will carry your flame."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_color", Color("#D5C8B5"))
	outer.add_child(subtitle)

	var currency_row := HBoxContainer.new()
	currency_row.add_theme_constant_override("separation", 24)
	outer.add_child(currency_row)

	small_currency_label = Label.new()
	small_currency_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	small_currency_label.add_theme_color_override("font_color", Color("#FFC16E"))
	currency_row.add_child(small_currency_label)

	large_currency_label = Label.new()
	large_currency_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	large_currency_label.add_theme_color_override("font_color", Color("#FFE7A0"))
	currency_row.add_child(large_currency_label)

	_add_section_heading_to(outer, "CAULDRON COLLECTION")

	var carousel := HBoxContainer.new()
	carousel.alignment = BoxContainer.ALIGNMENT_CENTER
	carousel.add_theme_constant_override("separation", 12)
	outer.add_child(carousel)

	var previous_button := Button.new()
	previous_button.text = "<"
	previous_button.custom_minimum_size = Vector2(48, 58)
	previous_button.add_theme_font_size_override("font_size", 24)
	previous_button.pressed.connect(_previous_cauldron)
	carousel.add_child(previous_button)

	var showcase := VBoxContainer.new()
	showcase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	showcase.add_theme_constant_override("separation", 4)
	carousel.add_child(showcase)

	carousel_preview = CauldronPreview.new()
	carousel_preview.custom_minimum_size = Vector2(260, 150)
	carousel_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	showcase.add_child(carousel_preview)

	cauldron_name_label = Label.new()
	cauldron_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cauldron_name_label.add_theme_font_size_override("font_size", 23)
	cauldron_name_label.add_theme_color_override("font_color", Color("#FFE0A0"))
	showcase.add_child(cauldron_name_label)

	cauldron_description_label = Label.new()
	cauldron_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cauldron_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cauldron_description_label.custom_minimum_size = Vector2(0, 34)
	cauldron_description_label.add_theme_font_size_override("font_size", 13)
	cauldron_description_label.add_theme_color_override("font_color", Color("#C6C0B8"))
	showcase.add_child(cauldron_description_label)

	cauldron_ability_label = Label.new()
	cauldron_ability_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cauldron_ability_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cauldron_ability_label.custom_minimum_size = Vector2(0, 42)
	cauldron_ability_label.add_theme_font_size_override("font_size", 13)
	cauldron_ability_label.add_theme_color_override("font_color", Color("#E8B879"))
	showcase.add_child(cauldron_ability_label)

	var next_button := Button.new()
	next_button.text = ">"
	next_button.custom_minimum_size = Vector2(48, 58)
	next_button.add_theme_font_size_override("font_size", 24)
	next_button.pressed.connect(_next_cauldron)
	carousel.add_child(next_button)

	var dots := Label.new()
	dots.name = "CarouselCounter"
	dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dots.add_theme_color_override("font_color", Color("#8D9298"))
	outer.add_child(dots)

	cauldron_action_button = Button.new()
	cauldron_action_button.custom_minimum_size = Vector2(0, 46)
	cauldron_action_button.pressed.connect(_on_cauldron_action)
	outer.add_child(cauldron_action_button)

	outer.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 170)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)

	items_container = VBoxContainer.new()
	items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_container.add_theme_constant_override("separation", 8)
	scroll.add_child(items_container)

	status_label = Label.new()
	status_label.custom_minimum_size = Vector2(0, 22)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color("#FFE0A0"))
	outer.add_child(status_label)

	reset_confirmation = ConfirmationDialog.new()
	reset_confirmation.title = "Reset Fire Keeper?"
	reset_confirmation.dialog_text = "This erases saved currencies and cauldron unlocks. Are you sure?"
	reset_confirmation.ok_button_text = "RESET EVERYTHING"
	reset_confirmation.confirmed.connect(_confirm_reset)
	add_child(reset_confirmation)

	var reset_button := Button.new()
	reset_button.text = "RESET ALL SAVE DATA"
	reset_button.custom_minimum_size = Vector2(0, 32)
	reset_button.add_theme_color_override("font_color", Color("#FF9A8C"))
	reset_button.pressed.connect(_on_reset_pressed)
	outer.add_child(reset_button)


func _add_section_heading_to(parent: VBoxContainer, text_value: String) -> void:
	var heading := Label.new()
	heading.text = text_value
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", Color("#F59E42"))
	parent.add_child(heading)


func _find_cauldron_index(cauldron_id: String) -> int:
	for i in range(CAULDRONS.size()):
		if CAULDRONS[i]["id"] == cauldron_id:
			return i
	return 0


func _previous_cauldron() -> void:
	cauldron_index = posmod(cauldron_index - 1, CAULDRONS.size())
	_refresh_cauldron()


func _next_cauldron() -> void:
	cauldron_index = posmod(cauldron_index + 1, CAULDRONS.size())
	_refresh_cauldron()


func _refresh_cauldron() -> void:
	var data: Dictionary = CAULDRONS[cauldron_index]
	var cauldron_id: String = data["id"]
	var unlocked: bool = GameData.unlocked_cauldrons.has(cauldron_id)
	var equipped: bool = GameData.equipped_cauldron == cauldron_id

	carousel_preview.cauldron_id = cauldron_id
	carousel_preview.accent = data["accent"]
	carousel_preview.queue_redraw()
	cauldron_name_label.text = data["name"]
	cauldron_description_label.text = data["description"]
	cauldron_ability_label.text = data["ability"]

	var counter := find_child("CarouselCounter", true, false) as Label
	if counter:
		counter.text = str(cauldron_index + 1) + "  /  " + str(CAULDRONS.size())

	if equipped:
		cauldron_action_button.text = "EQUIPPED"
		cauldron_action_button.disabled = true
	elif unlocked:
		cauldron_action_button.text = "EQUIP CAULDRON"
		cauldron_action_button.disabled = false
	else:
		cauldron_action_button.text = "UNLOCK  ·  200 FIRE FRAGMENTS"
		cauldron_action_button.disabled = false


func _on_cauldron_action() -> void:
	var data: Dictionary = CAULDRONS[cauldron_index]
	var cauldron_id: String = data["id"]

	if GameData.unlocked_cauldrons.has(cauldron_id):
		GameData.equip_cauldron(cauldron_id)
		_show_message(str(data["name"]) + " equipped.")
	else:
		if not GameData.spend_fire_fragments(200):
			_show_message("You need 200 Fire Fragments.")
			return
		GameData.unlock_cauldron(cauldron_id)
		GameData.equip_cauldron(cauldron_id)
		_show_message(str(data["name"]) + " unlocked and equipped.")

	_refresh()


func _refresh() -> void:
	if not is_instance_valid(items_container):
		return

	small_currency_label.text = "SMALL FIRES: " + str(GameData.fire_fragments)
	large_currency_label.text = "BOSS FRAGMENTS: " + str(GameData.boss_fire_fragments)

	for child in items_container.get_children():
		child.queue_free()

	_refresh_cauldron()


func _show_message(message: String) -> void:
	status_label.text = message
	message_timer = 2.5


func _on_reset_pressed() -> void:
	reset_confirmation.popup_centered()


func _confirm_reset() -> void:
	GameData.reset_save_data()
	cauldron_index = 0
	_refresh()
	_show_message("Save data reset. Fresh start!")


func _on_back_pressed() -> void:
	closed.emit()


class CauldronPreview extends Control:
	var cauldron_id: String = "default"
	var accent: Color = Color("#F59E42")

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.64)
		draw_circle(c + Vector2(0, 7), 82, Color(accent.r, accent.g, accent.b, 0.09))
		draw_circle(c + Vector2(0, 7), 58, Color(accent.r, accent.g, accent.b, 0.08))

		# Flame silhouette and warm inner core.
		var flame_height := 66.0
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(-20, -32), c + Vector2(-15, -65),
			c + Vector2(0, -32 - flame_height), c + Vector2(17, -64),
			c + Vector2(21, -32)
		]), accent)
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(-8, -30), c + Vector2(-4, -53),
			c + Vector2(1, -78), c + Vector2(10, -49),
			c + Vector2(9, -30)
		]), Color("#FFE5A1"))

		var half_width := 48.0
		var body_color := Color("#39434B")
		if cauldron_id == "thinner":
			half_width = 34.0
		elif cauldron_id == "broken":
			body_color = Color("#4A4147")
		elif cauldron_id == "ranged":
			body_color = Color("#4B4540")
		elif cauldron_id == "teal":
			body_color = Color("#31534F")
		elif cauldron_id == "spiky":
			body_color = Color("#454047")
		elif cauldron_id == "shotgun":
			body_color = Color("#51443B")

		var body := PackedVector2Array([
			c + Vector2(-half_width, -28), c + Vector2(half_width, -28),
			c + Vector2(half_width - 9, 23), c + Vector2(22, 40),
			c + Vector2(-22, 40), c + Vector2(-half_width + 9, 23)
		])
		draw_colored_polygon(body, body_color)
		draw_arc(c + Vector2(0, -27), half_width, PI, TAU, 32, Color("#A6A49A"), 6.0)
		draw_line(c + Vector2(-half_width + 3, -21), c + Vector2(half_width - 3, -21), accent, 3.0)

		# Individual silhouettes / identifying details.
		match cauldron_id:
			"spiky":
				for side in [-1.0, 1.0]:
					for i in range(3):
						var y := -10.0 + float(i) * 15.0
						draw_colored_polygon(PackedVector2Array([
							c + Vector2(side * (half_width - 4), y - 5),
							c + Vector2(side * (half_width + 17), y),
							c + Vector2(side * (half_width - 4), y + 5)
						]), Color("#C8B8B1"))
			"ranged":
				draw_rect(Rect2(c + Vector2(-8, -4), Vector2(16, 26)), Color("#242A30"))
				draw_circle(c + Vector2(0, -2), 7, accent)
			"teal":
				for i in range(3):
					var angle := TAU * float(i) / 3.0
					draw_circle(c + Vector2.RIGHT.rotated(angle) * 65.0, 7, accent)
			"shotgun":
				draw_rect(Rect2(c + Vector2(-20, -44), Vector2(12, 27)), Color("#6C6257"))
				draw_rect(Rect2(c + Vector2(8, -44), Vector2(12, 27)), Color("#6C6257"))
			"thinner":
				draw_line(c + Vector2(-18, 39), c + Vector2(-28, 48), accent, 4.0)
				draw_line(c + Vector2(18, 39), c + Vector2(28, 48), accent, 4.0)
			"broken":
				draw_polyline(PackedVector2Array([
					c + Vector2(8, -24), c + Vector2(1, -7),
					c + Vector2(12, 2), c + Vector2(4, 18)
				]), Color("#E4D3C4"), 3.0)
				draw_polyline(PackedVector2Array([
					c + Vector2(-26, -27), c + Vector2(-33, -38),
					c + Vector2(-22, -42)
				]), Color("#E4D3C4"), 3.0)

		draw_circle(c + Vector2(-15, 0), 4, Color("#FFE49A"))
		draw_circle(c + Vector2(15, 0), 4, Color("#FFE49A"))
