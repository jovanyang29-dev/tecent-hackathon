extends CharacterBody2D

## Player movement + interaction for 2D point-and-click adventure

const MOVE_SPEED := 140.0

var can_move: bool = true
var _held_sprite: Sprite2D = null
var _hotspot_label: Label = null
var _last_dir_x: float = 1.0
var _idle_tex: Texture2D = null
var _walk_tex: Array[ImageTexture] = []
var _walk_frame: int = 0
var _walk_timer: Timer
var _sprite: Sprite2D = null


func _ready() -> void:
	z_index = 100
	_sprite = $Sprite2D as Sprite2D
	if _sprite != null:
		_sprite.scale = Vector2(2.0 / 3.0 * 1.2, 2.0 / 3.0 * 1.2)  # 2/3 * 1.2 = 0.8
		var char_img := Image.load_from_file("res://assets/sprites/角色.png")
		if char_img != null:
			_sprite.texture = ImageTexture.create_from_image(char_img)
		elif _sprite.texture == null:
			_sprite.texture = _make_circle_texture(20, Color(0.9, 0.8, 0.5), Color(0.3, 0.2, 0.1))
		_idle_tex = _sprite.texture

		# Load all walk animation frames
		var i := 0
		while true:
			var fname := "res://assets/sprites/walk_%03d.png" % i
			if not FileAccess.file_exists(fname):
				break
			var walk_img := Image.load_from_file(fname)
			if walk_img != null:
				_walk_tex.append(ImageTexture.create_from_image(walk_img))
			i += 1

		_walk_timer = Timer.new()
		_walk_timer.name = "WalkTimer"
		_walk_timer.wait_time = 0.08
		_walk_timer.one_shot = false
		_walk_timer.timeout.connect(_on_walk_timer_timeout)
		add_child(_walk_timer)

	# Held item visual
	_held_sprite = Sprite2D.new()
	_held_sprite.name = "HeldItem"
	_held_sprite.centered = true
	_held_sprite.visible = false
	_held_sprite.position = Vector2(12, -8)
	add_child(_held_sprite)
	GameState.inventory_changed.connect(_on_inventory_changed)

	# Hotspot name popup
	_hotspot_label = Label.new()
	_hotspot_label.name = "HotspotLabel"
	_hotspot_label.add_theme_font_size_override("font_size", 12)
	_hotspot_label.add_theme_color_override("font_color", Color.WHITE)
	_hotspot_label.visible = false
	_hotspot_label.position = Vector2(24, -36)
	add_child(_hotspot_label)


func _physics_process(_delta: float) -> void:
	if not can_move:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var raw_velocity := input_dir * MOVE_SPEED

	# ── 物理碰撞检测：根据脚部 Y 位置与家具边界关系，阻止穿越方向 ──
	velocity = _apply_collision(raw_velocity)

	if input_dir.length() > 0.1:
		_update_sprite(input_dir)
		# 走路音效：直接在这里播放（不依赖动画 Timer）
		AudioManager.play_footstep()
	else:
		_update_idle_sprite()

	move_and_slide()
	_clamp_to_room()
	_update_furniture_z_index()
	_update_hotspot_label()


## 基于角色腿部（脚底）Y 判定茶几图层：
## - 脚底在茶几顶部下方（foot_y > table_top）→ 茶几在角色之下（z_index=0）
## - 脚底在茶几顶部上方（foot_y <= table_top）→ 茶几在角色之上（z_index=150）
func _update_furniture_z_index() -> void:
	if _sprite == null or _sprite.texture == null:
		return
	var half_h := _sprite.texture.get_size().y / 2.0 * _sprite.scale.y
	var foot_y := position.y + half_h  # 角色脚底 Y

	# 房间被添加到 root 下，从 root 查找 coffee_table
	var root := get_tree().root
	var node: Sprite2D = null
	for child in root.get_children():
		if child.has_node("coffee_table"):
			node = child.get_node("coffee_table") as Sprite2D
			break
	if node == null or node.texture == null:
		return

	var table_top := node.position.y  # 茶几图片顶部

	var new_z := 0
	if foot_y > table_top:
		new_z = 0    # 角色在茶几下方，茶几在角色之下
	else:
		new_z = 150  # 角色在茶几上方，茶几遮住角色

	if node.z_index != new_z:
		node.z_index = new_z


func _clamp_to_room() -> void:
	if _sprite == null or _sprite.texture == null:
		return
	var tex_size := _sprite.texture.get_size()
	var half_w := tex_size.x / 2.0 * _sprite.scale.x
	var half_h := tex_size.y / 2.0 * _sprite.scale.y

	const BOUND_TOP := -140.0
	const BOUND_BOT := 200.0
	const BOUND_LEFT := -360.0
	const BOUND_RIGHT := 360.0

	# Bottom of character is the reference for top/bottom
	var foot_y := position.y + half_h
	if foot_y < BOUND_TOP:
		position.y = BOUND_TOP - half_h
	if foot_y > BOUND_BOT:
		position.y = BOUND_BOT - half_h

	# Sides of character for left/right
	if position.x - half_w < BOUND_LEFT:
		position.x = BOUND_LEFT + half_w
	if position.x + half_w > BOUND_RIGHT:
		position.x = BOUND_RIGHT - half_w


