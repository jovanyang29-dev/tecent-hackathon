class_name SpriteSheet
extends RefCounted
## Extracts tiles from a 16x16 pixel-art spritesheet and creates tiled textures

var _texture: ImageTexture
var _image: Image
var _tile_size: int = 16
var _cols: int = 0
var _rows: int = 0


func load_sheet(path: String, tile_size: int = 16) -> bool:
	if not FileAccess.file_exists(path):
		push_error("SpriteSheet: file not found: %s" % path)
		return false
	_image = Image.load_from_file(path)
	if _image == null:
		return false
	_texture = ImageTexture.create_from_image(_image)
	_tile_size = tile_size
	_cols = _image.get_width() / _tile_size
	_rows = _image.get_height() / _tile_size
	return true


func tile_count() -> int:
	return _cols * _rows


func get_tile(col: int, row: int) -> ImageTexture:
	if _image == null or col < 0 or col >= _cols or row < 0 or row >= _rows:
		return null
	var src := Rect2i(col * _tile_size, row * _tile_size, _tile_size, _tile_size)
	var tile_img := _image.get_region(src)
	return ImageTexture.create_from_image(tile_img)


func get_tile_scaled(col: int, row: int, scale: int) -> ImageTexture:
	var src := get_tile(col, row)
	if src == null:
		return null
	var img := src.get_image()
	img.resize(_tile_size * scale, _tile_size * scale, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


func make_tiled(tile_col: int, tile_row: int, width_px: int, height_px: int) -> ImageTexture:
	if _image == null or tile_col < 0 or tile_col >= _cols or tile_row < 0 or tile_row >= _rows:
		return null

	var scale: int = 4
	var tw: int = _tile_size * scale
	var th: int = _tile_size * scale
	var tiles_x: int = ceili(float(width_px) / float(tw))
	var tiles_y: int = ceili(float(height_px) / float(th))

	var src_rect := Rect2i(tile_col * _tile_size, tile_row * _tile_size, _tile_size, _tile_size)
	var tile_img: Image = _image.get_region(src_rect)
	tile_img.resize(tw, th, Image.INTERPOLATE_NEAREST)

	var out: Image = Image.create(width_px, height_px, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))

	for ty: int in range(tiles_y):
		for tx: int in range(tiles_x):
			var px: int = tx * tw
			var py: int = ty * th
			if px + tw > width_px:
				out.blit_rect(tile_img, Rect2i(0, 0, width_px - px, th), Vector2i(px, py))
			elif py + th > height_px:
				out.blit_rect(tile_img, Rect2i(0, 0, tw, height_px - py), Vector2i(px, py))
			else:
				out.blit_rect(tile_img, Rect2i(0, 0, tw, th), Vector2i(px, py))

	return ImageTexture.create_from_image(out)


func get_tile_count() -> Dictionary:
	return {"cols": _cols, "rows": _rows, "total": _cols * _rows}
