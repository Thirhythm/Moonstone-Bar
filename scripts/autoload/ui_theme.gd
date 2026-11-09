extends Node

const FONT_PATH := "res://assets/fonts/pixel/fusion-pixel-12px-sc.woff2"
const SYSTEM_FONT_NAMES := [
	"Microsoft YaHei UI",
	"Microsoft YaHei",
	"SimSun",
	"Arial",
]

const FRAME_SIZE := 14
const FRAME_PATCH := 6
const FRAME_THICKNESS := 4

var COLORS := {
	"bg": Color.html("#0B1024"),
	"bg_soft": Color.html("#121A33"),
	"panel": Color.html("#121A2E"),
	"panel_light": Color.html("#22304F"),
	"cream": Color.html("#F6E3B4"),
	"amber": Color.html("#F0B95E"),
	"amber_soft": Color.html("#FFD88A"),
	"teal": Color.html("#7FE0C4"),
	"text": Color.html("#F4F0E6"),
	"muted": Color.html("#9AA7C0"),
	"dim": Color.html("#75839E"),
	"danger": Color.html("#E87878"),
	"danger_bg": Color.html("#3A1A24"),
	"line": Color.html("#4A5C7A"),
	"ink": Color.html("#10131F"),
}

var font: Font
var theme: Theme

var _cursor_texture: ImageTexture
var _box_cache: Dictionary = {}


func _ready() -> void:
	font = _load_pixel_font()
	theme = _build_theme()
	get_tree().root.theme = theme
	_fit_window()
	_install_cursor()


func _exit_tree() -> void:
	clear_cursor()


func clear_cursor() -> void:
	if _cursor_texture == null:
		return
	for shape in [
		Input.CURSOR_ARROW,
		Input.CURSOR_POINTING_HAND,
		Input.CURSOR_DRAG,
		Input.CURSOR_CAN_DROP,
		Input.CURSOR_MOVE,
		Input.CURSOR_FORBIDDEN,
	]:
		Input.set_custom_mouse_cursor(null, shape)
	_cursor_texture = null


func _load_pixel_font() -> Font:
	var font_file := load(FONT_PATH) as FontFile
	if font_file == null:
		push_error("无法加载像素字体：%s" % FONT_PATH)
		var system := SystemFont.new()
		system.font_names = PackedStringArray(SYSTEM_FONT_NAMES)
		return system

	font_file.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font_file.hinting = TextServer.HINTING_NONE
	font_file.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font_file.generate_mipmaps = false
	font_file.multichannel_signed_distance_field = false
	font_file.allow_system_fallback = true

	var fallback := SystemFont.new()
	fallback.font_names = PackedStringArray(SYSTEM_FONT_NAMES)
	fallback.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	fallback.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	var fallback_list: Array[Font] = [fallback]
	font_file.fallbacks = fallback_list
	return font_file


func _fit_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var window := get_tree().root
	if window == null:
		return
	window.min_size = Vector2i(640, 400)


func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 12

	t.set_font("font", "Label", font)
	t.set_font_size("font_size", "Label", 12)
	t.set_color("font_color", "Label", COLORS["text"])

	_add_label_variation(t, "DisplayTitle", 48, COLORS["cream"])
	_add_label_variation(t, "DisplaySubtitle", 24, COLORS["amber"])
	_add_label_variation(t, "PageTitle", 24, COLORS["cream"])
	_add_label_variation(t, "H1", 24, COLORS["text"])
	_add_label_variation(t, "H2", 24, COLORS["text"])
	_add_label_variation(t, "Body", 12, COLORS["muted"])
	_add_label_variation(t, "Hint", 12, COLORS["dim"])
	_add_label_variation(t, "SlotTitle", 12, COLORS["muted"])
	_add_label_variation(t, "SlotDetail", 12, COLORS["text"])
	_add_label_variation(t, "SlotNumber", 24, COLORS["amber"])
	_add_label_variation(t, "Money", 24, COLORS["amber"])
	_add_label_variation(t, "Toast", 12, COLORS["cream"])

	t.set_color("font_shadow_color", "DisplayTitle", Color(0.02, 0.03, 0.08, 0.9))
	t.set_constant("shadow_offset_x", "DisplayTitle", 2)
	t.set_constant("shadow_offset_y", "DisplayTitle", 2)
	t.set_constant("shadow_outline_size", "DisplayTitle", 0)
	t.set_constant("line_spacing", "Body", 2)
	t.set_color("font_outline_color", "Toast", Color(0.02, 0.03, 0.08, 1.0))
	t.set_constant("outline_size", "Toast", 2)

	_add_button_styles(t)
	_add_panel_styles(t)
	return t


func _add_label_variation(t: Theme, variation: String, size: int, color: Color) -> void:
	t.set_type_variation(variation, "Label")
	t.set_font("font", variation, font)
	t.set_font_size("font_size", variation, size)
	t.set_color("font_color", variation, color)


