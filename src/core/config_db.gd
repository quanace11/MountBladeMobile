extends Node
## Nạp các file trong config/ và trả về theo id. Code khác không tự load đường dẫn config.

const ROOT := "res://config/"

var game: GameConfig
var rules: CombatRules
var input: InputConfig
var poses: PoseSet
var audio: AudioConfig
var arena: ArenaDef
var characters: Dictionary = {}
var bots: Dictionary = {}
var matches: Dictionary = {}
var qualities: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	game = load(ROOT + "game_config.tres")
	rules = load(ROOT + "combat_rules.tres")
	input = load(ROOT + "input/touch.tres")
	poses = load(ROOT + "visual/poses.tres")
	audio = load(ROOT + "audio.tres")
	arena = load(ROOT + "visual/arena.tres")
	characters = _load_dir("characters")
	bots = _load_dir("ai")
	matches = _load_dir("matches")
	qualities = _load_dir("quality")


## Nạp mọi .tres trong một thư mục, khóa theo tên file (không đuôi).
func _load_dir(sub: String) -> Dictionary:
	var out := {}
	var path := ROOT + sub
	for file in ResourceLoader.list_directory(path):
		if not file.ends_with(".tres"):
			continue
		out[StringName(file.get_basename())] = load(path + "/" + file)
	return out


func sorted_keys(d: Dictionary) -> Array:
	var keys := d.keys()
	keys.sort()
	return keys
