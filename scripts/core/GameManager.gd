extends Node

## Game-wide state and signals

signal room_entered(room_id: String)
signal room_cleared(room_id: String)
signal game_paused
signal game_resumed

var current_room_id: String = ""
var rooms_cleared: Dictionary = {}
var player_health: int = 10
var player_max_health: int = 10
var is_paused: bool = false
var floor_level: int = 1


func reset() -> void:
	current_room_id = ""
	rooms_cleared.clear()
	player_health = player_max_health
	is_paused = false
	floor_level = 1


func clear_room(room_id: String) -> void:
	rooms_cleared[room_id] = true
	room_cleared.emit(room_id)


func is_room_cleared(room_id: String) -> bool:
	return rooms_cleared.get(room_id, false)
