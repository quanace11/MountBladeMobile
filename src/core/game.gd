extends Node
## Vòng đời game: lựa chọn trận, cài đặt người chơi, chuyển màn.

const SETTINGS_PATH := "user://settings.cfg"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const MATCH_SCENE := "res://scenes/match.tscn"

var match_id: StringName = &"1v1"
var bot_id: StringName = &"easy"
var player_character_id: StringName = &"dao_tuong"
var quality_id: StringName = &"medium"
var block_scheme: int = InputConfig.BlockScheme.BUTTON
var fps_cap_30: bool = false


func _ready() -> void:
	block_scheme = ConfigDB.input.block_scheme
	_load_settings()
	apply_fps_cap()


func current_match() -> MatchDef:
	return ConfigDB.matches.get(match_id)


func current_bot() -> BotProfile:
	return ConfigDB.bots.get(bot_id)


func current_quality() -> QualityPreset:
	return ConfigDB.qualities.get(quality_id)


func player_character() -> CharacterDef:
	var c: CharacterDef = ConfigDB.characters.get(player_character_id)
	return c if c else current_match().player_character


func apply_fps_cap() -> void:
	var q := current_quality()
	Engine.max_fps = 30 if fps_cap_30 else (q.target_fps if q else 60)


func start_match() -> void:
	save_settings()
	get_tree().change_scene_to_file(MATCH_SCENE)


func back_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "match", match_id)
	cfg.set_value("game", "bot", bot_id)
	cfg.set_value("game", "character", player_character_id)
	cfg.set_value("game", "quality", quality_id)
	cfg.set_value("game", "block_scheme", block_scheme)
	cfg.set_value("game", "fps30", fps_cap_30)
	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	match_id = cfg.get_value("game", "match", match_id)
	bot_id = cfg.get_value("game", "bot", bot_id)
	player_character_id = cfg.get_value("game", "character", player_character_id)
	quality_id = cfg.get_value("game", "quality", quality_id)
	block_scheme = cfg.get_value("game", "block_scheme", block_scheme)
	fps_cap_30 = cfg.get_value("game", "fps30", fps_cap_30)
