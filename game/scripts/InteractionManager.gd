extends Node

signal interaction_completed(interaction_id: String)
signal password_requested(correct_password: String, interaction: Dictionary)

var _pending_password: Dictionary = {}


func _ready() -> void:
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)


func handle_interaction(interaction: Dictionary, skip_password: bool = false) -> void:
	var interaction_id := String(interaction.get("id", ""))

	if not skip_password:
		var requires_password := String(interaction.get("requires_password", ""))
		if requires_password != "":
			var locked_dialogue := String(interaction.get("locked_dialogue", ""))
			if locked_dialogue != "":
				DialogueManager.start_dialogue(locked_dialogue)
				_pending_password = {"password": requires_password, "interaction": interaction}
				return
			password_requested.emit(requires_password, interaction)
			return

	var requires_item := String(interaction.get("requires_item", ""))
	if requires_item != "" and not GameState.has_item(requires_item):
		DialogueManager.start_dialogue(String(interaction.get("locked_dialogue", "")))
		return

	var gives_item := String(interaction.get("gives_item", ""))
	if gives_item != "":
		GameState.add_item(gives_item)

	var sets_flag := String(interaction.get("sets_flag", ""))
	if sets_flag != "":
		GameState.set_flag(sets_flag)

	DialogueManager.start_dialogue(String(interaction.get("dialogue", "")))
	interaction_completed.emit(interaction_id)


func _on_dialogue_finished(_dialogue_id: String) -> void:
	if _pending_password.is_empty():
		return
	var pw := _pending_password
	_pending_password = {}
	password_requested.emit(pw["password"], pw["interaction"])