func _add_button_styles(t: Theme) -> void:
	var normal := make_box(Color.html("#1A2540"), Color.html("#4A5C7A"))
	var hover := make_box(Color.html("#26365C"), COLORS["amber"])
	var pressed := make_box(COLORS["amber"], COLORS["amber_soft"])
	var disabled := make_box(Color.html("#141B2C"), Color.html("#2A3650"))

	t.set_font("font", "Button", font)
	t.set_font_size("font_size", "Button", 12)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("hover_pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", COLORS["text"])
	t.set_color("font_hover_color", "Button", COLORS["cream"])
	t.set_color("font_pressed_color", "Button", COLORS["ink"])
	t.set_color("font_hover_pressed_color", "Button", COLORS["ink"])
	t.set_color("font_focus_color", "Button", COLORS["text"])
	t.set_color("font_disabled_color", "Button", COLORS["dim"])

	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", make_box(COLORS["amber"], COLORS["amber_soft"]))
	t.set_stylebox("hover", "PrimaryButton", make_box(COLORS["amber_soft"], Color.html("#FFF0C8")))
	t.set_stylebox("pressed", "PrimaryButton", make_box(Color.html("#C98E3C"), COLORS["amber"]))
	t.set_stylebox("hover_pressed", "PrimaryButton", make_box(Color.html("#C98E3C"), COLORS["amber"]))
	t.set_stylebox("disabled", "PrimaryButton", disabled)
	t.set_stylebox("focus", "PrimaryButton", StyleBoxEmpty.new())
	t.set_color("font_color", "PrimaryButton", COLORS["ink"])
	t.set_color("font_hover_color", "PrimaryButton", COLORS["ink"])
	t.set_color("font_pressed_color", "PrimaryButton", COLORS["ink"])
	t.set_color("font_hover_pressed_color", "PrimaryButton", COLORS["ink"])
	t.set_color("font_disabled_color", "PrimaryButton", Color(COLORS["ink"], 0.4))

	t.set_type_variation("GhostButton", "Button")
	t.set_stylebox("normal", "GhostButton", make_box(Color.html("#141C30"), Color.html("#3A4A66")))
	t.set_stylebox("hover", "GhostButton", make_box(Color.html("#1E2A46"), COLORS["amber"]))
	t.set_stylebox("pressed", "GhostButton", make_box(Color.html("#0F1524"), COLORS["amber_soft"]))
	t.set_stylebox("hover_pressed", "GhostButton", make_box(Color.html("#0F1524"), COLORS["amber_soft"]))
	t.set_stylebox("disabled", "GhostButton", disabled)
	t.set_stylebox("focus", "GhostButton", StyleBoxEmpty.new())
	t.set_color("font_color", "GhostButton", COLORS["muted"])
	t.set_color("font_hover_color", "GhostButton", COLORS["cream"])
	t.set_color("font_pressed_color", "GhostButton", COLORS["cream"])
	t.set_color("font_hover_pressed_color", "GhostButton", COLORS["cream"])
	t.set_color("font_disabled_color", "GhostButton", COLORS["dim"])

	t.set_type_variation("DangerButton", "Button")
	t.set_stylebox("normal", "DangerButton", make_box(COLORS["danger_bg"], Color.html("#C85A5A")))
	t.set_stylebox("hover", "DangerButton", make_box(Color.html("#54222F"), COLORS["danger"]))
	t.set_stylebox("pressed", "DangerButton", make_box(Color.html("#7A2C3A"), Color.html("#FFB0B0")))
	t.set_stylebox("hover_pressed", "DangerButton", make_box(Color.html("#7A2C3A"), Color.html("#FFB0B0")))
	t.set_stylebox("disabled", "DangerButton", disabled)
	t.set_stylebox("focus", "DangerButton", StyleBoxEmpty.new())
	t.set_color("font_color", "DangerButton", Color.html("#F0A0A0"))
	t.set_color("font_hover_color", "DangerButton", Color.html("#FFD0D0"))
	t.set_color("font_pressed_color", "DangerButton", Color.html("#FFF0F0"))
	t.set_color("font_hover_pressed_color", "DangerButton", Color.html("#FFF0F0"))
	t.set_color("font_disabled_color", "DangerButton", Color(COLORS["dim"], 0.5))


func _add_panel_styles(t: Theme) -> void:
	t.set_stylebox("panel", "PanelContainer", make_box(Color.html("#121A2E"), Color.html("#3A4A66")))

	t.set_type_variation("CardPanel", "PanelContainer")
	t.set_stylebox("panel", "CardPanel", make_box(Color.html("#111A2D"), Color.html("#3A4A66")))

	t.set_type_variation("ModalPanel", "PanelContainer")
	t.set_stylebox("panel", "ModalPanel", make_box(Color.html("#0E1526"), COLORS["amber"]))

	t.set_type_variation("BadgePanel", "PanelContainer")
	t.set_stylebox("panel", "BadgePanel", make_box(Color.html("#2A2113"), COLORS["amber"]))


