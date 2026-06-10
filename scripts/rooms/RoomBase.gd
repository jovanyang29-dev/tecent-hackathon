@tool
extends Node2D

## 2D room — reads game1 JSON, builds walls, furniture, interactive hotspots

const WALL_FB := 160.0   # front/back wall depth (3D effect, 120 gray + 40 white)
const WALL_SIDE := 40.0  # side wall width (top-down only)
const WALL_BLOCK := 40.0
const TRIM_THICKNESS := 4.0

var room_data: Dictionary = {}
var entry_from: String = ""
var hotspots: Array[Area2D] = []
var _tv_cabinet_sprite: Sprite2D = null
var _drawer_open := false
var _tv_cabinet_orig_pos: Vector2 = Vector2.ZERO
const DRAWER_OPEN_OFFSET := Vector2(0, 2)


func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_preview()


func _editor_preview() -> void:
	# Derive room_id from scene filename (e.g. "room_2008" from "room_2008.tscn")
	var path := scene_file_path
	var file := path.get_file().trim_suffix(".tscn")
	room_data = {"id": file, "type": "story"}
	var full_data := _load_full_room_data()
	if not full_data.is_empty():
		room_data = full_data
	_build_floor()
	_build_walls()
	_build_furniture()
	_build_hotspots()
	_build_exits()


func setup(data: Dictionary, entry_dir: String = "") -> void:
	room_data = data
	entry_from = entry_dir

	# 清空上一房间的碰撞数据
	CollisionManager.clear_all()

	var full_data := _load_full_room_data()
	if not full_data.is_empty():
		room_data = full_data

	_build_floor()
	_build_walls()
	_build_furniture()
	_build_hotspots()
	_build_exits()
	InteractionManager.item_spawn_requested.connect(_on_item_spawn)
	InteractionManager.spawn_anim_triggered.connect(_on_spawn_anim)
	GameState.inventory_changed.connect(_on_inventory_changed)
	_place_player(entry_dir)


func _load_full_room_data() -> Dictionary:
	var room_id: String = room_data.get("id", GameState.current_room_id)
	var path := "res://data/rooms/%s.json" % room_id
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


func _build_floor() -> void:
	var room_size := RoomManager.ROOM_SIZE
	var half_w := room_size.x / 2.0
	var half_h := room_size.y / 2.0

	var floor_x := -half_w + WALL_SIDE
	var floor_y := -half_h + WALL_FB
	var floor_w := int(room_size.x - WALL_SIDE * 2)
	var floor_h := int(room_size.y - WALL_FB * 2)

	var tile_tex := _make_tile_floor(floor_w, floor_h)

	var floor := Sprite2D.new()
	floor.name = "Floor"
	floor.texture = tile_tex
	floor.centered = false
	floor.position = Vector2(floor_x, floor_y)
	add_child(floor)
	move_child(floor, 0)


