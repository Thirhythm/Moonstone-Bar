class_name CustomerArt
extends Control

var patience_ratio := 1.0
var variant := 0
var patience_bar_visible := true

var _texture: ImageTexture
var _portrait: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_variant(0)


func set_variant(index: int) -> void:
	variant = clampi(index, 0, 3)
	_portrait = null
	_texture = PixelFactory.customer_sprite(variant)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func set_portrait(texture: Texture2D) -> void:
	_portrait = texture
	if _portrait == null:
		_texture = PixelFactory.customer_sprite(variant)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		_texture = null
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	queue_redraw()


func set_patience_bar_visible(visible_now: bool) -> void:
	if patience_bar_visible == visible_now:
		return
	patience_bar_visible = visible_now
	queue_redraw()


func set_patience(ratio: float) -> void:
	var clamped := clampf(ratio, 0.0, 1.0)
	if absf(clamped - patience_ratio) < 0.002:
		return
	patience_ratio = clamped
	queue_redraw()


func _draw() -> void:
	if _portrait != null:
		_draw_portrait()
	elif _texture != null:
		draw_texture_rect(_texture, Rect2(0, 0, 64, 88), false)

	if not patience_bar_visible:
		return

	var bar_rect := Rect2(6, 90, 52, 5)
	draw_rect(bar_rect, Color.html("#0B111E"))
	var fill_color := Color.html("#7FE0C4")
	if patience_ratio < 0.3:
		fill_color = Color.html("#E87878")
	elif patience_ratio < 0.6:
		fill_color = Color.html("#F0B95E")
	var fill_width := floorf(bar_rect.size.x * patience_ratio)
	if fill_width > 0.0:
		draw_rect(Rect2(bar_rect.position, Vector2(fill_width, bar_rect.size.y)), fill_color)
	draw_rect(bar_rect, Color.html("#3A4A66"), false, 1.0)


func _draw_portrait() -> void:
	var texture_size := _portrait.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var factor := minf(size.x / texture_size.x, size.y / texture_size.y)
	var draw_size := texture_size * factor
	var offset := (size - draw_size) * 0.5
	draw_texture_rect(_portrait, Rect2(offset, draw_size), false)
