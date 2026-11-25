extends Node

const SAVE_PATH := "user://fire_keeper_save.cfg"

var fire_fragments: int = 0
var boss_fire_fragments: int = 0
var permanent_damage_bonus: int = 0
var permanent_health_bonus: int = 0
var unlocked_skins: Array = ["default"]
var selected_skin: String = "default"
var unlocked_cauldrons: Array = ["default"]
var equipped_cauldron: String = "default"
var pending_temp_upgrades: Array = []
var open_workshop_on_menu: bool = false


func _ready() -> void:
	load_game()


func load_game() -> void:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)
	if error != OK:
		return

	fire_fragments = int(config.get_value("currency", "fire_fragments", 0))
	boss_fire_fragments = int(config.get_value("currency", "boss_fire_fragments", 0))
	permanent_damage_bonus = int(config.get_value("upgrades", "damage", 0))
	permanent_health_bonus = int(config.get_value("upgrades", "health", 0))
	unlocked_skins = config.get_value("cosmetics", "unlocked_skins", ["default"])
	selected_skin = str(config.get_value("cosmetics", "selected_skin", "default"))
	pending_temp_upgrades = config.get_value("run", "pending_temp_upgrades", [])
	unlocked_cauldrons = config.get_value("cauldrons", "unlocked", ["default"])
	equipped_cauldron = str(config.get_value("cauldrons", "equipped", "default"))
	if not unlocked_cauldrons.has("default"):
		unlocked_cauldrons.append("default")
	if not unlocked_cauldrons.has(equipped_cauldron):
		equipped_cauldron = "default"


func save_game() -> void:
	var config := ConfigFile.new()
	config.set_value("currency", "fire_fragments", fire_fragments)
	config.set_value("currency", "boss_fire_fragments", boss_fire_fragments)
	config.set_value("upgrades", "damage", permanent_damage_bonus)
	config.set_value("upgrades", "health", permanent_health_bonus)
	config.set_value("cosmetics", "unlocked_skins", unlocked_skins)
	config.set_value("cosmetics", "selected_skin", selected_skin)
	config.set_value("run", "pending_temp_upgrades", pending_temp_upgrades)
	config.set_value("cauldrons", "unlocked", unlocked_cauldrons)
	config.set_value("cauldrons", "equipped", equipped_cauldron)
	config.save(SAVE_PATH)


func add_fire_fragments(amount: int) -> void:
	fire_fragments = maxi(0, fire_fragments + amount)
	save_game()


func add_boss_fire_fragments(amount: int) -> void:
	boss_fire_fragments = maxi(0, boss_fire_fragments + amount)
	save_game()


func spend_fire_fragments(amount: int) -> bool:
	if amount < 0 or fire_fragments < amount:
		return false
	fire_fragments -= amount
	save_game()
	return true


func spend_boss_fire_fragments(amount: int) -> bool:
	if amount < 0 or boss_fire_fragments < amount:
		return false
	boss_fire_fragments -= amount
	save_game()
	return true


func queue_temporary_upgrade(upgrade_id: String) -> void:
	pending_temp_upgrades.append(upgrade_id)
	save_game()


func take_pending_temp_upgrades() -> Array[String]:
	var result: Array[String] = []
	for upgrade_id in pending_temp_upgrades:
		result.append(str(upgrade_id))
	pending_temp_upgrades.clear()
	save_game()
	return result


func unlock_skin(skin_id: String) -> void:
	if not unlocked_skins.has(skin_id):
		unlocked_skins.append(skin_id)
	save_game()


func select_skin(skin_id: String) -> void:
	if unlocked_skins.has(skin_id):
		selected_skin = skin_id
		save_game()


func unlock_cauldron(cauldron_id: String) -> void:
	if not unlocked_cauldrons.has(cauldron_id):
		unlocked_cauldrons.append(cauldron_id)
		save_game()


func equip_cauldron(cauldron_id: String) -> void:
	if unlocked_cauldrons.has(cauldron_id):
		equipped_cauldron = cauldron_id
		save_game()



func reset_save_data() -> void:
	# Restore every saved value to a brand-new game.
	fire_fragments = 0
	boss_fire_fragments = 0
	permanent_damage_bonus = 0
	permanent_health_bonus = 0
	unlocked_skins = ["default"]
	selected_skin = "default"
	unlocked_cauldrons = ["default"]
	equipped_cauldron = "default"
	pending_temp_upgrades.clear()

	var config := ConfigFile.new()
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_error("Could not reset Fire Keeper save data. Error: " + str(error))
