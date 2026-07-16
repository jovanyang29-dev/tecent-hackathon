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
var _room_size_override: Vector2 = Vector2.ZERO
var _phone_ring_player: AudioStreamPlayer = null
var _bath_anim_active: bool = false
var _phone_ringing: bool = false
var _phone_ring_gen: AudioStreamGenerator = null
var _phone_ring_phase: float = 0.0
var _phone_ring_elapsed: float = 0.0
const RING_FREQ := 425.0
const RING_SAMPLE_RATE := 44100
const RING_BURST := 0.4   # 响铃时长
const RING_GAP := 0.2     # 间隙
const RING_PAUSE := 1.2   # 静音段
const RING_CYCLE := RING_BURST + RING_GAP + RING_BURST + RING_PAUSE  # = 2.2s


func _get_room_size() -> Vector2:
	if _room_size_override != Vector2.ZERO:
		return _room_size_override
	var size_arr: Array = room_data.get("room_size", [])
	if size_arr.size() >= 2:
		_room_size_override = Vector2(float(size_arr[0]), float(size_arr[1]))
		return _room_size_override
	return RoomManager.ROOM_SIZE
var _tv_cabinet_sprite: Sprite2D = null
var _fridge_sprite: Sprite2D = null
var _basket_sprite: Sprite2D = null
var _drawer_open := false
var _tv_cabinet_orig_pos: Vector2 = Vector2.ZERO
var _textures_pixelated := false
const DRAWER_OPEN_OFFSET := Vector2(0, 2)
static var _modern_collision_cache: Dictionary = {}  # 缓存像素级碰撞数据


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
	_refresh_room_hotspots()
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
	_restore_drawer_state()
	_restore_cooking_state()
	_restore_story_state()
	_build_hotspots()
	_refresh_room_hotspots()
	_override_father_story_hotspots()

	_build_exits()
	InteractionManager.item_spawn_requested.connect(_on_item_spawn)
	InteractionManager.spawn_anim_triggered.connect(_on_spawn_anim)
	GameState.inventory_changed.connect(_on_inventory_changed)
	GameState.flag_changed.connect(_on_flag_changed)
	if not DialogueManager.dialogue_finished.is_connected(_on_dialogue_finished):
		DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
	if not DialogueManager.dialogue_started.is_connected(_on_dialogue_started):
		DialogueManager.dialogue_started.connect(_on_dialogue_started)
	if not DialogueManager.dialogue_event.is_connected(_on_dialogue_event):
		DialogueManager.dialogue_event.connect(_on_dialogue_event)
	_phone_ringing = false
	_place_player(entry_dir)

	# 首次进入08卧室时自动播放对话
	if room_data.get("id") == "room_bedroom" and not GameState.has_flag("entered_bedroom"):
		GameState.set_flag("entered_bedroom", true)
		DialogueManager.start_dialogue.call_deferred("res://data/dialogues/enter_bedroom_first.json")

	# 首次进入厨房见到奶奶时自动播放对话 — 表达思念与惊讶（厨房门出现后第一次进入触发）
	if room_data.get("id") == "kitchen" and not GameState.has_flag("entered_kitchen") and GameState.has_flag("kitchen_door_revealed"):
		GameState.set_flag("entered_kitchen", true)
		DialogueManager.start_dialogue.call_deferred("res://data/dialogues/enter_kitchen_first.json")

	# 首次进入2026客厅时自动播放对话 — 对裂缝和穿越的惊讶
	if room_data.get("id") == "room_2026" and not GameState.has_flag("entered_2026"):
		GameState.set_flag("entered_2026", true)
		DialogueManager.start_dialogue.call_deferred("res://data/dialogues/enter_2026_first.json")


func _load_full_room_data() -> Dictionary:
	var room_id: String = room_data.get("id", GameState.current_room_id)
	var path := "res://data/rooms/%s.json" % room_id
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


func _build_floor() -> void:
	var room_size := _get_room_size()
	var half_w := room_size.x / 2.0
	var half_h := room_size.y / 2.0

	var floor_x := -half_w + WALL_SIDE
	var floor_y := -half_h + WALL_FB
	var floor_w := int(room_size.x - WALL_SIDE * 2)
	var floor_h := int(room_size.y - WALL_FB * 2)

	# 支持房间定制地板颜色（默认木色，厨房偏白）
	var base_color_arr: Array = room_data.get("floor_base", [])
	var alt_color_arr: Array = room_data.get("floor_alt", [])
	var line_color_arr: Array = room_data.get("floor_line", [])

	var base_col := Color(0.48, 0.33, 0.18)
	var alt_col := Color(0.51, 0.36, 0.20)
	var line_col := Color(0.28, 0.18, 0.08)

	if base_color_arr.size() >= 3:
		base_col = Color(base_color_arr[0], base_color_arr[1], base_color_arr[2])
	if alt_color_arr.size() >= 3:
		alt_col = Color(alt_color_arr[0], alt_color_arr[1], alt_color_arr[2])
	if line_color_arr.size() >= 3:
		line_col = Color(line_color_arr[0], line_color_arr[1], line_color_arr[2])

	var tile_tex := _make_tile_floor(floor_w, floor_h, base_col, alt_col, line_col)

	var floor := Sprite2D.new()
	floor.name = "Floor"
	floor.texture = tile_tex
	floor.centered = false
	floor.position = Vector2(floor_x, floor_y)
	floor.z_index = -2  # 最底层
	add_child(floor)
	move_child(floor, 0)

	# 卧室卫生间区域：白黄色瓷砖地板，与主地板相同格子样式
	var is_bedroom: bool = room_data.get("id") in ["room_bedroom", "room_2026_bedroom"]
	if is_bedroom:
		# 隔断墙 x=48（相对于房间中心），在 floor 坐标系中：divider_floor_x = 48 - floor_x
		var divider_floor_x := 48.0 - floor_x
		var bath_floor_w := int(floor_w - divider_floor_x)
		var bath_floor_h := floor_h
		if bath_floor_w > 0:
			# 白黄色调，不刺眼，保留格子地板纹理
			var bath_base := Color(0.96, 0.93, 0.83)
			var bath_alt := Color(0.93, 0.90, 0.80)
			var bath_line := Color(0.85, 0.80, 0.68)
			var bath_tile_tex := _make_tile_floor(bath_floor_w, bath_floor_h, bath_base, bath_alt, bath_line)
			var bath_floor := Sprite2D.new()
			bath_floor.name = "BathroomFloor"
			bath_floor.texture = bath_tile_tex
			bath_floor.centered = false
			bath_floor.position = Vector2(floor_x + divider_floor_x, floor_y)
			bath_floor.z_index = -1  # 仅高于主地板，低于其他所有物件
			add_child(bath_floor)


func _build_walls() -> void:
	var room_size := _get_room_size()
	var half_w := room_size.x / 2.0
	var half_h := room_size.y / 2.0
	var is_kitchen: bool = room_data.get("id") == "kitchen" or room_data.get("id") == "room_2026_kitchen"
	var is_living_room: bool = room_data.get("id") in ["room_2008", "room_2008_return"]
	var is_bedroom_wall: bool = room_data.get("id") in ["room_bedroom", "room_2026_bedroom"]

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
		if is_kitchen or is_living_room:
			tf.z_index = 1  # 上方墙体在地板之上
		# Edge narrowing (3px each side for kitchen/living_room)
		if (is_kitchen or is_living_room) and col == 0:
			tf.position.x += 3
			tf.scale.x = (WALL_BLOCK - 3) / WALL_BLOCK
		elif (is_kitchen or is_living_room) and col >= int(room_size.x) - int(WALL_BLOCK):
			tf.scale.x = (WALL_BLOCK - 3) / WALL_BLOCK
		add_child(tf)
		# Face row 1 (gray — vertical wall, below white top)
		var f1 := _make_rect_sprite(Vector2(WALL_BLOCK, WALL_BLOCK), face_color)
		f1.name = "TopWall_F1_%d" % col
		f1.position = Vector2(x, -half_h + WALL_BLOCK)
		if is_kitchen:
			f1.z_index = 0  # 厨房：灰色墙在白色墙下方
		if is_kitchen and col == 0:
			f1.position.x += 3
			f1.scale.x = (WALL_BLOCK - 3) / WALL_BLOCK
		elif is_kitchen and col >= int(room_size.x) - int(WALL_BLOCK):
			f1.scale.x = (WALL_BLOCK - 3) / WALL_BLOCK
		add_child(f1)
		# Face row 2 (gray — vertical wall, below white top)
		var f2 := _make_rect_sprite(Vector2(WALL_BLOCK, WALL_BLOCK), face_color)
		f2.name = "TopWall_F2_%d" % col
		f2.position = Vector2(x, -half_h + WALL_BLOCK * 2)
		if is_kitchen:
			f2.z_index = 0
		if is_kitchen and col == 0:
			f2.position.x += 3
			f2.scale.x = (WALL_BLOCK - 3) / WALL_BLOCK
		elif is_kitchen and col >= int(room_size.x) - int(WALL_BLOCK):
			f2.scale.x = (WALL_BLOCK - 3) / WALL_BLOCK
		add_child(f2)
		# Face row 3 (gray — vertical wall into room, below white top)
		var f3 := _make_rect_sprite(Vector2(WALL_BLOCK, WALL_BLOCK), face_color)
		f3.name = "TopWall_F3_%d" % col
		f3.position = Vector2(x, -half_h + WALL_BLOCK * 3)
		if is_kitchen:
			f3.z_index = 0
		if is_kitchen and col == 0:
			f3.position.x += 3
			f3.scale.x = (WALL_BLOCK - 3) / WALL_BLOCK
		elif is_kitchen and col >= int(room_size.x) - int(WALL_BLOCK):
			f3.scale.x = (WALL_BLOCK - 3) / WALL_BLOCK
		add_child(f3)

	# ═══════════════════════════════════════════════
	# BOTTOM wall (front) — 3D: 40px white top + 120px gray face
	# ═══════════════════════════════════════════════
	for col: int in range(0, int(room_size.x), int(WALL_BLOCK)):
		var x := -half_w + float(col)
		# 厨房：跳过两侧边缘列（col=0 和 col=last）的白色顶面，与侧墙内壁对齐
		var is_edge_col := (col == 0 or col >= int(room_size.x) - int(WALL_BLOCK))
		if not (is_kitchen and is_edge_col):
			# Top face (white — horizontal surface, seen first from room)
			var tf := _make_rect_sprite(Vector2(WALL_BLOCK, WALL_BLOCK), top_color)
			tf.name = "BotWall_T_%d" % col
			tf.position = Vector2(x, half_h - WALL_FB)
			tf.z_index = 200
			# Narrow edges by 5px on left/right (skip for kitchen: align flush)
			if not is_kitchen:
				if col == 0:
					tf.position.x += 5
					tf.scale.x = (WALL_BLOCK - 5) / WALL_BLOCK
				elif col >= int(room_size.x) - int(WALL_BLOCK):
					tf.scale.x = (WALL_BLOCK - 5) / WALL_BLOCK
			add_child(tf)
		# Kitchen: skip edge blocks so gray face fits between side walls
		if is_kitchen and is_edge_col:
			continue
		# Face row 1 (gray — vertical wall)
		var f1 := _make_rect_sprite(Vector2(WALL_BLOCK, WALL_BLOCK), face_color)
		f1.name = "BotWall_F1_%d" % col
		f1.position = Vector2(x, half_h - WALL_FB + WALL_BLOCK)
		if is_kitchen or is_living_room or is_bedroom_wall:
			f1.z_index = 80 if is_living_room else 20  # 下方墙在玩家之上
		add_child(f1)
		# Face row 2 (gray — vertical wall)
		var f2 := _make_rect_sprite(Vector2(WALL_BLOCK, WALL_BLOCK), face_color)
		f2.name = "BotWall_F2_%d" % col
		f2.position = Vector2(x, half_h - WALL_FB + WALL_BLOCK * 2)
		if is_kitchen or is_living_room or is_bedroom_wall:
			f2.z_index = 80 if is_living_room else 20
		add_child(f2)
		# Face row 3 (gray — vertical wall, closest to edge)
		var f3 := _make_rect_sprite(Vector2(WALL_BLOCK, WALL_BLOCK), face_color)
		f3.name = "BotWall_F3_%d" % col
		f3.position = Vector2(x, half_h - WALL_FB + WALL_BLOCK * 3)
		if is_kitchen or is_living_room or is_bedroom_wall:
			f3.z_index = 80 if is_living_room else 20
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

	# ═══════════════════════════════════════════════
	# 卧室内部隔断墙（厕所隔断）
	# ═══════════════════════════════════════════════
	var is_bedroom: bool = room_data.get("id") in ["room_bedroom", "room_2026_bedroom"]
	if is_bedroom:
		# 竖向隔断墙：在 x=48 处（原60缩放至80%），从上内墙延伸到下内墙
		var divider_x: float = 48.0
		var divider_w: float = 16.0
		var wall_inner_top := -half_h + WALL_FB
		var wall_inner_bot := half_h - WALL_FB
		var divider_h := wall_inner_bot - wall_inner_top
		# 门洞参数：在隔断墙中间偏上位置留一个通道
		var door_gap_top: float = -64.0   # 门洞上沿（相对于房间中心）
		var door_gap_bot: float = 16.0    # 门洞下沿
		var door_gap_h := door_gap_bot - door_gap_top  # 门洞高度
		var gap_width := 32.0             # 门洞宽度（留作通道，不画墙）

		# 隔断墙上段（门洞上方）：上方缩短40px（伸长10px），下方缩短30px
		var upper_start := -half_h + 40
		var upper_end := door_gap_top - 30
		var upper_h := upper_end - upper_start
		if upper_h > 0:
			var div_upper := _make_rect_sprite(Vector2(divider_w, upper_h), face_color)
			div_upper.name = "DividerWall_Upper"
			div_upper.position = Vector2(divider_x, upper_start)
			div_upper.z_index = 40
			add_child(div_upper)

		# 隔断墙下段（门洞下方）：不延伸
		var lower_h := wall_inner_bot - door_gap_bot
		if lower_h > 0:
			var div_lower := _make_rect_sprite(Vector2(divider_w, lower_h), face_color)
			div_lower.name = "DividerWall_Lower"
			div_lower.position = Vector2(divider_x, door_gap_bot)
			div_lower.z_index = 40
			add_child(div_lower)

		# 隔断墙左边线（仅覆盖有墙的部分）
		if upper_h > 0:
			var edge_left_top := _make_rect_sprite(Vector2(3, upper_h), Color(0.14, 0.12, 0.09))
			edge_left_top.name = "DividerWall_EdgeLeftTop"
			edge_left_top.position = Vector2(divider_x, upper_start)
			edge_left_top.z_index = 41
			add_child(edge_left_top)
		if lower_h > 0:
			var edge_left_bot := _make_rect_sprite(Vector2(3, lower_h), Color(0.14, 0.12, 0.09))
			edge_left_bot.name = "DividerWall_EdgeLeftBot"
			edge_left_bot.position = Vector2(divider_x, door_gap_bot)
			edge_left_bot.z_index = 41
			add_child(edge_left_bot)

		# 隔断墙右边线（仅覆盖有墙的部分）
		if upper_h > 0:
			var edge_right_top := _make_rect_sprite(Vector2(3, upper_h), Color(0.14, 0.12, 0.09))
			edge_right_top.name = "DividerWall_EdgeRightTop"
			edge_right_top.position = Vector2(divider_x + divider_w - 3, upper_start)
			edge_right_top.z_index = 41
			add_child(edge_right_top)
		if lower_h > 0:
			var edge_right_bot := _make_rect_sprite(Vector2(3, lower_h), Color(0.14, 0.12, 0.09))
			edge_right_bot.name = "DividerWall_EdgeRightBot"
			edge_right_bot.position = Vector2(divider_x + divider_w - 3, door_gap_bot)
			edge_right_bot.z_index = 41
			add_child(edge_right_bot)

		# 注册隔断墙碰撞（上段碰撞向下延伸20px，防止贴墙穿过）
		if upper_h > 0:
			var upper_rect := Rect2(Vector2(divider_x, upper_start), Vector2(divider_w, upper_h + 80))
			CollisionManager.register_collider("divider_upper", upper_rect)
		if lower_h > 0:
			var lower_rect := Rect2(Vector2(divider_x, door_gap_bot), Vector2(divider_w, lower_h))
			CollisionManager.register_collider("divider_lower", lower_rect)

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

