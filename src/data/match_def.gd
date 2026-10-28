class_name MatchDef
extends Resource
## Kịch bản một trận: tướng người chơi và danh sách địch.

@export var id: StringName = &""
@export var display_name: String = ""
@export var player_character: CharacterDef
@export var enemy_characters: Array[CharacterDef] = []
