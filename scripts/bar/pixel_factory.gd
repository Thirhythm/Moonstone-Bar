class_name PixelFactory
extends RefCounted

static var OUTLINE := Color.html("#141A26")
static var GLASS_EDGE := Color.html("#BFE0EC")
static var GLASS_FILL := Color(0.55, 0.76, 0.86, 0.14)
static var CREAM := Color.html("#F6E3B4")
static var AMBER := Color.html("#F0B95E")
static var ICE := Color(0.86, 0.96, 1.0, 0.78)


static func bottle(ingredient: Dictionary) -> ImageTexture:
	var image := _new_image(16, 30)
	var tint := _color(str(ingredient.get("bottle", "#5B6E8C")), Color.html("#5B6E8C"))
	var light := tint.lightened(0.28)
	var dark := tint.darkened(0.32)

	_rect(image, 3, 12, 11, 18, tint)
	_rect(image, 6, 3, 4, 10, tint)
	_rect(image, 6, 1, 4, 2, AMBER)
	_rect(image, 5, 12, 9, 1, light)
	_rect(image, 4, 13, 1, 16, light)
	_rect(image, 12, 13, 1, 16, dark)
	_rect(image, 5, 18, 7, 8, CREAM)
	_rect(image, 5, 21, 7, 1, AMBER)
	_rect(image, 6, 19, 5, 1, Color.html("#D8C08A"))
	_rect(image, 6, 23, 5, 1, Color.html("#C8A96A"))
	_outline_rect(image, 3, 12, 11, 18)
	_outline_rect(image, 6, 1, 4, 3)
	_outline_rect(image, 6, 4, 4, 9)
	return ImageTexture.create_from_image(image)


static func glass_icon(glass_id: String) -> ImageTexture:
	var image := _new_image(18, 28)
	match glass_id:
		"martini":
			_line(image, 1, 6, 8, 20, GLASS_EDGE)
			_line(image, 16, 6, 9, 20, GLASS_EDGE)
			_line(image, 1, 7, 8, 21, GLASS_EDGE)
			_line(image, 16, 7, 9, 21, GLASS_EDGE)
			_rect(image, 8, 8, 1, 12, Color(0.55, 0.76, 0.86, 0.25))
			_rect(image, 8, 22, 1, 3, GLASS_EDGE)
			_rect(image, 5, 25, 7, 1, GLASS_EDGE)
		"rocks":
			_rect(image, 4, 14, 10, 11, GLASS_FILL)
			_rect(image, 3, 14, 12, 1, GLASS_EDGE)
			_rect(image, 4, 15, 1, 10, GLASS_EDGE)
			_rect(image, 13, 15, 1, 10, GLASS_EDGE)
			_rect(image, 4, 25, 10, 1, GLASS_EDGE)
			_rect(image, 5, 21, 9, 4, Color(0.92, 0.63, 0.25, 0.55))
		_:
			_rect(image, 5, 4, 8, 21, GLASS_FILL)
			_rect(image, 4, 4, 10, 1, GLASS_EDGE)
			_rect(image, 5, 5, 1, 20, GLASS_EDGE)
			_rect(image, 12, 5, 1, 20, GLASS_EDGE)
			_rect(image, 5, 24, 8, 1, GLASS_EDGE)
			_rect(image, 6, 17, 6, 7, Color(0.92, 0.63, 0.25, 0.55))
			_px(image, 6, 6, Color(1, 1, 1, 0.45))
	return ImageTexture.create_from_image(image)


