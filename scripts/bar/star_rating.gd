class_name StarRating
extends Control

var stars := 0
var _reveal := -1.0

var _star_filled: ImageTexture
var _star_empty: ImageTexture


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_star_filled = PixelFactory.star(true)
	_star_empty = PixelFactory.star(false)
	set_process(false)
	queue_redraw()


func set_stars(value: int) -> void:
	stars = clampi(value, 0, 3)
	_reveal = -1.0
	set_process(false)
	queue_redraw()


func play_reveal() -> void:
	_reveal = 0.0
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if _reveal < 0.0:
		set_process(false)
		return
	_reveal += delta
	if _reveal > 1.1:
		_reveal = -1.0
		set_process(false)
	queue_redraw()


func _draw() -> void:
	for i in range(3):
		var filled := i < stars
		var base := _star_filled if filled else _star_empty
		var position := Vector2(i * 22 + 2, 0)
		draw_texture_rect(base, Rect2(position, Vector2(18, 18)), false)

		if not filled or _reveal < 0.0:
			continue
		var progress := clampf((_reveal - float(i) * 0.14) / 0.28, 0.0, 1.0)
		if progress <= 0.0:
			continue
		var scale_factor := 0.55 + 0.45 * progress + sin(progress * PI) * 0.3
		var draw_size := Vector2(18, 18) * scale_factor
		var offset := (Vector2(18, 18) - draw_size) * 0.5
		var color := Color(1, 1, 1, progress)
		draw_texture_rect(_star_filled, Rect2(position + offset, draw_size), false, color)
