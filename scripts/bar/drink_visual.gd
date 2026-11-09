class_name DrinkVisual
extends Control

signal drag_requested

const SPRITE_W := 44
const SPRITE_H := 60

var glass_id := ""
var volume := 0.0
var capacity := 0.0
var liquid := Color.html("#DCEFE4")
var ice_count := 0
var garnishes: Array[String] = []

var _texture: ImageTexture
var _activity := ""
var _activity_time := 0.0
var _error_flash := 0.0

var _edge := Color.html("#BFE0EC")
var _glass_tint := Color(0.55, 0.76, 0.86, 0.12)
var _ice_color := Color(0.86, 0.96, 1.0, 0.72)
var _ice_light := Color(1, 1, 1, 0.85)
var _ice_shadow := Color(0.34, 0.60, 0.72, 0.7)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tooltip_text = "拖给顾客上酒"
	set_process(false)
	_rebuild()


func set_activity(kind: String) -> void:
	if _activity != kind:
		_activity_time = 0.0
	_activity = kind
	if kind != "":
		set_process(true)


func clear_activity() -> void:
	if _activity == "":
		return
	_activity = ""
	queue_redraw()
	if _error_flash <= 0.0:
		set_process(false)


func pulse_error() -> void:
	_error_flash = 0.55
	set_process(true)


func _process(delta: float) -> void:
	_activity_time += delta
	if _error_flash > 0.0:
		_error_flash = maxf(0.0, _error_flash - delta * 1.7)
	if _activity == "" and _error_flash <= 0.0:
		set_process(false)
	queue_redraw()


func update_from(session: DrinkSession) -> void:
	glass_id = session.glass_id
	volume = session.total_volume()
	capacity = session.get_capacity()
	liquid = session.liquid_color()
	ice_count = session.ice_count
	garnishes = session.garnish_added.duplicate()
	_rebuild()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			drag_requested.emit()
			accept_event()


func _draw() -> void:
	if _texture == null:
		return
	var scale_factor := maxi(1, int(floorf(minf(size.x / float(SPRITE_W), size.y / float(SPRITE_H)))))
	var draw_size := Vector2(SPRITE_W * scale_factor, SPRITE_H * scale_factor)
	var origin := Vector2(
		floorf((size.x - draw_size.x) * 0.5),
		floorf(size.y - draw_size.y)
	)

	var offset := Vector2.ZERO
	if _activity == "shake":
		offset.x = roundf(sin(_activity_time * 44.0))
	elif _activity == "stir":
		offset.y = roundf(sin(_activity_time * 9.0) * 1.0)

	draw_texture_rect(_texture, Rect2(origin + offset, draw_size), false)
	_draw_activity(origin + offset, scale_factor)
	if _error_flash > 0.0:
		var flash := Color(0.91, 0.47, 0.47, _error_flash * 0.7)
		draw_rect(Rect2(origin + Vector2(8, 4) * scale_factor, draw_size - Vector2(16, 8) * scale_factor), flash, false, 1.0)


func _draw_activity(origin: Vector2, scale_factor: int) -> void:
	if _activity == "" or glass_id == "":
		return
	if volume <= 1.0:
		return
	var bounds := _glass_bounds()
	var top: int = bounds["top"]
	var bottom: int = bounds["bottom"]
	var center: float = bounds["center"]
	var half_bottom: float = bounds["half_bottom"]
	var ratio := 0.0
	if capacity > 0.0:
		ratio = clampf(volume / capacity, 0.0, 1.0)
	var surface := float(bottom) - ratio * float(bottom - top - 1)

	var bubbles := 3 if _activity == "pour" else 2
	for i in range(bubbles):
		var phase := fmod(_activity_time * (1.4 + float(i) * 0.3) + float(i) * 0.37, 1.0)
		var x := center + sin(float(i) * 2.4 + _activity_time * 2.0) * half_bottom * 0.45
		var y := surface + 6.0 - phase * 8.0
		var bubble := Vector2(
			origin.x + floorf(x * scale_factor),
			origin.y + floorf(y * scale_factor)
		)
		var color := liquid.lightened(0.45)
		color.a = (1.0 - phase) * 0.7
		draw_rect(Rect2(bubble, Vector2(scale_factor, scale_factor)), color)

	if _activity == "stir":
		var ripple := Color(1, 1, 1, 0.22 + 0.16 * sin(_activity_time * 9.0))
		var ripple_y := origin.y + floorf((surface + 1.0) * scale_factor)
		var ripple_start := center - half_bottom * 0.45
		var ripple_width := half_bottom * 0.9
		draw_rect(Rect2(
			origin.x + floorf(ripple_start * scale_factor),
			ripple_y,
			floorf(ripple_width * scale_factor),
			scale_factor
		), ripple)