static func customer_sprite(variant: int = 0) -> ImageTexture:
	var image := _new_image(32, 44)
	var skins := [
		Color.html("#E8B98A"), Color.html("#C98E62"),
		Color.html("#F0C9A0"), Color.html("#B07A5A"),
	]
	var hairs := [
		Color.html("#2A2030"), Color.html("#5A3A24"),
		Color.html("#3A4A6A"), Color.html("#1E1A24"),
	]
	var shirts := [
		Color.html("#7A4A5A"), Color.html("#3F6E6C"),
		Color.html("#5A4A7A"), Color.html("#3A3A4A"),
	]
	var index := clampi(variant, 0, 3)
	var skin: Color = skins[index]
	var hair: Color = hairs[index]
	var shirt: Color = shirts[index]

	_rect(image, 8, 42, 16, 2, Color(0, 0, 0, 0.22))

	_rect(image, 5, 25, 4, 13, shirt)
	_rect(image, 23, 25, 4, 13, shirt)
	_rect(image, 4, 37, 5, 4, skin)
	_rect(image, 23, 37, 5, 4, skin)

	_rect(image, 8, 23, 16, 19, shirt)
	_rect(image, 9, 24, 14, 6, shirt.lightened(0.12))
	_rect(image, 14, 29, 4, 13, shirt.lightened(0.06))

	_rect(image, 14, 19, 4, 5, skin)
	_rect(image, 10, 7, 12, 13, skin)
	_rect(image, 11, 8, 10, 11, skin.lightened(0.06))

	if index == 0:
		_rect(image, 10, 4, 12, 6, hair)
		_rect(image, 9, 8, 2, 7, hair)
		_rect(image, 21, 8, 2, 7, hair)
	elif index == 1:
		_rect(image, 10, 4, 12, 4, hair)
		_rect(image, 9, 6, 2, 5, hair)
		_rect(image, 21, 6, 2, 5, hair)
		_rect(image, 10, 15, 3, 6, hair)
	elif index == 2:
		_rect(image, 10, 4, 12, 7, hair)
		_rect(image, 9, 9, 2, 10, hair)
		_rect(image, 21, 9, 2, 10, hair)
		_rect(image, 12, 3, 8, 2, hair)
	else:
		var hat := Color.html("#2E3A52")
		_rect(image, 9, 2, 14, 6, hat)
		_rect(image, 8, 7, 16, 1, hat.darkened(0.25))
		_rect(image, 9, 8, 2, 8, hair)
		_rect(image, 21, 8, 2, 8, hair)

	_px(image, 13, 13, Color.html("#20242E"))
	_px(image, 18, 13, Color.html("#20242E"))
	_rect(image, 15, 16, 2, 1, Color.html("#A8624A"))
	_rect(image, 14, 21, 4, 2, CREAM)
	_rect(image, 8, 23, 1, 19, shirt.darkened(0.3))
	_rect(image, 23, 23, 1, 19, shirt.darkened(0.3))

	_outline_rect(image, 10, 7, 12, 13)
	_outline_rect(image, 8, 23, 16, 19)
	return ImageTexture.create_from_image(image)


static func ice_bucket() -> ImageTexture:
	var image := _new_image(16, 18)
	var metal := Color.html("#5B7C92")
	var metal_light := Color.html("#8FAFC2")
	_rect(image, 3, 6, 10, 11, metal)
	_rect(image, 2, 7, 1, 9, metal_light)
	_rect(image, 13, 7, 1, 9, metal.darkened(0.3))
	_rect(image, 2, 6, 12, 1, metal_light)
	_rect(image, 5, 17, 6, 1, metal.darkened(0.4))
	_rect(image, 2, 2, 3, 3, ICE)
	_rect(image, 6, 1, 3, 3, ICE)
	_rect(image, 10, 2, 3, 3, ICE)
	_rect(image, 7, 4, 2, 2, ICE)
	_outline_rect(image, 3, 6, 10, 11)
	return ImageTexture.create_from_image(image)


static func shaker() -> ImageTexture:
	var image := _new_image(14, 22)
	var metal := Color.html("#9CB6C8")
	var metal_dark := Color.html("#5F7A90")
	_rect(image, 4, 4, 6, 14, metal)
	_rect(image, 3, 16, 8, 5, metal_dark)
	_rect(image, 4, 1, 6, 4, metal_dark)
	_rect(image, 5, 2, 4, 2, metal)
	_rect(image, 5, 6, 1, 10, metal.lightened(0.35))
	_rect(image, 9, 6, 1, 10, metal_dark)
	_outline_rect(image, 3, 16, 8, 5)
	_outline_rect(image, 4, 1, 6, 17)
	return ImageTexture.create_from_image(image)


