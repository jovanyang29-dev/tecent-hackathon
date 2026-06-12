extends Node3D

var item_id := ""
var item_color := Color.WHITE
var button_action: Dictionary = {}
var _area: Area3D
var _highlight_mat: StandardMaterial3D


func create_visual(color: Color, label_text: String) -> void:
	item_color = color

	_highlight_mat = StandardMaterial3D.new()
	_highlight_mat.albedo_color = color.lightened(0.3)
	_highlight_mat.roughness = 0.3
	_highlight_mat.emission_enabled = true
	_highlight_mat.emission = Color(0.3, 0.3, 0.15)
	_highlight_mat.emission_energy = 0.5

	_area = Area3D.new()
	_area.name = "ClickArea"
	_area.collision_layer = 2
	_area.collision_mask = 0
	add_child(_area)

	var col_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.6, 0.25, 0.1)
	col_shape.shape = box_shape
	_area.add_child(col_shape)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 0.25, 0.1)
	box.material = _make_mat(color)
	mesh.mesh = box
	_area.add_child(mesh)

	var label := Label3D.new()
	label.text = label_text
	label.position = Vector3(0, 0.3, 0)
	label.font_size = 32
	label.modulate = Color(1, 1, 1)
	label.outline_size = 1
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_area.add_child(label)

	if not button_action.is_empty():
		_add_button_indicator(_area)


func set_custom_model(model: Node3D, label_text: String, collision_size: Vector3 = Vector3(0.6, 0.25, 0.1)) -> void:
	_highlight_mat = StandardMaterial3D.new()
	_highlight_mat.emission_enabled = true
	_highlight_mat.emission = Color(0.3, 0.3, 0.15)
	_highlight_mat.emission_energy = 0.5

	_area = Area3D.new()
	_area.name = "ClickArea"
	_area.collision_layer = 2
	_area.collision_mask = 0
	add_child(_area)

	var col_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = collision_size
	col_shape.shape = box_shape
	_area.add_child(col_shape)

	_area.add_child(model)

	var label := Label3D.new()
	label.text = label_text
	label.position = Vector3(0, collision_size.y / 2 + 0.15, 0)
	label.font_size = 32
	label.modulate = Color(1, 1, 1)
	label.outline_size = 1
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_area.add_child(label)

	if not button_action.is_empty():
		_add_button_indicator(_area)


func _add_button_indicator(parent: Node3D) -> void:
	var btn_mesh := MeshInstance3D.new()
	var btn_box := BoxMesh.new()
	btn_box.size = Vector3(0.12, 0.12, 0.05)
	var btn_mat := StandardMaterial3D.new()
	btn_mat.albedo_color = Color(0.2, 0.9, 0.3, 1.0)
	btn_box.material = btn_mat
	btn_mesh.mesh = btn_box
	btn_mesh.position = Vector3(0.35, 0.25, 0.06)
	parent.add_child(btn_mesh)


func _make_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.5
	return m


func highlight() -> void:
	for child in _area.get_children():
		if child is MeshInstance3D:
			child.material_override = _highlight_mat


func unhighlight() -> void:
	for child in _area.get_children():
		if child is MeshInstance3D:
			child.material_override = null


func has_button() -> bool:
	return not button_action.is_empty()
