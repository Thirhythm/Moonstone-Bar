extends Node


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

	var bar := get_tree().current_scene
	print("[TEST] scene=", bar.name, " day=", bar._day_number, " pool=", bar._recipe_pool)
	print("[TEST] ingredients=", bar._available_ingredients)

	for recipe_id in ["gin_tonic", "screwdriver", "mojito", "margarita", "old_fashioned"]:
		var recipe := GameData.get_recipe(recipe_id)
		var session := DrinkSession.new(recipe)
		session.glass_id = str(recipe.get("glass", ""))
		for entry in recipe.get("ingredients", []):
			session.add_liquid(str(entry.get("id", "")), float(entry.get("amount", 0)))
		session.add_ice(int(recipe.get("ice", 0)))
		for garnish in recipe.get("garnish", []):
			session.garnish_added.append(str(garnish))
		if str(recipe.get("method", "")) == "shake":
			session.shake_energy = float(recipe.get("shake_power", 8))
		elif str(recipe.get("method", "")) == "stir":
			session.stir_turns = float(recipe.get("stir_turns", 4))
		var result := DrinkScoring.evaluate(session, 1.0)
		print("[TEST] %s total=%.2f stars=%d income=%d notes=%s" % [
			recipe_id, result["total"], result["stars"], result["income"], str(result["notes"])
		])

	bar._current_recipe = GameData.get_recipe("gin_tonic")
	bar._session.reset_for(bar._current_recipe)
	bar._populate_order_card(bar._current_recipe)
	bar._select_glass("highball")
	bar._session.add_liquid("gin", 45)
	bar._session.add_liquid("tonic_water", 90)
	bar._session.add_liquid("lime_juice", 15)
	bar._session.add_ice(2)
	bar._session.garnish_added.append("lime")
	bar._cup.update_from(bar._session)
	bar._update_recipe_progress()

	bar._serve_current_drink()
	await get_tree().create_timer(0.9).timeout
	await _capture("res://test/m1_feedback.png")

	await get_tree().create_timer(2.2).timeout
	await _capture("res://test/m1_bar.png")
	print("[TEST] earned=%d served=%d stars=%d money=%d" % [
		bar._day_earned, bar._day_served, bar._day_stars, GameState.get_money()
	])

	bar._time_left = 0.0
	bar._end_day()
	await get_tree().create_timer(0.4).timeout
	await _capture("res://test/m1_result.png")
	print("[TEST] result_open=", bar._result_open, " title=", bar._result_title.text, " money=%d" % GameState.get_money())
	await AudioDirector.shutdown()
	get_tree().quit()


func _capture(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	print("[TEST] screenshot %s err=%d" % [path, error])
