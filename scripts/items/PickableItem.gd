extends Area2D

## A visible item on the ground that the player can walk to and pick up

var item_id: String = ""
var item_name: String = ""


func setup(id: String, display_name: String, pos: Vector2) -> void:
	item_id = id
	item_name = display_name
	set_meta("item_id", id)
	position = pos
	monitoring = true
	monitorable = true
	collision_layer = 0
	collision_mask = 1

	# Visual — colorful rectangle
	var visual := ColorRect.new()
	visual.name = "Visual"
	visual.color = Color(1, 0.85, 0.2, 0.8)
	visual.size = Vector2(24, 24)
	visual.position = -visual.size / 2.0
	add_child(visual)

	# Collision
	var col := CollisionShape2D.new()
	col.shape = RectangleShape2D.new()
	col.shape.size = Vector2(40, 40)
	add_child(col)

	# Label
	var label := Label.new()
	label.name = "Label"
	label.text = display_name
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.position = Vector2(-30, -30)
	add_child(label)

	# Signal
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		set_meta("player_nearby", true)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		set_meta("player_nearby", false)