func _make_tile_floor(width_px: int, height_px: int, base := Color(0.48, 0.33, 0.18), alt := Color(0.51, 0.36, 0.20), line_color := Color(0.28, 0.18, 0.08)) -> ImageTexture:
	var img: Image = Image.create(width_px, height_px, false, Image.FORMAT_RGBA8)
	var tile_size: int = 40

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
		if child is Sprite2D and child.visible and str(child.name) in ["tv_cabinet", "coffee_table", "side_table", "sofa_chair", "stove", "refrigerator", "cabinet", "crate", "clock", "plate", "grandma", "bed", "wardrobe", "nightstand", "toilet", "sink", "bathtub", "basket", "leek_bag", "corner_cabinet", "modern_tvstand", "modern_sofa", "modern_dining_table", "modern_cabinet", "modern_plant", "modern_shoe_rack", "old_clock", "modern_plant2", "k26_upper_cabinet", "k26_drawer", "k26_appliances", "k26_microwave", "k26_tools", "k26_stove", "k26_sink", "k26_dishwasher", "modern_bed", "modern_toilet_2026", "modern_toilet", "modern_bathtub_2026", "modern_towel_rack_2026", "modern_towel_rack", "modern_shelf_2026", "modern_shelf", "modern_shower_2026", "modern_shower", "modern_bathtub", "modern_bathtub_2026", "modern_bathroom_shelf", "modern_sink_2026"]:
			has_manual = true
			move_child(child, get_child_count() - 1)
			if child.name == "basket":
				_basket_sprite = child
				# 白菜已被拾取时，进入厨房应直接显示空篮
				if GameState.has_flag("got_cabbage"):
					var empty_img: Image = Image.load_from_file("res://assets/sprites/竹篮.png")
					if empty_img != null:
						child.texture = ImageTexture.create_from_image(empty_img)
			elif child.name == "tv_cabinet":
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
			elif child.name == "bed" and child.texture == null:
				var img: Image = Image.load_from_file("res://assets/sprites/卧室_床.png")
				if img != null:
					child.texture = ImageTexture.create_from_image(img)
			elif child.name == "wardrobe" and child.texture == null:
				var img: Image = Image.load_from_file("res://assets/sprites/卧室_衣柜.png")
				if img != null:
					child.texture = ImageTexture.create_from_image(img)
			elif child.name == "nightstand" and child.texture == null:
				var img: Image = Image.load_from_file("res://assets/sprites/卧室_床头柜.png")
				if img != null:
					child.texture = ImageTexture.create_from_image(img)
			elif child.name == "toilet" and child.texture == null:
				var img: Image = Image.load_from_file("res://assets/sprites/厕所_马桶.png")
				if img != null:
					child.texture = ImageTexture.create_from_image(img)
			elif child.name == "sink" and child.texture == null:
				var img: Image = Image.load_from_file("res://assets/sprites/厕所_水槽.png")
				if img != null:
					child.texture = ImageTexture.create_from_image(img)
			elif child.name == "bathtub" and child.texture == null:
				var img: Image = Image.load_from_file("res://assets/sprites/厕所_浴缸.png")
				if img != null:
					child.texture = ImageTexture.create_from_image(img)
			elif child.name == "refrigerator":
				_fridge_sprite = child
			elif child.name == "leek_bag":
				# 韭菜袋子：初始隐藏，grandma_invited 后才显示，拾取后直接隐藏
				# 从2026返回后不再显示韭菜
				if GameState.has_flag("returned_from_2026") or not GameState.has_flag("grandma_invited") or GameState.has_flag("got_chives"):
					child.visible = false
				else:
					child.visible = true
			elif child.name == "flour_bag":
				# 面粉袋：拾取后隐藏
				if GameState.has_flag("got_flour"):
					child.visible = false
			# ── 2026厨房家具：无条件直接加载纹理 ──
			elif child.name == "k26_upper_cabinet":
				var img: Image = Image.load_from_file("res://assets/sprites/26厨房_吊柜.png")
				if img != null:
					child.texture = ImageTexture.create_from_image(img)
					child.visible = true
			elif child.name == "k26_drawer":
				var img: Image = Image.load_from_file("res://assets/sprites/26厨房_抽屉柜.png")
				if img != null:
					child.texture = ImageTexture.create_from_image(img)
					child.visible = true
			elif child.name == "k26_appliances":
				var img: Image = Image.load_from_file("res://assets/sprites/26厨房_小家电.png")
				if img != null:
					child.texture = ImageTexture.create_from_image(img)
					child.visible = true
			elif child.name == "k26_microwave":
				var img: Image = Image.load_from_file("res://assets/sprites/26厨房_微波炉.png")
				if img != null:
					child.texture = ImageTexture.create_from_image(img)
					child.visible = true
			elif child.name == "k26_tools":
				var img: Image = Image.load_from_file("res://assets/sprites/26厨房_厨具.png")
				if img != null:
					child.texture = ImageTexture.create_from_image(img)
					child.visible = true
			elif child.name == "k26_stove":
				var img: Image = Image.load_from_file("res://assets/sprites/26厨房_灶台.png")
				if img != null:
					child.texture = ImageTexture.create_from_image(img)
					child.visible = true
			elif child.name == "k26_sink":
				var img: Image = Image.load_from_file("res://assets/sprites/26厨房_水槽.png")
				if img != null:
					child.texture = ImageTexture.create_from_image(img)
					child.visible = true
			elif child.name == "k26_dishwasher":
				var img: Image = Image.load_from_file("res://assets/sprites/26厨房_洗碗机.png")
				if img != null:
					child.texture = ImageTexture.create_from_image(img)
					child.visible = true
	# 诊断：打印 k26 家具加载后的纹理状态
	if room_data.get("id") == "room_2026_kitchen":
		var k26_count := 0
		var k26_null := 0
		for c in get_children():
			if c is Sprite2D and str(c.name).begins_with("k26_"):
				k26_count += 1
				if c.texture == null:
					k26_null += 1
		print("K26 DIAG: found=", k26_count, " null_texture=", k26_null)
	if has_manual:
		# Pixelate specific furniture to pixel-art style (tv_cabinet and coffee_table keep original)
		if not _textures_pixelated:
			for child in get_children():
				if child is Sprite2D and child.name in ["old_tv", "side_table"]:
					child.texture = _pixelate_texture(child.texture)
			_textures_pixelated = true
		# Furniture sprites already placed in scene — register colliders for them
		for child in get_children():
			if child is Sprite2D and child.visible and str(child.name) in ["tv_cabinet", "coffee_table", "sofa_chair", "stove", "refrigerator", "cabinet", "crate", "clock", "plate", "grandma", "bed", "wardrobe", "nightstand", "toilet", "sink", "bathtub", "basket", "leek_bag", "corner_cabinet", "modern_tvstand", "modern_sofa", "modern_dining_table", "modern_cabinet", "modern_plant", "modern_plant2", "modern_shoe_rack", "k26_upper_cabinet", "k26_drawer", "k26_appliances", "k26_microwave", "k26_tools", "k26_stove", "k26_sink", "k26_dishwasher", "modern_bed", "modern_toilet_2026", "modern_toilet", "modern_bathtub_2026", "modern_towel_rack_2026", "modern_towel_rack", "modern_shelf_2026", "modern_shelf", "modern_shower_2026", "modern_shower", "modern_bathtub", "modern_bathtub_2026", "modern_bathroom_shelf", "modern_sink_2026"]:
				# grandma/basket/leek_bag/现代家具 保持 TSCN 中设定的 z_index，其他家具恢复默认图层
				if child.name not in ["grandma", "basket", "leek_bag", "coffee_table", "modern_dining_table", "modern_tvstand", "modern_cabinet", "old_clock", "modern_plant", "modern_plant2", "k26_upper_cabinet", "k26_drawer", "k26_appliances", "k26_microwave", "k26_tools", "k26_stove", "k26_sink", "k26_dishwasher", "modern_bed", "modern_toilet_2026", "modern_toilet", "modern_bathtub_2026", "modern_towel_rack_2026", "modern_towel_rack", "modern_shelf_2026", "modern_shelf", "modern_shower_2026", "modern_shower", "modern_bathtub", "modern_bathtub_2026", "modern_bathroom_shelf", "modern_sink_2026"]:
					child.z_index = 0
				var cname := str(child.name)
				if cname.begins_with("modern_"):
					# 现代家具：使用像素级碰撞矩形（多个小矩形贴合实际形状）
					if cname == "modern_dining_table":
						# 餐桌顶部碰撞下缩 55px
						_register_modern_pixel_colliders(cname, child.position, child.scale, 55.0)
					else:
						_register_modern_pixel_colliders(cname, child.position, child.scale)
				else:
					if child.texture == null:
						continue
					var tex_size: Vector2 = child.texture.get_size()
					# 客厅/厨房家具：使用 Sprite 中心点（与 _register_furniture_collider 的微调参数校准）
					var tex_pos: Vector2 = child.position
					var bedroom_items := ["bed", "wardrobe", "nightstand", "toilet", "sink", "bathtub", "sofa_chair", "k26_upper_cabinet", "k26_drawer", "k26_appliances", "k26_microwave", "k26_tools", "k26_stove", "k26_sink", "k26_dishwasher"]
					if cname in bedroom_items:
						# 卧室家具：使用实际可见内容区域，排除透明边距
						var img: Image = child.texture.get_image()
						var bbox: Rect2 = _get_visible_bbox(img)
						tex_size = bbox.size
						# 转换为左上角坐标：中心 - 半尺寸 + 可见内容偏移
						tex_pos = child.position - child.texture.get_size() * child.scale / 2.0 + bbox.position * child.scale
					_register_furniture_collider(cname, tex_pos, tex_size, child.scale)
		return

	var furniture: Array = room_data.get("furniture", [])
	for item in furniture:
		var fname: String = item.get("name", "furniture")
		var pos_2d: Vector2
		# 支持 pos_2d 直接指定 2D 像素坐标，也兼容旧的 pos 3D 坐标
		if item.has("pos_2d"):
			var arr_2d: Array = item.get("pos_2d", [0, 0])
			pos_2d = Vector2(float(arr_2d[0]), float(arr_2d[1]))
		else:
			var pos_3d: Vector3 = _arr_to_vec3(item.get("pos", [0, 0, 0]))
			pos_2d = _to_2d(pos_3d)
		var size_3d: Vector3 = _arr_to_vec3(item.get("size", [1, 1, 1]))
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
		# Modern TV stand (room 2026)
		elif fname == "modern_tvstand":
			var img: Image = Image.load_from_file("res://assets/sprites/modern_tvstand.png")
			if img != null:
				tex = ImageTexture.create_from_image(img)
		# Modern sofa (room 2026) - blue
		elif fname == "modern_sofa":
			var img: Image = Image.load_from_file("res://assets/sprites/modern_sofa.png")
			if img != null:
				tex = ImageTexture.create_from_image(img)
		# Modern dining table (room 2026)
		elif fname == "modern_dining_table":
			var img: Image = Image.load_from_file("res://assets/sprites/modern_dining_table.png")
			if img != null:
				tex = ImageTexture.create_from_image(img)
		# Modern cabinet with plant (room 2026)
		elif fname == "modern_cabinet":
			var img: Image = Image.load_from_file("res://assets/sprites/modern_cabinet.png")
			if img != null:
				tex = ImageTexture.create_from_image(img)
		# Modern plant (room 2026)
		elif fname == "modern_plant":
			var img: Image = Image.load_from_file("res://assets/sprites/modern_plant.png")
			if img != null:
				tex = ImageTexture.create_from_image(img)
		# Modern shoe rack (room 2026)
		elif fname == "modern_shoe_rack":
			var img: Image = Image.load_from_file("res://assets/sprites/modern_shoe_rack.png")
			if img != null:
				tex = ImageTexture.create_from_image(img)
		# Stove: standalone PNG (kitchen) — scaled 4x smaller
		elif fname == "stove":
			var img: Image = Image.load_from_file("res://assets/sprites/炉灶.png")
			if img != null:
				tex = ImageTexture.create_from_image(img)
		# Refrigerator: standalone PNG (kitchen) — scaled 4x smaller
		elif fname == "refrigerator":
			var img: Image = Image.load_from_file("res://assets/sprites/冰箱.png")
			if img != null:
				tex = ImageTexture.create_from_image(img)
		# Food soup on stove
		elif fname == "food_soup":
			var img: Image = Image.load_from_file("res://assets/sprites/food_top.png")
			if img != null:
				tex = ImageTexture.create_from_image(img)
		# Food fried egg on stove
		elif fname == "food_egg":
			var img: Image = Image.load_from_file("res://assets/sprites/food_bottom.png")
			if img != null:
				tex = ImageTexture.create_from_image(img)
		# Kitchen cabinet (from SmallItems sprite sheet)
		elif fname == "cabinet":
			var img: Image = Image.load_from_file("res://assets/sprites/kitchen_cabinet.png")
			if img != null:
				tex = ImageTexture.create_from_image(img)
		# Kitchen crate (from SmallItems sprite sheet)
		elif fname == "crate":
			var img: Image = Image.load_from_file("res://assets/sprites/kitchen_crate.png")
			if img != null:
				tex = ImageTexture.create_from_image(img)
		# Kitchen clock (from SmallItems sprite sheet)
		elif fname == "clock":
			var img: Image = Image.load_from_file("res://assets/sprites/kitchen_clock.png")
			if img != null:
				tex = ImageTexture.create_from_image(img)
		# Kitchen plate (from SmallItems sprite sheet)
		elif fname == "plate":
			var img: Image = Image.load_from_file("res://assets/sprites/kitchen_plate.png")
			if img != null:
				tex = ImageTexture.create_from_image(img)
		# Side table: Furn1 tiles (11,0) + (11,1) = 1w×2h
		elif fname == "side_table":
			var sheet := _load_sheet("res://assets/sprites/TopDownHouse_FurnitureState1.png")
			if sheet != null:
				tex = _compose_tiles(sheet, 11, 0, 1, 2, 3)
		# Bed: standalone PNG
		elif fname == "bed":
			var img: Image = Image.load_from_file("res://assets/sprites/卧室_床.png")
			if img != null:
				tex = ImageTexture.create_from_image(img)
		# Wardrobe: standalone PNG
		elif fname == "wardrobe":
			var img: Image = Image.load_from_file("res://assets/sprites/卧室_衣柜.png")
			if img != null:
				tex = ImageTexture.create_from_image(img)
		# Nightstand: standalone PNG
		elif fname == "nightstand":
			var img: Image = Image.load_from_file("res://assets/sprites/卧室_床头柜.png")
			if img != null:
				tex = ImageTexture.create_from_image(img)
		# Toilet: standalone PNG
		elif fname == "toilet":
			var img: Image = Image.load_from_file("res://assets/sprites/厕所_马桶.png")
			if img != null:
				tex = ImageTexture.create_from_image(img)
		# Sink: standalone PNG
		elif fname == "sink":
			var img: Image = Image.load_from_file("res://assets/sprites/厕所_水槽.png")
			if img != null:
				tex = ImageTexture.create_from_image(img)
		# Bathtub: standalone PNG
		elif fname == "bathtub":
			var img: Image = Image.load_from_file("res://assets/sprites/厕所_浴缸.png")
			if img != null:
				tex = ImageTexture.create_from_image(img)

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
			elif fname == "modern_tvstand":
				sprite.scale = Vector2(0.2, 0.2)
				sprite.z_index = 1
			elif fname == "modern_sofa":
				sprite.scale = Vector2(0.225, 0.225)
			elif fname == "modern_dining_table":
				sprite.scale = Vector2(0.175, 0.175)
			elif fname == "modern_cabinet":
				sprite.scale = Vector2(0.25, 0.25)
				sprite.z_index = 2
			elif fname == "modern_plant":
				sprite.scale = Vector2(0.2, 0.2)
				sprite.z_index = 3
			elif fname == "modern_shoe_rack":
				sprite.scale = Vector2(0.175, 0.175)
			elif fname == "stove" or fname == "refrigerator":
				sprite.scale = Vector2(0.25, 0.25)
				sprite.z_index = 5  # 厨房：厨具在上方墙之上、角色之下
			elif fname == "food_soup":
				sprite.scale = Vector2(0.25, 0.25)
				sprite.z_index = 8
				offset = Vector2(0, -20)
			elif fname == "food_egg":
				sprite.scale = Vector2(0.5, 0.5)
				sprite.z_index = 8
				sprite.flip_h = true
			elif fname == "cabinet":
				sprite.scale = Vector2(4, 4)
				sprite.z_index = 0
			elif fname == "clock":
				sprite.scale = Vector2(2.67, 2.67)
				sprite.z_index = 0
			elif fname == "crate" or fname == "plate":
				sprite.scale = Vector2(4, 4)
				sprite.z_index = 0
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
			furn.position = pos_2d - furn.texture.get_size() / 2.0
			add_child(furn)
			# 注册碰撞边界
			_register_furniture_collider(fname, pos_2d - furn.texture.get_size() / 2.0, furn.texture.get_size(), Vector2.ONE)



