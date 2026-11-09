extends Node

const ALL_RECIPES := [
	"gin_tonic", "screwdriver", "mojito", "margarita", "old_fashioned",
	"black_russian", "blue_lagoon", "dry_martini", "sidecar", "manhattan",
]
const STARTING_INGREDIENTS := ["gin", "vodka", "tonic_water", "orange_juice", "lime_juice"]

var _failures := 0


func _ready() -> void:
	await get_tree().process_frame

	_check_data()
	_check_unlock()
	await _check_shop_scene()
	await _check_normal_day_to_shop()
	await _check_final_day()
	await _check_save_resume()
	_check_save_normalize()

	if _failures == 0:
		print("[M2] ALL CHECKS PASSED")
	else:
		push_error("[M2] %d CHECK(S) FAILED" % _failures)
	await AudioDirector.shutdown()
	get_tree().quit(0 if _failures == 0 else 1)


func _check_data() -> void:
	print("[M2] shop_items=%d" % GameData.shop_items.size())
	_check(GameData.shop_items.size() == 8, "商店应有 8 个配方")
	for day in range(1, 8):
		var config := GameData.get_day_config(day)
		_check(int(config.get("day", 0)) == day, "第 %d 天配置应存在" % day)
		_check(not config.get("recipe_pool", []).is_empty(), "第 %d 天应有配方池" % day)
	var final_config := GameData.get_day_config(7)
	_check(bool(final_config.get("final", false)), "第 7 天应标记为终局")
	_check(int(final_config.get("required_cups", 0)) == 6, "终局应要求 6 杯")
	_check(int(final_config.get("max_major_mistakes", -1)) == 1, "终局允许 1 次失误")


func _check_unlock() -> void:
	_setup_state(1, 500, ["gin_tonic", "screwdriver"])
	_check(GameState.unlock_recipe("mojito", 60), "应能解锁莫吉托")
	_check(GameState.get_money() == 440, "解锁后应扣除 60 月亮石")
	_check(GameState.has_recipe("mojito"), "存档应记录莫吉托")
	_check(not GameState.unlock_recipe("mojito", 0), "已解锁配方不能重复购买")
	var unlocked_ingredients: Array = GameState.get_progress().get("unlocked_ingredients", [])
	for ingredient_id in ["rum", "mint", "sugar", "soda"]:
		_check(unlocked_ingredients.has(ingredient_id), "解锁莫吉托应附带原料 %s" % ingredient_id)


func _check_shop_scene() -> void:
	_setup_state(2, 500, ["gin_tonic", "screwdriver"])
	get_tree().change_scene_to_file("res://scenes/shop/shop.tscn")
	await get_tree().process_frame
	await get_tree().process_frame

	var shop := get_tree().current_scene
	_check(shop != null and shop.name == "Shop", "应进入商店场景")
	var grid: GridContainer = shop.get_node("%ShopGrid")
	_check(grid.get_child_count() == 8, "商店应显示 8 张配方卡")
	var start_button: Button = shop.get_node("%StartButton")
	_check(start_button.text == "开始第 2 天", "商店按钮应指向第 2 天")
	_check(not start_button.disabled, "第 2 天商店应可开始营业")

	var first_card := grid.get_child(0)
	var buy_button := first_card.find_children("*", "Button", true, false)[0] as Button
	_check(buy_button.text == "解锁", "第 2 天莫吉托应可解锁")
	buy_button.pressed.emit()
	await get_tree().process_frame
	_check(GameState.has_recipe("mojito"), "在商店购买后应解锁莫吉托")
	_check(GameState.get_money() == 440, "在商店购买后余额应为 440")
	print("[M2] shop: cards=%d money=%d" % [grid.get_child_count(), GameState.get_money()])
	await _capture("res://test/m2_shop.png")

	await get_tree().create_timer(0.6).timeout
	start_button.pressed.emit()
	await get_tree().create_timer(1.2).timeout
	var bar := get_tree().current_scene
	_check(bar != null and bar.name == "Bar", "开始营业按钮应进入吧台")
	_check(bar._recipe_pool.has("mojito"), "解锁后第 2 天点单池应包含莫吉托")