func _build_walls() -> void:
	var room_size := RoomManager.ROOM_SIZE
	var half_w := room_size.x / 2.0
	var half_h := room_size.y / 2.0

	var top_color := Color(0.96, 0.95, 0.90)   # top face (light)
	var face_color := Color(0.74, 0.72, 0.68)  # front face (darker, feels like a wall)
	var side_color := Color(0.94, 0.93, 0.88)  # side walls — top-only, slightly different
	var edge_color := Color(0.10, 0.09, 0.08)  # trim border

	# ═══════════════════════════════════════════════
	# TOP wall (back) — 3D: 40px white top + 120px gray face
	# ═══════════════════════════════════════════════
	for col: int in range(0, int(room_size.x), int(WALL_BLOCK)):
		var x := -half_w + float(col)
		# Top face (white — horizontal surface closest to edge)
		var tf := _make_rect_sprite(Vector2(WALL_BLOCK, WALL_BLOCK), top_color)
		tf.name = "TopWall_T_%d" % col
		tf.position = Vector2(x, -half_h)
		add_child(tf)
		# Face row 1 (gray — vertical wall)
		var f1 := _make_rect_sprite(Vector2(WALL_BLOCK, WALL_BLOCK), face_color)
		f1.name = "TopWall_F1_%d" % col
		f1.position = Vector2(x, -half_h + WALL_BLOCK)
		add_child(f1)
		# Face row 2 (gray — vertical wall)
		var f2 := _make_rect_sprite(Vector2(WALL_BLOCK, WALL_BLOCK), face_color)
		f2.name = "TopWall_F2_%d" % col
		f2.position = Vector2(x, -half_h + WALL_BLOCK * 2)
		add_child(f2)
		# Face row 3 (gray — vertical wall into room)
		var f3 := _make_rect_sprite(Vector2(WALL_BLOCK, WALL_BLOCK), face_color)
		f3.name = "TopWall_F3_%d" % col
		f3.position = Vector2(x, -half_h + WALL_BLOCK * 3)
		add_child(f3)

	# ═══════════════════════════════════════════════
	# BOTTOM wall (front) — 3D: 40px white top + 120px gray face
	# ═══════════════════════════════════════════════
	for col: int in range(0, int(room_size.x), int(WALL_BLOCK)):
		var x := -half_w + float(col)
		# Top face (white — horizontal surface, seen first from room)
		var tf := _make_rect_sprite(Vector2(WALL_BLOCK, WALL_BLOCK), top_color)
		tf.name = "BotWall_T_%d" % col
		tf.position = Vector2(x, half_h - WALL_FB)
		tf.z_index = 200
		# Narrow edges by 5px on left/right
		if col == 0:
			tf.position.x += 5
			tf.scale.x = (WALL_BLOCK - 5) / WALL_BLOCK
		elif col >= int(room_size.x) - int(WALL_BLOCK):
			tf.scale.x = (WALL_BLOCK - 5) / WALL_BLOCK
		add_child(tf)
		# Face row 1 (gray — vertical wall)
		var f1 := _make_rect_sprite(Vector2(WALL_BLOCK, WALL_BLOCK), face_color)
		f1.name = "BotWall_F1_%d" % col
		f1.position = Vector2(x, half_h - WALL_FB + WALL_BLOCK)
		add_child(f1)
		# Face row 2 (gray — vertical wall)
		var f2 := _make_rect_sprite(Vector2(WALL_BLOCK, WALL_BLOCK), face_color)
		f2.name = "BotWall_F2_%d" % col
		f2.position = Vector2(x, half_h - WALL_FB + WALL_BLOCK * 2)
		add_child(f2)
		# Face row 3 (gray — vertical wall, closest to edge)
		var f3 := _make_rect_sprite(Vector2(WALL_BLOCK, WALL_BLOCK), face_color)
		f3.name = "BotWall_F3_%d" % col
		f3.position = Vector2(x, half_h - WALL_FB + WALL_BLOCK * 3)
		add_child(f3)

	# ═══════════════════════════════════════════════
	# LEFT wall — flat top-down, bottom 80px gray
	# ═══════════════════════════════════════════════
	var left_top_h := room_size.y - 120.0
	var left_top := _make_rect_sprite(Vector2(WALL_SIDE, left_top_h), side_color)
	left_top.name = "LeftWallTop"
	left_top.position = Vector2(-half_w, -half_h)
	add_child(left_top)
	var left_bot := _make_rect_sprite(Vector2(WALL_SIDE, 120), face_color)
	left_bot.name = "LeftWallBot"
	left_bot.position = Vector2(-half_w, half_h - 120)
	add_child(left_bot)

	# ═══════════════════════════════════════════════
	# RIGHT wall — flat top-down, bottom 80px gray
	# ═══════════════════════════════════════════════
	var right_top_h := room_size.y - 120.0
	var right_top := _make_rect_sprite(Vector2(WALL_SIDE, right_top_h), side_color)
	right_top.name = "RightWallTop"
	right_top.position = Vector2(half_w - WALL_SIDE, -half_h)
	add_child(right_top)
	var right_bot := _make_rect_sprite(Vector2(WALL_SIDE, 120), face_color)
	right_bot.name = "RightWallBot"
	right_bot.position = Vector2(half_w - WALL_SIDE, half_h - 120)
	add_child(right_bot)

	# ── Outer border trim ──
	var trim_top := _make_rect_sprite(Vector2(room_size.x, TRIM_THICKNESS), edge_color)
	trim_top.position = Vector2(-half_w, -half_h)
	add_child(trim_top)

	var trim_bot := _make_rect_sprite(Vector2(room_size.x, TRIM_THICKNESS), edge_color)
	trim_bot.position = Vector2(-half_w, half_h - TRIM_THICKNESS)
	add_child(trim_bot)

	var trim_left := _make_rect_sprite(Vector2(TRIM_THICKNESS, room_size.y), edge_color)
	trim_left.position = Vector2(-half_w, -half_h)
	add_child(trim_left)

	var trim_right := _make_rect_sprite(Vector2(TRIM_THICKNESS, room_size.y), edge_color)
	trim_right.position = Vector2(half_w - TRIM_THICKNESS, -half_h)
	add_child(trim_right)

	# ── Skirting (wall-floor boundary) ──
	var wall_inner_x := -half_w + WALL_SIDE
	var wall_inner_y_top := -half_h + WALL_FB
	var wall_inner_y_bot := half_h - WALL_FB
	var inner_width := room_size.x - WALL_SIDE * 2
	var skirt_color := Color(0.14, 0.12, 0.09)
	var skirt_h := 3.0

	# Top skirt
	var skirt_top := _make_rect_sprite(Vector2(inner_width, skirt_h), skirt_color)
	skirt_top.position = Vector2(wall_inner_x, wall_inner_y_top - skirt_h)
	add_child(skirt_top)

	# Bottom skirt
	var skirt_bot := _make_rect_sprite(Vector2(inner_width, skirt_h), skirt_color)
	skirt_bot.position = Vector2(wall_inner_x, wall_inner_y_bot)
	add_child(skirt_bot)

	# Left skirt
	var skirt_left := _make_rect_sprite(Vector2(skirt_h, room_size.y - WALL_FB * 2), skirt_color)
	skirt_left.position = Vector2(wall_inner_x, wall_inner_y_top)
	add_child(skirt_left)

	# Right skirt
	var skirt_right := _make_rect_sprite(Vector2(skirt_h, room_size.y - WALL_FB * 2), skirt_color)
	skirt_right.position = Vector2(half_w - WALL_SIDE - skirt_h, wall_inner_y_top)
	add_child(skirt_right)

	var title: String = room_data.get("title", "")
	if title != "":
		var label := Label.new()
		label.name = "TitleLabel"
		label.text = title
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(0.4, 0.35, 0.3))
		label.position = Vector2(-half_w + WALL_SIDE + 8, -half_h + 6)
		add_child(label)


