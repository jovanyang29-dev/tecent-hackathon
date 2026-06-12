extends Node2D

## Entry point — loads starting room and sets up UI


func _ready() -> void:
	# 开始播放背景音乐
	AudioManager.play_bgm()
	
	# Load game1 room system
	RoomManager.enter_room("room_2008", "")
