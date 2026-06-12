@tool
extends Node3D

const DraggableItem3DClass = preload("res://scripts/DraggableItem3D.gd")
const Models = preload("res://scripts/models/furniture_models.gd")

@export var room_id := ""

var room_data: Dictionary = {}
var _hotspot_areas: Array[Area3D] = []
var _pickup_items: Array[Node3D] = []
var _highlighted_item: Node3D = null
var _pending_spawn: Dictionary = {}
var _camera: Camera3D
var _game_initialized := false


func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_init()
	else:
		_game_init()


# ── Editor setup (runs once per scene, creates editable nodes) ──

func _editor_init() -> void:
	_ensure_room_geometry()
	room_data = _load_room_data()
	_ensure_furniture()
	_ensure_hotspots()


func _ensure_room_geometry() -> void:
	if has_node("RoomGeometry"):
		return
	var geo := _make_node(Node3D.new(), "RoomGeometry")
	add_child(geo)

	var wall_tex := load("res://textures/wall_beige.png")
	var floor_tex := load("res://textures/wood_medium.png")
	var wood_dark_tex := load("res://textures/wood_dark.png")
	var fabric_tex := load("res://textures/fabric_red.png")
	var wall_mat := _make_tex_mat(wall_tex, 0.85)
	var floor_mat := _make_tex_mat(floor_tex, 0.6, Color(0.7, 0.5, 0.3))
	var ceil_mat := _make_mat(Color(0.85, 0.83, 0.78), 0.9)
	var base_mat := _make_tex_mat(wood_dark_tex, 0.7, Color(0.5, 0.35, 0.2))
	var trim_mat := _make_mat(Color(0.9, 0.87, 0.82), 0.8)
	var carpet_mat := _make_tex_mat(fabric_tex, 0.85, Color(0.65, 0.18, 0.15))

	# Main room shell (Z depth reduced from 11 to 7)
	_add_mesh(geo, "Floor", Vector3(0, -0.05, -3), Vector3(14, 0.1, 7), floor_mat)
	_add_mesh(geo, "BackWall", Vector3(0, 2.5, -6.5), Vector3(14, 5, 0.15), wall_mat)
	_add_mesh(geo, "LeftWall", Vector3(-7, 2.5, -3), Vector3(0.15, 5, 7), wall_mat)
	_add_mesh(geo, "RightWall", Vector3(7, 2.5, -3), Vector3(0.15, 5, 7), wall_mat)
	_add_mesh(geo, "Ceiling", Vector3(0, 5.05, -3), Vector3(14, 0.1, 7), ceil_mat)

	# Baseboards (3 walls, Y ~0.05)
	_add_mesh(geo, "BaseBack", Vector3(0, 0.05, -6.41), Vector3(13.9, 0.15, 0.05), base_mat)
	_add_mesh(geo, "BaseLeft", Vector3(-6.93, 0.05, -3), Vector3(0.05, 0.15, 6.9), base_mat)
	_add_mesh(geo, "BaseRight", Vector3(6.93, 0.05, -3), Vector3(0.05, 0.15, 6.9), base_mat)

	# Crown molding (3 walls, Y ~4.95)
	_add_mesh(geo, "CrownBack", Vector3(0, 4.95, -6.41), Vector3(13.9, 0.1, 0.05), trim_mat)
	_add_mesh(geo, "CrownLeft", Vector3(-6.93, 4.95, -3), Vector3(0.05, 0.1, 6.9), trim_mat)
	_add_mesh(geo, "CrownRight", Vector3(6.93, 4.95, -3), Vector3(0.05, 0.1, 6.9), trim_mat)

	# Side wall doors
	_build_doors(geo)

	# Floor carpet
	_add_mesh(geo, "Carpet", Vector3(0, 0.01, -2.5), Vector3(5.5, 0.02, 3.0), carpet_mat)

	# Ceiling light fixture
	var ceiling_light := Models.make_ceiling_light()
	geo.add_child(ceiling_light)

	_set_editor_owners(geo)