# ── Wood floor texture generator ──

func _make_tile_floor(width_px: int, height_px: int) -> ImageTexture:
	var img: Image = Image.create(width_px, height_px, false, Image.FORMAT_RGBA8)
	var tile_size: int = 40
	var base := Color(0.48, 0.33, 0.18)   # warm medium wood
	var alt := Color(0.51, 0.36, 0.20)    # slightly different tile
	var line_color := Color(0.28, 0.18, 0.08)  # dark grout line

	for y: int in range(height_px):
		for x: int in range(width_px):
			var c := base
			# Grout lines
			if y % tile_size == 0 or y % tile_size == tile_size - 1:
				c = line_color
			elif x % tile_size == 0 or x % tile_size == tile_size - 1:
				c = line_color
			else:
				# Checkerboard variation
				var tile_x: int = x / tile_size
				var tile_y: int = y / tile_size
				if (tile_x + tile_y) % 2 == 1:
					c = alt
			img.set_pixel(x, y, c)

	return ImageTexture.create_from_image(img)


# ── SpriteSheet helpers ──

var _sheet_cache: Dictionary = {}

func _load_sheet(path: String) -> SpriteSheet:
	if _sheet_cache.has(path):
		return _sheet_cache[path]
	var sheet := SpriteSheet.new()
	sheet.load_sheet(path)
	_sheet_cache[path] = sheet
	return sheet


