class_name AudioConfig
extends Resource
## Âm thanh cho từng sự kiện. Để trống thì không phát.

@export var swing: AudioStream
@export var block: AudioStream
@export var parry: AudioStream
@export var hit: AudioStream
@export var death: AudioStream
@export var max_voices: int = 8
@export var volume_db: float = 0.0
