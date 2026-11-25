extends Node

const SFX_PATH := "res://audio/"
const MUSIC_PATH := "res://audio/"

var master_volume: float = 1.0
var music_volume: float = 0.55
var sfx_volume: float = 0.8

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0
var _current_music: String = ""

const SFX_FILES := {
	"dash": "dash.wav",
	"melee": "melee.wav",
	"fire_burst": "fire_burst.wav",
	"player_hit": "player_hit.wav",
	"enemy_hit": "enemy_hit.wav",
	"enemy_death": "enemy_death.wav",
	"projectile": "projectile.wav",
	"pickup": "pickup.wav",
	"upgrade": "upgrade.wav",
	"boss_warn": "boss_warn.wav",
	"boss_shield": "boss_shield.wav",
	"ui_click": "ui_click.wav",
	"room_clear": "room_clear.wav"
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	add_child(_music_player)
	for i in range(8):
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer%d" % i
		add_child(player)
		_sfx_players.append(player)
	_load_settings()

func play_sfx(sound_name: String, volume_scale: float = 1.0) -> void:
	if not SFX_FILES.has(sound_name):
		return
	var stream := load(SFX_PATH + SFX_FILES[sound_name]) as AudioStream
	if stream == null:
		return
	var player := _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_players.size()
	player.stop()
	player.stream = stream
	player.volume_db = linear_to_db(maxf(0.001, master_volume * sfx_volume * volume_scale))
	player.play()

func play_music(track_name: String, fade_in: bool = true) -> void:
	if _current_music == track_name and _music_player.playing:
		return
	var file_name := "dungeon_music.wav" if track_name == "dungeon" else "menu_music.wav"
	var stream := load(MUSIC_PATH + file_name) as AudioStreamWAV
	if stream == null:
		return
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * float(stream.mix_rate))
	_current_music = track_name
	_music_player.stop()
	_music_player.stream = stream
	_music_player.volume_db = linear_to_db(maxf(0.001, master_volume * music_volume))
	_music_player.play()

func stop_music() -> void:
	_music_player.stop()
	_current_music = ""

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_update_music_volume()
	_save_settings()

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_update_music_volume()
	_save_settings()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_save_settings()

func _update_music_volume() -> void:
	_music_player.volume_db = linear_to_db(maxf(0.001, master_volume * music_volume))

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://fire_keeper_audio.cfg") == OK:
		master_volume = float(config.get_value("audio", "master", 1.0))
		music_volume = float(config.get_value("audio", "music", 0.55))
		sfx_volume = float(config.get_value("audio", "sfx", 0.8))
	_update_music_volume()

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.save("user://fire_keeper_audio.cfg")