# ── Interactive Hotspots ──

func _build_hotspots() -> void:
	# Check for manually placed hotspots (Area2D nodes starting with "Hotspot_")
	var interactions: Array = room_data.get("interactions", [])
	var matched_ids: Array[String] = []
	for child in get_children():
		if child is Area2D and str(child.name).begins_with("Hotspot_"):
			var hotspot_id := str(child.name).trim_prefix("Hotspot_")
			# Find matching interaction data from JSON and set meta
			var found_inter: Dictionary = {}
			for inter in interactions:
				if str(inter.get("id", "")) == hotspot_id:
					found_inter = inter
					break
			if _is_hidden(found_inter):
				# 隐藏该热点（食材等需在触发前不可见）
				child.monitoring = false
				child.monitorable = false
				child.visible = false
				var hidden_visual := child.get_node_or_null("Visual")
				if hidden_visual != null:
					hidden_visual.visible = false
				continue
			# 显式启用 Area2D 检测（TSCN 默认值不可靠）
			child.monitoring = true
			child.monitorable = true
			child.collision_layer = 0
			child.collision_mask = 1
			child.z_index = 160  # 确保热点可交互层在最前方
			if hotspot_id in ["family_photo", "landline"]:
				child.z_index = 5  # 全家福、老电话永远在底层
			if hotspot_id == "family_photo" and GameState.has_flag("saw_photo"):
				found_inter = found_inter.duplicate(true)
				found_inter["dialogue"] = "res://data/dialogues/photo_2008_no_key.json"
			if hotspot_id == "drawer" and GameState.has_flag("drawer_opened"):
				# 电视柜CG仅触发一次，打开后彻底禁用交互热点
				child.monitoring = false
				child.monitorable = false
				continue
			if hotspot_id == "grandma_finale" and GameState.has_flag("dumpling_done"):
				# 做完饺子后奶奶简化交互：只提醒去看看闹钟
				found_inter = found_inter.duplicate(true)
				found_inter["dialogue"] = "res://data/dialogues/grandma_check_clock.json"
				found_inter["sets_flag"] = ""
		
			child.set_meta("interaction", found_inter)
			hotspots.append(child)
			matched_ids.append(hotspot_id)
			child.body_entered.connect(func(b: Node2D): _on_hotspot_body(b, true, child))
			child.body_exited.connect(func(b: Node2D): _on_hotspot_body(b, false, child))
			child.add_to_group("hotspots")
			move_child(child, get_child_count() - 1)
			# 所有房间移除已有的 Visual 蓝色背景子节点（仅保留交互功能），但保留图片精灵
			var existing_visual := child.get_node_or_null("Visual")
			if existing_visual != null and existing_visual is ColorRect:
				existing_visual.queue_free()
			# Set up editor visual for manual hotspots (仅特殊精灵)
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
					sprite.scale = Vector2(0.05, 0.05)
					child.add_child(sprite)
			# 所有房间不再为普通手动热点创建蓝色 ColorRect 背景

	# 创建未被手动放置覆盖的动态热点（如 calendar 等）
	for inter in interactions:
		var id: String = inter.get("id", "")
		if id in matched_ids:
			continue  # 已由手动热点覆盖
		if _is_hidden(inter):
			continue
		_create_hotspot(inter)