func make_box(bg: Color, border: Color, pad_x: int = 6, pad_y: int = 3) -> StyleBoxTexture:
	var key := "%s|%s|%d|%d" % [bg.to_html(), border.to_html(), pad_x, pad_y]
	if _box_cache.has(key):
		return _box_cache[key]

	var box := StyleBoxTexture.new()
	box.texture = _build_frame_texture(bg, border)
	box.texture_margin_left = float(FRAME_PATCH)
	box.texture_margin_right = float(FRAME_PATCH)
	box.texture_margin_top = float(FRAME_PATCH)
	box.texture_margin_bottom = float(FRAME_PATCH)
	box.content_margin_left = float(pad_x + FRAME_THICKNESS - 2)
	box.content_margin_right = float(pad_x + FRAME_THICKNESS - 2)
	box.content_margin_top = float(pad_y + FRAME_THICKNESS - 2)
	box.content_margin_bottom = float(pad_y + FRAME_THICKNESS - 2)
	_box_cache[key] = box
	return box


func _build_frame_texture(bg: Color, border: Color) -> ImageTexture:
	var img := Image.create(FRAME_SIZE, FRAME_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(bg)
	var ink: Color = COLORS["ink"]
	var cut_color := Color(0, 0, 0, 0)
	for y in range(FRAME_SIZE):
		for x in range(FRAME_SIZE):
			var edge := mini(x, FRAME_SIZE - 1 - x) + mini(y, FRAME_SIZE - 1 - y)
			var ring := mini(mini(x, y), mini(FRAME_SIZE - 1 - x, FRAME_SIZE - 1 - y))
			if edge < 2:
				img.set_pixel(x, y, cut_color)
			elif edge == 2 or ring == 0 or ring == FRAME_THICKNESS - 1:
				img.set_pixel(x, y, ink)
			elif ring < FRAME_THICKNESS:
				img.set_pixel(x, y, border)
	return ImageTexture.create_from_image(img)


func _install_cursor() -> void:
	if DisplayServer.get_name() == "headless":
		return

	var hotspot := Vector2(8, 26)
	var shapes := {
		Input.CURSOR_ARROW: "moon",
		Input.CURSOR_POINTING_HAND: "spark",
		Input.CURSOR_DRAG: "drag",
		Input.CURSOR_CAN_DROP: "drop",
		Input.CURSOR_MOVE: "drag",
		Input.CURSOR_FORBIDDEN: "blocked",
	}
	for shape in shapes:
		var texture := _build_cursor_image(str(shapes[shape]))
		_cursor_texture = texture
		Input.set_custom_mouse_cursor(texture, shape, hotspot)


func _build_cursor_image(kind: String) -> ImageTexture:
	var base := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	base.fill(Color(0, 0, 0, 0))

	var mask: Array = []
	for y in range(16):
		var row: Array[bool] = []
		row.resize(16)
		for x in range(16):
			var point := Vector2(x + 0.5, y + 0.5)
			var outer := point.distance_to(Vector2(7.0, 8.5)) <= 7.0
			var cutout := point.distance_to(Vector2(10.0, 6.0)) < 6.3
			row[x] = outer and not cutout
		mask.append(row)

	var outline_color := Color.html("#1A1420")
	var moon_color := Color.html("#C88A8A") if kind == "blocked" else Color.html("#F6E3B4")
	var highlight_color := Color.html("#FFF6D8")

	for y in range(16):
		for x in range(16):
			if mask[y][x]:
				base.set_pixel(x, y, moon_color)
				continue
			var near_moon := false
			for offset in [
				Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
				Vector2i(-1, 0), Vector2i(1, 0),
				Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
			]:
				var nx: int = x + offset.x
				var ny: int = y + offset.y
				if nx >= 0 and nx < 16 and ny >= 0 and ny < 16 and mask[ny][nx]:
					near_moon = true
					break
			if near_moon:
				base.set_pixel(x, y, outline_color)

	for point in [
		Vector2i(5, 7), Vector2i(5, 8), Vector2i(6, 9), Vector2i(6, 10),
	]:
		base.set_pixel(point.x, point.y, highlight_color)

	match kind:
		"spark":
			for point in [
				Vector2i(12, 2), Vector2i(12, 3), Vector2i(11, 3), Vector2i(13, 3), Vector2i(12, 4),
			]:
				base.set_pixel(point.x, point.y, highlight_color)
		"drag":
			for point in [
				Vector2i(10, 12), Vector2i(9, 13), Vector2i(10, 13), Vector2i(11, 13),
				Vector2i(10, 14),
			]:
				base.set_pixel(point.x, point.y, Color.html("#E8892E"))
		"drop":
			for point in [
				Vector2i(10, 11), Vector2i(9, 12), Vector2i(10, 12), Vector2i(11, 12),
				Vector2i(10, 13), Vector2i(10, 14),
			]:
				base.set_pixel(point.x, point.y, Color.html("#7FE0C4"))
		"blocked":
			for point in [
				Vector2i(9, 11), Vector2i(10, 12), Vector2i(11, 13), Vector2i(12, 14),
				Vector2i(12, 11), Vector2i(11, 12), Vector2i(10, 13), Vector2i(9, 14),
			]:
				base.set_pixel(point.x, point.y, Color.html("#E87878"))

	base.resize(32, 32, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(base)
