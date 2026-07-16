extends Sprite2D

var _frames: Array[Texture2D] = []
var _frame_idx := 0
var _timer: float = 0.0
const FRAME_DURATION := 0.15

func _ready() -> void:
	for i in range(7):
		var tex: Texture2D = load("res://assets/sprites/steam/frame_%02d.png" % i)
		if tex != null:
			_frames.append(tex)
	if not _frames.is_empty():
		texture = _frames[0]

func _process(delta: float) -> void:
	if _frames.is_empty():
		return
	_timer += delta
	if _timer >= FRAME_DURATION:
		_timer = 0.0
		_frame_idx = (_frame_idx + 1) % _frames.size()
		texture = _frames[_frame_idx]
