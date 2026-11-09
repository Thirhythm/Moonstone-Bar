extends Node

var _bar: Control


func _ready() -> void:
	await get_tree().process_frame
	GameState.current_slot = 99
	GameState.data = {
		"schema_version": 1, "slot": 99, "created_at": 0, "updated_at": 0,
		"updated_at_text": "", "play_seconds": 0,
		"progress": {
			"day": 1, "money": 24, "stars": 0, "completed_days": 0,
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

	_bar._patience_left = 0.01
	await get_tree().create_timer(1.8).timeout
	print("[DAY] timeout: done=%d active=%s patience=%.1f" % [
		_bar._customers_done, str(_bar._customer_active), _bar._patience_left
	])

	for i in range(4):
		_force_gin_tonic()
		_bar._serve_current_drink()
		await get_tree().create_timer(2.6).timeout

	print("[DAY] served=%d earned=%d stars=%d money=%d" % [
		_bar._day_served, _bar._day_earned, _bar._day_stars, GameState.get_money()
	])

	_bar._time_left = 0.0
	_bar._end_day()
	await get_tree().create_timer(0.5).timeout
	print("[DAY] success title=%s day=%d completed=%d stats=%s" % [
		_bar._result_title.text,
		GameState.get_day(),
		int(GameState.get_progress().get("completed_days", 0)),
		str(GameState.get_stats()),
	])
	await _capture("res://test/m1_success.png")

	_bar._on_result_primary_pressed()
	await get_tree().create_timer(1.2).timeout
	var shop := get_tree().current_scene
	print("[DAY] next day=%d money=%d scene=%s" % [
		GameState.get_day(), GameState.get_money(), shop.name
	])
	await _capture("res://test/m1_day2_shop.png")
	await AudioDirector.shutdown()
	get_tree().quit()


func _force_gin_tonic() -> void:
	_bar._current_recipe = GameData.get_recipe("gin_tonic")
	_bar._session.reset_for(_bar._current_recipe)
	_bar._populate_order_card(_bar._current_recipe)
	_bar._select_glass("highball")
	_bar._session.add_liquid("gin", 45)
	_bar._session.add_liquid("tonic_water", 90)
	_bar._session.add_liquid("lime_juice", 15)
	_bar._session.add_ice(2)
	_bar._session.garnish_added.append("lime")
	_bar._cup.update_from(_bar._session)


func _capture(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	print("[DAY] screenshot %s err=%d" % [path, error])
