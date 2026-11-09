extends Node


func _ready() -> void:
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
	var driver := Node.new()
	driver.name = "ManualDriver"
	driver.set_script(load("res://test/manual_driver.gd"))
	get_tree().root.add_child.call_deferred(driver)
	get_tree().change_scene_to_file.call_deferred("res://scenes/bar/bar.tscn")
