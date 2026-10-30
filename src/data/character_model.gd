class_name CharacterModel
extends Resource
## Model 3D có khung xương chuẩn UE5 thay cho thân dựng bằng khối. Model không cần hoạt cảnh:
## game tự uốn xương theo động tác (SkinnedRig).

## Tên hiện ở menu chọn nhân vật.
@export var display_name: String = ""
## Ảnh chân dung trên nút chọn nhân vật.
@export var portrait: Texture2D
@export var scene: PackedScene
## Chiều cao model trong file (đơn vị của file), để phóng cho cao 1,8 m.
@export var height: float = 1.0
## Ảnh màu và ảnh pháp tuyến. Để trống thì model một màu tint.
@export var albedo: Texture2D
@export var normal: Texture2D
@export var tint: Color = Color(1, 1, 1)