func _make_rect_sprite(size: Vector2, color: Color) -> Sprite2D:
	var w: int = maxi(1, int(size.x))
	var h: int = maxi(1, int(size.y))
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.centered = false
	return sprite

# ── Furniture (from game1 room data) ──

func _build_furniture() -> void:
	# If furniture sprites are already placed in the scene, just grab references
	var has_manual := false
	for child in get_children():
		if child is Sprite2D and str(child.name) in ["tv_cabinet", "coffee_table", "side_table"]:
			has_manual = true
			move_child(child, get_child_count() - 1)
			if child.name == "tv_cabinet":
				_tv_cabinet_sprite = child
				if child.texture == null:
					var img: Image = Image.load_from_file("res://assets/sprites/电视机柜.png")
					if img != null:
						child.texture = ImageTexture.create_from_image(img)
			elif child.name == "coffee_table" and child.texture == null:
				var img: Image = Image.load_from_file("res://assets/sprites/茶几.png")
				if img != null:
					child.texture = ImageTexture.create_from_image(img)
			elif child.name == "side_table":
				child.scale = Vector2(0.7, 0.7)
				if child.texture == null:
					var sh := _load_sheet("res://assets/sprites/TopDownHouse_FurnitureState1.png")
					if sh != null:
						child.texture = _compose_tiles(sh, 11, 0, 1, 2, 3)
	if has_manual:
		# Furniture sprites already placed in scene — register colliders for them
		for child in get_children():
			if child is Sprite2D and str(child.name) in ["tv_cabinet", "coffee_table", "side_table"]:
				child.z_index = 0  # 恢复默认图层
				if child.texture != null:
					_register_furniture_collider(
						str(child.name),
						child.position,
						child.texture.get_size(),
						child.scale
					)
		return

	var furniture: Array = room_data.get("furniture", [])
	for item in furniture:
		var fname: String = item.get("name", "furniture")
		var pos_3d: Vector3 = _arr_to_vec3(item.get("pos", [0, 0, 0]))
		var size_3d: Vector3 = _arr_to_vec3(item.get("size", [1, 1, 1]))
		var pos_2d := _to_2d(pos_3d)
		var tex: ImageTexture = null

		# TV cabinet: standalone PNG, resize to 40×160
		if fname == "tv_cabinet":
			var img: Image = Image.load_from_file("res://assets/sprites/电视机柜.png")
			if img != null:
				tex = ImageTexture.create_from_image(img)
		# Coffee table: standalone PNG
		elif fname == "coffee_table":
			var img: Image = Image.load_from_file("res://assets/sprites/茶几.png")
			if img != null:
				tex = ImageTexture.create_from_image(img)
		# Side table: Furn1 tiles (11,0) + (11,1) = 1w×2h
		elif fname == "side_table":
			var sheet := _load_sheet("res://assets/sprites/TopDownHouse_FurnitureState1.png")
			if sheet != null:
				tex = _compose_tiles(sheet, 11, 0, 1, 2, 3)

		if tex != null:
			var sprite := Sprite2D.new()
			sprite.name = fname
			sprite.texture = tex
			sprite.z_index = 0  # 默认图层
			var offset := Vector2.ZERO
			if fname == "side_table":
				sprite.scale = Vector2(0.7, 0.7)
				offset = Vector2(0, 15)
			elif fname == "tv_cabinet":
				offset = Vector2(0, 25)
			sprite.position = pos_2d + offset
			add_child(sprite)
			if fname == "tv_cabinet":
				_tv_cabinet_sprite = sprite
			# 注册碰撞边界到 CollisionManager
			_register_furniture_collider(fname, pos_2d + offset, tex.get_size(), sprite.scale)
		else:
			var size_2d := Vector2(size_3d.x * 40, size_3d.z * 60)
			var color_arr: Array = item.get("color", [0.5, 0.5, 0.5])
			var color := Color(color_arr[0], color_arr[1], color_arr[2])
			var furn := _make_rect_sprite(Vector2(max(size_2d.x, 8), max(size_2d.y, 8)), color)
			furn.name = fname
			furn.z_index = 0  # 默认图层
			furn.position = pos_2d - furn.size / 2.0
			add_child(furn)
			# 注册碰撞边界
			_register_furniture_collider(fname, pos_2d - furn.size / 2.0, furn.size, Vector2.ONE)