func _create_hotspot(inter: Dictionary) -> void:
	var id: String = inter.get("id", "")
	var name: String = inter.get("name", "")

	if _is_hidden(inter):
		return

	# 全家福：钥匙被拿走后的对话不再提钥匙
	var inter_saved := inter
	if id == "family_photo" and GameState.has_flag("saw_photo"):
		inter_saved = inter.duplicate(true)
		inter_saved["dialogue"] = "res://data/dialogues/photo_2008_no_key.json"
	# 闹钟：首次穿越显示醒悟独白，后续穿越仅显示时间
	if id == "old_clock_return" and GameState.has_flag("seen_2026_clock"):
		inter_saved = inter.duplicate(true)
		inter_saved["dialogue"] = "res://data/dialogues/clock_return_quick.json"
	# 2008返回闹钟：首次显示完整独白，之后仅显示时间
	if id == "return_clock" and GameState.has_flag("seen_return_clock"):
		inter_saved = inter.duplicate(true)
		inter_saved["dialogue"] = "res://data/dialogues/return_clock_2008_quick.json"

	var pos_3d: Vector3 = _arr_to_vec3(inter.get("pos_3d", [0, 0, 0]))
	var size_3d: Vector3 = _arr_to_vec3(inter.get("size_3d", [1, 1, 1]))
	var pos_2d: Vector2
	# 优先使用 pos_3d 转换，否则使用 pos_2d 直接像素坐标（厨房等2D房间）
	if inter.has("pos_3d"):
		pos_2d = _to_2d(pos_3d)
	elif inter.has("pos_2d"):
		var arr_2d: Array = inter.get("pos_2d", [0, 0])
		pos_2d = Vector2(float(arr_2d[0]), float(arr_2d[1]))
	else:
		pos_2d = _to_2d(pos_3d)
	var size_2d := Vector2(maxf(size_3d.x * 60, 32), maxf(size_3d.z * 60, 32))

	var area := Area2D.new()
	area.name = "Hotspot_" + id
	area.set_meta("interaction", inter_saved)
	area.monitoring = true
	area.monitorable = true
	area.collision_layer = 0
	area.collision_mask = 1

	var col := CollisionShape2D.new()
	col.shape = RectangleShape2D.new()
	col.shape.size = size_2d
	area.add_child(col)
	if id == "family_photo":
		col.position = Vector2(0, 0)
	area.position = pos_2d

	# 所有房间不显示蓝色交互背景 ColorRect，仅保留交互功能
	# landline / family_photo 等特殊精灵背景仍保留
	if id in ["landline", "landline_forgot", "landline_call_xiaojie", "landline_post_call"]:
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
			sprite.scale = Vector2(0.05, 0.05)
			sprite.position = Vector2.ZERO
			area.add_child(sprite)
	if id in ["family_photo_complete", "photo_crack_finale"]:
		var img: Image = Image.load_from_file("res://assets/images/cg/family_photo_new.png")
		if img != null:
			var tex: ImageTexture = ImageTexture.create_from_image(img)
			var sprite := Sprite2D.new()
			sprite.name = "Visual"
			sprite.texture = tex
			sprite.centered = true
			sprite.scale = Vector2(0.06, 0.06)
			sprite.position = Vector2.ZERO
			area.add_child(sprite)
	if id == "calendar":
		var img: Image = Image.load_from_file("res://assets/sprites/台历.png")
		if img != null:
			var tex: ImageTexture = ImageTexture.create_from_image(img)
			var sprite := Sprite2D.new()
			sprite.name = "Visual"
			sprite.texture = tex
			sprite.centered = true
			sprite.scale = Vector2(0.08, 0.08)
			sprite.position = Vector2(0, 20)
			sprite.z_index = 151  # 始终在桌子之上
			area.add_child(sprite)
	# 不再创建蓝色 ColorRect 背景（所有房间统一隐藏）

	area.body_entered.connect(func(b: Node2D): _on_hotspot_body(b, true, area))
	area.body_exited.connect(func(b: Node2D): _on_hotspot_body(b, false, area))

	area.add_to_group("hotspots")
	add_child(area)
	hotspots.append(area)




## 父亲剧情线（room_2008_return）：将抽屉CG和座机对话替换为像素风版本
func _override_father_story_hotspots() -> void:
	if room_data.get("id") != "room_2008_return":
		return
	for child in get_children():
		if child is Area2D and child.name == "Hotspot_drawer":
			var inter: Dictionary = child.get_meta("interaction", {}).duplicate(true)
			inter["dialogue"] = "res://data/dialogues/drawer_reveal_father.json"
			child.set_meta("interaction", inter)
			print("[RoomBase] drawer dialogue swapped to pixel version")
			break


## 判断当前房间是否为卧室
func _is_bedroom_room() -> bool:
	return room_data.get("id") in ["room_bedroom", "room_2026_bedroom"]


func _is_hidden(inter: Dictionary) -> bool:
	var id: String = inter.get("id", "")
	
	# 故事动态热点 — show_when / hide_when 控制
	var show_flag: String = inter.get("show_when", "")
	var hide_flag: String = inter.get("hide_when", "")
	var hide_before: bool = inter.get("starts_hidden", false)

	# 厨房中的奶奶：邀请完成后隐藏，由 grandma_collect 取代
	if id == "grandma" and room_data.get("id") == "kitchen":
		return GameState.has_flag("grandma_invited")

	# 食材等被拾取后（hide_when 旗标已设），永久隐藏
	if hide_flag != "" and GameState.has_flag(hide_flag):
		return true

	# 特定热点：根据故事旗标决定初始可见性
	match id:
		"grandma":
			return not GameState.has_flag("drawer_opened") or GameState.has_flag("grandma_invited") or GameState.has_flag("ingredients_collected")
		"grandma_dumpling":
			return not GameState.has_flag("ingredients_collected") or GameState.has_flag("dumpling_made")
		"grandma_finale":
			return not GameState.has_flag("dumplings_cooked") or GameState.has_flag("story_complete")
		"time_return":
			return not GameState.has_flag("dumpling_done")
		"smartphone":
			return not GameState.has_item("receipt")
		"drawer":
			return false

	# 通用 starts_hidden 热点：隐藏到 show_when 条件满足为止
	if hide_before:
		if show_flag.is_empty():
			return true
		elif not GameState.has_flag(show_flag):
			return true  # show_when 条件未满足，保持隐藏

	return false



## 统一控制门的可见性与可交互性
func _set_door_enabled(door_name: String, enabled: bool) -> void:
	var door := get_node_or_null(door_name) as Node2D
	if door == null:
		return
	door.visible = enabled
	var area := door.get_node_or_null("Area") as Area2D
	if area != null:
		area.monitoring = enabled
		area.monitorable = enabled


# ── Room exits ──

func _build_exits() -> void:
	var room_id: String = room_data.get("id", GameState.current_room_id)
	var room_size := _get_room_size()
	var half_w := room_size.x / 2.0
	var half_h := room_size.y / 2.0

	# Doors on the back (top) wall — bottom of frame aligned with skirting
	var door_y := -half_h + WALL_FB - 3.0 - 48  # skirting top - half door height
	var door_x_kitchen := -half_w + WALL_SIDE + 110  # 厨房门：再左移40px

	match room_id:
		"room_2008":
			_add_door("Exit_kitchen", "厨房", -220, door_y + 1, "kitchen")
			# 厨房门：电话结束前隐藏（同时禁用碰撞避免隐形交互）
			if not GameState.has_flag("kitchen_door_revealed"):
				_set_door_enabled("Exit_kitchen", false)
			# 卧室门：在右侧墙壁，首次穿越前隐藏（穿越完成或故事完成后显示）
			_add_door("Exit_bedroom", "卧室", 110, door_y, "room_bedroom")
			if not GameState.has_flag("first_time_travel") and not GameState.has_flag("story_complete"):
				_set_door_enabled("Exit_bedroom", false)
		"room_2008_return":
			_add_door("Exit_kitchen", "厨房", -220, door_y + 1, "kitchen")
			_add_door("Exit_bedroom", "卧室", 110, door_y, "room_bedroom")
		"room_2012":
			var r2012_target := "room_2008_return" if GameState.has_flag("returned_from_2026") else "room_2008"
			_add_door("Exit_2008", "客厅", -30.0, door_y, r2012_target)
		"room_2015":
			var r2015_target := "room_2008_return" if GameState.has_flag("returned_from_2026") else "room_2008"
			_add_door("Exit_2008", "客厅", -30.0, door_y, r2015_target)
		"kitchen":
			# 厨房底部门：回到客厅
			var k_door_y := half_h - WALL_FB + WALL_BLOCK + 45
			var k_living_target := "room_2008_return" if GameState.has_flag("returned_from_2026") else "room_2008"
			_add_door("Exit_2008", "客厅", -100, k_door_y, k_living_target)
		"room_bedroom":
			# 卧室底部开门回到客厅（与厨房门相同摆放方式）
			var bdoor_y := half_h - WALL_FB + WALL_BLOCK + 45
			var b_living_target := "room_2008_return" if GameState.has_flag("returned_from_2026") else "room_2008"
			_add_door("Exit_2008", "客厅", 0, bdoor_y, b_living_target)
		"room_2026":
			# 2026年现代客厅：左侧门通向厨房，右侧门通向卧室
			_add_door("Exit_kitchen", "厨房", -220, door_y + 1, "room_2026_kitchen", 1.0, 5)
			_add_door("Exit_bedroom", "卧室", 220, door_y, "room_2026_bedroom", 1.0, 5)
		"room_2026_kitchen":
			# 2026年厨房：底部门回到客厅
			var k26_door_y := half_h - WALL_FB + WALL_BLOCK + 45
			_add_door("Exit_2026", "客厅", -100, k26_door_y, "room_2026")
		"room_2026_bedroom":
			# 2026年卧室（含卫生间）：底部门回到客厅
			var bed26_door_y := half_h - WALL_FB + WALL_BLOCK + 45
			_add_door("Exit_2026", "客厅", -100, bed26_door_y, "room_2026")


