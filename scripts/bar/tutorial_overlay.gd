class_name TutorialOverlay
extends Control

signal finished(skipped: bool)

var _steps: Array[Dictionary] = []
var _index := 0
var _elapsed := 0.0
var _current_rects: Array[Rect2] = []
var _panel: PanelContainer
var _step_label: Label
var _title_label: Label
var _text_label: Label
var _next_button: Button
var _skip_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 55
	_build_panel()
	visible = false
	set_process(false)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"ModalPanel"
	_panel.custom_minimum_size = Vector2(236, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	margin.add_child(box)

	_step_label = _make_label("引导 1/6", "Hint")
	box.add_child(_step_label)

	_title_label = _make_label("", "H1")
	box.add_child(_title_label)

	_text_label = _make_label("", "Body")
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(206, 0)
	box.add_child(_text_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 6)
	box.add_child(buttons)

	_skip_button = _make_button("跳过引导", "GhostButton")
	_skip_button.custom_minimum_size = Vector2(72, 22)
	_skip_button.pressed.connect(_on_skip_pressed)
	buttons.add_child(_skip_button)

	_next_button = _make_button("下一步", "PrimaryButton")
	_next_button.custom_minimum_size = Vector2(72, 22)
	_next_button.pressed.connect(_on_next_pressed)
	buttons.add_child(_next_button)

	_panel.resized.connect(_place_panel)


func start(steps: Array[Dictionary]) -> void:
	if steps.is_empty():
		return
	_steps = steps
	_index = 0
	_elapsed = 0.0
	visible = true
	set_process(true)
	_apply_step()
	AudioDirector.play_sfx("tutorial", 1.0, -2.0, 0.0)


func is_active() -> bool:
	return visible and not _steps.is_empty()


func current_step_id() -> String:
	if not is_active():
		return ""
	return str(_steps[_index].get("id", ""))


func complete_current() -> void:
	if not is_active():
		return
	if _index >= _steps.size() - 1:
		_finish(false)
	else:
		_index += 1
		_apply_step()


func skip() -> void:
	_finish(true)


func stop() -> void:
	visible = false
	set_process(false)
	_current_rects.clear()
	queue_redraw()


func _apply_step() -> void:
	if _index < 0 or _index >= _steps.size():
		_finish(false)
		return
	var step: Dictionary = _steps[_index]
	_step_label.text = "引导 %d / %d" % [_index + 1, _steps.size()]
	_title_label.text = str(step.get("title", ""))
	_text_label.text = str(step.get("text", ""))
	_next_button.text = "完成" if _index >= _steps.size() - 1 else "下一步"

	_current_rects.clear()
	var rects: Variant = step.get("rects", [])
	if typeof(rects) == TYPE_ARRAY:
		for raw in rects:
			if raw is Rect2:
				var rect: Rect2 = raw
				if rect.size.x > 0.0 and rect.size.y > 0.0:
					_current_rects.append(rect)

	_panel.size = Vector2(236, 0)
	_panel.reset_size()
	_place_panel()
	queue_redraw()


func _place_panel() -> void:
	if _panel == null:
		return
	if _current_rects.is_empty():
		_panel.position = Vector2(200, 140)
		return

	var union: Rect2 = _current_rects[0]
	for i in range(1, _current_rects.size()):
		union = union.merge(_current_rects[i])

	var panel_size := _panel.get_combined_minimum_size()
	panel_size.x = maxf(panel_size.x, 236.0)
	var center_x := union.get_center().x - panel_size.x * 0.5
	var lowest_y := 298.0 - panel_size.y
	var order_rect := Rect2(12, 36, 180, 262)

	var candidates: Array[Vector2] = [
		Vector2(center_x, union.position.y - panel_size.y - 12.0),
		Vector2(center_x, union.end.y + 12.0),
		Vector2(8.0, lowest_y),
		Vector2(632.0 - panel_size.x, lowest_y),
		Vector2((640.0 - panel_size.x) * 0.5, 34.0),
	]

	var best_position := candidates[0]
	var best_score := INF
	for candidate in candidates:
		var position := Vector2(
			clampf(candidate.x, 8.0, 632.0 - panel_size.x),
			clampf(candidate.y, 34.0, lowest_y)
		)
		var rect := Rect2(position, panel_size)
		var score := _overlap_area(rect, order_rect) * 1.5
		for target in _current_rects:
			score += _overlap_area(rect, target) * 4.0
		if score < best_score:
			best_score = score
			best_position = position

	_panel.position = best_position.floor()


func _overlap_area(a: Rect2, b: Rect2) -> float:
	var overlap := a.intersection(b)
	return maxf(0.0, overlap.size.x) * maxf(0.0, overlap.size.y)


func _on_next_pressed() -> void:
	AudioDirector.play_sfx("ui_click", 1.0, -2.0, 0.0)
	if _index >= _steps.size() - 1:
		_finish(false)
	else:
		_index += 1
		_apply_step()
		AudioDirector.play_sfx("tutorial", 1.12, -4.0, 0.0)


func _on_skip_pressed() -> void:
	AudioDirector.play_sfx("ui_click", 0.9, -4.0, 0.0)
	_finish(true)


func _finish(skipped: bool) -> void:
	visible = false
	set_process(false)
	_steps = []
	_current_rects.clear()
	queue_redraw()
	AudioDirector.play_sfx("tutorial", 0.85, -4.0, 0.0)
	finished.emit(skipped)


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var alpha := 0.55 + 0.3 * sin(_elapsed * 5.0)
	var amber: Color = UITheme.COLORS["amber"]
	amber.a = alpha
	for rect in _current_rects:
		var grown := rect.grow(5.0)
		draw_rect(grown, Color(amber.r, amber.g, amber.b, 0.06))
		_draw_dashed_rect(grown, amber)


func _draw_dashed_rect(rect: Rect2, color: Color) -> void:
	var step := 8.0
	var x := rect.position.x
	while x < rect.end.x:
		var width := minf(4.0, rect.end.x - x)
		draw_rect(Rect2(floorf(x), floorf(rect.position.y), width, 1), color)
		draw_rect(Rect2(floorf(x), floorf(rect.end.y - 1.0), width, 1), color)
		x += step
	var y := rect.position.y
	while y < rect.end.y:
		var height := minf(4.0, rect.end.y - y)
		draw_rect(Rect2(floorf(rect.position.x), floorf(y), 1, height), color)
		draw_rect(Rect2(floorf(rect.end.x - 1.0), floorf(y), 1, height), color)
		y += step


func _make_label(text: String, variation: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = StringName(variation)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_button(text: String, variation: String) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = StringName(variation)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button
