extends Node
## Vòng đời game: lựa chọn trận, cài đặt người chơi, chuyển màn.

const SETTINGS_PATH := "user://settings.cfg"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const MATCH_SCENE := "res://scenes/match.tscn"

var match_id: StringName = &"1v1"
var bot_id: StringName = &"easy"
var player_character_id: StringName = &"dao_tuong"
## Nhân vật (model 3D) của người chơi, theo tên file trong config/models.
var player_model_id: StringName = &"tuongtrang"
var quality_id: StringName = &"medium"
var fps_cap_30: bool = false
## Chế độ điều khiển (ControlPrefs.Mode) và bộ tự chỉnh dùng khi chọn CUSTOM.
var control_mode: int = ControlPrefs.Mode.FREE
var custom_controls := ControlPrefs.new()

## Chế độ vượt tháp (PvE): tầng N đấu 1 vs N, thắng thì lên tầng tiếp, tới tầng TOWER_FLOORS.
const TOWER_FLOORS := 10
var tower_mode: bool = false
var tower_floor: int = 1
## Tầng cao nhất đã qua (0 = chưa qua tầng nào). Được chọn mọi tầng tới tower_best + 1.
var tower_best: int = 0


func _ready() -> void:
	custom_controls.block_scheme = ConfigDB.input.block_scheme
	_load_settings()
	apply_fps_cap()


func current_match() -> MatchDef:
	if tower_mode:
		return tower_match(tower_floor)
	return ConfigDB.matches.get(match_id)


## Trận của một tầng tháp: tầng n có n địch, lần lượt các tướng trong config/characters.
func tower_match(floor_no: int) -> MatchDef:
	var keys := ConfigDB.sorted_keys(ConfigDB.characters)
	var md := MatchDef.new()
	md.id = StringName("tower_%d" % floor_no)
	md.display_name = "Tầng %d: 1 đấu %d" % [floor_no, floor_no]
	md.player_character = ConfigDB.characters.get(player_character_id, ConfigDB.characters[keys[0]])
	for i in floor_no:
		md.enemy_characters.append(ConfigDB.characters[keys[(i + 1) % keys.size()]])
	return md


func current_bot() -> BotProfile:
	return ConfigDB.bots.get(bot_id)


func current_quality() -> QualityPreset:
	return ConfigDB.qualities.get(quality_id)


func player_character() -> CharacterDef:
	var c: CharacterDef = ConfigDB.characters.get(player_character_id)
	return c if c else current_match().player_character


func player_model() -> CharacterModel:
	var m: CharacterModel = ConfigDB.models.get(player_model_id)
	return m if m else ConfigDB.game.player_model


## Cách điều khiển đang dùng theo chế độ đã chọn.
func controls() -> ControlPrefs:
	return custom_controls if control_mode == ControlPrefs.Mode.CUSTOM else ControlPrefs.preset(control_mode)


func apply_fps_cap() -> void:
	var q := current_quality()
	Engine.max_fps = 30 if fps_cap_30 else (q.target_fps if q else 60)


func start_match() -> void:
	save_settings()
	get_tree().change_scene_to_file(MATCH_SCENE)


## Vào trận thường (chọn ở dòng "Trận" trong menu).
func start_normal_match() -> void:
	tower_mode = false
	start_match()


## Vào một tầng tháp (chỉ được chọn tầng đã mở).
func start_tower(floor_no: int) -> void:
	tower_mode = true
	tower_floor = clampi(floor_no, 1, mini(tower_best + 1, TOWER_FLOORS))
	start_match()


## Gọi khi thắng một tầng: mở khoá tầng tiếp theo.
func tower_cleared() -> void:
	if tower_mode and tower_floor > tower_best:
		tower_best = tower_floor
		save_settings()


func back_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "match", match_id)
	cfg.set_value("game", "bot", bot_id)
	cfg.set_value("game", "character", player_character_id)
	cfg.set_value("game", "model", player_model_id)
	cfg.set_value("game", "quality", quality_id)
	cfg.set_value("game", "fps30", fps_cap_30)
	cfg.set_value("game", "control_mode", control_mode)
	cfg.set_value("game", "tower_best", tower_best)
	custom_controls.save(cfg, "custom_controls")
	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	match_id = cfg.get_value("game", "match", match_id)
	bot_id = cfg.get_value("game", "bot", bot_id)
	player_character_id = cfg.get_value("game", "character", player_character_id)
	player_model_id = cfg.get_value("game", "model", player_model_id)
	quality_id = cfg.get_value("game", "quality", quality_id)
	fps_cap_30 = cfg.get_value("game", "fps30", fps_cap_30)
	control_mode = cfg.get_value("game", "control_mode", control_mode)
	tower_best = clampi(cfg.get_value("game", "tower_best", tower_best), 0, TOWER_FLOORS)
	custom_controls.load_from(cfg, "custom_controls")