static func stirrer() -> ImageTexture:
	var image := _new_image(8, 22)
	var rod := Color.html("#D8C08A")
	_rect(image, 3, 4, 2, 17, rod)
	_rect(image, 2, 2, 4, 2, AMBER)
	_rect(image, 3, 0, 2, 2, rod)
	_rect(image, 1, 19, 6, 2, rod.darkened(0.25))
	return ImageTexture.create_from_image(image)


static func garnish_icon(kind: String) -> ImageTexture:
	var image := _new_image(14, 14)
	match kind:
		"lime":
			_filled_circle(image, 7, 7, 5, Color.html("#7FC23E"))
			_filled_circle(image, 7, 7, 3, Color.html("#B9E06A"))
			_px(image, 7, 7, Color.html("#F2F3C4"))
			_line(image, 7, 3, 7, 11, Color.html("#F2F3C4"))
			_line(image, 3, 7, 11, 7, Color.html("#F2F3C4"))
		"mint":
			_filled_circle(image, 5, 8, 3, Color.html("#5FA83A"))
			_filled_circle(image, 9, 5, 3, Color.html("#7FC23E"))
			_filled_circle(image, 10, 10, 2, Color.html("#4E8E32"))
			_rect(image, 4, 11, 1, 3, Color.html("#3F6E2A"))
			_px(image, 6, 5, Color.html("#B9E06A"))
		"orange":
			_filled_circle(image, 7, 7, 5, Color.html("#E8892E"))
			_filled_circle(image, 7, 7, 3, Color.html("#F6B860"))
			_line(image, 7, 3, 7, 11, Color.html("#FFD88A"))
			_line(image, 3, 7, 11, 7, Color.html("#FFD88A"))
		"salt":
			_filled_circle(image, 7, 8, 4, Color.html("#D8D2C0"))
			_filled_circle(image, 7, 8, 2, Color.html("#F4F0E6"))
			_px(image, 5, 6, Color.html("#FFFFFF"))
			_px(image, 9, 9, Color.html("#FFFFFF"))
			_px(image, 9, 5, Color.html("#B8B2A0"))
		_:
			_filled_circle(image, 7, 7, 4, AMBER)
	return ImageTexture.create_from_image(image)


static func star(filled: bool) -> ImageTexture:
	var image := _new_image(9, 9)
	var color := AMBER if filled else Color(0.32, 0.38, 0.48, 0.7)
	var pattern := [
		"....#....",
		"...###...",
		"#########",
		".#######.",
		"..#####..",
		"..#####..",
		".##...##.",
	]
	for y in range(pattern.size()):
		var row: String = pattern[y]
		for x in range(row.length()):
			if row[x] == "#":
				_px(image, x, y + 1, color)
	return ImageTexture.create_from_image(image)


static func _new_image(width: int, height: int) -> Image:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	return image


static func _color(value: String, fallback: Color) -> Color:
	if value.is_valid_html_color():
		return Color.html(value)
	return fallback


static func _px(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height():
		image.set_pixel(x, y, color)


static func _rect(image: Image, x: int, y: int, width: int, height: int, color: Color) -> void:
	for yy in range(y, y + height):
		for xx in range(x, x + width):
			_px(image, xx, yy, color)


static func _outline_rect(image: Image, x: int, y: int, width: int, height: int) -> void:
	_rect(image, x, y, width, 1, OUTLINE)
	_rect(image, x, y + height - 1, width, 1, OUTLINE)
	_rect(image, x, y, 1, height, OUTLINE)
	_rect(image, x + width - 1, y, 1, height, OUTLINE)


static func _line(image: Image, x0: int, y0: int, x1: int, y1: int, color: Color) -> void:
	var dx := absi(x1 - x0)
	var sx := 1 if x0 < x1 else -1
	var dy := -absi(y1 - y0)
	var sy := 1 if y0 < y1 else -1
	var error := dx + dy
	while true:
		_px(image, x0, y0, color)
		if x0 == x1 and y0 == y1:
			break
		var doubled := error * 2
		if doubled >= dy:
			error += dy
			x0 += sx
		if doubled <= dx:
			error += dx
			y0 += sy


static func _filled_circle(image: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	for y in range(cy - radius, cy + radius + 1):
		for x in range(cx - radius, cx + radius + 1):
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy <= radius * radius:
				_px(image, x, y, color)