# ── Interactive Hotspots ──

func _build_hotspots() -> void:
	# Check for manually placed hotspots (Area2D nodes starting with "Hotspot_")
	var has_manual := false
	var interactions: Array = room_data.get("interactions", [])
	for child in get_children():
		if child is Area2D and str(child.name).begins_with("Hotspot_"):
			has_manual = true
			var hotspot_id := str(child.name).trim_prefix("Hotspot_")
			# Find matching interaction data from JSON and set meta
			var found_inter: Dictionary = {}
			for inter in interactions:
				if str(inter.get("id", "")) == hotspot_id:
					found_inter = inter
					break
			if _is_hidden(found_inter):
				continue
			child.set_meta("interaction", found_inter)
			hotspots.append(child)
			child.body_entered.connect(func(b: Node2D): _on_hotspot_body(b, true, child))
			child.body_exited.connect(func(b: Node2D): _on_hotspot_body(b, false, child))
			child.add_to_group("hotspots")
			move_child(child, get_child_count() - 1)
			# Set up editor visual for manual hotspots
			if hotspot_id == "landline":
				var sheet := _load_sheet("res://assets/sprites/TopDownHouse_SmallItems.png")
				if sheet != null:
					var tex: ImageTexture = sheet.get_tile_scaled(6, 3, 3)
					if tex != null:
						var sprite := Sprite2D.new()
						sprite.name = "Visual"
						sprite.texture = tex
						sprite.centered = true
						sprite.scale = Vector2(0.6, 0.6)
						child.add_child(sprite)
			elif hotspot_id == "family_photo":
				var img: Image = Image.load_from_file("res://assets/sprites/全家福.png")
				if img != null:
					var tex: ImageTexture = ImageTexture.create_from_image(img)
					var sprite := Sprite2D.new()
					sprite.name = "Visual"
					sprite.texture = tex
					sprite.centered = true
					child.add_child(sprite)
			elif hotspot_id != "drawer":
				var col_shape := child.get_node_or_null("CollisionShape2D") as CollisionShape2D
				if col_shape != null and col_shape.shape is RectangleShape2D:
					var rect_size := (col_shape.shape as RectangleShape2D).size
					var visual := ColorRect.new()
					visual.name = "Visual"
					visual.color = Color(0.5, 0.65, 0.85, 0.45)
					visual.size = rect_size
					visual.position = -rect_size / 2.0
					child.add_child(visual)
	if has_manual:
		# Furniture sprites already placed in scene
		return

	for inter in interactions:
		_create_hotspot(inter)


func _create_hotspot(inter: Dictionary) -> void:
	var id: String = inter.get("id", "")
	var name: String = inter.get("name", "")

	if _is_hidden(inter):
		return

	var pos_3d: Vector3 = _arr_to_vec3(inter.get("pos_3d", [0, 0, 0]))
	var size_3d: Vector3 = _arr_to_vec3(inter.get("size_3d", [1, 1, 1]))
	var pos_2d := _to_2d(pos_3d)
	var size_2d := Vector2(maxf(size_3d.x * 60, 32), maxf(size_3d.z * 60, 32))

	var area := Area2D.new()
	area.name = "Hotspot_" + id
	area.set_meta("interaction", inter)
	area.monitoring = true
	area.monitorable = true
	area.collision_layer = 0
	area.collision_mask = 1

	var col := CollisionShape2D.new()
	col.shape = RectangleShape2D.new()
	col.shape.size = size_2d
	area.add_child(col)
	if id == "family_photo":
		col.position = Vector2(0, 35)
	area.position = pos_2d

	# Visual marker — use sprite for landline/family_photo, ColorRect for others
	if id == "landline":
		var sheet := _load_sheet("res://assets/sprites/TopDownHouse_SmallItems.png")
		if sheet != null:
			var tex: ImageTexture = sheet.get_tile_scaled(6, 3, 3)
			if tex != null:
				var sprite := Sprite2D.new()
				sprite.name = "Visual"
				sprite.texture = tex
				sprite.centered = true
				sprite.scale = Vector2(0.6, 0.6)
				sprite.position = Vector2.ZERO
				area.add_child(sprite)
	if id == "family_photo":
		var img: Image = Image.load_from_file("res://assets/sprites/全家福.png")
		if img != null:
			var tex: ImageTexture = ImageTexture.create_from_image(img)
			var sprite := Sprite2D.new()
			sprite.name = "Visual"
			sprite.texture = tex
			sprite.centered = true
			sprite.position = Vector2.ZERO
			area.add_child(sprite)
	if area.get_node_or_null("Visual") == null and id != "drawer":
		var visual := ColorRect.new()
		visual.name = "Visual"
		visual.color = Color(0.5, 0.65, 0.85, 0.45)
		visual.size = size_2d
		visual.position = -size_2d / 2.0
		area.add_child(visual)

	area.body_entered.connect(func(b: Node2D): _on_hotspot_body(b, true, area))
	area.body_exited.connect(func(b: Node2D): _on_hotspot_body(b, false, area))

	area.add_to_group("hotspots")
	add_child(area)
	hotspots.append(area)