func _add_door(e_name: String, e_label: String, pos_x: float, pos_y: float, target_room: String, door_scale_y: float = 1.0, door_z_index: int = 30) -> void:
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
	door_node.z_index = door_z_index  # 门图层：默认在上方墙之上、下方墙白色顶面之下
	add_child(door_node)


	# Frame sprite (always visible, behind everything)
	# 子节点 z_index=0，层级完全由父节点 door_node 的 z_index 控制
	if frame_tex != null:
		var frame_sprite := Sprite2D.new()
		frame_sprite.name = "Frame"
		frame_sprite.texture = frame_tex
		frame_sprite.centered = true
		frame_sprite.scale = Vector2(1.0, door_scale_y)
		door_node.add_child(frame_sprite)

	# Closed door sprite
	var closed_sprite := Sprite2D.new()
	closed_sprite.name = "Closed"
	closed_sprite.texture = closed_tex
	closed_sprite.centered = true
	closed_sprite.scale = Vector2(1.0, door_scale_y)
	door_node.add_child(closed_sprite)

	# Open door sprite (starts hidden)
	var open_sprite := Sprite2D.new()
	open_sprite.name = "Open"
	open_sprite.texture = open_tex
	open_sprite.centered = true
	open_sprite.scale = Vector2(1.0, door_scale_y)
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
	col.shape.size = Vector2(tw * 2, tw * 3 * door_scale_y)
	area.add_child(col)

	# 碰撞区域向上偏移20px，扩大上方交互范围
	area.position = Vector2(0, -20)

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
	# 同时在 Area2D 上设置 meta，否则 _try_interact() 无法读取
	var area: Area2D = door_node.get_node("Area") as Area2D
	if area != null:
		area.set_meta("player_nearby", entered)
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
	# 防重复生成：已在场景中 或 已在背包中
	for child in get_children():
		if child.is_in_group("pickables") and child.get_meta("item_id", "") == item_id:
			return
	if GameState.has_item(item_id):
		return

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
	if anim_name == "drawer_open" and _tv_cabinet_sprite != null and not _drawer_open:
		var img: Image = Image.load_from_file("res://assets/sprites/电视机柜拉开.png")
		if img != null:
			_tv_cabinet_sprite.texture = ImageTexture.create_from_image(img)
			_drawer_open = true
			_tv_cabinet_orig_pos = _tv_cabinet_sprite.position
			_tv_cabinet_sprite.position = _tv_cabinet_orig_pos + DRAWER_OPEN_OFFSET


func _restore_drawer_state() -> void:
	# 如果抽屉已被打开过，重新加载房间时恢复开启状态
	if GameState.has_flag("drawer_opened") and _tv_cabinet_sprite != null and not _drawer_open:
		var img: Image = Image.load_from_file("res://assets/sprites/电视机柜拉开.png")
		if img != null:
			_tv_cabinet_sprite.texture = ImageTexture.create_from_image(img)
			_drawer_open = true
			_tv_cabinet_orig_pos = _tv_cabinet_sprite.position
			_tv_cabinet_sprite.position = _tv_cabinet_orig_pos + DRAWER_OPEN_OFFSET


## 重新进入厨房时恢复饺子锅/炉灶/蒸汽的显示状态
func _restore_cooking_state() -> void:
	if not GameState.has_flag("dumplings_cooked"):
		return
	if name != "kitchen":
		return
	var dumpling_pot := get_node_or_null("dumpling_pot") as Sprite2D
	if dumpling_pot != null:
		dumpling_pot.visible = true
	var stove := get_node_or_null("stove") as Sprite2D
	if stove != null:
		stove.visible = false
	var stove_lit := get_node_or_null("stove_lit") as Sprite2D
	if stove_lit != null:
		stove_lit.visible = true
	var steam_soup := get_node_or_null("steam_soup") as Sprite2D
	if steam_soup != null:
		steam_soup.visible = true


## 重新进入房间时恢复 dumpling_done 后的故事视觉状态（裂缝精灵等）
func _restore_story_state() -> void:
	if room_data.get("id") == "room_2026":
		if GameState.has_flag("dumpling_done"):
			var wall_crack_node := get_node_or_null("wall_crack") as Sprite2D
			if wall_crack_node != null:
				wall_crack_node.visible = true
		# 回到26年后且已叫来小杰拍照 → 自动设置照片完成标志
		if GameState.has_flag("called_xiaojie") and not GameState.has_flag("family_photo_taken"):
			GameState.set_flag("family_photo_taken", true)
		# 父亲结局完成 → 显示裂缝入口热点
		if GameState.has_flag("father_story_complete"):
			_create_npc_hotspot("photo_crack_finale")
			var father_sprite := get_node_or_null("father") as Sprite2D
			if father_sprite != null:
				father_sprite.visible = false
		# 父亲精灵：饺子完成后始终在客厅（除非父亲结局已完成）
		if GameState.has_flag("dumpling_done") and not GameState.has_flag("father_story_complete"):
			var father_sprite := get_node_or_null("father") as Sprite2D
			if father_sprite != null:
				father_sprite.visible = true
	if room_data.get("id") in ["room_2008", "room_2008_return"]:
		if GameState.has_flag("dumpling_done"):
			var wall_crack_node := get_node_or_null("wall_crack") as Sprite2D
			if wall_crack_node != null:
				wall_crack_node.visible = true
			var clock_node := get_node_or_null("old_clock") as Sprite2D
			if clock_node != null:
				clock_node.visible = true
		# 首次穿越后或故事完成后显示卧室门
		if GameState.has_flag("first_time_travel") or GameState.has_flag("story_complete"):
			_set_door_enabled("Exit_bedroom", true)


## 将当前房间中的 grandma_finale 热点统一更新为"去看看闹钟"对话
func _update_grandma_finale_hotspot() -> void:
	for child in get_children():
		if child is Area2D and child.name == "Hotspot_grandma_finale":
			var inter: Dictionary = child.get_meta("interaction", {}).duplicate(true)
			inter["dialogue"] = "res://data/dialogues/grandma_check_clock.json"
			inter["sets_flag"] = ""
			child.set_meta("interaction", inter)
			print("[RoomBase] grandma_finale updated to grandma_check_clock (room=%s)" % name)


func _on_inventory_changed(_items: Array[String]) -> void:
	# 抽屉打开后永久保持开启状态，不再因取走遥控器而关闭
	pass


# ── 厨房门揭示（电话结束后触发）──

func _reveal_kitchen_door() -> void:
	GameState.set_flag("kitchen_door_revealed", true)
	_show_kitchen_door()

func _show_kitchen_door() -> void:
	_set_door_enabled("Exit_kitchen", true)
	print("[RoomBase] kitchen door revealed")


func _on_flag_changed(flag: String, value: bool) -> void:
	if not value:
		return
	# 所有交互均可多次触发，仅推进 NPC 链，不再隐藏热点
	if flag == "kitchen_door_revealed":
		_show_kitchen_door()
		# 第一次揭示时触发对话
		if not GameState.has_flag("kitchen_door_dialogue_done") and room_data.get("id") in ["room_2008", "room_2008_return"]:
			GameState.set_flag("kitchen_door_dialogue_done", true)
			DialogueManager.start_dialogue.call_deferred("res://data/dialogues/kitchen_door_reveal.json")
	elif flag == "dumpling_done":
		# 饺子做完后，立即显示墙上的裂缝精灵和父亲
		var wall_crack_node := get_node_or_null("wall_crack") as Sprite2D
		if wall_crack_node != null:
			wall_crack_node.visible = true
		# 2026客厅裂缝热点和父亲精灵
		if room_data.get("id") == "room_2026":
			_create_npc_hotspot("wall_crack_2026")
			var father_sprite := get_node_or_null("father") as Sprite2D
			if father_sprite != null:
				father_sprite.visible = true
	elif flag == "crack_in_2026_seen":
		# 看完全家福/裂缝后发现异常
		if room_data.get("id") == "room_2026":
			_hide_hotspot("family_photo_2026")
	elif flag == "drawer_opened":
		_create_npc_hotspot("grandma")
		# 电视柜CG仅触发一次，打开后不再显示任何内容
		for child in get_children():
			if child is Area2D and child.name == "Hotspot_drawer":
				var inter: Dictionary = child.get_meta("interaction", {}).duplicate(true)
				inter["dialogue"] = ""
				inter["requires_item"] = ""
				inter["requires_flag"] = ""
				inter["spawn_anim"] = ""
				child.set_meta("interaction", inter)
				break
	elif flag == "grandma_invited":
		_create_npc_hotspot("grandma_collect")
		# 在奶奶剧情线中，邀请奶奶后揭示厨房门（使第一次进门就触发 enter_kitchen_first）
		if room_data.get("id") == "room_2008":
			_reveal_kitchen_door()
		# 同时激活三个房间中的材料热点（show_when: grandma_invited）
		_refresh_room_hotspots()
		# 显示韭菜袋子精灵（客厅），确保在最顶层不被其他家具遮挡
		# 从2026返回后不再显示韭菜
		if not GameState.has_flag("returned_from_2026"):
			var leek_node := get_node_or_null("leek_bag")
			if leek_node != null and leek_node is Sprite2D:
				leek_node.visible = true
				leek_node.z_index = 100
	elif flag == "ingredients_collected":
		_create_npc_hotspot("grandma_dumpling")
	elif flag == "dumpling_made":
		# 灶台热点由 JSON show_when 自动显示，无需手动创建
		pass
	elif flag == "dumplings_cooked":
		_create_npc_hotspot("grandma_finale")
		if name == "kitchen":
			var steam_soup := get_node_or_null("steam_soup") as Sprite2D
			if steam_soup != null:
				steam_soup.visible = true
			var stove := get_node_or_null("stove") as Sprite2D
			if stove != null:
				stove.visible = false
			var stove_lit := get_node_or_null("stove_lit") as Sprite2D
			if stove_lit != null:
				stove_lit.visible = true
			var dumpling_pot := get_node_or_null("dumpling_pot") as Sprite2D
			if dumpling_pot != null:
				dumpling_pot.visible = true
	elif flag == "first_time_travel":
		# 首次穿越后，卧室门永久可见
		if room_data.get("id") in ["room_2008", "room_2008_return"]:
			_set_door_enabled("Exit_bedroom", true)
	elif flag == "story_complete":
		# 故事完成，更新房间标题，显示卧室门
		var title_label := _find_child_by_name("TitleLabel")
		if title_label != null:
			var label := title_label as Label
			if label != null:
				label.text = "2026年 —— 记忆里的配方，从未忘记"
		if room_data.get("id") in ["room_2008", "room_2008_return"]:
			_set_door_enabled("Exit_bedroom", true)
	# 食材被拾取后刷新热点（隐藏已拾取的，显示解锁的下一阶段）
	if flag.begins_with("got_") or flag in ["drawer_opened", "ingredients_collected", "dumpling_made", "dumplings_cooked", "dumpling_done", "met_father_2026", "called_xiaojie", "got_xiaojie_number", "family_photo_taken", "photo_is_complete", "first_time_travel", "used_shower", "seen_2026_clock", "seen_return_clock", "father_story_complete"]:
		_refresh_room_hotspots()
	if flag == "father_story_complete":
		# 父亲结局完成，隐藏父亲精灵，显示裂缝入口
		var father_sprite := get_node_or_null("father") as Sprite2D
		if father_sprite != null:
			father_sprite.visible = false
		_create_npc_hotspot("photo_crack_finale")
	# dumpling_done 后 _refresh_room_hotspots 会重置 old_clock，重新交换并隐藏 clock_time_return 避免重叠
	if flag == "dumpling_done":
		# 先确保闹钟精灵在所有拥有它的房间都可见（必须在 _refresh_room_hotspots 之后）
		var clock_sprite := get_node_or_null("old_clock") as Sprite2D
		if clock_sprite != null:
			clock_sprite.visible = true
		# 更新 Hotspot_old_clock 为穿越对话
		for child in get_children():
			if child is Area2D and child.name == "Hotspot_old_clock":
				var inter: Dictionary = child.get_meta("interaction", {}).duplicate(true)
				inter["dialogue"] = "res://data/dialogues/clock_time_return.json"
				inter["sets_flag"] = "story_complete"
				child.set_meta("interaction", inter)
				child.monitoring = true
				child.monitorable = true
				child.visible = true
				child.add_to_group("hotspots")
				break
		# 隐藏 clock_time_return 热点，由 old_clock 处理穿越
		_hide_hotspot("clock_time_return")
		# 所有房间的奶奶终局热点统一更新为"去看看闹钟"
		_update_grandma_finale_hotspot()
	# 猪肉馅拾取后 → 冰箱热点切换为上层生姜对话
	if flag == "got_pork":
		for child in get_children():
			if child is Area2D and child.name == "Hotspot_kitchen_fridge":
				var inter: Dictionary = child.get_meta("interaction", {}).duplicate(true)
				inter["dialogue"] = "res://data/dialogues/ingredient_ginger_fridge.json"
				inter["collect_item"] = "ginger"
				inter["sets_flag"] = "got_ginger"
				child.set_meta("interaction", inter)
				print("[RoomBase] kitchen_fridge metadata swapped to ginger_fridge")
				break
	# 韭菜拾取后同步隐藏韭菜袋子精灵
	if flag == "got_chives":
		var leek_node := get_node_or_null("leek_bag")
		if leek_node != null:
			leek_node.visible = false
	# 面粉拾取后同步隐藏面粉袋精灵
	if flag == "got_flour":
		var flour_node := get_node_or_null("flour_bag")
		if flour_node != null:
			flour_node.visible = false


