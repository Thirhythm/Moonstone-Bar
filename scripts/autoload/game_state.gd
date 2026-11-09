extends Node

signal game_loaded(slot: int)

var current_slot: int = 0
var data: Dictionary = {}

var day_active := false
var day_start_money := 0

var _session_start_msec: int = 0


func _ready() -> void:
	get_tree().auto_accept_quit = false
	get_tree().root.close_requested.connect(_on_close_requested)


func has_active_game() -> bool:
	return current_slot > 0 and not data.is_empty()


func new_game(slot: int) -> bool:
	var save := SaveManager.create_save(slot)
	if save.is_empty():
		return false
	_activate(slot, save)
	return true


func load_game(slot: int) -> bool:
	var save := SaveManager.read_save(slot)
	if save.is_empty():
		return false
	_activate(slot, save)
	return true


func autosave() -> bool:
	if not has_active_game():
		return false
	_accumulate_playtime()
	return SaveManager.write_save(current_slot, data)


func end_game(save_first: bool = true) -> void:
	if has_active_game():
		if day_active:
			set_money(day_start_money)
			day_active = false
		if save_first:
			autosave()
	current_slot = 0
	data = {}
	_session_start_msec = 0


func begin_day() -> int:
	day_start_money = get_money()
	day_active = true
	return day_start_money


func end_day() -> void:
	day_active = false


func get_progress() -> Dictionary:
	if data.is_empty():
		return {}
	return data.get("progress", {})


func get_day() -> int:
	return int(get_progress().get("day", 1))


func get_money() -> int:
	return int(get_progress().get("money", 0))


func get_unlocked_recipes() -> Array:
	var result: Variant = get_progress().get("unlocked_recipes", [])
	if typeof(result) != TYPE_ARRAY:
		return []
	return result.duplicate()


func has_recipe(recipe_id: String) -> bool:
	return get_unlocked_recipes().has(recipe_id)


func unlock_recipe(recipe_id: String, price: int) -> bool:
	if data.is_empty() or price < 0:
		return false
	if GameData.get_recipe(recipe_id).is_empty() or has_recipe(recipe_id):
		return false
	var progress := get_progress()
	if int(progress.get("money", 0)) < price:
		return false

	progress["money"] = int(progress.get("money", 0)) - price
	var unlocked: Array = get_unlocked_recipes()
	unlocked.append(recipe_id)
	progress["unlocked_recipes"] = unlocked

	var unlocked_ingredients: Variant = progress.get("unlocked_ingredients", [])
	if typeof(unlocked_ingredients) != TYPE_ARRAY:
		unlocked_ingredients = []
	for ingredient_id in GameData.ingredient_ids_for([recipe_id]):
		if not unlocked_ingredients.has(ingredient_id):
			unlocked_ingredients.append(ingredient_id)
	progress["unlocked_ingredients"] = unlocked_ingredients

	data["progress"] = progress
	return true


func is_finished() -> bool:
	return bool(get_progress().get("finished", false))


func is_tutorial_done() -> bool:
	return bool(get_progress().get("tutorial_done", false))


func mark_tutorial_done() -> void:
	if data.is_empty():
		return
	var progress := get_progress()
	progress["tutorial_done"] = true
	data["progress"] = progress


func mark_finished() -> void:
	if data.is_empty():
		return
	var progress := get_progress()
	progress["finished"] = true
	progress["finished_at"] = int(Time.get_unix_time_from_system())
	data["progress"] = progress


func add_money(amount: int) -> void:
	if data.is_empty():
		return
	var progress := get_progress()
	progress["money"] = maxi(0, int(progress.get("money", 0)) + amount)
	data["progress"] = progress


func set_money(amount: int) -> void:
	if data.is_empty():
		return
	var progress := get_progress()
	progress["money"] = maxi(0, amount)
	data["progress"] = progress


func complete_day(earned: int, served: int, stars: int, best_combo: int) -> void:
	if data.is_empty():
		return
	var progress := get_progress()
	progress["day"] = int(progress.get("day", 1)) + 1
	progress["completed_days"] = int(progress.get("completed_days", 0)) + 1
	progress["stars"] = int(progress.get("stars", 0)) + stars
	data["progress"] = progress

	var stats := get_stats()
	stats["total_earned"] = int(stats.get("total_earned", 0)) + earned
	stats["drinks_served"] = int(stats.get("drinks_served", 0)) + served
	stats["best_combo"] = maxi(int(stats.get("best_combo", 0)), best_combo)
	data["stats"] = stats


func get_stats() -> Dictionary:
	if data.is_empty():
		return {}
	return data.get("stats", {})


func _activate(slot: int, save: Dictionary) -> void:
	current_slot = slot
	data = save
	_session_start_msec = Time.get_ticks_msec()
	game_loaded.emit(slot)


func _accumulate_playtime() -> void:
	if _session_start_msec <= 0:
		return
	var elapsed := int((Time.get_ticks_msec() - _session_start_msec) / 1000.0)
	if elapsed > 0:
		data["play_seconds"] = int(data.get("play_seconds", 0)) + elapsed
	_session_start_msec = Time.get_ticks_msec()


func _on_close_requested() -> void:
	if has_active_game():
		if day_active:
			set_money(day_start_money)
			day_active = false
		autosave()
	await AudioDirector.shutdown()
	UITheme.clear_cursor()
	get_tree().quit()
