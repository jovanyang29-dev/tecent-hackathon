@tool
class_name FurnitureModels
extends RefCounted

# ── Texture cache (loaded once) ──

static var _tex_cache: Dictionary = {}

static func _tex(path: String) -> CompressedTexture2D:
	if not _tex_cache.has(path):
		var tex := load(path) as CompressedTexture2D
		if tex != null:
			_tex_cache[path] = tex
		else:
			_tex_cache[path] = null
	return _tex_cache[path]

static func _try_tex(path: String) -> CompressedTexture2D:
	if not _tex_cache.has(path):
		if FileAccess.file_exists(path):
			return _tex(path)
		_tex_cache[path] = null
		return null
	return _tex_cache[path]

static func _mat_tex(tex_path: String, roughness: float = 0.7, color: Color = Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex(tex_path)
	m.albedo_color = color
	m.roughness = roughness

	# Auto-load PBR sibling textures
	var base := tex_path.trim_suffix(".png")
	var normal_path := base + "_normal.png"
	var rough_path := base + "_roughness.png"
	var normal_tex := _try_tex(normal_path)
	var rough_tex := _try_tex(rough_path)
	if normal_tex != null:
		m.normal_texture = normal_tex
	if rough_tex != null:
		m.roughness_texture = rough_tex

	return m

static func _mat_color(color: Color, roughness: float = 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m


# ── Mesh builders ──

static func box(name_str: String, pos: Vector3, size: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name_str
	mi.position = pos
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	return mi

static func box_tex(name_str: String, pos: Vector3, size: Vector3, tex_path: String, roughness: float = 0.75, color: Color = Color.WHITE) -> MeshInstance3D:
	return box(name_str, pos, size, _mat_tex(tex_path, roughness, color))

static func box_col(name_str: String, pos: Vector3, size: Vector3, color: Color, roughness: float = 0.7) -> MeshInstance3D:
	return box(name_str, pos, size, _mat_color(color, roughness))

static func cylinder(name_str: String, pos: Vector3, radius: float, height: float, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name_str
	mi.position = pos
	mi.rotation_degrees = Vector3(90, 0, 0)
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.material = mat
	mi.mesh = cm
	return mi

static func cylinder_tex(name_str: String, pos: Vector3, radius: float, height: float, tex_path: String, roughness: float = 0.5, color: Color = Color.WHITE) -> MeshInstance3D:
	return cylinder(name_str, pos, radius, height, _mat_tex(tex_path, roughness, color))

static func cylinder_col(name_str: String, pos: Vector3, radius: float, height: float, color: Color, roughness: float = 0.5) -> MeshInstance3D:
	return cylinder(name_str, pos, radius, height, _mat_color(color, roughness))


# ── Texture paths ──

const TEX_WOOD_DARK := "res://textures/wood_dark.png"
const TEX_WOOD_MED := "res://textures/wood_medium.png"
const TEX_WOOD_LIGHT := "res://textures/wood_light.png"
const TEX_METAL := "res://textures/metal_gray.png"
const TEX_METAL_GOLD := "res://textures/metal_gold.png"
const TEX_PLASTIC_DARK := "res://textures/plastic_dark.png"
const TEX_PLASTIC_TV := "res://textures/plastic_tv.png"
const TEX_PAPER := "res://textures/paper_aged.png"
const TEX_PAPER_WHITE := "res://textures/paper_white.png"
const TEX_TV_SCREEN := "res://textures/tv_screen.png"
const TEX_WALL := "res://textures/wall_beige.png"
const TEX_FABRIC_RED := "res://textures/fabric_red.png"

# Solid colors for small details
const BLACK = Color(0.08, 0.08, 0.09)
const WHITE_IVORY = Color(0.95, 0.93, 0.85)
const GREEN_BTN = Color(0.2, 0.9, 0.3)
const DARK_PLASTIC = Color(0.12, 0.12, 0.18)


# ── TV Cabinet ──

static func make_tv_cabinet() -> Node3D:
	var root := Node3D.new()
	root.name = "tv_cabinet"

	root.add_child(box_tex("Body", Vector3(0, 0, 0), Vector3(7, 1.4, 1.5), TEX_WOOD_DARK, 0.8))
	root.add_child(box_tex("Top", Vector3(0, 0.72, 0), Vector3(7.2, 0.06, 1.65), TEX_WOOD_MED, 0.5))
	root.add_child(box_tex("Base", Vector3(0, -0.68, 0), Vector3(7.2, 0.04, 1.65), TEX_WOOD_MED, 0.8))
	root.add_child(box_tex("DrawerFront", Vector3(-2.2, -0.35, 0.77), Vector3(1.2, 0.45, 0.04), TEX_WOOD_MED, 0.6))
	root.add_child(cylinder_tex("KnobL", Vector3(-2.2, -0.35, 0.81), 0.04, 0.04, TEX_METAL, 0.3))
	root.add_child(box_tex("Divider", Vector3(0.8, -0.15, 0), Vector3(0.05, 0.6, 1.3), TEX_WOOD_LIGHT, 0.7))
	root.add_child(box_tex("Shelf", Vector3(2.5, -0.15, 0), Vector3(3.0, 0.04, 1.3), TEX_WOOD_MED, 0.6))
	root.add_child(box_tex("BackPanel", Vector3(0, 0, -0.72), Vector3(6.5, 1.1, 0.04), TEX_WOOD_LIGHT, 0.8))

	return root


# ── Coffee Table ──

static func make_coffee_table() -> Node3D:
	var root := Node3D.new()
	root.name = "coffee_table"

	root.add_child(box_tex("Top", Vector3(0, 0, 0), Vector3(5, 0.08, 2.2), TEX_WOOD_MED, 0.4))
	var leg_h := 0.48
	var leg_y := -0.28
	var off_x := 2.1
	var off_z := 0.85
	for lx in [-off_x, off_x]:
		for lz in [-off_z, off_z]:
			root.add_child(box_tex("Leg", Vector3(lx, leg_y, lz), Vector3(0.1, leg_h, 0.1), TEX_WOOD_DARK, 0.8))
	root.add_child(box_tex("Shelf", Vector3(0, -0.47, 0), Vector3(4.0, 0.04, 1.5), TEX_WOOD_LIGHT, 0.7))

	return root


# ── Side Table ──

static func make_side_table() -> Node3D:
	var root := Node3D.new()
	root.name = "side_table"

	root.add_child(box_tex("Top", Vector3(0, 0, 0), Vector3(1.0, 0.05, 1.0), TEX_WOOD_MED, 0.4))
	var leg_h := 0.55
	var leg_y := -0.3
	for lx in [-0.35, 0.35]:
		for lz in [-0.35, 0.35]:
			root.add_child(box_tex("Leg", Vector3(lx, leg_y, lz), Vector3(0.06, leg_h, 0.06), TEX_WOOD_DARK, 0.8))

	return root


# ── CRT TV ──

static func make_crt_tv() -> Node3D:
	var root := Node3D.new()
	root.name = "old_tv"

	root.add_child(box_tex("Body", Vector3(0, 0.5, 0), Vector3(3.0, 1.0, 1.2), TEX_PLASTIC_TV, 0.6))
	root.add_child(box_col("Bezel", Vector3(0, 0.5, 0.6), Vector3(3.1, 1.05, 0.08), BLACK, 0.5))
	root.add_child(box_tex("Screen", Vector3(0, 0.55, 0.65), Vector3(2.2, 0.8, 0.02), TEX_TV_SCREEN, 0.2, Color(1, 1, 1)))
	root.add_child(box_tex("Badge", Vector3(0, 0.78, 0.65), Vector3(0.3, 0.08, 0.02), TEX_METAL, 0.3))
	root.add_child(box_col("Stand", Vector3(0, 0.06, 0), Vector3(2.0, 0.12, 0.8), BLACK, 0.5))
	root.add_child(box_tex("Controls", Vector3(1.3, 0.25, 0.67), Vector3(0.3, 0.6, 0.04), TEX_PLASTIC_TV, 0.5, Color(0.7, 0.7, 0.7)))
	root.add_child(cylinder_col("PowerBtn", Vector3(1.3, 0.55, 0.7), 0.06, 0.02, GREEN_BTN, 0.3))
	root.add_child(cylinder_tex("ChUp", Vector3(1.3, 0.35, 0.7), 0.04, 0.04, TEX_METAL, 0.3))
	root.add_child(cylinder_tex("ChDn", Vector3(1.3, 0.2, 0.7), 0.04, 0.04, TEX_METAL, 0.3))

	return root


# ── Family Photo Frame ──

static func make_family_photo() -> Node3D:
	var root := Node3D.new()
	root.name = "family_photo"

	root.add_child(box_tex("Frame", Vector3(0, 0, 0), Vector3(0.8, 1.0, 0.06), TEX_WOOD_DARK, 0.5))
	root.add_child(box_col("Inner", Vector3(0, 0, 0.03), Vector3(0.6, 0.8, 0.01), Color(0.8, 0.75, 0.65), 0.9))
	root.add_child(box_tex("Photo", Vector3(0, 0, 0.035), Vector3(0.5, 0.7, 0.01), TEX_PAPER, 0.9, Color(1, 0.95, 0.85)))

	return root


# ── Alarm Clock ──

static func make_alarm_clock() -> Node3D:
	var root := Node3D.new()
	root.name = "old_clock"

	root.add_child(cylinder_col("Body", Vector3(0, 0.15, 0), 0.22, 0.3, WHITE_IVORY, 0.4))
	root.add_child(box_tex("Face", Vector3(0, 0.15, 0.12), Vector3(0.38, 0.32, 0.02), TEX_PAPER_WHITE, 0.5))
	root.add_child(cylinder_tex("BellL", Vector3(-0.2, 0.33, 0), 0.1, 0.08, TEX_METAL_GOLD, 0.3))
	root.add_child(cylinder_tex("BellR", Vector3(0.2, 0.33, 0), 0.1, 0.08, TEX_METAL_GOLD, 0.3))
	root.add_child(cylinder_tex("Hammer", Vector3(0, 0.4, 0), 0.02, 0.2, TEX_METAL, 0.3))
	root.add_child(box_tex("LegL", Vector3(-0.15, 0.03, 0), Vector3(0.04, 0.06, 0.1), TEX_METAL, 0.3))
	root.add_child(box_tex("LegR", Vector3(0.15, 0.03, 0), Vector3(0.04, 0.06, 0.1), TEX_METAL, 0.3))

	return root


# ── Landline Phone ──

static func make_landline() -> Node3D:
	var root := Node3D.new()
	root.name = "landline"

	root.add_child(box_tex("Base", Vector3(0, 0.05, 0), Vector3(0.55, 0.1, 0.45), TEX_FABRIC_RED, 0.6, Color(0.7, 0.15, 0.1)))
	root.add_child(box_tex("Keypad", Vector3(0, 0.11, -0.05), Vector3(0.35, 0.02, 0.25), TEX_PLASTIC_DARK, 0.5))
	root.add_child(box_tex("HandsetBody", Vector3(0, 0.17, 0), Vector3(0.5, 0.08, 0.2), TEX_FABRIC_RED, 0.5, Color(0.75, 0.2, 0.15)))
	root.add_child(box_tex("Earpiece", Vector3(0, 0.22, 0.06), Vector3(0.2, 0.04, 0.12), TEX_PLASTIC_DARK, 0.6))
	root.add_child(box_tex("Mouthpiece", Vector3(0, 0.22, -0.06), Vector3(0.2, 0.04, 0.12), TEX_PLASTIC_DARK, 0.6))
	root.add_child(cylinder_tex("Antenna", Vector3(0.15, 0.17, 0.15), 0.02, 0.3, TEX_METAL, 0.3))

	return root


# ── DVD Player ──

static func make_dvd_player() -> Node3D:
	var root := Node3D.new()
	root.name = "dvd_player"

	root.add_child(box_tex("Body", Vector3(0, 0, 0), Vector3(0.8, 0.25, 0.5), TEX_PLASTIC_DARK, 0.6))
	root.add_child(box_col("Front", Vector3(0, 0, 0.25), Vector3(0.78, 0.22, 0.03), Color(0.15, 0.15, 0.18), 0.5))
	root.add_child(box_col("Slot", Vector3(0, 0.03, 0.27), Vector3(0.4, 0.02, 0.01), BLACK, 0.3))
	root.add_child(box_col("Display", Vector3(-0.2, 0.06, 0.27), Vector3(0.25, 0.06, 0.01), Color(0.2, 0.8, 0.3, 0.8), 0.3))
	root.add_child(cylinder_col("PowerBtn", Vector3(0.3, 0, 0.27), 0.03, 0.02, GREEN_BTN, 0.3))

	return root


# ── Draggable Items ──

static func make_small_key() -> Node3D:
	var root := Node3D.new()
	root.name = "small_key"

	root.add_child(cylinder_tex("Head", Vector3(0, 0.05, 0), 0.1, 0.05, TEX_METAL_GOLD, 0.25, Color(0.9, 0.8, 0.3)))
	root.add_child(box_tex("Shaft", Vector3(0, -0.1, 0), Vector3(0.04, 0.2, 0.02), TEX_METAL_GOLD, 0.25, Color(0.9, 0.8, 0.3)))
	root.add_child(box_tex("Tooth1", Vector3(0.03, -0.17, 0), Vector3(0.02, 0.06, 0.02), TEX_METAL_GOLD, 0.25, Color(0.9, 0.8, 0.3)))
	root.add_child(box_tex("Tooth2", Vector3(0.03, -0.11, 0), Vector3(0.02, 0.04, 0.02), TEX_METAL_GOLD, 0.25, Color(0.9, 0.8, 0.3)))

	return root

static func make_remote_control() -> Node3D:
	var root := Node3D.new()
	root.name = "remote_control"

	root.add_child(box_tex("Body", Vector3(0, 0, 0), Vector3(0.18, 0.55, 0.08), TEX_PLASTIC_DARK, 0.5))
	root.add_child(box_col("IR", Vector3(0, 0.29, 0), Vector3(0.08, 0.04, 0.08), Color(0.8, 0.1, 0.1, 0.8), 0.3))
	root.add_child(box_col("Screen", Vector3(0, 0.14, 0.04), Vector3(0.14, 0.15, 0.01), Color(0.3, 0.35, 0.3), 0.4))
	root.add_child(box_col("Power", Vector3(0, 0.24, 0.04), Vector3(0.06, 0.05, 0.02), GREEN_BTN, 0.3))
	for row in range(3):
		for col in range(3):
			var bx := (col - 1) * 0.04
			var by := 0.05 - row * 0.05
			root.add_child(cylinder_tex("Btn%d%d" % [row, col], Vector3(bx, by, 0.04), 0.015, 0.01, TEX_METAL, 0.3))

	return root

static func make_old_phone() -> Node3D:
	var root := Node3D.new()
	root.name = "old_phone"

	root.add_child(box_tex("Body", Vector3(0, 0, 0), Vector3(0.25, 0.4, 0.06), TEX_PLASTIC_DARK, 0.5))
	root.add_child(box_col("Screen", Vector3(0, 0.05, 0.03), Vector3(0.18, 0.22, 0.01), Color(0.3, 0.5, 0.7), 0.4))
	root.add_child(cylinder_tex("HomeBtn", Vector3(0, -0.14, 0.03), 0.03, 0.01, TEX_METAL, 0.3))
	root.add_child(box_tex("Speaker", Vector3(0, 0.17, 0.03), Vector3(0.12, 0.02, 0.01), TEX_METAL, 0.3))

	return root

static func make_receipt() -> Node3D:
	var root := Node3D.new()
	root.name = "receipt"

	root.add_child(box_tex("Paper", Vector3(0, 0, 0), Vector3(0.25, 0.35, 0.01), TEX_PAPER, 0.9))
	root.add_child(box_col("Crease", Vector3(0, -0.05, 0.01), Vector3(0.24, 0.01, 0.01), Color(0.85, 0.83, 0.7), 0.9))
	for i in range(4):
		root.add_child(box_col("Line%d" % i, Vector3(-0.04, 0.05 + i * 0.06, 0.01), Vector3(0.18, 0.01, 0.01), Color(0.5, 0.48, 0.4), 0.9))

	return root

static func make_password_note() -> Node3D:
	var root := Node3D.new()
	root.name = "password_note"

	root.add_child(box_tex("Paper", Vector3(0, 0, 0), Vector3(0.22, 0.3, 0.01), TEX_PAPER, 0.9, Color(1, 0.95, 0.85)))
	root.add_child(box_col("Fold", Vector3(0, 0.05, 0.01), Vector3(0.2, 0.008, 0.01), Color(0.8, 0.75, 0.6), 0.9))

	return root


# ── Ceiling Light Fixture ──

static func make_ceiling_light() -> Node3D:
	var root := Node3D.new()
	root.name = "ceiling_light"

	root.add_child(cylinder_tex("Mount", Vector3(0, 5.02, -1), 0.15, 0.08, TEX_METAL_GOLD, 0.2))
	root.add_child(cylinder_tex("Rod", Vector3(0, 4.9, -1), 0.03, 0.24, TEX_METAL_GOLD, 0.2))
	# Lampshade: inverted bowl shape approximated by cylinder
	var shade_mat := StandardMaterial3D.new()
	shade_mat.albedo_texture = _tex(TEX_PAPER_WHITE)
	shade_mat.albedo_color = Color(1, 0.95, 0.85)
	shade_mat.roughness = 0.6
	shade_mat.emission_enabled = true
	shade_mat.emission = Color(1, 0.9, 0.6)
	shade_mat.emission_energy_multiplier = 0.5
	root.add_child(cylinder("Shade", Vector3(0, 4.75, -1), 0.3, 0.2, shade_mat))
	root.add_child(box_tex("PullChain", Vector3(0, 4.55, -1), Vector3(0.01, 0.15, 0.01), TEX_METAL, 0.3))

	return root


# ── LCD TV (Room 2012) ──

static func make_lcd_tv() -> Node3D:
	var root := Node3D.new()
	root.name = "new_tv"

	root.add_child(box_tex("Body", Vector3(0, 0.8, 0), Vector3(3.5, 0.08, 1.8), TEX_PLASTIC_DARK, 0.5))
	var screen_mat := StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.05, 0.06, 0.08)
	screen_mat.roughness = 0.15
	root.add_child(box("Screen", Vector3(0, 0.8, 0.05), Vector3(3.3, 1.65, 0.01), screen_mat))
	root.add_child(box_tex("Stand", Vector3(0, 0.05, 0), Vector3(1.2, 0.1, 0.8), TEX_PLASTIC_DARK, 0.5))
	root.add_child(box_tex("Neck", Vector3(0, 0.25, 0), Vector3(0.15, 0.3, 0.15), TEX_METAL, 0.3))

	return root


# ── Desk (Room 2012/2015) ──

static func make_desk() -> Node3D:
	var root := Node3D.new()
	root.name = "desk"

	root.add_child(box_tex("Top", Vector3(0, 0, 0), Vector3(4, 0.08, 2), TEX_WOOD_MED, 0.4))
	var leg_h := 0.75
	var leg_y := -0.4
	for lx in [-1.7, 1.7]:
		for lz in [-0.75, 0.75]:
			root.add_child(box_tex("Leg", Vector3(lx, leg_y, lz), Vector3(0.08, leg_h, 0.08), TEX_WOOD_DARK, 0.8))

	return root


# ── Desktop PC (Room 2012) ──

static func make_desktop_pc() -> Node3D:
	var root := Node3D.new()
	root.name = "computer"

	# Monitor
	root.add_child(box_tex("Monitor", Vector3(0, 0.5, 0), Vector3(1.6, 1.1, 0.1), TEX_PLASTIC_DARK, 0.5))
	var scr_mat := StandardMaterial3D.new()
	scr_mat.albedo_color = Color(0.1, 0.12, 0.18)
	scr_mat.roughness = 0.1
	root.add_child(box("Screen", Vector3(0, 0.5, 0.06), Vector3(1.4, 0.9, 0.01), scr_mat))
	root.add_child(cylinder_tex("Neck", Vector3(0, 0.02, 0.0), 0.04, 0.15, TEX_METAL, 0.3))
	root.add_child(box_tex("Base", Vector3(0, -0.15, 0), Vector3(0.6, 0.06, 0.6), TEX_PLASTIC_DARK, 0.6))

	# Tower
	root.add_child(box_tex("Tower", Vector3(1.2, 0.25, 0.3), Vector3(0.5, 0.5, 1.2), TEX_PLASTIC_TV, 0.6))
	root.add_child(box_col("PowerLED", Vector3(1.5, 0.42, 0.85), Vector3(0.02, 0.04, 0.02), GREEN_BTN, 0.3))

	return root


# ── Construction Crane (Room 2012) ──

static func make_construction_crane() -> Node3D:
	var root := Node3D.new()
	root.name = "construction"

	var crane_mat := _mat_color(Color(0.6, 0.45, 0.2), 0.5)
	root.add_child(box("Tower", Vector3(0, 2.5, 0), Vector3(0.15, 5, 0.15), crane_mat))
	root.add_child(box("Boom", Vector3(1.5, 4.8, 0), Vector3(3, 0.1, 0.1), crane_mat))
	var hook_mat := _mat_tex(TEX_METAL, 0.3)
	root.add_child(cylinder("Cable", Vector3(3, 4.3, 0), 0.02, 1.0, hook_mat))
	root.add_child(box("Hook", Vector3(3, 3.78, 0), Vector3(0.12, 0.12, 0.12), hook_mat))

	return root


# ── Old Calendar (Room 2012) ──

static func make_calendar() -> Node3D:
	var root := Node3D.new()
	root.name = "old_calendar"

	root.add_child(box_tex("Back", Vector3(0, 0, 0), Vector3(0.5, 0.6, 0.04), TEX_WOOD_LIGHT, 0.7))
	root.add_child(box_tex("Paper", Vector3(0, 0.1, 0.03), Vector3(0.4, 0.4, 0.01), TEX_PAPER, 0.9, Color(1, 0.95, 0.85)))
	root.add_child(cylinder_tex("Ring", Vector3(0, 0.32, 0.02), 0.06, 0.02, TEX_METAL, 0.3))

	return root


# ── Smartphone (Room 2015) ──

static func make_smartphone() -> Node3D:
	var root := Node3D.new()
	root.name = "smartphone"

	root.add_child(box_tex("Body", Vector3(0, 0, 0), Vector3(0.2, 0.5, 0.03), TEX_PLASTIC_DARK, 0.4))
	var scr_mat := StandardMaterial3D.new()
	scr_mat.albedo_color = Color(0.1, 0.2, 0.35)
	scr_mat.roughness = 0.1
	scr_mat.emission_enabled = true
	scr_mat.emission = Color(0.15, 0.25, 0.4)
	scr_mat.emission_energy_multiplier = 0.6
	root.add_child(box("Screen", Vector3(0, 0.02, 0.02), Vector3(0.16, 0.4, 0.01), scr_mat))
	root.add_child(cylinder_col("HomeBtn", Vector3(0, -0.21, 0.02), 0.02, 0.005, Color(0.5, 0.5, 0.55), 0.3))

	return root


# ── Empty TV Wall (Room 2015) ──

static func make_empty_tv_wall() -> Node3D:
	var root := Node3D.new()
	root.name = "empty_wall"

	# Bare wall patch with faint marks of where a TV used to hang
	var mark_mat := _mat_color(Color(0.75, 0.72, 0.65), 0.8)
	root.add_child(box("Mark", Vector3(0, 1.2, 0), Vector3(3.2, 1.6, 0.01), mark_mat))
	root.add_child(box_col("Hole1", Vector3(-1.5, 1.5, 0.01), Vector3(0.03, 0.03, 0.01), Color(0.5, 0.48, 0.4), 0.6))
	root.add_child(box_col("Hole2", Vector3(1.5, 1.5, 0.01), Vector3(0.03, 0.03, 0.01), Color(0.5, 0.48, 0.4), 0.6))

	return root