func _check_normal_day_to_shop() -> void:
	_setup_state(1, 0, ["gin_tonic", "screwdriver"])
	get_tree().change_scene_to_file("res://scenes/bar/bar.tscn")
	await get_tree().process_frame
	await get_tree().process_frame

	var bar := get_tree().current_scene
	bar._customers_done = 99
	bar._spawn_customer()
	_check(bar._day_running, "超出原顾客上限后仍应继续营业")
	_check(bar._customer_active, "超出原顾客上限后应继续接待顾客")

	GameState.add_money(200)
	bar._day_earned = 200
	bar._day_served = 4
	bar._day_stars = 10
	bar._best_combo = 3
	bar._time_left = 50.0
	bar._end_day()
	await get_tree().create_timer(0.4).timeout

	_check(GameState.get_day() == 2, "达标后应推进到第 2 天")
	_check(bar._result_primary_action == "shop", "达标后主按钮应前往商店")
	_check(GameState.get_money() == 200, "达标后应保留当日收入")
	print("[M2] day1 result=%s action=%s" % [bar._result_title.text, bar._result_primary_action])

	bar._on_result_primary_pressed()
	await get_tree().create_timer(1.2).timeout
	var shop := get_tree().current_scene
	_check(shop != null and shop.name == "Shop", "达标后应进入商店")
	var start_button: Button = shop.get_node("%StartButton")
	_check(start_button.text == "开始第 2 天", "商店应开始第 2 天")
	await _capture("res://test/m2_day2_shop.png")


func _check_final_day() -> void:
	_setup_state(7, 500, ALL_RECIPES)
	get_tree().change_scene_to_file("res://scenes/bar/bar.tscn")
	await get_tree().process_frame
	await get_tree().process_frame

	var bar := get_tree().current_scene
	_check(bar._is_final_day, "第 7 天应识别为终局")
	_check(bar._day_label.text.contains("终局"), "终局 HUD 应显示终局")
	print("[M2] final hud=%s" % bar._goal_label.text)
	await _capture("res://test/m2_final_bar.png")

	GameState.add_money(120)
	bar._day_served = 5
	bar._day_major_mistakes = 2
	bar._day_stars = 10
	bar._day_earned = 200
	bar._time_left = 20.0
	_check(bar._day_running, "终局失误超限后仍应营业到倒计时结束")
	bar._end_day()
	await get_tree().create_timer(0.4).timeout

	_check(not GameState.is_finished(), "终局失误超限不应通关")
	_check(GameState.get_day() == 7, "终局失败应停在第 7 天")
	_check(GameState.get_money() == 500, "终局失败应回滚当日收入")
	_check(bar._result_primary_action == "retry", "终局失败应允许重试")
	print("[M2] final fail: title=%s money=%d" % [bar._result_title.text, GameState.get_money()])

	bar._on_result_primary_pressed()
	await get_tree().create_timer(1.2).timeout
	bar = get_tree().current_scene
	_check(bar._is_final_day and bar._day_number == 7, "重试后应回到第 7 天")

	bar._day_served = 5
	bar._day_major_mistakes = 1
	bar._day_stars = 15
	bar._day_earned = 250
	bar._time_left = 0.0
	_force_drink(bar, "gin_tonic")
	bar._serve_current_drink()
	await get_tree().create_timer(2.8).timeout

	_check(GameState.is_finished(), "满足终局条件应标记通关")
	_check(GameState.get_day() == 8, "通关后应记录为完成 7 天")
	_check(int(GameState.get_progress().get("completed_days", 0)) == 7, "通关应累计 7 天")
	_check(bar._epilogue_active, "达标后应先接待打烊顾客")
	print("[M2] final epilogue: recipe=%s" % bar._current_recipe.get("name", ""))

	var epilogue_recipe := str(bar._current_recipe.get("id", ""))
	_force_drink(bar, epilogue_recipe)
	bar._serve_current_drink()
	await get_tree().create_timer(2.8).timeout

	_check(not bar._epilogue_active, "打烊顾客完成后应进入结算")
	_check(bar._result_primary_action == "ending", "通关后主按钮应进入结算")
	_check(bar._result_title.text.contains("通关"), "结果标题应显示通关")
	print("[M2] final success: title=%s action=%s" % [bar._result_title.text, bar._result_primary_action])
	await _capture("res://test/m2_final_result.png")

	bar._on_result_primary_pressed()
	await get_tree().create_timer(1.2).timeout
	var ending := get_tree().current_scene
	_check(ending != null and ending.name == "Ending", "通关后应进入结算场景")
	await _capture("res://test/m2_ending.png")


