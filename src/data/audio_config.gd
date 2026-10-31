class_name AudioConfig
extends Resource
## Âm thanh cho từng sự kiện. Để trống thì dùng tiếng tạo bằng code (SfxSynth).

@export var swing: AudioStream
@export var block: AudioStream
@export var parry: AudioStream
@export var hit: AudioStream
@export var death: AudioStream
## Tiếng va chạm theo chỗ vũ khí chạm vào. Mỗi mảng là vài bản của cùng một tiếng, chọn ngẫu nhiên
## để không lặp đều. Để trống thì dùng tiếng tạo bằng code.
## Lưỡi chạm lưỡi (đỡ hoàn hảo): kim loại "keng" ngân dài.
@export var clash_blade: Array[AudioStream] = []
## Chém vào cán gỗ khi đỡ: "cộc" khô.
@export var clash_haft: Array[AudioStream] = []
## Chém vào khiên: "bộp" trầm.
@export var clash_shield: Array[AudioStream] = []
## Chém trúng người: "xoẹt-phập".
@export var hit_slash: Array[AudioStream] = []
## Đâm trúng người: "phập".
@export var hit_stab: Array[AudioStream] = []
## Đòn chí mạng (giết chết).
@export var hit_lethal: Array[AudioStream] = []
@export var max_voices: int = 8
@export var volume_db: float = 0.0
