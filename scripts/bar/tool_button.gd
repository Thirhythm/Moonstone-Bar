class_name ToolButton
extends Control

signal press_started(tool: ToolButton)

var tool_kind := ""
var tool_id := ""
var label_text := ""
var icon_texture: Texture2D
var selected := false
var enabled := true

var _label: Label
var _hover := false


func configure(kind: String, id: String, text: String, texture: Texture2D) -> void:
	tool_kind = kind
	tool_id = id
	label_text = text
	icon_texture = texture


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_label = Label.new()
	_label.text = label_text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", UITheme.COLORS["muted"])
	_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_label.offset_top = -15.0
	_label.offset_bottom = 0.0
	add_child(_label)
	mouse_entered.connect(_on_hover_changed.bind(true))
	mouse_exited.connect(_on_hover_changed.bind(false))
	queue_redraw()


func set_selected(value: bool) -> void:
	if selected == value:
		return
	selected = value
	_refresh_label_color()
	queue_redraw()


func set_tool_enabled(value: bool) -> void:
	enabled = value
	modulate.a = 1.0 if value else 0.45
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if value else Control.CURSOR_ARROW
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			press_started.emit(self)
			accept_event()


func _draw() -> void:
	var bg := Color.html("#141C30")
	var border := Color.html("#3A4A66")
	if selected:
		bg = Color.html("#2A2113")
		border = UITheme.COLORS["amber"]
	elif _hover and enabled:
		bg = Color.html("#1E2A46")
		border = UITheme.COLORS["amber_soft"]

	UITheme.make_box(bg, border, 2, 2).draw(
		get_canvas_item(),
		Rect2(Vector2.ZERO, Vector2(floorf(size.x), floorf(size.y)))
	)

	if icon_texture == null:
		return
	var texture_size := icon_texture.get_size()
	var icon_area := Vector2(size.x - 4.0, size.y - 16.0)
	var scale_factor := maxi(1, int(floorf(minf(icon_area.x / texture_size.x, icon_area.y / texture_size.y))))
	var draw_size := texture_size * scale_factor
	var position := Vector2(
		floorf((size.x - draw_size.x) * 0.5),
		floorf((icon_area.y - draw_size.y) * 0.5) + 2.0
	)
	draw_texture_rect(icon_texture, Rect2(position, draw_size), false)


func _on_hover_changed(value: bool) -> void:
	_hover = value
	_refresh_label_color()
	queue_redraw()


func _refresh_label_color() -> void:
	if _label == null:
		return
	var color: Color = UITheme.COLORS["dim"]
	if selected:
		color = UITheme.COLORS["amber_soft"]
	elif _hover and enabled:
		color = UITheme.COLORS["cream"]
	elif enabled:
		color = UITheme.COLORS["muted"]
	_label.add_theme_color_override("font_color", color)