func _build_doors(geo: Node3D) -> void:
	var frame_mat: StandardMaterial3D = _make_tex_mat(load("res://textures/wood_medium.png"), 0.5, Color(0.5, 0.32, 0.18))
	var panel_mat: StandardMaterial3D = _make_tex_mat(load("res://textures/wood_light.png"), 0.55, Color(0.65, 0.45, 0.25))
	var handle_mat: StandardMaterial3D = _make_tex_mat(load("res://textures/metal_gold.png"), 0.25, Color(0.85, 0.7, 0.2))
	var wall_thick: float = 0.15

	for side: int in [-1, 1]:  # -1 = left wall, 1 = right wall
		var wx: float = float(side) * 6.93   # wall front face X
		var dz: float = -4.5                  # door Z position (near back wall, TV side)
		var dw: float = 1.0                   # door width
		var dh: float = 2.2                   # door height
		var dy: float = dh / 2.0              # door center Y
		var ft: float = 0.06                  # frame thickness
		var hdw: float = dw / 2.0
		var hdh: float = dh / 2.0
		var side_label: String = "Left" if side == -1 else "Right"

		# Frame: top, bottom, left, right strips
		_add_mesh(geo, "DoorFrameTop" + side_label, Vector3(wx, dy + hdh, dz), Vector3(ft, ft, dw + ft * 2.0), frame_mat)
		_add_mesh(geo, "DoorFrameBot" + side_label, Vector3(wx, dy - hdh, dz), Vector3(ft, ft, dw + ft * 2.0), frame_mat)
		_add_mesh(geo, "DoorFrameL" + side_label,  Vector3(wx, dy, dz - hdw), Vector3(ft, dh, ft), frame_mat)
		_add_mesh(geo, "DoorFrameR" + side_label,  Vector3(wx, dy, dz + hdw), Vector3(ft, dh, ft), frame_mat)

		# Door panel (recessed slightly into wall)
		_add_mesh(geo, "DoorPanel" + side_label, Vector3(wx + ft * 0.5, dy, dz), Vector3(ft * 0.5, dh - ft * 2.0, dw - ft * 2.0), panel_mat)

		# Handle (on the outside face, offset to one side)
		var handle_x: float = wx + ft * 1.5
		var handle_y: float = dy + 0.1
		var handle_z: float = dz + (hdw - 0.15) * float(side)
		var handle: MeshInstance3D = MeshInstance3D.new()
		handle.name = "DoorHandle" + side_label
		handle.position = Vector3(handle_x, handle_y, handle_z)
		handle.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.025
		cm.bottom_radius = 0.025
		cm.height = 0.12
		cm.material = handle_mat
		handle.mesh = cm
		geo.add_child(handle)


func _ensure_furniture() -> void:
	if has_node("Furniture"):
		return
	var furn := _make_node(Node3D.new(), "Furniture")
	add_child(furn)

	var furniture: Array = room_data.get("furniture", [])
	for f in furniture:
		var d: Dictionary = f
		var name: String = d.get("name", "piece")
		var pa: Array = d.get("pos", [0, 0, 0])

		var model := _build_furniture_model(name)
		if model != null:
			model.position = Vector3(pa[0], pa[1], pa[2])
			furn.add_child(model)
		else:
			# Fallback: simple box
			var sa: Array = d.get("size", [1, 1, 1])
			var ca: Array = d.get("color", [0.3, 0.2, 0.1])
			var mat := _make_mat(Color(ca[0], ca[1], ca[2]))
			_add_mesh(furn, name, Vector3(pa[0], pa[1], pa[2]), Vector3(sa[0], sa[1], sa[2]), mat)

	_set_editor_owners(furn)


