class_name DragOverlay
extends Control

var _texture: Texture2D
var _ghost_position := Vector2.ZERO
var _ghost_scale := 2
var _show_ghost := false
var _stream_color := Color.html("#E89B3C")
var _stream_to := Vector2.ZERO
var _show_stream := false
var _elapsed := 0.0
var _spill_glow := 0.0
var _target_rect := Rect2()
var _target_color := Color.html("#F0B95E")
var _show_target := false
var _droplets: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(true)


func show_ghost(texture: Texture2D, position: Vector2, scale_factor: int = 2) -> void:
	_texture = texture
	_ghost_position = position
	_ghost_scale = scale_factor
	_show_ghost = true
	queue_redraw()


func set_ghost_position(position: Vector2) -> void:
	_ghost_position = position
	queue_redraw()


func hide_ghost() -> void:
	_show_ghost = false
	_show_stream = false
	queue_redraw()


func show_stream(color: Color, target: Vector2) -> void:
	_stream_color = color
	_stream_to = target
	_show_stream = true
	queue_redraw()


func hide_stream() -> void:
	_show_stream = false
	queue_redraw()


func flash_spill(amount: float) -> void:
	_spill_glow = minf(1.0, _spill_glow + amount * 0.12 + 0.25)
	queue_redraw()


func burst_spill(origin: Vector2, amount: float, direction: Vector2 = Vector2.ZERO, color: Color = Color.html("#F0B95E")) -> void:
	_stream_to = origin
	var count := clampi(int(round(amount * 1.3)) + 3, 4, 18)
	for i in range(count):
		var velocity := Vector2(
			randf_range(-52.0, 52.0),
			randf_range(-72.0, -18.0)
		) + direction
		var life := randf_range(0.28, 0.62)
		_droplets.append({
			"pos": origin + Vector2(randf_range(-5.0, 5.0), randf_range(-2.0, 5.0)),
			"vel": velocity,
			"life": life,
			"max_life": life,
			"color": color,
			"size": 2 if randf() < 0.35 else 1,
		})
	queue_redraw()


func splash_at(origin: Vector2, color: Color = Color.html("#DCEFE4")) -> void:
	for i in range(4):
		var velocity := Vector2(randf_range(-30.0, 30.0), randf_range(-46.0, -16.0))
		var life := randf_range(0.16, 0.32)
		_droplets.append({
			"pos": origin,
			"vel": velocity,
			"life": life,
			"max_life": life,
			"color": color,
			"size": 1,
		})


func set_target(rect: Rect2, color: Color) -> void:
	_target_rect = rect
	_target_color = color
	_show_target = true
	queue_redraw()


func clear_target() -> void:
	_show_target = false
	queue_redraw()


func clear_all() -> void:
	_show_ghost = false
	_show_stream = false
	_show_target = false
	_spill_glow = 0.0
	queue_redraw()


func has_activity() -> bool:
	return not _droplets.is_empty() or _show_ghost or _show_stream or _spill_glow > 0.0


func _process(delta: float) -> void:
	_elapsed += delta
	if _spill_glow > 0.0:
		_spill_glow = maxf(0.0, _spill_glow - delta * 1.6)

	var index := _droplets.size() - 1
	while index >= 0:
		var droplet: Dictionary = _droplets[index]
		droplet["life"] = float(droplet["life"]) - delta
		if float(droplet["life"]) <= 0.0:
			_droplets.remove_at(index)
		else:
			droplet["vel"] = (droplet["vel"] as Vector2) + Vector2(0.0, 320.0 * delta)
			droplet["pos"] = (droplet["pos"] as Vector2) + (droplet["vel"] as Vector2) * delta
		index -= 1

	if has_activity():
		queue_redraw()


func _draw() -> void:
	if _show_target:
		_draw_target()
	if _show_stream and _texture != null:
		_draw_stream()
	if _show_ghost and _texture != null:
		_draw_ghost()
	if _spill_glow > 0.0:
		_draw_spill_glow()
	_draw_droplets()


func _draw_target() -> void:
	var color := _target_color
	color.a = 0.5 + 0.35 * sin(_elapsed * 5.0)
	var rect := _target_rect
	var step := 7
	var x := rect.position.x
	while x < rect.end.x:
		draw_rect(Rect2(floorf(x), floorf(rect.position.y), 3, 1), color)
		draw_rect(Rect2(floorf(x), floorf(rect.end.y - 1.0), 3, 1), color)
		x += step
	var y := rect.position.y
	while y < rect.end.y:
		draw_rect(Rect2(floorf(rect.position.x), floorf(y), 1, 3), color)
		draw_rect(Rect2(floorf(rect.end.x - 1.0), floorf(y), 1, 3), color)
		y += step


func _draw_ghost() -> void:
	var texture_size := _texture.get_size() * _ghost_scale
	draw_rect(
		Rect2(_ghost_position + Vector2(4, 4), texture_size),
		Color(0, 0, 0, 0.35)
	)
	draw_texture_rect(_texture, Rect2(_ghost_position, texture_size), false)


func _draw_stream() -> void:
	var texture_size := _texture.get_size() * _ghost_scale
	var start := _ghost_position + Vector2(texture_size.x * 0.5, texture_size.y * 0.7)
	var distance := start.distance_to(_stream_to)
	if distance < 4.0:
		return
	var direction := (_stream_to - start).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var step := 6.0
	var offset := fmod(_elapsed * 46.0, step)
	var traveled := offset
	while traveled < distance:
		var wobble := sin(traveled * 0.22 - _elapsed * 9.0) * 1.6
		var point := start + direction * traveled + normal * wobble
		var pixel_color := _stream_color
		pixel_color.a = 0.9
		draw_rect(Rect2(floorf(point.x), floorf(point.y), 2, 2), pixel_color)
		if int(traveled) % 12 < 6:
			draw_rect(Rect2(floorf(point.x) + 1, floorf(point.y) - 1, 1, 1), pixel_color.lightened(0.3))
		traveled += step

	for i in range(3):
		var phase := fmod(_elapsed * 7.0 + float(i) * 0.33, 1.0)
		var spread := Vector2(float(i - 1) * (2.0 + phase * 6.0), -phase * 7.0)
		var splash := _stream_to + spread
		var splash_color := _stream_color
		splash_color.a = (1.0 - phase) * 0.8
		draw_rect(Rect2(floorf(splash.x), floorf(splash.y), 1, 1), splash_color)


func _draw_spill_glow() -> void:
	var color := Color.html("#F0B95E")
	color.a = clampf(_spill_glow, 0.0, 1.0) * 0.9
	var origin := _stream_to
	for i in range(6):
		var angle := float(i) * 1.35 + _elapsed * 2.2
		var radius := 15.0 + float(i % 3) * 7.0
		var point := origin + Vector2(cos(angle), sin(angle) * 0.5) * radius
		draw_rect(Rect2(floorf(point.x), floorf(point.y), 2, 2), color)


func _draw_droplets() -> void:
	for droplet in _droplets:
		var life := float(droplet["life"])
		var max_life := maxf(0.01, float(droplet["max_life"]))
		var color: Color = droplet["color"]
		color.a = clampf(life / max_life, 0.0, 1.0) * 0.95
		var point: Vector2 = droplet["pos"]
		var pixel_size: int = droplet["size"]
		draw_rect(Rect2(floorf(point.x), floorf(point.y), pixel_size, pixel_size), color)