func _is_hidden(inter: Dictionary) -> bool:
	var id: String = inter.get("id", "")
	if id == "smartphone" and not GameState.has_item("receipt"):
		return true
	if id == "drawer" and GameState.has_flag("drawer_opened"):
		return true
	return false


# ── Room exits ──

func _build_exits() -> void:
	var room_id: String = room_data.get("id", GameState.current_room_id)
	var room_size := RoomManager.ROOM_SIZE
	var half_w := room_size.x / 2.0
	var half_h := room_size.y / 2.0

	# Doors on the back (top) wall — bottom of frame aligned with skirting
	var door_y := -half_h + WALL_FB - 3.0 - 48  # skirting top - half door height
	var door_x_2012 := -half_w + WALL_SIDE + 100  # moved 40px right

	match room_id:
		"room_2008":
			_add_door("Exit_2012", "2012", door_x_2012, door_y, "room_2012")
		"room_2012":
			_add_door("Exit_2008", "客厅", -30.0, door_y, "room_2008")
		"room_2015":
			_add_door("Exit_2008", "客厅", -30.0, door_y, "room_2008")


func _add_door(e_name: String, e_label: String, pos_x: float, pos_y: float, target_room: String) -> void:
	var door_sheet := _load_sheet("res://assets/sprites/TopDownHouse_DoorsAndWindows.png")
	if door_sheet == null:
		return

	var scale: int = 2  # 16×16 → 32×32 per tile
	var tw: int = 16 * scale

	# ── Build composite door textures ──
	# Frame: tiles (6-7, 0-2) = 2w×3h
	# Closed door: tiles (8-9, 0-2) = 2w×3h
	# Open door: tiles (10-11, 0-2) = 2w×3h

	var frame_tex := _compose_tiles(door_sheet, 6, 0, 2, 3, scale)
	var closed_tex := _compose_tiles(door_sheet, 8, 0, 2, 3, scale)
	var open_tex := _compose_tiles(door_sheet, 10, 0, 2, 3, scale)

	# Container node at door position
	var door_node := Node2D.new()
	door_node.name = e_name
	door_node.position = Vector2(pos_x, pos_y)
	add_child(door_node)

	# Frame sprite (always visible, behind everything)
	if frame_tex != null:
		var frame_sprite := Sprite2D.new()
		frame_sprite.name = "Frame"
		frame_sprite.texture = frame_tex
		frame_sprite.centered = true
		frame_sprite.z_index = 0
		door_node.add_child(frame_sprite)

	# Closed door sprite
	var closed_sprite := Sprite2D.new()
	closed_sprite.name = "Closed"
	closed_sprite.texture = closed_tex
	closed_sprite.centered = true
	closed_sprite.z_index = 0
	door_node.add_child(closed_sprite)

	# Open door sprite (starts hidden)
	var open_sprite := Sprite2D.new()
	open_sprite.name = "Open"
	open_sprite.texture = open_tex
	open_sprite.centered = true
	open_sprite.z_index = 0
	open_sprite.visible = false
	door_node.add_child(open_sprite)

	# Collision area
	var area := Area2D.new()
	area.name = "Area"
	area.set_meta("target_room", target_room)
	area.set_meta("door_node", door_node)
	area.monitoring = true
	area.monitorable = true
	area.collision_layer = 0
	area.collision_mask = 1

	var col := CollisionShape2D.new()
	col.shape = RectangleShape2D.new()
	col.shape.size = Vector2(tw * 2, tw * 3)
	area.add_child(col)

	area.body_entered.connect(func(b: Node2D): _on_door_body(b, true, door_node))
	area.body_exited.connect(func(b: Node2D): _on_door_body(b, false, door_node))

	area.add_to_group("exits")
	door_node.add_child(area)

	# Label below door
	var label := Label.new()
	label.name = "Label"
	label.text = e_label
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.3, 0.25, 0.2))
	label.position = Vector2(-16, tw * 3 / 2.0 + 4)
	door_node.add_child(label)


