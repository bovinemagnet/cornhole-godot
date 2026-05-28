extends Sprite3D
class_name BillboardSprite3D

@export var face_camera := true
@export var bob_enabled := false
@export var bob_height := 0.05
@export var bob_speed := 2.0

var _base_y := 0.0
var _t := 0.0

func _ready() -> void:
    billboard = BaseMaterial3D.BILLBOARD_ENABLED
    shaded = false
    _base_y = position.y

func _process(delta: float) -> void:
    if bob_enabled:
        _t += delta * bob_speed
        position.y = _base_y + sin(_t) * bob_height
