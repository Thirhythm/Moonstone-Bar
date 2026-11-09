extends Node

var _bar: Control
var _mouse_position := Vector2(320, 350)


func _ready() -> void:
	await get_tree().process_frame
	GameState.current_slot = 99
	GameState.data = {
		"schema_version": 1,
		"slot": 99,
		"created_at": 0,
		"updated_at": 0,
		"updated_at_text": "",
		"play_seconds": 0,
		"progress": {
			"day": 1,
			"money": 24,
			"stars": 0,
			"completed_days": 0,
			"unlocked_recipes": ["gin_tonic", "screwdriver"],
			"unlocked_ingredients": ["gin", "vodka", "tonic_water", "orange_juice", "lime_juice"],
			"tutorial_done": true,
			"employee_hired": false,
		},
		"stats": {"total_earned": 0, "drinks_served": 0, "best_combo": 0},
	}

	get_tree().change_scene_to_file("res://scenes/bar/bar.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	_bar = get_tree().current_scene

	_bar._current_recipe = GameData.get_recipe("gin_tonic")
	_bar._session.reset_for(_bar._current_recipe)
	_bar._populate_order_card(_bar._current_recipe)

	await _click_control(_bar._glass_buttons["highball"])
	print("[INPUT] glass=", _bar._session.glass_id)

	await _pour("gin", 1.45, true)
	await _pour("tonic_water", 1.9, false)
	await _pour("lime_juice", 0.65, false)
	await _drag_ice()
	await _drag_ice()
	await _click_control(_find_tool("garnish", "lime"))

	print("[INPUT] poured=", _bar._session.poured, " ice=", _bar._session.ice_count, " garnish=", _bar._session.garnish_added)
	print("[INPUT] spill=", _bar._session.spill_ml, " total=", _bar._session.total_volume())
	await _capture("res://test/m1_filled.png")

	await _drag_cup_to_customer()
	await get_tree().create_timer(0.8).timeout
	print("[INPUT] stars=", _bar._feedback_stars.stars, " income=", _bar._feedback_income.text, " notes=", _bar._feedback_notes.text)
	await _capture("res://test/m1_served.png")

	await get_tree().create_timer(2.2).timeout
	_bar._current_recipe = GameData.get_recipe("screwdriver")
	_bar._session.reset_for(_bar._current_recipe)
	_bar._populate_order_card(_bar._current_recipe)
	await _click_control(_bar._glass_buttons["highball"])
	await _jitter_pour("vodka", 0.9)
	print("[INPUT] jitter spill=", _bar._session.spill_ml)
	await _capture("res://test/m1_spill.png")

	await AudioDirector.shutdown()
	get_tree().quit()


func _find_tool(kind: String, id: String) -> ToolButton:
	for child in _bar._shelf.get_children():
		if child is ToolButton and child.tool_kind == kind and child.tool_id == id:
			return child
	return null


func _click_control(control: Control) -> void:
	var center := control.get_global_rect().get_center()
	_bar._pointer_position = center
	control._gui_input(_button_event(center, true))
	await get_tree().process_frame
	_bar._input(_button_event(center, false))
	await get_tree().process_frame


func _pour(ingredient_id: String, seconds: float, capture_mid: bool) -> void:
	var button := _find_tool("bottle", ingredient_id)
	var center := button.get_global_rect().get_center()
	_bar._pointer_position = center
	button._gui_input(_button_event(center, true))
	await get_tree().process_frame

	var cup_position: Vector2 = _bar._cup.get_global_rect().get_center() + Vector2(0, -12)
	await _move_to(cup_position, 10, true)

	var elapsed := 0.0
	var captured := false
	while elapsed < seconds:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var wobble := Vector2(sin(elapsed * 9.0) * 0.7, cos(elapsed * 7.0) * 0.6)
		var target: Vector2 = cup_position + wobble
		_send_motion(target, target - _mouse_position, true)
		_mouse_position = target
		if capture_mid and not captured and elapsed > seconds * 0.5:
			captured = true
			await _capture("res://test/m1_pour.png")
	_release(_mouse_position)
	await get_tree().process_frame


func _jitter_pour(ingredient_id: String, seconds: float) -> void:
	var button := _find_tool("bottle", ingredient_id)
	var center := button.get_global_rect().get_center()
	_bar._pointer_position = center
	button._gui_input(_button_event(center, true))
	await get_tree().process_frame
	var cup_position: Vector2 = _bar._cup.get_global_rect().get_center() + Vector2(0, -12)
	await _move_to(cup_position, 10, true)

	var elapsed := 0.0
	var step := 0
	while elapsed < seconds:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		step += 1
		var target: Vector2 = cup_position + Vector2(sin(float(step) * 2.7) * 14.0, cos(float(step) * 3.1) * 10.0)
		_send_motion(target, target - _mouse_position, true)
		_mouse_position = target
	_release(_mouse_position)
	await get_tree().process_frame


func _drag_ice() -> void:
	var button := _find_tool("ice", "ice")
	var center := button.get_global_rect().get_center()
	_bar._pointer_position = center
	button._gui_input(_button_event(center, true))
	await get_tree().process_frame
	var cup_position: Vector2 = _bar._cup.get_global_rect().get_center()
	await _move_to(cup_position, 8, true)
	_release(cup_position)
	await get_tree().process_frame


func _drag_cup_to_customer() -> void:
	var cup_position: Vector2 = _bar._cup.get_global_rect().get_center()
	_bar._pointer_position = cup_position
	_bar._cup._gui_input(_button_event(cup_position, true))
	await get_tree().process_frame
	var customer_position: Vector2 = _bar._customer.get_global_rect().get_center()
	await _move_to(customer_position, 14, true)
	await get_tree().process_frame
	await _capture("res://test/m1_droptarget.png")
	_release(customer_position)
	await get_tree().process_frame


func _move_to(target: Vector2, steps: int = 6, held: bool = false) -> void:
	var from := _mouse_position
	for i in range(steps):
		var t := float(i + 1) / float(steps)
		var position := from.lerp(target, t)
		_send_motion(position, position - _mouse_position, held)
		_mouse_position = position
		await get_tree().process_frame


func _send_motion(position: Vector2, relative: Vector2, held: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	_bar._input(event)


func _button_event(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	return event


func _release(position: Vector2) -> void:
	_bar._pointer_position = position
	_bar._input(_button_event(position, false))


func _capture(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	print("[INPUT] screenshot %s err=%d" % [path, error])
