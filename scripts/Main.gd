extends Node2D

## Entry point — loads starting room, plays opening animation, sets up UI

var _player: CharacterBody2D = null

var _rewind_stack: Array[String] = [
	"dumpling_done", "dumplings_cooked", "dumpling_made", "ingredients_collected",
]

var _pending_cooking_sets_flag: String = ""
var _pending_cooking_dialogue: String = ""


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_BACKSPACE and event.pressed:
		_rewind_story()


func _rewind_story() -> void:
	for flag in _rewind_stack:
		if GameState.has_flag(flag):
			GameState.flags.erase(flag)
			_show_toast("已回退: " + flag)
			RoomManager.enter_room(GameState.current_room_id, "")
			return
	_show_toast("已回到最初状态")


func _show_toast(msg: String) -> void:
	var label := Label.new()
	label.text = msg
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	label.offset_left = -200
	label.offset_right = 200
	label.offset_top = 60
	label.offset_bottom = 90
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 1.5).set_delay(0.5)
	tween.tween_callback(label.queue_free)

func _ready() -> void:
	# 开始播放背景音乐
	AudioManager.play_bgm()

	_player = $Player

	# 连接提交面板信号
	if has_node("GrandmaSubmissionPanel"):
		InteractionManager.submission_grid_requested.connect(_on_submission_grid_requested)

	# 连接煮饺子小游戏信号
	if has_node("CookingPanel"):
		InteractionManager.cooking_minigame_requested.connect(_on_cooking_minigame_requested)
		$CookingPanel.cooking_complete.connect(_on_cooking_complete)

	# ── 继续游戏：跳过开场动画，直接进入存档房间 ──
	if GameState.has_flag("_skip_intro"):
		GameState.flags.erase("_skip_intro")  # 清除临时标记
		_player.visible = true
		_player.z_index = 100
		_player.unlock_movement()
		RoomManager.enter_room(GameState.current_room_id, "")
		return

	# ── 新游戏：完整开场流程 ──
	# 主角初始状态：隐藏在沙发上睡觉，被家具遮挡不可见
	_player.visible = false
	_player.lock_movement()

	# Load game1 room system (setup + _place_player 是 call_deferred，下一帧执行)
	RoomManager.enter_room("room_2008", "")

	# ── 播放开场睁眼动画 ──
	var opening_anim: CanvasLayer = load("res://scenes/ui/OpeningAnimation.tscn").instantiate()
	add_child(opening_anim)
	opening_anim.intro_finished.connect(_on_intro_finished)


func _on_intro_finished() -> void:
	# 此时 room setup 早已完成，位置设置不会被 _place_player 覆盖
	_player.position = Vector2(40, 20)
	_player.visible = true
	_player.rotation = 0.0
	_player.z_index = 100  # 在沙发之下(150)、茶几之上(0)

	# 锁定家具图层：沙发遮住角色，茶几在角色之下
	_set_furniture_foreground("sofa_chair")
	_set_furniture_background("coffee_table")

	# ── 起床动画：从沙发上躺着 → 坐起 → 站立 ──
	_player.scale = Vector2(1.3, 0.25)  # 宽扁 = 侧躺在沙发上

	var tween := get_tree().create_tween()
	tween.set_parallel(true)
	# 坐起阶段：纵向拉伸 + 略微上移
	tween.tween_property(_player, "scale", Vector2(1.0, 0.7), 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(_player, "position:y", 12.0, 0.5).set_ease(Tween.EASE_OUT)

	tween.chain().tween_callback(_do_stand_bounce)


func _set_furniture_foreground(fname: String) -> void:
	var node := _find_furniture(fname)
	if node != null:
		node.z_index = 150

func _set_furniture_background(fname: String) -> void:
	var node := _find_furniture(fname)
	if node != null:
		node.z_index = 0

func _find_furniture(fname: String) -> Node:
	for child in get_tree().root.get_children():
		if child.has_node(fname):
			return child.get_node(fname)
	return null


func _do_stand_bounce() -> void:
	# 站立 + 弹跳缓冲
	var tween := get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(_player, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(_player, "position:y", 38.0, 0.2).set_ease(Tween.EASE_OUT)  # 下移至 sofa 前方
	tween.chain().tween_property(_player, "scale", Vector2(1.0, 0.92), 0.06)
	tween.chain().tween_property(_player, "scale", Vector2(1.0, 1.0), 0.1)
	tween.chain().tween_callback(func():
		# 动画结束：沙发置于角色身后，解锁移动
		_set_furniture_background("sofa_chair")
		_player.unlock_movement()
	)


func _on_submission_grid_requested(grid_items: Array, dialogue: String, sets_flag: String) -> void:
	var panel := $GrandmaSubmissionPanel
	if panel != null and panel.has_method("open"):
		panel.open(dialogue, sets_flag)


func _on_cooking_minigame_requested(dialogue: String, sets_flag: String) -> void:
	_pending_cooking_sets_flag = sets_flag
	_pending_cooking_dialogue = dialogue
	var panel := $CookingPanel
	if panel != null and panel.has_method("open"):
		panel.open()


func _on_cooking_complete() -> void:
	if _pending_cooking_sets_flag != "":
		GameState.set_flag(_pending_cooking_sets_flag)
		_pending_cooking_sets_flag = ""
	# 立即更新当前厨房的奶奶终局热点，不依赖 _on_flag_changed 信号链路
	if RoomManager.current_room != null and RoomManager.current_room.has_method("_update_grandma_finale_hotspot"):
		RoomManager.current_room._update_grandma_finale_hotspot()
	# 播放饺子出锅对话（此前被 cooking_minigame_requested 丢弃了）
	if _pending_cooking_dialogue != "":
		DialogueManager.start_dialogue.call_deferred(_pending_cooking_dialogue)
		_pending_cooking_dialogue = ""