func _compose_tiles(sheet: SpriteSheet, start_col: int, start_row: int, cols: int, rows: int, scale: int) -> ImageTexture:
	var ts: int = 16
	var tw: int = ts * scale
	var out: Image = Image.create(tw * cols, tw * rows, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))

	for r: int in range(rows):
		for c: int in range(cols):
			var tile_tex: ImageTexture = sheet.get_tile(start_col + c, start_row + r)
			if tile_tex == null:
				continue
			var tile_img: Image = tile_tex.get_image()
			tile_img.resize(tw, tw, Image.INTERPOLATE_NEAREST)
			out.blit_rect(tile_img, Rect2i(0, 0, tw, tw), Vector2i(c * tw, r * tw))

	return ImageTexture.create_from_image(out)


func _on_door_body(body: Node2D, entered: bool, door_node: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	door_node.set_meta("player_nearby", entered)
	var closed_sprite: Sprite2D = door_node.get_node("Closed") as Sprite2D
	var open_sprite: Sprite2D = door_node.get_node("Open") as Sprite2D
	if closed_sprite != null and open_sprite != null:
		closed_sprite.visible = not entered
		open_sprite.visible = entered


func _on_hotspot_body(body: Node2D, entered: bool, area: Area2D) -> void:
	if body.is_in_group("player"):
		area.set_meta("player_nearby", entered)


func _on_exit_body(body: Node2D, entered: bool, area: Area2D) -> void:
	if body.is_in_group("player"):
		area.set_meta("player_nearby", entered)


func _on_item_spawn(item_id: String, item_name: String, pos: Vector2) -> void:
	var spawn_pos := pos
	if item_id == "remote_control" and _tv_cabinet_sprite != null:
		spawn_pos = _tv_cabinet_sprite.global_position + Vector2(-30, 0)

	# Remote control is hidden inside drawer — invisible pickable, no label
	if item_id == "remote_control":
		var area := Area2D.new()
		area.name = "Pickable_" + item_id
		area.set_meta("item_id", item_id)
		area.position = spawn_pos
		area.z_index = 160  # 高于茶几(150)，始终在茶几之上
		area.monitoring = true
		area.monitorable = true
		area.collision_layer = 0
		area.collision_mask = 1
		var col := CollisionShape2D.new()
		col.shape = RectangleShape2D.new()
		col.shape.size = Vector2(40, 40)
		area.add_child(col)
		area.body_entered.connect(func(b: Node2D): _on_pickable_body(b, true, area))
		area.body_exited.connect(func(b: Node2D): _on_pickable_body(b, false, area))
		area.add_to_group("pickables")
		add_child(area)
		return

	var pickable: Area2D = load("res://scripts/items/PickableItem.gd").new()
	pickable.setup(item_id, item_name, spawn_pos)
	pickable.add_to_group("pickables")
	pickable.z_index = 160  # 高于茶几(150)，始终在茶几之上
	add_child(pickable)


func _on_pickable_body(body: Node2D, entered: bool, area: Area2D) -> void:
	if body.is_in_group("player"):
		area.set_meta("player_nearby", entered)


func _on_spawn_anim(anim_name: String) -> void:
	if anim_name == "drawer_open" and _tv_cabinet_sprite != null:
		var img: Image = Image.load_from_file("res://assets/sprites/电视机柜拉开.png")
		if img != null:
			_tv_cabinet_sprite.texture = ImageTexture.create_from_image(img)
			_drawer_open = true
			_tv_cabinet_orig_pos = _tv_cabinet_sprite.position
			_tv_cabinet_sprite.position = _tv_cabinet_orig_pos + DRAWER_OPEN_OFFSET


func _on_inventory_changed(_items: Array[String]) -> void:
	if _drawer_open and GameState.has_item("remote_control"):
		_drawer_open = false
		var img: Image = Image.load_from_file("res://assets/sprites/电视机柜.png")
		if img != null and _tv_cabinet_sprite != null:
			_tv_cabinet_sprite.texture = ImageTexture.create_from_image(img)
			_tv_cabinet_sprite.position = _tv_cabinet_orig_pos


# ── Player placement ──

func _place_player(from_dir: String) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var player: CharacterBody2D = tree.get_first_node_in_group("player")
	if player == null:
		return

	var room_size := RoomManager.ROOM_SIZE
	var spawn_pos := Vector2.ZERO

	match from_dir:
		"room_2012": spawn_pos = Vector2(-room_size.x / 2.0 + 60, 0)
		"room_2015": spawn_pos = Vector2(room_size.x / 2.0 - 60, 0)
		_:           spawn_pos = Vector2(0, -room_size.y / 2.0 + WALL_FB + 40)

	player.global_position = spawn_pos


# ── Coordinate mapping: 3D → 2D top-down ──

func _arr_to_vec3(arr: Array) -> Vector3:
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))


