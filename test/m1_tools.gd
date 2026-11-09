extends Node

var _bar: Control
var _pointer := Vector2(320, 350)


func _ready() -> void:
	await get_tree().process_frame
	GameState.current_slot = 99
	GameState.data = {
		"schema_version": 1, "slot": 99, "created_at": 0, "updated_at": 0,
		"updated_at_text": "", "play_seconds": 0,
		"progress": {
			"day": 1, "money": 24, "stars": 0, "completed_days": 0,
			"unlocked_recipes": ["gin_tonic", "screwdriver", "mojito", "margarita", "old_fashioned"],
			"unlocked_ingredients": GameData.ingredients.keys(),
			"tutorial_done": true,
			"employee_hired": false,
		},
		"stats": {"total_earned": 0, "drinks_served": 0, "best_combo": 0},
	}
	get_tree().change_scene_to_file("res://scenes/bar/bar.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	_bar = get_tree().current_scene

	await _shake_round()
	await get_tree().create_timer(2.6).timeout
	await _stir_round()
	await AudioDirector.shutdown()
	get_tree().quit()


func _shake_round() -> void:
	_bar._current_recipe = GameData.get_recipe("margarita")
	_bar._session.reset_for(_bar._current_recipe)
	_bar._populate_order_card(_bar._current_recipe)
	await _click(_bar._glass_buttons["martini"])
	_bar._session.add_liquid("tequila", 45)
	_bar._session.add_liquid("triple_sec", 25)
	_bar._session.add_liquid("lime_juice", 20)
	await _click(_find_tool("garnish", "salt"))
	await _click(_find_tool("garnish", "lime"))
	_bar._cup.update_from(_bar._session)

	var shaker := _find_tool("shaker", "shaker")
	_press_tool(shaker)
	await get_tree().process_frame
	var center: Vector2 = _bar._cup.get_global_rect().get_center()
	_move_to(center, true)
	await get_tree().process_frame
	for i in range(36):
		var target := center + Vector2(-30.0 if i % 2 == 0 else 30.0, 0)
		_move_to(target, true)
		await get_tree().process_frame
	_release(_pointer)
	await get_tree().process_frame
	print("[TOOLS] shake_energy=%.2f spill=%.2f" % [_bar._session.shake_energy, _bar._session.spill_ml])

	await _serve()
	await get_tree().create_timer(0.8).timeout
	print("[TOOLS] margarita stars=%d income=%s notes=%s" % [
		_bar._feedback_stars.stars, _bar._feedback_income.text, _bar._feedback_notes.text
	])


func _stir_round() -> void:
	_bar._current_recipe = GameData.get_recipe("old_fashioned")
	_bar._session.reset_for(_bar._current_recipe)
	_bar._populate_order_card(_bar._current_recipe)
	await _click(_bar._glass_buttons["rocks"])
	_bar._session.add_liquid("whiskey", 50)
	_bar._session.add_liquid("sugar", 10)
	_bar._session.add_liquid("bitters", 5)
	await _drag_ice()
	await _click(_find_tool("garnish", "orange"))
	_bar._cup.update_from(_bar._session)

	var stirrer := _find_tool("stirrer", "stirrer")
	_press_tool(stirrer)
	await get_tree().process_frame
	var center: Vector2 = _bar._cup.get_global_rect().get_center()
	_move_to(center + Vector2(40, 0), true)
	await get_tree().process_frame
	var angle := 0.0
	for i in range(80):
		angle += 0.35
		var target := center + Vector2(cos(angle), sin(angle)) * 40.0
		_move_to(target, true)
		await get_tree().process_frame
	_release(_pointer)
	await get_tree().process_frame
	print("[TOOLS] stir_turns=%.2f spill=%.2f ice=%d garnish=%s" % [
		_bar._session.stir_turns, _bar._session.spill_ml, _bar._session.ice_count, _bar._session.garnish_added
	])

	await _serve()
	await get_tree().create_timer(0.8).timeout
	print("[TOOLS] old_fashioned stars=%d income=%s notes=%s" % [
		_bar._feedback_stars.stars, _bar._feedback_income.text, _bar._feedback_notes.text
	])


func _serve() -> void:
	var cup_position: Vector2 = _bar._cup.get_global_rect().get_center()
	_bar._pointer_position = cup_position
	_bar._cup._gui_input(_button_event(cup_position, true))
	await get_tree().process_frame
	var customer_position: Vector2 = _bar._customer.get_global_rect().get_center()
	for i in range(12):
		var position := cup_position.lerp(customer_position, float(i + 1) / 12.0)
		_move_to(position, true)
		await get_tree().process_frame
	_release(customer_position)
	await get_tree().process_frame


func _click(control: Control) -> void:
	var center := control.get_global_rect().get_center()
	_bar._pointer_position = center
	control._gui_input(_button_event(center, true))
	await get_tree().process_frame
	_bar._input(_button_event(center, false))
	await get_tree().process_frame


func _drag_ice() -> void:
	var button := _find_tool("ice", "ice")
	_press_tool(button)
	await get_tree().process_frame
	_move_to(_bar._cup.get_global_rect().get_center(), true)
	await get_tree().process_frame
	_release(_pointer)
	await get_tree().process_frame


func _find_tool(kind: String, id: String) -> ToolButton:
	for child in _bar._shelf.get_children():
		if child is ToolButton and child.tool_kind == kind and child.tool_id == id:
			return child
	return null


func _press_tool(button: ToolButton) -> void:
	_bar._pointer_position = button.get_global_rect().get_center()
	button._gui_input(_button_event(_bar._pointer_position, true))


func _move_to(target: Vector2, held: bool = false) -> void:
	var relative := target - _pointer
	var event := InputEventMouseMotion.new()
	event.position = target
	event.global_position = target
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	_bar._input(event)
	_pointer = target


func _release(position: Vector2) -> void:
	_bar._pointer_position = position
	_bar._input(_button_event(position, false))


func _button_event(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	return event