# ── 电话响铃（抽屉回忆后触发）—— AudioStreamGenerator 合成 ──

func _start_phone_ring() -> void:
	if _phone_ringing:
		return

	_phone_ring_gen = AudioStreamGenerator.new()
	_phone_ring_gen.mix_rate = RING_SAMPLE_RATE
	_phone_ring_gen.buffer_length = 0.5  # 500ms 缓冲，足够实时的

	_phone_ring_player = AudioStreamPlayer.new()
	_phone_ring_player.name = "PhoneRingPlayer"
	_phone_ring_player.bus = "SFX"
	_phone_ring_player.volume_db = -4.0
	_phone_ring_player.stream = _phone_ring_gen
	add_child(_phone_ring_player)
	_phone_ring_player.play()

	_phone_ring_phase = 0.0
	_phone_ring_elapsed = 0.0
	_phone_ringing = true
	set_process(true)
	print("[PhoneRing] started (synthesized)")


func _process(delta: float) -> void:
	# 电话响铃音频推送（铃声可持续数个循环周期，由 _stop_phone_ring 控制）
	if not _phone_ringing or _phone_ring_player == null or _phone_ring_gen == null:
		return

	_phone_ring_elapsed += delta
	var pb := _phone_ring_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null:
		return

	var frames_to_push := pb.get_frames_available()
	while frames_to_push > 0:
		var t := _phone_ring_phase / RING_SAMPLE_RATE
		var pos_in_cycle := fmod(t, RING_CYCLE)
		var in_ring1 := pos_in_cycle < RING_BURST
		var in_ring2 := pos_in_cycle >= RING_BURST + RING_GAP and pos_in_cycle < RING_BURST + RING_GAP + RING_BURST
		var sample: float = 0.0
		if in_ring1 or in_ring2:
			var v := 0.55 * sin(2.0 * PI * RING_FREQ * t) + 0.35 * sin(2.0 * PI * (RING_FREQ + 25.0) * t)
			v *= 0.7 + 0.3 * sin(2.0 * PI * 8.0 * t)  # 微弱颤音
			sample = v
		pb.push_frame(Vector2(sample, sample))
		_phone_ring_phase += 1.0
		frames_to_push -= 1


func _stop_phone_ring() -> void:
	if not _phone_ringing:
		return
	_phone_ringing = false
	set_process(false)
	if _phone_ring_player != null:
		_phone_ring_player.stop()
		_phone_ring_player.queue_free()
		_phone_ring_player = null
		_phone_ring_gen = null
	print("[PhoneRing] stopped")


func _on_dialogue_finished(dialogue_id: String) -> void:
	if dialogue_id == "drawer_reveal":
		# 抽屉回忆结束 → 电话响起
		print("[RoomBase] drawer_reveal finished → starting phone ring")
		_start_phone_ring()
		# 第2层：CG结束后座机切换为「小杰来电邀请抓鱼」
		if room_data.get("id") in ["room_2008", "room_2008_return"]:
			for child in get_children():
				if child is Area2D and child.name == "Hotspot_landline":
					var inter: Dictionary = child.get_meta("interaction", {}).duplicate(true)
					inter["dialogue"] = "res://data/dialogues/xiaojie_calls_fishing.json"
					child.set_meta("interaction", inter)
					print("[RoomBase] landline dialogue swapped to xiaojie_calls_fishing (layer 2)")
					break
	if dialogue_id == "xiaojie_calls_fishing":
		# 第2层小杰来电结束 → 厨房门出现
		print("[RoomBase] xiaojie_calls_fishing finished → revealing kitchen door")
		_reveal_kitchen_door()
	if dialogue_id == "ingredient_pork" and _fridge_sprite != null:
		# 冰箱交互结束 → 恢复关闭状态纹理
		var img: Image = Image.load_from_file("res://assets/sprites/冰箱.png")
		if img != null:
			_fridge_sprite.texture = ImageTexture.create_from_image(img)
	if dialogue_id == "ingredient_ginger_fridge" and _fridge_sprite != null:
		# 冰箱上层交互结束 → 恢复关闭状态纹理
		var img2: Image = Image.load_from_file("res://assets/sprites/冰箱.png")
		if img2 != null:
			_fridge_sprite.texture = ImageTexture.create_from_image(img2)
	if dialogue_id == "ingredient_cabbage" and _basket_sprite != null:
		# 白菜被拾取后 → 竹篮切换为空篮纹理
		var img: Image = Image.load_from_file("res://assets/sprites/竹篮.png")
		if img != null:
			_basket_sprite.texture = ImageTexture.create_from_image(img)
	if dialogue_id == "dumpling_finale":
		# 饺子煮好对话结束 — 兜底更新奶奶交互为"去看看闹钟"
		if GameState.has_flag("dumpling_done"):
			_update_grandma_finale_hotspot()

func _play_shower_spray_anim() -> void:
	var anim: AnimatedSprite2D = get_node_or_null("ShowerSprayAnim")
	if anim == null:
		return
	var tex := load("res://assets/sprites/shower_spray_sheet.png")
	if tex == null:
		return
	var frames := SpriteFrames.new()
	frames.add_animation("spray")
	var fh := 247.0
	for i in range(8):
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(0, i * fh, 234, fh)
		frames.add_frame("spray", atlas, 0.12)
	frames.set_animation_loop("spray", true)
	anim.sprite_frames = frames
	anim.visible = true
	anim.play("spray")


func _play_bath_anim() -> void:
	var anim: AnimatedSprite2D = get_node_or_null("BathtubBathAnim")
	if anim == null:
		return
	var tex := load("res://assets/sprites/bath_bath_sheet.png")
	if tex == null:
		return
	var frames := SpriteFrames.new()
	frames.add_animation("bath")
	var fw := 836.0
	var fh := 480.0
	var cols := 10
	for i in range(61):
		var col := i % cols
		var row := i / cols
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(col * fw, row * fh, fw, fh)
		frames.add_frame("bath", atlas, 0.08)
	frames.set_animation_loop("bath", true)
	anim.sprite_frames = frames
	anim.visible = true
	anim.play("bath")
	# 隐藏主角并锁定移动
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.visible = false
		if player.has_method("lock_movement"):
			player.lock_movement()
	# 设置 ESC 退出洗澡
	_bath_anim_active = true


func _stop_bath_anim() -> void:
	AudioManager.stop_shower_water()
	var anim: AnimatedSprite2D = get_node_or_null("BathtubBathAnim")
	if anim:
		anim.visible = false
		anim.stop()
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.visible = true
		if player.has_method("unlock_movement"):
			player.unlock_movement()
	_bath_anim_active = false


func _input(event: InputEvent) -> void:
	if not _bath_anim_active:
		return
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		_stop_bath_anim()



func _on_dialogue_started(dialogue_id: String) -> void:
	if dialogue_id in ["phone_call_xiaojie", "xiaojie_calls_fishing"]:
		# 玩家接起电话 → 停铃
		print("[RoomBase] ", dialogue_id, " started → stopping ring")
		_stop_phone_ring()
	if dialogue_id == "ingredient_pork" and _fridge_sprite != null:
		# 冰箱交互开始 → 切换到打开状态纹理
		var img: Image = Image.load_from_file("res://assets/sprites/冰箱打开.png")
		if img != null:
			_fridge_sprite.texture = ImageTexture.create_from_image(img)
	if dialogue_id == "ingredient_ginger_fridge" and _fridge_sprite != null:
		# 冰箱上层交互开始 → 切换到上层打开状态纹理
		var img2: Image = Image.load_from_file("res://assets/sprites/冰箱上层打开.png")
		if img2 != null:
			_fridge_sprite.texture = ImageTexture.create_from_image(img2)
	if dialogue_id == "bathroom_shower":
		# 花洒交互 → 播放喷水动画 + 水声
		_play_shower_spray_anim()
		AudioManager.play_shower_water()
	if dialogue_id == "bathtub_bath":
		# 浴缸交互 → 播放洗澡动画
		_play_bath_anim()


func _on_dialogue_event(event_name: String) -> void:
	match event_name:
		"travel_to_2026":
			# 闹钟穿越：先停顿1秒让玩家看完文字 → 白光一闪 → 切换到2026年现代客厅
			await get_tree().create_timer(1.0).timeout
			RoomManager.travel_to_room_with_flash("room_2026")
		"travel_to_2008":
			# 闹钟穿越：先停顿1秒让玩家看完文字 → 白光一闪 → 切换回2008年客厅（父亲剧情线）
			# 任何从2026返回2008的行为都做标记
			GameState.set_flag("returned_from_2026", true)
			GameState.set_flag("seen_2026_clock", true)
			await get_tree().create_timer(1.0).timeout
			RoomManager.travel_to_room_with_flash("room_2008_return")
		"travel_to_2026_bedroom":
			# 父亲剧情：先停顿1秒让玩家看完文字 → 白光一闪 → 穿越到2026卧室
			await get_tree().create_timer(1.0).timeout
			RoomManager.travel_to_room_with_flash("room_2026_bedroom")
		"ending_game":
			# 游戏结局：翻开全家福走进裂缝 → 白屏 → 黑屏 → 结束文字 → 回主界面
			await get_tree().create_timer(0.8).timeout
			_play_game_ending()
		_: pass