func _check_save_resume() -> void:
	if bool(SaveManager.get_slot_summary(4).get("exists", false)):
		print("[M2] slot 4 occupied, skip save resume test")
		return

	var save := SaveManager.create_save(4)
	_check(not save.is_empty(), "应能创建槽 4 测试存档")
	if save.is_empty():
		return
	var progress: Dictionary = save["progress"]
	progress["day"] = 3
	progress["money"] = 200
	progress["unlocked_recipes"] = ["gin_tonic", "screwdriver", "mojito"]
	progress["unlocked_ingredients"] = ["gin", "vodka", "tonic_water", "orange_juice", "lime_juice", "rum", "mint", "sugar", "soda"]
	_check(SaveManager.write_save(4, save), "应能写入槽 4 进度")

	_check(GameState.load_game(4), "应能从槽 4 读档")
	_check(GameState.get_day() == 3, "读档应继续第 3 天")
	_check(GameState.get_money() == 200, "读档应恢复月亮石")
	_check(GameState.has_recipe("mojito"), "读档应恢复已解锁配方")
	var summary := SaveManager.get_slot_summary(4)
	_check(int(summary.get("day", 0)) == 3, "存档摘要应显示第 3 天")
	_check(not bool(summary.get("finished", true)), "未通关存档摘要不应标记通关")

	get_tree().change_scene_to_file("res://scenes/save_select/save_select.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	var select := get_tree().current_scene
	_check(select != null and select.name == "SaveSelect", "应打开存档列表")
	select._continue_game(4)
	await get_tree().create_timer(1.2).timeout
	var scene_after_continue := get_tree().current_scene
	_check(scene_after_continue != null and scene_after_continue.name == "Shop", "第 3 天读档应进入商店")

	var finished_save := SaveManager.read_save(4)
	var finished_progress: Dictionary = finished_save["progress"]
	finished_progress["day"] = 8
	finished_progress["completed_days"] = 7
	finished_progress["finished"] = true
	SaveManager.write_save(4, finished_save)
	_check(GameState.load_game(4), "应能读取通关存档")
	_check(GameState.is_finished(), "通关存档应被识别")
	_check(bool(SaveManager.get_slot_summary(4).get("finished", false)), "存档摘要应显示已通关")

	get_tree().change_scene_to_file("res://scenes/save_select/save_select.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	select = get_tree().current_scene
	select._continue_game(4)
	await get_tree().create_timer(1.2).timeout
	scene_after_continue = get_tree().current_scene
	_check(scene_after_continue != null and scene_after_continue.name == "Ending", "已通关存档应进入结算")

	GameState.end_game(false)
	_check(SaveManager.delete_slot(4), "应能清理槽 4 测试存档")
	_check(not bool(SaveManager.get_slot_summary(4).get("exists", true)), "槽 4 应恢复为空")
	GameState.current_slot = 99
	print("[M2] save resume: day3->Shop, finished->Ending, slot4 cleaned")


func _check_save_normalize() -> void:
	var normalized := SaveManager._normalize_save({"progress": {"day": 7, "finished": true}}, 1)
	_check(bool(normalized.get("progress", {}).get("finished", false)), "存档规范化应保留通关标记")
	_check(int(normalized.get("progress", {}).get("finished_at", -1)) == 0, "缺省通关时间应为 0")


func _force_drink(bar: Control, recipe_id: String) -> void:
	var recipe := GameData.get_recipe(recipe_id)
	bar._current_recipe = recipe
	bar._session.reset_for(recipe)
	bar._populate_order_card(recipe)
	bar._select_glass(str(recipe.get("glass", "")))
	for entry in recipe.get("ingredients", []):
		bar._session.add_liquid(str(entry.get("id", "")), float(entry.get("amount", 0)))
	bar._session.add_ice(int(recipe.get("ice", 0)))
	for garnish in recipe.get("garnish", []):
		bar._session.garnish_added.append(str(garnish))
	bar._cup.update_from(bar._session)


func _setup_state(day: int, money: int, unlocked_recipes: Array) -> void:
	GameState.current_slot = 99
	GameState.day_active = false
	GameState.day_start_money = 0
	GameState.data = {
		"schema_version": 2,
		"slot": 99,
		"created_at": 0,
		"updated_at": 0,
		"updated_at_text": "",
		"play_seconds": 0,
		"progress": {
			"day": day,
			"money": money,
			"stars": 0,
			"completed_days": day - 1,
			"finished": false,
			"finished_at": 0,
			"unlocked_recipes": unlocked_recipes.duplicate(),
			"unlocked_ingredients": STARTING_INGREDIENTS.duplicate(),
			"tutorial_done": true,
			"employee_hired": false,
		},
		"stats": {"total_earned": 0, "drinks_served": 0, "best_combo": 0},
	}


func _check(condition: bool, message: String) -> void:
	if condition:
		print("[M2] ok: %s" % message)
	else:
		_failures += 1
		push_error("[M2] FAILED: %s" % message)


func _capture(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	print("[M2] screenshot %s err=%d" % [path, error])