func _rebuild() -> void:
	var image := Image.create(SPRITE_W, SPRITE_H, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var edge := _edge if glass_id != "" else Color(0.55, 0.70, 0.80, 0.30)
	var glass_tint := _glass_tint if glass_id != "" else Color(0.55, 0.70, 0.80, 0.06)
	var bounds := _glass_bounds()
	var top: int = bounds["top"]
	var bottom: int = bounds["bottom"]
	var center: float = bounds["center"]
	var half_top: float = bounds["half_top"]
	var half_bottom: float = bounds["half_bottom"]
	var ratio := 0.0
	if capacity > 0.0:
		ratio = clampf(volume / capacity, 0.0, 1.0)

	var surface := float(bottom)
	if ratio > 0.0:
		surface = float(bottom) - ratio * float(bottom - top - 1)

	for row in range(top, bottom + 1):
		var t := float(row - top) / float(bottom - top)
		var half := lerpf(half_top, half_bottom, t)
		var left := int(roundf(center - half))
		var right := int(roundf(center + half))
		for x in range(left + 1, right):
			_px(image, x, row, glass_tint)
		_px(image, left, row, edge)
		_px(image, right, row, edge)
		if row > int(surface) and row < bottom:
			var fill := liquid
			fill.a = 0.94
			if row == int(surface) + 1:
				fill = fill.lightened(0.25)
			elif row >= bottom - 2:
				fill = fill.darkened(0.22)
			for x in range(left + 1, right):
				_px(image, x, row, fill)

	for x in range(int(roundf(center - half_top)), int(roundf(center + half_top)) + 1):
		_px(image, x, top, edge)

	if glass_id == "martini":
		_rect(image, 21, 34, 2, 18, edge)
		_rect(image, 16, 52, 12, 1, edge)
		_rect(image, 18, 53, 8, 1, Color(0.55, 0.76, 0.86, 0.4))
	elif glass_id != "":
		_rect(image, int(roundf(center - half_bottom)), bottom, int(roundf(half_bottom * 2.0)) + 1, 1, edge)

	_draw_ice(image)
	_draw_garnishes(image, top, center, half_top)

	if glass_id != "":
		_rect(image, int(roundf(center - half_top)) + 1, top + 2, 1, maxi(1, bottom - top - 5), Color(1, 1, 1, 0.28))

	_rect(image, 12, 56, 20, 1, Color(0, 0, 0, 0.30))
	_rect(image, 15, 57, 14, 1, Color(0, 0, 0, 0.18))

	_texture = ImageTexture.create_from_image(image)
	queue_redraw()


func _glass_bounds() -> Dictionary:
	match glass_id:
		"martini":
			return {"top": 10, "bottom": 33, "center": 22.0, "half_top": 17.0, "half_bottom": 1.0}
		"rocks":
			return {"top": 20, "bottom": 51, "center": 22.0, "half_top": 12.0, "half_bottom": 10.0}
		"highball":
			return {"top": 7, "bottom": 53, "center": 22.0, "half_top": 11.0, "half_bottom": 9.0}
		_:
			return {"top": 7, "bottom": 53, "center": 22.0, "half_top": 11.0, "half_bottom": 9.0}


func _draw_ice(image: Image) -> void:
	if ice_count <= 0:
		return
	var spots := [
		Vector2i(15, 43), Vector2i(24, 46), Vector2i(18, 49), Vector2i(26, 40), Vector2i(14, 38),
	]
	if glass_id == "rocks":
		spots = [Vector2i(14, 45), Vector2i(24, 47), Vector2i(19, 40), Vector2i(27, 42), Vector2i(16, 50)]
	elif glass_id == "martini":
		spots = [Vector2i(17, 26), Vector2i(26, 28), Vector2i(21, 24), Vector2i(29, 25), Vector2i(14, 28)]

	for i in range(mini(ice_count, spots.size())):
		var spot: Vector2i = spots[i]
		_rect(image, spot.x, spot.y, 4, 4, _ice_color)
		_rect(image, spot.x, spot.y, 2, 1, _ice_light)
		_rect(image, spot.x, spot.y, 1, 2, _ice_light)
		_px(image, spot.x + 3, spot.y + 3, _ice_shadow)
		_px(image, spot.x + 2, spot.y + 3, _ice_shadow)


func _draw_garnishes(image: Image, top: int, center: float, half_top: float) -> void:
	if garnishes.has("salt"):
		for x in range(int(roundf(center - half_top)), int(roundf(center + half_top)) + 1, 2):
			_px(image, x, top, Color.html("#F4F0E6"))
			_px(image, x, top + 1, Color.html("#D8D2C0"))

	var rim_right := int(roundf(center + half_top)) - 1
	var rim_left := int(roundf(center - half_top)) + 1

	if garnishes.has("lime"):
		_filled_circle(image, rim_right - 1, top - 2, 3, Color.html("#7FC23E"))
		_px(image, rim_right - 1, top - 2, Color.html("#F2F3C4"))
		_px(image, rim_right - 3, top - 2, Color.html("#B9E06A"))
		_px(image, rim_right + 1, top - 2, Color.html("#B9E06A"))

	if garnishes.has("orange"):
		_rect(image, rim_right - 2, top - 3, 3, 4, Color.html("#E8892E"))
		_px(image, rim_right - 1, top - 2, Color.html("#FFD88A"))

	if garnishes.has("mint"):
		_filled_circle(image, rim_right - 2, top - 6, 2, Color.html("#5FA83A"))
		_filled_circle(image, rim_right + 1, top - 4, 2, Color.html("#7FC23E"))
		_rect(image, rim_right - 2, top - 4, 1, 4, Color.html("#3F6E2A"))


func _filled_circle(image: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	for y in range(cy - radius, cy + radius + 1):
		for x in range(cx - radius, cx + radius + 1):
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy <= radius * radius:
				_px(image, x, y, color)


func _px(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and x < SPRITE_W and y >= 0 and y < SPRITE_H:
		image.set_pixel(x, y, color)


func _rect(image: Image, x: int, y: int, width: int, height: int, color: Color) -> void:
	for yy in range(y, y + height):
		for xx in range(x, x + width):
			_px(image, xx, yy, color)