func _ensure_hotspots() -> void:
	if has_node("Hotspots"):
		return
	var hs := _make_node(Node3D.new(), "Hotspots")
	add_child(hs)

	var interactions: Array = room_data.get("interactions", [])
	var items_per_row := 3
	var row_z := [-4.5, -1.0]
	var row_y := [2.2, 1.8]
	var col_x := [-3.0, 0.0, 3.0]

	for i in interactions.size():
		var interaction: Dictionary = interactions[i]
		var id: String = interaction.get("id", "hs_%d" % i)
		var label_text: String = interaction.get("name", "???")

		var pos: Vector3
		var size: Vector3
		if interaction.has("pos_3d"):
			var pa: Array = interaction.get("pos_3d", [0, 0, 0])
			var sa: Array = interaction.get("size_3d", [2.0, 1.0, 0.5])
			pos = Vector3(pa[0], pa[1], pa[2])
			size = Vector3(sa[0], sa[1], sa[2])
		else:
			var row := i / items_per_row
			var col := i % items_per_row
			if row >= 2:
				break
			pos = Vector3(col_x[col], row_y[row], row_z[row])
			size = Vector3(2.0, 1.0, 0.5)

		var area := Area3D.new()
		area.name = id
		area.position = pos
		area.collision_layer = 1
		area.collision_mask = 0
		area.set_meta("interaction_id", id)
		hs.add_child(area)

		# Use model for visual if available, otherwise simple box
		var model := _build_hotspot_model(id)
		if model != null:
			area.add_child(model)
			_add_collision(area, "Collision", size)
		else:
			var mat := _make_mat(Color(0.25, 0.35, 0.55, 0.7))
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_add_mesh(area, "Mesh", Vector3.ZERO, size, mat)
			_add_collision(area, "Collision", size)

		_add_label(area, "Label", label_text, Vector3(0, size.y / 2 + 0.15, 0))

	_set_editor_owners(hs)


# ── Editor helpers ──

func _set_editor_owners(node: Node) -> void:
	var root := get_tree().edited_scene_root
	node.owner = root
	for child in node.get_children():
		_set_editor_owners(child)


func _make_node(node: Node3D, name_str: String) -> Node3D:
	node.name = name_str
	return node


func _make_mat(color: Color, roughness: float = 0.75) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