func _to_2d(pos_3d: Vector3) -> Vector2:
	var x: float = pos_3d.x * 60.0
	var y: float = (pos_3d.z + 3.0) * 70.0
	return Vector2(x, y)


# ── Collision registration ──

## 将家具的 2D 碰撞边界注册到全局 CollisionManager
## 每个家具单独调整碰撞区域，以匹配视觉上的合理碰撞体
##
## @param fname: 家具名称（用作唯一 ID）
## @param pos: 家具左上角位置
## @param size: 家具纹理原始尺寸
## @param scale: 家具缩放
func _register_furniture_collider(fname: String, pos: Vector2, size: Vector2, scale: Vector2) -> void:
	var scaled_size := size * scale
	var adj_pos := pos
	var adj_size := scaled_size

	# ── 各家具碰撞区域微调 ──
	match fname:
		"coffee_table":
			# 茶几（房间中心）：向左移动 58px，上方延伸 20px，下方缩短 25px，左右碰撞各增加 15px
			adj_pos.x -= 58.0
			adj_pos.y -= 20.0
			adj_size.x *= 2.0 / 3.0  # 右方缩小约 1/3
			adj_size.x += 30.0  # 左右各 +15px
			adj_size.y += 20.0 - 18.0  # 上方 +20，下方 -18（原 -25 + 7）
		"tv_cabinet":
			# 电视柜（房间上方）：向左移动 65px，下方缩短 10px，右方缩小约 1/3，左右碰撞各增加 15px
			adj_pos.x -= 65.0
			adj_size.x *= 2.0 / 3.0  # 右方缩小约 1/3
			adj_size.x += 30.0  # 左右各 +15px
			adj_size.y -= 10.0  # 下方缩短 10px
		"side_table":
			# 边桌/台灯（右上角）：右侧缩短 30px，下方缩短 35px，左右碰撞各增加 5px
			adj_pos.x -= 5.0
			adj_size.x -= 20.0  # 原 -30 + 10 = -20
			adj_size.y -= 35.0

	# 所有物品纵轴碰撞缩短至原来的 2/3（即缩短 1/3）
	adj_size.y *= 2.0 / 3.0

	var rect := Rect2(adj_pos, adj_size)
	CollisionManager.register_collider(fname, rect)