func _update_hotspot_label() -> void:
	if _hotspot_label == null:
		return
	var nearby_name := ""
	for area in get_tree().get_nodes_in_group("hotspots"):
		if not area is Area2D:
			continue
		if bool(area.get_meta("player_nearby", false)):
			var inter: Dictionary = area.get_meta("interaction", {})
			nearby_name = str(inter.get("name", ""))
			break
	_hotspot_label.text = nearby_name
	_hotspot_label.visible = nearby_name != ""


func _input(event: InputEvent) -> void:
	if DialogueManager.active_dialogue_id != "":
		return
	if event.is_action_pressed("interact"):
		_try_interact()
	elif event.is_action_pressed("attack"):
		_try_interact()


func _try_interact() -> void:
	# 1. Pick up visible items on the ground
	for area in get_tree().get_nodes_in_group("pickables"):
		if not area is Area2D:
			continue
		if bool(area.get_meta("player_nearby", false)):
			GameState.add_item(str(area.get_meta("item_id", "")))
			AudioManager.play_pickup()
			area.queue_free()
			return

	# 2. Interact with hotspots
	for area in get_tree().get_nodes_in_group("hotspots"):
		if not area is Area2D:
			continue
		if bool(area.get_meta("player_nearby", false)):
			var inter: Dictionary = area.get_meta("interaction", {})
			if not inter.is_empty():
				AudioManager.play_interact()
				InteractionManager.set_last_spawn_pos(area.global_position + Vector2(0, 30))
				InteractionManager.handle_interaction(inter)
			return

	# 3. Room exits
	for area in get_tree().get_nodes_in_group("exits"):
		if not area is Area2D:
			continue
		if bool(area.get_meta("player_nearby", false)):
			var target: String = area.get_meta("target_room", "")
			if target != "":
				AudioManager.play_interact()
				RoomManager.switch_to_room(target)
			return


func _update_sprite(input_dir: Vector2) -> void:
	if _sprite == null:
		return
	if abs(input_dir.x) > 0.1:
		_last_dir_x = input_dir.x
	_sprite.flip_h = _last_dir_x < 0
	if not _walk_tex.is_empty():
		if _walk_timer.is_stopped():
			_walk_frame = 0
			_sprite.texture = _walk_tex[0]
			_walk_timer.start()


func _update_idle_sprite() -> void:
	if _sprite == null:
		return
	_walk_timer.stop()
	_sprite.texture = _idle_tex
	_sprite.flip_h = _last_dir_x < 0


func _on_walk_timer_timeout() -> void:
	if _sprite == null or _walk_tex.is_empty():
		return
	_walk_frame = (_walk_frame + 1) % _walk_tex.size()
	_sprite.texture = _walk_tex[_walk_frame]
	_sprite.flip_h = _last_dir_x < 0


func _on_inventory_changed(_items: Array[String]) -> void:
	if _held_sprite == null:
		return
	if GameState.has_item("remote_control"):
		var img := Image.load_from_file("res://assets/sprites/遥控器.png")
		if img != null:
			_held_sprite.texture = ImageTexture.create_from_image(img)
			_held_sprite.visible = true
	else:
		_held_sprite.visible = false


func _make_circle_texture(radius: int, color: Color, outline: Color = Color.BLACK) -> ImageTexture:
	var pad := 3
	var size := (radius + pad) * 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx: float = float(size) / 2.0
	var cy: float = float(size) / 2.0
	for y: int in range(size):
		for x: int in range(size):
			var dx: float = float(x) - cx
			var dy: float = float(y) - cy
			var dist := dx * dx + dy * dy
			if dist <= (radius + pad) * (radius + pad):
				img.set_pixel(x, y, outline)
			if dist <= radius * radius:
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


func lock_movement() -> void:
	can_move = false


func unlock_movement() -> void:
	can_move = true


## 应用物理碰撞：根据脚部 Y 与家具范围的关系阻挡移动方向
## 逻辑：若脚底 Y 位于物品 top_y ~ bottom_y 之间，
##       且人物与物品水平重叠，则阻止朝向物品的移动分量
func _apply_collision(desired_velocity: Vector2) -> Vector2:
	if _sprite == null or _sprite.texture == null:
		return desired_velocity

	var half_h := _sprite.texture.get_size().y / 2.0 * _sprite.scale.y
	var half_w := _sprite.texture.get_size().x / 2.0 * _sprite.scale.x

	return CollisionManager.resolve_collision(
		position,
		half_h,
		half_w,
		desired_velocity
	)