## 游戏结局动画：白屏 → 黑屏 → 结束文字 → 回主界面
func _play_game_ending() -> void:
	# 隐藏对话面板和UI
	var dialogue_ui := get_tree().root.get_node_or_null("Main/DialogueUILayer")
	if dialogue_ui != null:
		dialogue_ui.hide()

	# 强制结束对话
	if DialogueManager.active_dialogue_id != "":
		var prev_id := DialogueManager.active_dialogue_id
		DialogueManager.active_lines.clear()
		DialogueManager.active_dialogue_id = ""
		DialogueManager.dialogue_finished.emit(prev_id)

	var canvas := CanvasLayer.new()
	canvas.name = "EndingCanvas"
	canvas.layer = 129
	get_tree().root.add_child(canvas)

	var bg := ColorRect.new()
	bg.name = "EndingBG"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(1, 1, 1, 0)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(bg)

	var tween := create_tween()

	# 白屏
	tween.tween_property(bg, "color:a", 1.0, 1.0).set_ease(Tween.EASE_IN)
	tween.tween_interval(0.8)

	# 黑下来
	tween.tween_property(bg, "color", Color(0, 0, 0, 1), 1.2).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(0.5)

	# 显示结束文字
	tween.tween_callback(func():
		_show_ending_credits(canvas)
	)


## 在黑色背景上显示"游戏结束"和"创作者团队：kskbl"
func _show_ending_credits(parent_layer: CanvasLayer) -> void:
	# 游戏结束
	var end_label := Label.new()
	end_label.name = "EndLabel"
	end_label.text = "游戏结束"
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	end_label.add_theme_font_size_override("font_size", 52)
	end_label.add_theme_color_override("font_color", Color(0.9, 0.82, 0.55, 0))
	end_label.set_anchors_preset(Control.PRESET_CENTER)
	end_label.position = Vector2(0, -40)
	parent_layer.add_child(end_label)

	# 制作团队
	var credit_label := Label.new()
	credit_label.name = "CreditLabel"
	credit_label.text = "创作者团队：kskbl"
	credit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	credit_label.add_theme_font_size_override("font_size", 26)
	credit_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65, 0))
	credit_label.set_anchors_preset(Control.PRESET_CENTER)
	credit_label.position = Vector2(0, 30)
	parent_layer.add_child(credit_label)

	var tween := create_tween()

	# 游戏结束淡入
	tween.tween_property(end_label, "modulate:a", 1.0, 1.2).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.0)

	# 制作团队淡入
	tween.tween_property(credit_label, "modulate:a", 1.0, 1.0).set_ease(Tween.EASE_OUT)
	tween.tween_interval(3.0)

	# 全部淡出
	tween.set_parallel(true)
	tween.tween_property(end_label, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_IN)
	tween.tween_property(credit_label, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_IN)

	# 回到主界面
	tween.tween_callback(func():
		AudioManager.stop_bgm()
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	)


## 查找直接子节点（不走递归）
func _find_child_by_name(child_name: String) -> Node:
	for child in get_children():
		if child.name == child_name:
			return child
	return null


## 确保热点有正确的全家福图片精灵（替换 ColorRect）
func _ensure_photo_sprite(area: Area2D) -> void:
	var existing_visual := area.get_node_or_null("Visual")
	if existing_visual is Sprite2D:
		return  # 已经是精灵，无需处理
	if existing_visual != null:
		existing_visual.queue_free()
	var img: Image = Image.load_from_file("res://assets/images/cg/family_photo_new.png")
	if img != null:
		var tex: ImageTexture = ImageTexture.create_from_image(img)
		var sprite := Sprite2D.new()
		sprite.name = "Visual"
		sprite.texture = tex
		sprite.centered = true
		sprite.scale = Vector2(0.06, 0.06)
		sprite.position = Vector2.ZERO
		area.add_child(sprite)


## 根据 JSON 中的交互数据动态创建一个 NPC 热点（绕过 _is_hidden 检查）
func _create_npc_hotspot(npc_id: String) -> void:
	# 检查是否已存在
	for child in get_children():
		if child is Area2D and child.name == "Hotspot_" + npc_id:
			# 已有但隐藏的——显示它，并更新 metadata
			child.monitoring = true
			child.monitorable = true
			child.visible = true
			child.add_to_group("hotspots")
			# 从 JSON 更新正确的交互数据（修复 TSCN 中 metadata 为空的问题）
			var interactions2: Array = room_data.get("interactions", [])
			for inter2 in interactions2:
				if str(inter2.get("id", "")) == npc_id:
					var inter_copy = inter2.duplicate(true)
					# 应用条件文案覆盖（与 _build_hotspots 中的逻辑保持一致）
					if npc_id == "family_photo" and GameState.has_flag("saw_photo"):
						inter_copy["dialogue"] = "res://data/dialogues/photo_2008_no_key.json"
					if npc_id == "grandma_finale" and GameState.has_flag("dumpling_done"):
						inter_copy["dialogue"] = "res://data/dialogues/grandma_check_clock.json"
						inter_copy["sets_flag"] = ""
					child.set_meta("interaction", inter_copy)
					break
			# 重新连接交互信号（若之前未连接，如 TSCN 中初始隐藏的热点）
			if child.body_entered.get_connections().is_empty():
				child.body_entered.connect(func(b: Node2D): _on_hotspot_body(b, true, child))
				child.body_exited.connect(func(b: Node2D): _on_hotspot_body(b, false, child))
			var visual := child.get_node_or_null("Visual") as Node
			if visual != null:
				visual.visible = true
			# 确保全家福热点显示的是真实图片精灵而非 ColorRect
			if npc_id in ["family_photo_complete", "photo_crack_finale"]:
				_ensure_photo_sprite(child)
			return

	# 不存在——从 JSON 中找到数据并手动创建
	var interactions: Array = room_data.get("interactions", [])
	var inter: Dictionary = {}
	for i in interactions:
		if str(i.get("id", "")) == npc_id:
			inter = i
			break
	if inter.is_empty():
		return

	# 手动构建热点（绕过 _is_hidden）
	var id: String = inter.get("id", "")
	var pos_3d: Vector3 = _arr_to_vec3(inter.get("pos_3d", [0, 0, 0]))
	var size_3d: Vector3 = _arr_to_vec3(inter.get("size_3d", [1, 1, 1]))
	var pos_2d: Vector2
	# 优先使用 pos_3d 转换，否则使用 pos_2d 直接像素坐标
	if inter.has("pos_3d"):
		pos_2d = _to_2d(pos_3d)
	elif inter.has("pos_2d"):
		var arr_2d: Array = inter.get("pos_2d", [0, 0])
		pos_2d = Vector2(float(arr_2d[0]), float(arr_2d[1]))
	else:
		pos_2d = _to_2d(pos_3d)
	var size_2d := Vector2(maxf(size_3d.x * 60, 32), maxf(size_3d.z * 60, 32))

	var area := Area2D.new()
	area.name = "Hotspot_" + id
	# 应用条件文案覆盖（与已有热点分支、_build_hotspots 中的逻辑保持一致）
	var inter_final = inter.duplicate(true)
	if id == "family_photo" and GameState.has_flag("saw_photo"):
		inter_final["dialogue"] = "res://data/dialogues/photo_2008_no_key.json"
	if id == "grandma_finale" and GameState.has_flag("dumpling_done"):
		inter_final["dialogue"] = "res://data/dialogues/grandma_check_clock.json"
		inter_final["sets_flag"] = ""
	area.set_meta("interaction", inter_final)
	area.monitoring = true
	area.monitorable = true
	area.collision_layer = 0
	area.collision_mask = 1
	area.z_index = 300  # 高于常驻热点（如 old_clock at 100），确保动态穿越热点截获点击优先

	var col := CollisionShape2D.new()
	col.shape = RectangleShape2D.new()
	col.shape.size = size_2d
	area.add_child(col)
	area.position = pos_2d

	# NPC 视觉标记——奶奶和采集品不显示，只对 time_return 等显示
	var has_collect: bool = inter.has("collect_item") or inter.has("collect_all") or inter.has("submission_grid") or inter.has("cooking_minigame")
	if id not in ["grandma", "grandma_collect", "grandma_dumpling", "grandma_finale"] and not has_collect:
		# 完整全家福和裂缝结局：显示真实图片精灵
		if id in ["family_photo_complete", "photo_crack_finale"]:
			var img: Image = Image.load_from_file("res://assets/images/cg/family_photo_new.png")
			if img != null:
				var tex: ImageTexture = ImageTexture.create_from_image(img)
				var sprite := Sprite2D.new()
				sprite.name = "Visual"
				sprite.texture = tex
				sprite.centered = true
				sprite.scale = Vector2(0.06, 0.06)
				sprite.position = Vector2.ZERO
				area.add_child(sprite)
		else:
			var visual := ColorRect.new()
			visual.name = "Visual"
			match id:
				"time_return":
					visual.color = Color(1.0, 0.9, 0.6, 0.7)  # 金色——配方
				"clock_time_return":
					visual.color = Color(1.0, 0.95, 0.7, 0.75)  # 浅金色——发光的闹钟
				"wall_crack":
					visual.color = Color(0.35, 0.15, 0.1, 0.75)  # 深褐——裂缝
				_:
					visual.color = Color(0.5, 0.65, 0.85, 0.45)
			visual.size = size_2d
			visual.position = -size_2d / 2.0
			area.add_child(visual)

		# NPC 名称标签
		var label := Label.new()
		label.name = "NameTag"
		label.text = String(inter.get("name", id))
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color(1, 1, 0.8))
		label.position = Vector2(-size_2d.x / 2.0, -size_2d.y / 2.0 - 16)
		area.add_child(label)

	area.body_entered.connect(func(b: Node2D): _on_hotspot_body(b, true, area))
	area.body_exited.connect(func(b: Node2D): _on_hotspot_body(b, false, area))
	area.add_to_group("hotspots")
	add_child(area)
	hotspots.append(area)


func _hide_hotspot(hotspot_id: String) -> void:
	for child in get_children():
		if child is Area2D and child.name == "Hotspot_" + hotspot_id:
			# 移除碰撞监听，使其不可交互
			child.monitoring = false
			child.monitorable = false
			child.set_meta("player_nearby", false)
			child.remove_from_group("hotspots")
			# 隐藏视觉标记
			child.visible = false
			# 同时隐藏子节点中的 Visual 标记
			var visual := child.get_node_or_null("Visual") as Node
			if visual != null:
				visual.visible = false


## 刷新当前房间中由 show_when/hide_when 控制的热点
func _refresh_room_hotspots() -> void:
	var interactions: Array = room_data.get("interactions", [])
	for inter in interactions:
		var id: String = inter.get("id", "")
		var show_flag: String = inter.get("show_when", "")
		var hide_flag: String = inter.get("hide_when", "")

		# 检查是否应该显示
		var should_show := true
		if show_flag != "" and not GameState.has_flag(show_flag):
			should_show = false
		if hide_flag != "" and GameState.has_flag(hide_flag):
			should_show = false
		# starts_hidden 的热点，若未满足 show_when 则跳过
		if inter.get("starts_hidden", false) and show_flag == "":
			continue

		if should_show:
			_create_npc_hotspot(id)
		else:
			_hide_hotspot(id)


# ── Player placement ──

