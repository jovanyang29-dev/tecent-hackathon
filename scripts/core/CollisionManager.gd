extends Node

## 全局碰撞管理器
## 管理场景中所有家具的碰撞边界，提供 Y 轴碰撞检测
##
## 逻辑：
## - 每件家具在 2D 空间中有自己的矩形区域（top-left ~ bottom-right）
## - 人物脚部 Y 坐标（foot_y）位于家具 top_y ~ bottom_y 之间时，
##   该家具对该方向有阻挡作用
## - 如果人物试图向家具所在方向移动，则阻止该方向的速度分量

# 存储所有注册的碰撞体：{ "furniture_id": Rect2 }
var colliders: Dictionary = {}


## 注册一个碰撞体
## @param id: 唯一标识
## @param rect: Rect2(position=top-left, size=width×height)
func register_collider(id: String, rect: Rect2) -> void:
	colliders[id] = rect


## 注销碰撞体
func unregister_collider(id: String) -> void:
	colliders.erase(id)


## 清空所有碰撞体（切换房间时调用）
func clear_all() -> void:
	colliders.clear()


## 获取指定碰撞体的矩形区域
func get_collider_rect(id: String) -> Rect2:
	return colliders.get(id, Rect2())



## 核心碰撞检测：根据人物位置和输入方向，返回允许的速度
##
## @param player_pos: 人物中心点位置 (Vector2)
## @param player_half_h: 人物半高（用于计算脚部 Y）
## @param player_half_w: 人物半宽（用于水平方向容差）
## @param desired_velocity: 原始输入速度 (Vector2)
## @return Vector2: 碰撞修正后的速度
func resolve_collision(
	player_pos: Vector2,
	player_half_h: float,
	player_half_w: float,
	desired_velocity: Vector2
) -> Vector2:
	var result := desired_velocity
	var foot_y := player_pos.y + player_half_h  # 脚底 Y 坐标

	for id in colliders:
		var rect: Rect2 = colliders[id]
		var item_top := rect.position.y       # 物品上边界
		var item_bottom := rect.end.y         # 物品下边界
		var item_left := rect.position.x      # 物品左边界
		var item_right := rect.end.x          # 物品右边界

		# ── Y 轴判定：仅以脚底判定，不使用头部 ──
		# 脚底在物品 Y 范围内（含少量余量）→ 考虑碰撞
		var next_foot_y := foot_y + result.y * 0.02
		var in_range := (foot_y >= item_top - 5.0 and foot_y <= item_bottom + 5.0) or \
						(next_foot_y >= item_top and next_foot_y <= item_bottom)
		if not in_range:
			continue

		# ── 水平方向重叠预判 ──
		var next_left := player_pos.x + result.x * 0.02 - player_half_w
		var next_right := player_pos.x + result.x * 0.02 + player_half_w
		var player_left := player_pos.x - player_half_w
		var player_right := player_pos.x + player_half_w

		var will_overlap := next_right > item_left and next_left < item_right
		var now_overlap := player_right > item_left and player_left < item_right
		if not will_overlap and not now_overlap:
			continue

		# ── 水平方向阻挡 ──
		if player_pos.x <= item_left:
			if result.x > 0:
				result.x = 0
		elif player_pos.x >= item_right:
			if result.x < 0:
				result.x = 0

		# ── 垂直方向阻挡（仅用脚底判断） ──
		if foot_y <= item_top + 5.0:
			# 脚底在物品上方 → 阻止向下
			if result.y > 0:
				result.y = 0
		elif foot_y >= item_bottom - 5.0:
			# 脚底在物品下方 → 阻止向上
			if result.y < 0:
				result.y = 0

	return result
