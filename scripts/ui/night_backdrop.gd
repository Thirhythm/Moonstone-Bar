extends Control

@export var moon_position := Vector2(0.78, 0.27)
@export var show_counter := true
@export var star_count := 70
@export var counter_ratio := 0.82

var _stars: Array[Dictionary] = []
var _elapsed := 0.0
var _moon_texture: ImageTexture

var _sky_bands := [
	Color.html("#080D1C"),
	Color.html("#0A1024"),
	Color.html("#0D142B"),
	Color.html("#101A33"),
	Color.html("#13203B"),
	Color.html("#16233D"),
]
var _counter_color := Color.html("#070C16")
var _bottle_color := Color.html("#1B2E3E")
var _bottle_rim := Color.html("#3E6A72")
var _amber := Color.html("#F0B95E")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_generate_stars()
	_build_moon_texture()
	resized.connect(queue_redraw)
	set_process(not Engine.is_editor_hint())
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()


func _generate_stars() -> void:
	_stars.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261102
	for i in range(star_count):
		_stars.append({
			"pos": Vector2(rng.randf(), rng.randf()),
			"phase": rng.randf() * TAU,
			"speed": rng.randf_range(0.2, 0.9),
			"alpha": rng.randf_range(0.3, 0.9),
			"big": rng.randf() < 0.16,
		})


func _build_moon_texture() -> void:
	var image := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var mask: Array = []
	for y in range(48):
		var row: Array[bool] = []
		row.resize(48)
		for x in range(48):
			var point := Vector2(x + 0.5, y + 0.5)
			var outer := point.distance_to(Vector2(22.0, 24.0)) <= 16.0
			var cutout := point.distance_to(Vector2(29.0, 17.0)) < 15.0
			row[x] = outer and not cutout
		mask.append(row)

	var outline := Color.html("#211C14")
	var cream := Color.html("#F6E3B4")
	var highlight := Color.html("#FFF6D8")
	var crater := Color.html("#D8C08A")
	var glow := Color(0.65, 0.80, 1.0, 0.16)

	for y in range(48):
		for x in range(48):
			if mask[y][x]:
				image.set_pixel(x, y, cream)
				continue
			var near_moon := false
			for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var nx: int = x + offset.x
				var ny: int = y + offset.y
				if nx >= 0 and nx < 48 and ny >= 0 and ny < 48 and mask[ny][nx]:
					near_moon = true
					break
			if near_moon:
				image.set_pixel(x, y, outline)
			elif (x + y) % 2 == 0:
				var distance := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(22.0, 24.0))
				if distance > 17.0 and distance < 23.0:
					image.set_pixel(x, y, glow)

	for point in [
		Vector2i(12, 18), Vector2i(13, 18), Vector2i(12, 19),
		Vector2i(16, 29), Vector2i(17, 29),
	]:
		image.set_pixel(point.x, point.y, crater)
	for point in [
		Vector2i(9, 22), Vector2i(9, 23), Vector2i(10, 24),
	]:
		image.set_pixel(point.x, point.y, highlight)

	_moon_texture = ImageTexture.create_from_image(image)


func _draw() -> void:
	var s := size
	if s.x < 2.0 or s.y < 2.0:
		return

	_draw_sky(s)
	_draw_stars(s)
	_draw_moon(s)
	if show_counter:
		_draw_counter(s)


func _draw_sky(s: Vector2) -> void:
	var band_height := s.y / float(_sky_bands.size())
	for i in range(_sky_bands.size()):
		draw_rect(Rect2(0, floorf(band_height * i), s.x, ceilf(band_height) + 1.0), _sky_bands[i])

	draw_rect(Rect2(0, 0, s.x, 1), Color.html("#090F20"))
	draw_rect(Rect2(0, s.y - 1, s.x, 1), Color.html("#050810"))


func _draw_stars(s: Vector2) -> void:
	for star in _stars:
		var normalized: Vector2 = star["pos"]
		var x := int(floorf(normalized.x * (s.x - 2.0)))
		var y := int(floorf(normalized.y * s.y * 0.74))
		var twinkle := 0.55 + 0.45 * sin(_elapsed * float(star["speed"]) + float(star["phase"]))
		var alpha := float(star["alpha"]) * twinkle
		var pixel_size := 2 if bool(star["big"]) else 1
		draw_rect(Rect2(x, y, pixel_size, pixel_size), Color(0.82, 0.90, 1.0, alpha))


func _draw_moon(s: Vector2) -> void:
	if _moon_texture == null:
		return
	var position := Vector2(
		floorf(s.x * moon_position.x) - 24.0,
		floorf(s.y * moon_position.y) - 24.0
	)
	draw_texture_rect(_moon_texture, Rect2(position, Vector2(48, 48)), false)


func _draw_counter(s: Vector2) -> void:
	var top := floorf(s.y * counter_ratio)
	draw_rect(Rect2(0, top, s.x, s.y - top), _counter_color)
	draw_rect(Rect2(0, top, s.x, 1), Color(0.94, 0.73, 0.37, 0.65))
	draw_rect(Rect2(0, top + 3, s.x, 1), Color(0.35, 0.46, 0.62, 0.28))

	var base_y := int(top)
	_draw_bottle_px(int(s.x * 0.045), base_y, 26, 7)
	_draw_bottle_px(int(s.x * 0.080), base_y, 32, 6)
	_draw_bottle_px(int(s.x * 0.112), base_y, 22, 8)
	_draw_bottle_px(int(s.x * 0.145), base_y, 28, 6)

	_draw_bottle_px(int(s.x * 0.860), base_y, 24, 6)
	_draw_bottle_px(int(s.x * 0.893), base_y, 30, 7)
	_draw_bottle_px(int(s.x * 0.930), base_y, 20, 6)

	_draw_glass_px(int(s.x * 0.115), base_y, 9, 13)
	_draw_glass_px(int(s.x * 0.905), base_y, 8, 11)


func _draw_bottle_px(x: int, base_y: int, height: int, width: int) -> void:
	var body_height := int(height * 0.66)
	var neck_height := height - body_height
	var neck_width := maxi(2, int(width * 0.34))
	var neck_x := x + int((width - neck_width) * 0.5)
	draw_rect(Rect2(x, base_y - body_height, width, body_height), _bottle_color)
	draw_rect(Rect2(neck_x, base_y - height, neck_width, neck_height), _bottle_color)
	draw_rect(Rect2(x, base_y - height - 2, width, 2), _bottle_rim)
	draw_rect(Rect2(x + 1, base_y - body_height + 3, 1, maxi(1, body_height - 6)), Color(0.55, 0.82, 0.86, 0.18))
	draw_rect(Rect2(x + width - 2, base_y - body_height + 4, 1, maxi(1, body_height - 8)), Color(0.02, 0.05, 0.08, 0.45))


func _draw_glass_px(x: int, base_y: int, width: int, height: int) -> void:
	var outline := Color(0.72, 0.86, 0.96, 0.42)
	draw_rect(Rect2(x, base_y - height, width, height), Color(0.55, 0.76, 0.86, 0.14))
	draw_rect(Rect2(x, base_y - height, width, 1), outline)
	draw_rect(Rect2(x, base_y - int(height * 0.42), width, int(height * 0.42)), Color(0.92, 0.63, 0.25, 0.55))
	draw_rect(Rect2(x + 1, base_y - height + 2, 1, height - 3), Color(1, 1, 1, 0.16))