func _place_player(from_dir: String) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var player: CharacterBody2D = tree.get_first_node_in_group("player")
	if player == null:
		return

	# 将玩家重新挂载到当前房间下，使 z_index 与房间元素（墙/门/家具）在同一层级生效
	var old_parent := player.get_parent()
	if old_parent != self:
		old_parent.remove_child(player)
		add_child(player)
		# 根据房间类型重新设置玩家 z_index（必须在此处立即设置，不能等 _physics_process）
		player.z_index = 60 if room_data.get("id") in ["room_2008", "room_2008_return"] else 10

	var room_size := _get_room_size()
	var spawn_pos := Vector2.ZERO

	match from_dir:
		"room_2012": spawn_pos = Vector2(-room_size.x / 2.0 + 60, 0)
		"room_2015": spawn_pos = Vector2(room_size.x / 2.0 - 60, 0)
		"room_2008":
			if room_data.get("id") == "kitchen":
				# 进入厨房：出现在回客厅门附近
				var hh := room_size.y / 2.0
				var k_door_y := hh - WALL_FB + WALL_BLOCK + 45
				spawn_pos = Vector2(-100, k_door_y - 50)
			elif room_data.get("id") == "room_bedroom":
				# 进入卧室：出现在底部门内侧（与厨房门相同摆放方式）
				var hh := room_size.y / 2.0
				var bdoor_y := hh - WALL_FB + WALL_BLOCK + 45
				spawn_pos = Vector2(0, bdoor_y - 50)
			elif room_data.get("id") == "room_2026" and GameState.has_flag("returned_from_2026"):
				# 后续穿越到2026：直接出现在闹钟旁边
				spawn_pos = Vector2(-100, 50)
			else:
				spawn_pos = Vector2(0, room_size.y / 2.0 - WALL_FB - 50)
		"room_2008_return":
			if room_data.get("id") == "kitchen":
				var hh := room_size.y / 2.0
				var k_door_y := hh - WALL_FB + WALL_BLOCK + 45
				spawn_pos = Vector2(-100, k_door_y - 50)
			elif room_data.get("id") == "room_bedroom":
				var hh := room_size.y / 2.0
				var bdoor_y := hh - WALL_FB + WALL_BLOCK + 45
				spawn_pos = Vector2(0, bdoor_y - 50)
			else:
				spawn_pos = Vector2(0, room_size.y / 2.0 - WALL_FB - 50)
		"kitchen":
			# 从厨房返回：出现在当前房间厨房门附近
			spawn_pos = Vector2(-room_size.x / 2.0 + WALL_SIDE + 110, -room_size.y / 2.0 + WALL_FB - 3.0 - 48 + 60)
		"room_bedroom":
			# 从卧室返回：出现在当前房间右侧卧室门附近
			spawn_pos = Vector2(110, -room_size.y / 2.0 + WALL_FB - 3.0 - 48 + 60)
		"room_2026_kitchen":
			# 从26年厨房返回：出现在客厅厨房门附近
			spawn_pos = Vector2(-220, -room_size.y / 2.0 + WALL_FB - 3.0 - 48 + 60)
		"room_2026_bedroom":
			# 从26年卧室返回：出现在2026客厅右侧卧室门附近
			spawn_pos = Vector2(220, -room_size.y / 2.0 + WALL_FB - 3.0 - 48 + 60)
		"room_2026":
			# 从26年客厅进入厨房/卧室：出现在对应底部门内侧
			if room_data.get("id") == "room_2026_kitchen":
				var hh := room_size.y / 2.0
				var k26_door_y := hh - WALL_FB + WALL_BLOCK + 45
				spawn_pos = Vector2(-100, k26_door_y - 50)
			elif room_data.get("id") == "room_2026_bedroom":
				var hh := room_size.y / 2.0
				var bed26_door_y := hh - WALL_FB + WALL_BLOCK + 45
				spawn_pos = Vector2(-100, bed26_door_y - 50)
			else:
				spawn_pos = Vector2(0, -room_size.y / 2.0 + WALL_FB + 40)
		_:           spawn_pos = Vector2(0, -room_size.y / 2.0 + WALL_FB + 40)

	player.position = spawn_pos
	# 动态更新玩家移动边界以适配不同房间尺寸
	if player.has_method("set_room_bounds"):
		player.set_room_bounds(room_size)


# ── Coordinate mapping: 3D → 2D top-down ──

func _arr_to_vec3(arr: Array) -> Vector3:
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))


func _to_2d(pos_3d: Vector3) -> Vector2:
	var x: float = pos_3d.x * 60.0
	var y: float = (pos_3d.z + 3.0) * 70.0
	return Vector2(x, y)


# ── Collision registration ──

## 计算图片中实际可见内容的包围盒（排除透明像素）
## @param img: 源图片
## @return: Rect2 包含可见内容的位置和尺寸
func _get_visible_bbox(img: Image) -> Rect2:
	var w := img.get_width()
	var h := img.get_height()
	var min_x := w
	var min_y := h
	var max_x := 0
	var max_y := 0
	for y in range(h):
		for x in range(w):
			var pixel := img.get_pixel(x, y)
			if pixel.a > 0.01:  # 非透明像素
				if x < min_x: min_x = x
				if y < min_y: min_y = y
				if x > max_x: max_x = x
				if y > max_y: max_y = y
	if min_x > max_x:  # 全透明图片
		return Rect2(0, 0, float(w), float(h))
	return Rect2(float(min_x), float(min_y), float(max_x - min_x + 1), float(max_y - min_y + 1))

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

	# 卧室家具：碰撞体积 = 可见内容尺寸 × 缩放（已在上游计算可见区域）
	var bedroom_furniture := ["bed", "wardrobe", "nightstand", "toilet", "sink", "bathtub", "sofa_chair", "k26_upper_cabinet", "k26_drawer", "k26_appliances", "k26_microwave", "k26_tools", "k26_stove", "k26_sink", "k26_dishwasher"]
	if fname in bedroom_furniture:
		var rect := Rect2(adj_pos, adj_size)
		CollisionManager.register_collider(fname, rect)
		return

	# ── 各家具碰撞区域微调 ──
	match fname:
		"coffee_table":
			# 茶几（房间中心）：向左移动 58px，上方延伸 5px，左右碰撞各增加 10px
			adj_pos.x -= 58.0
			adj_pos.y -= 5.0
			adj_size.x *= 2.0 / 3.0  # 右方缩小约 1/3
			adj_size.x += 20.0  # 左右各 +10px
			adj_size.y += 5.0 - 18.0  # 上方 +5，下方 -18
		"tv_cabinet":
			# 电视柜（房间上方）：向左移动 115px，下方缩短 10px，右方缩小约 1/3，左右碰撞各增加 15px
			adj_pos.x -= 115.0
			adj_size.x *= 2.0 / 3.0  # 右方缩小约 1/3
			adj_size.x += 30.0  # 左右各 +15px
			adj_size.y -= 10.0  # 下方缩短 10px
		"side_table":
			# 边桌/台灯（右上角）：右侧缩短 30px，下方缩短 35px，左右碰撞各增加 5px
			adj_pos.x -= 5.0
			adj_size.x -= 20.0  # 原 -30 + 10 = -20
			adj_size.y -= 35.0
		"sofa_chair":
			# 可视区域 141×64，精灵中心 (-1, 50)，像素区域左上 (-71, 18)
			# 碰撞左右各缩短10px
			adj_pos.x = -61.0
			adj_pos.y = 18.0
			adj_size.x = 121.0
			adj_size.y = 96.0  # 96 * 2/3 = 64（补偿全局 y 缩放）
		"corner_cabinet":
			# 角落柜子：贴合实际像素区域 (纹理367x1024, scale 0.12 → 44x123)，右侧缩短20px
			adj_pos.x = -200.0  # center.x - half_width
			adj_pos.y = -10.0   # center.y - half_height，上方缩进
			adj_size.x = 24.0   # 44 - 20
			adj_size.y = 165.0  # 110 * 3/2，下方缩进 (补偿全局 y *= 2/3)
	adj_size.y *= 2.0 / 3.0

	var rect := Rect2(adj_pos, adj_size)
	CollisionManager.register_collider(fname, rect)


## 加载现代家具的像素级碰撞数据（JSON）
func _load_modern_collision_data() -> Dictionary:
	if not _modern_collision_cache.is_empty():
		return _modern_collision_cache
	var file := FileAccess.open("res://data/modern_furniture_collision.json", FileAccess.READ)
	if file == null:
		push_warning("[RoomBase] 无法加载碰撞数据: modern_furniture_collision.json")
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_warning("[RoomBase] JSON 解析错误: ", json.get_error_message())
		return {}
	_modern_collision_cache = json.get_data()
	return _modern_collision_cache


## 为现代家具注册像素级碰撞矩形（多个小矩形贴合实际像素形状）
## top_trim_world: 从顶部裁切的世界像素数（仅裁切顶部，底部不变）
func _register_modern_pixel_colliders(fname: String, sprite_pos: Vector2, sprite_scale: Vector2, top_trim_world: float = 0.0) -> void:
	var data: Dictionary = _load_modern_collision_data()
	var item: Dictionary = data.get(fname, {})
	var rects: Array = item.get("rects", [])

	if rects.is_empty():
		return

	# 如果指定了顶部裁切，过滤/裁剪顶部区域
	if top_trim_world > 0.0:
		var top_trim_local := top_trim_world / sprite_scale.y
		# 找到所有 rect 中最小的 y（顶部边界）
		var min_y: float = INF
		for r in rects:
			min_y = minf(min_y, float(r[1]))
		var clip_y := min_y + top_trim_local
		var new_rects: Array = []
		for r in rects:
			var local_y := float(r[1])
			var h := float(r[3])
			var bottom_y := local_y + h
			if bottom_y <= clip_y:
				# 整个矩形在裁切线之上，跳过
				continue
			if local_y < clip_y:
				# 矩形跨裁切线，从顶部裁剪
				new_rects.append([r[0], clip_y, r[2], bottom_y - clip_y])
			else:
				new_rects.append(r)
		rects = new_rects

	for i in range(rects.size()):
		var r: Array = rects[i]
		var local_x: float = float(r[0])
		var local_y: float = float(r[1])
		var rw: float = float(r[2])
		var rh: float = float(r[3])

		var world_x := sprite_pos.x + local_x * sprite_scale.x
		var world_y := sprite_pos.y + local_y * sprite_scale.y
		var world_w := rw * sprite_scale.x
		var world_h := rh * sprite_scale.y

		CollisionManager.register_collider(
			fname + "_" + str(i),
			Rect2(Vector2(world_x, world_y), Vector2(world_w, world_h))
		)


## 将高分辨率纹理像素化为像素风格（缩小为 1/3 再放大回原尺寸，最近邻插值，锯齿感明显）
func _pixelate_texture(tex: Texture2D) -> ImageTexture:
	var img := tex.get_image()
	if img == null:
		return tex as ImageTexture
	var orig_size := img.get_size()
	var small_w := maxi(1, orig_size.x / 3)
	var small_h := maxi(1, orig_size.y / 3)
	img.resize(small_w, small_h, Image.INTERPOLATE_NEAREST)
	img.resize(orig_size.x, orig_size.y, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


## 更重的像素化处理：更大像素块 + 颜色量化，产生强烈锯齿感和像素色块
func _pixelate_heavy(tex: Texture2D) -> ImageTexture:
	var img := tex.get_image()
	if img == null:
		return tex as ImageTexture
	var orig_size := img.get_size()
	# 缩小到 1/5，像素块更粗大
	var small_w := maxi(1, orig_size.x / 5)
	var small_h := maxi(1, orig_size.y / 5)
	img.resize(small_w, small_h, Image.INTERPOLATE_NEAREST)
	# 颜色量化：每个通道压缩到 4 bit（16 级），产生明显色块边界
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			c.r = round(c.r * 15.0) / 15.0
			c.g = round(c.g * 15.0) / 15.0
			c.b = round(c.b * 15.0) / 15.0
			img.set_pixel(x, y, c)
	# 放大回原尺寸（最近邻保持锯齿）
	img.resize(orig_size.x, orig_size.y, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)