func _make_tex_mat(tex: Texture2D, roughness: float = 0.75, color: Color = Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = color
	m.roughness = roughness

	# Auto-load PBR sibling textures from the same directory
	if tex != null and tex.resource_path != "":
		var base := tex.resource_path.trim_suffix(".png")
		var normal_path := base + "_normal.png"
		var rough_path := base + "_roughness.png"
		if FileAccess.file_exists(normal_path):
			m.normal_texture = load(normal_path) as Texture2D
		if FileAccess.file_exists(rough_path):
			m.roughness_texture = load(rough_path) as Texture2D

	return m


func _try_load_texture(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	return load(path) as Texture2D


func _add_mesh(parent: Node3D, name_str: String, pos: Vector3, size: Vector3, mat: StandardMaterial3D) -> void:
	var m := MeshInstance3D.new()
	m.name = name_str
	m.position = pos
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	m.mesh = box
	parent.add_child(m)


func _add_collision(parent: Node3D, name_str: String, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	cs.name = name_str
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	parent.add_child(cs)


func _add_label(parent: Node3D, name_str: String, text: String, pos: Vector3) -> void:
	var l := Label3D.new()
	l.name = name_str
	l.position = pos
	l.text = text
	l.font_size = 48
	l.modulate = Color(0.95, 0.9, 0.8)
	l.outline_size = 1
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(l)


func _build_furniture_model(name: String) -> Node3D:
	match name:
		"tv_cabinet": return Models.make_tv_cabinet()
		"coffee_table": return Models.make_coffee_table()
		"side_table": return Models.make_side_table()
		"desk": return Models.make_desk()
	return null


func _build_hotspot_model(id: String) -> Node3D:
	match id:
		"family_photo":
			var imported := _try_imported_model("res://assets/models/frame_1.glb", "family_photo")
			if imported != null:
				imported.scale = Vector3(2.0, 2.0, 2.0)
				_apply_picture_texture(imported, "res://assets/models/family_photo.png")
				return imported
			return Models.make_family_photo()
		"old_clock": return Models.make_alarm_clock()
		"landline": return Models.make_landline()
		"dvd_player": return Models.make_dvd_player()
		"old_tv":
			var imported := _try_imported_model("res://assets/models/crt_tv.glb", "old_tv")
			if imported != null:
				imported.scale = Vector3(4, 4, 4)
				imported.rotation_degrees.y = 180
				imported.position.y = 0.7
				return imported
			return Models.make_crt_tv()
		"new_tv": return Models.make_lcd_tv()
		"construction": return Models.make_construction_crane()
		"old_calendar": return Models.make_calendar()
		"desk_drawer": return Models.make_desk()
		"computer": return Models.make_desktop_pc()
		"empty_wall": return Models.make_empty_tv_wall()
		"smartphone": return Models.make_smartphone()
		"delivery_receipt": return Models.make_desk()
	return null


func _build_item_model(item_id: String) -> Node3D:
	match item_id:
		"small_key": return Models.make_small_key()
		"remote_control": return Models.make_remote_control()
		"old_phone": return Models.make_old_phone()
		"receipt": return Models.make_receipt()
		"password_note": return Models.make_password_note()
	return null


func _try_imported_model(path: String, node_name: String) -> Node3D:
	if not FileAccess.file_exists(path):
		return null
	var packed: PackedScene = load(path)
	if packed == null:
		return null
	var instance := packed.instantiate()
	instance.name = node_name
	return instance


func _apply_picture_texture(root: Node, tex_path: String) -> void:
	if not FileAccess.file_exists(tex_path):
		return
	var tex: Texture2D = load(tex_path)
	if tex == null:
		return
	for child: MeshInstance3D in root.find_children("frame_image_*", "MeshInstance3D", true, false):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		child.set_surface_override_material(0, mat)


func _load_room_data() -> Dictionary:
	var path := "res://data/rooms/%s.json" % room_id
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


# ── Game init (runs at runtime) ──

func _game_init() -> void:
	room_data = _load_room_data()
	GameState.current_room_id = room_id

	# Ensure nodes exist (may not if scene was never saved in editor)
	_ensure_room_geometry()
	_ensure_furniture()
	_ensure_hotspots()

	_camera = $Camera3D
	_setup_environment()

	# Collect existing hotspot areas and attach interaction data
	_collect_hotspots()

	if has_node("Draggables"):
		$Draggables.queue_free()
	var drag_node := Node3D.new()
	drag_node.name = "Draggables"
	add_child(drag_node)

	var look_arr: Array = room_data.get("look_at", [0, 1.5, -1])
	_camera.look_at(Vector3(look_arr[0], look_arr[1], look_arr[2]), Vector3.UP)

	InteractionManager.interaction_completed.connect(_on_interaction_completed)
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
	_game_initialized = true


func _collect_hotspots() -> void:
	_hotspot_areas.clear()
	var hs_node = get_node_or_null("Hotspots")
	if hs_node == null:
		return
	for child in hs_node.get_children():
		if child is Area3D:
			var interaction_id: String = child.get_meta("interaction_id", "")
			if interaction_id != "":
				for inter in room_data.get("interactions", []):
					if inter.get("id") == interaction_id:
						child.set_meta("interaction", inter)
						break
			_hotspot_areas.append(child)


func _setup_environment() -> void:
	var we := $WorldEnvironment
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.1, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.4, 0.35)
	env.ambient_light_energy = 0.7

	# SSAO for corner depth
	env.ssao_enabled = true
	env.ssao_radius = 2.0
	env.ssao_intensity = 1.2
	env.ssao_light_affect = 0.3

	# Filmic tonemapping
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.0

	# Depth fog for atmosphere
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_density = 0.003
	env.fog_light_color = Color(0.25, 0.22, 0.18)
	env.fog_light_energy = 0.6

	# Subtle warm color adjustment
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	env.adjustment_color_correction = _try_load_texture("res://textures/warm_lut.png")

	# Glow
	env.glow_enabled = true
	env.glow_intensity = 0.15

	we.environment = env


func get_camera() -> Camera3D:
	return _camera


# ── Interaction ──

func try_interact(collider: Node3D) -> void:
	var node := collider
	while node != null:
		if node.has_meta("interaction"):
			InteractionManager.handle_interaction(node.get_meta("interaction"))
			return
		node = node.get_parent()


# ── Pickup system ──

func get_hovered_item(mouse_pos: Vector2) -> Node3D:
	var from := _camera.project_ray_origin(mouse_pos)
	var dir := _camera.project_ray_normal(mouse_pos)
	var to := from + dir * 50

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result := space_state.intersect_ray(query)

	if result.is_empty():
		return null

	var collider: Node3D = result.collider
	return _find_pickup_item(collider)


func _find_pickup_item(collider: Node3D) -> Node3D:
	var node := collider
	while node != null:
		if node in _pickup_items:
			return node
		node = node.get_parent()
	return null


func highlight_item(item: Node3D) -> void:
	if _highlighted_item == item:
		return
	clear_highlight()
	_highlighted_item = item
	if item.has_method("highlight"):
		item.highlight()


func clear_highlight() -> void:
	if _highlighted_item != null and _highlighted_item.has_method("unhighlight"):
		_highlighted_item.unhighlight()
	_highlighted_item = null


func pickup_item(item: Node3D) -> Dictionary:
	var data: Dictionary = {
		"item_id": item.get("item_id"),
		"item_color": item.get("item_color"),
		"button_action": item.get("button_action"),
		"position": item.global_position,
	}
	_pickup_items.erase(item)
	clear_highlight()
	item.queue_free()
	return data


func drop_item(item_data: Dictionary) -> void:
	var btn_action: Dictionary = item_data.get("button_action", {})
	spawn_draggable(item_data["item_id"], item_data["position"], btn_action)


# ── Spawn & Animation system ──

func _on_interaction_completed(interaction_id: String) -> void:
	for interaction in room_data.get("interactions", []):
		if interaction.get("id") == interaction_id:
			var spawn_id := String(interaction.get("spawns_draggable", ""))
			if spawn_id != "":
				var idx := _find_interaction_index(interaction_id)
				var default_pos := _get_hotspot_position(idx) + Vector3(0, -0.6, 0.6)
				var btn_action: Dictionary = interaction.get("spawned_item_action", {})
				var anim_type := String(interaction.get("spawn_anim", ""))
				var target_arr: Array = interaction.get("spawn_target", [])
				var target_pos := default_pos
				if not target_arr.is_empty():
					target_pos = Vector3(target_arr[0], target_arr[1], target_arr[2])
				_pending_spawn = {
					"item_id": spawn_id,
					"position": target_pos,
					"button_action": btn_action,
					"anim": anim_type,
					"interaction_id": interaction_id,
				}
			return


func _on_dialogue_finished(_dialogue_id: String) -> void:
	if _pending_spawn.is_empty():
		return
	_play_spawn_animation(_pending_spawn)


func _play_spawn_animation(data: Dictionary) -> void:
	var anim: String = data.get("anim", "")
	var interaction_id: String = data.get("interaction_id", "")

	match anim:
		"shake":
			_animate_shake_then_spawn(interaction_id, data)
		"drawer_open":
			_animate_drawer_then_spawn(data)
		_:
			_do_spawn(data)


func _do_spawn(data: Dictionary) -> void:
	var btn_action: Dictionary = data.get("button_action", {})
	var anim_str: String = data.get("anim", "")
	var has_anim: bool = anim_str != ""
	spawn_draggable(data["item_id"], data["position"], btn_action, has_anim)
	_pending_spawn = {}


# ── Shake animation ──

func _animate_shake_then_spawn(hotspot_id: String, data: Dictionary) -> void:
	var hotspot := _find_hotspot_area(hotspot_id)
	if hotspot == null:
		_do_spawn(data)
		return

	# Shake the hotspot for ~0.8s then spawn
	var original_pos := hotspot.position
	var tween := create_tween()
	var shakes := 10
	for i in range(shakes):
		var ox := randf_range(-0.04, 0.04)
		var oy := randf_range(-0.03, 0.03)
		var oz := randf_range(-0.03, 0.03)
		tween.tween_property(hotspot, "position", original_pos + Vector3(ox, oy, oz), 0.04)
		tween.tween_property(hotspot, "position", original_pos, 0.04)
	tween.tween_callback(_do_spawn.bind(data))


# ── Drawer open animation ──

func _animate_drawer_then_spawn(data: Dictionary) -> void:
	var drawer_front := _find_node_in_tree(get_tree().current_scene, "DrawerFront")
	var knob := _find_node_in_tree(get_tree().current_scene, "KnobL")

	if drawer_front == null:
		_do_spawn(data)
		return

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(drawer_front, "position:z", drawer_front.position.z + 0.5, 0.6).set_ease(Tween.EASE_OUT)
	if knob:
		tween.tween_property(knob, "position:z", knob.position.z + 0.5, 0.6).set_ease(Tween.EASE_OUT)

	# After drawer opens, pause briefly then spawn
	var seq := create_tween()
	seq.tween_interval(0.7)
	seq.tween_callback(_do_spawn.bind(data))


# ── Item fall animation ──

func _animate_item_fall(item: Node3D, target_pos: Vector3) -> void:
	item.position = target_pos + Vector3(0, 1.5, 0)
	var tween := create_tween()
	tween.tween_property(item, "position", target_pos, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	# Small bounce
	tween.tween_property(item, "position", target_pos + Vector3(0, 0.05, 0), 0.08)
	tween.tween_property(item, "position", target_pos, 0.06)


# ── Helpers ──

func _find_hotspot_area(hotspot_id: String) -> Area3D:
	for area in _hotspot_areas:
		if area.has_meta("interaction_id") and area.get_meta("interaction_id") == hotspot_id:
			return area
	return null


func _find_node_in_tree(root: Node, name_str: String) -> Node:
	if root.name == name_str:
		return root
	for child in root.get_children():
		var found := _find_node_in_tree(child, name_str)
		if found != null:
			return found
	return null


func _find_interaction_index(interaction_id: String) -> int:
	for i in _hotspot_areas.size():
		if _hotspot_areas[i].has_meta("interaction"):
			var interaction: Dictionary = _hotspot_areas[i].get_meta("interaction")
			if String(interaction.get("id", "")) == interaction_id:
				return i
	return -1


func _get_hotspot_position(idx: int) -> Vector3:
	if idx < 0 or idx >= _hotspot_areas.size():
		return Vector3.ZERO
	return _hotspot_areas[idx].global_position


func spawn_draggable(item_id: String, pos: Vector3, button_action: Dictionary = {}, with_fall: bool = false) -> void:
	var item := DraggableItem3DClass.new()
	item.item_id = item_id
	item.position = pos
	item.button_action = button_action

	var item_label := ""
	var item_color := Color.WHITE
	var collision_size := Vector3(0.6, 0.25, 0.1)
	match item_id:
		"small_key":
			item_label = "钥匙"
			item_color = Color(0.85, 0.75, 0.2, 1.0)
			collision_size = Vector3(0.3, 0.4, 0.15)
		"remote_control":
			item_label = "遥控器"
			item_color = Color(0.2, 0.25, 0.35, 1.0)
			collision_size = Vector3(0.2, 0.55, 0.1)
		"password_note":
			item_label = "密码纸条"
			item_color = Color(0.95, 0.95, 0.85, 1.0)
			collision_size = Vector3(0.25, 0.3, 0.1)
		"old_phone":
			item_label = "旧手机"
			item_color = Color(0.15, 0.15, 0.2, 1.0)
			collision_size = Vector3(0.25, 0.4, 0.1)
		"receipt":
			item_label = "外卖单"
			item_color = Color(1.0, 0.95, 0.8, 1.0)
			collision_size = Vector3(0.25, 0.35, 0.1)

	var model := _build_item_model(item_id)
	if model != null:
		item.item_color = item_color
		item.set_custom_model(model, item_label, collision_size)
	else:
		item.create_visual(item_color, item_label)

	var drag_parent = get_node_or_null("Draggables")
	if drag_parent == null:
		add_child(item)
	else:
		drag_parent.add_child(item)

	_pickup_items.append(item)

	if with_fall:
		_animate_item_fall(item, pos)
