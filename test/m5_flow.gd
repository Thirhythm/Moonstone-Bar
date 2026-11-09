extends Node

const DAYS := [1, 2, 3, 4, 5, 6]
# 不再限制顾客数，用每杯服务时间估算单日可接待杯数。
const SECONDS_PER_CUP := 15.0

var _failures := 0


func _ready() -> void:
	await get_tree().process_frame
	_check_balance_curve()
	_check_shop_affordability()
	_check_audio_gains()
	await _check_drag_guards()

	if _failures == 0:
		print("[M5] ALL CHECKS PASSED")
	else:
		push_error("[M5] %d CHECK(S) FAILED" % _failures)
	await AudioDirector.shutdown()
	get_tree().quit(0 if _failures == 0 else 1)


func _check_balance_curve() -> void:
	var previous_goal := 0
	var previous_duration := 9999.0
	for day in DAYS:
		var config := GameData.get_day_config(day)
		var goal := int(config.get("goal", 0))
		var duration := float(config.get("duration", 0))
		var capacity := duration / SECONDS_PER_CUP
		var pool: Array = config.get("recipe_pool", [])
		_check(goal > previous_goal, "第 %d 天目标应高于前一天" % day)
		_check(duration <= previous_duration, "第 %d 天时长不应长于前一天" % day)
		_check(not config.has("max_customers"), "第 %d 天不应配置顾客上限" % day)
		previous_goal = goal
		previous_duration = duration

		for recipe_id in pool:
			_check(GameData.recipes.has(str(recipe_id)), "第 %d 天配方池应存在：%s" % [day, recipe_id])

		var income_3 := _expected_income(day, pool, 1.0)
		var income_2 := _expected_income(day, pool, 0.66)
		var cups_3 := float(goal) / maxf(0.01, income_3)
		var cups_2 := float(goal) / maxf(0.01, income_2)
		_check(cups_3 <= capacity * 0.8, "第 %d 天 3 星应在时限内留有余量：%.2f/%.2f" % [day, cups_3, capacity])
		_check(cups_2 <= capacity * 0.95, "第 %d 天 2 星不应依赖零失误：%.2f/%.2f" % [day, cups_2, capacity])
		print("[M5] day%d goal=%d cups3=%.2f cups2=%.2f capacity=%.2f" % [day, goal, cups_3, cups_2, capacity])

	var final_config := GameData.get_day_config(7)
	var required := int(final_config.get("required_cups", 0))
	var allowed := int(final_config.get("max_major_mistakes", 0))
	var final_duration := float(final_config.get("duration", 0))
	var final_capacity := final_duration / SECONDS_PER_CUP
	_check(not final_config.has("max_customers"), "终局不应配置顾客上限")
	_check(required > 0, "终局完成杯数应大于 0")
	_check(float(required + allowed) <= final_capacity, "终局时间应足够完成要求杯数并允许一次失误")
	print("[M5] day7 cups=%d mistakes=%d time=%.0f capacity=%.2f" % [required, allowed, final_duration, final_capacity])


func _expected_income(day: int, pool: Array, total: float) -> float:
	var weight_sum := 0.0
	var income_sum := 0.0
	for customer in GameData.customers_for_day(day):
		var ids: Array[String] = []
		var mode := str(customer.get("recipe_pool", "any"))
		for recipe_id in pool:
			var recipe := GameData.get_recipe(str(recipe_id))
			var difficulty := int(recipe.get("difficulty", 1))
			if mode == "simple" and difficulty > 1:
				continue
			if mode == "complex" and difficulty < 2:
				continue
			ids.append(str(recipe_id))
		if ids.is_empty():
			continue
		var weight := float(customer.get("weight", 1))
		var day_income := 0.0
		for recipe_id in ids:
			var price := float(GameData.get_recipe(recipe_id).get("price", 20))
			var stars := 3 if total >= 0.8 else 2
			# 3 星取完美收入；2 星按总分 0.66 估算，含星星小费。
			day_income += price * (0.35 + 0.65 * total) + float(stars * 3)
		weight_sum += weight
		income_sum += weight * day_income / float(ids.size())
	return income_sum / maxf(0.01, weight_sum)


func _check_shop_affordability() -> void:
	var total_price := 0
	for item in GameData.shop_items:
		total_price += int(item.get("price", 0))
	var goal_sum := 0
	for day in DAYS:
		goal_sum += int(GameData.get_day_config(day).get("goal", 0))
	_check(total_price <= goal_sum, "只达标的收入应足够买齐商店（%d / %d）" % [total_price, goal_sum])
	print("[M5] shop total=%d goal sum=%d" % [total_price, goal_sum])


func _check_audio_gains() -> void:
	for id in AudioDirector.BGM_ASSETS:
		_check(AudioDirector.BGM_GAIN_DB.has(id), "外部 BGM 应有响度补偿：%s" % id)
	_check(AudioDirector.BGM_GAIN_DB.has("finale"), "尾声 BGM 应有响度补偿")
	_check(float(AudioDirector.BGM_GAIN_DB["game"]) < float(AudioDirector.BGM_GAIN_DB["lobby"]), "游戏 BGM 应低于大厅 BGM")
	_check(float(AudioDirector.BGM_GAIN_DB["finale"]) < float(AudioDirector.BGM_GAIN_DB["lobby"]), "尾声 BGM 应低于大厅 BGM")


func _check_drag_guards() -> void:
	GameState.current_slot = 99
	GameState.day_active = false
	GameState.data = {
		"schema_version": 2,
		"slot": 99,
		"created_at": 0,
		"updated_at": 0,
		"updated_at_text": "",
		"play_seconds": 0,
		"progress": {
			"day": 1,
			"money": 200,
			"stars": 0,
			"completed_days": 0,
			"finished": false,
			"finished_at": 0,
			"unlocked_recipes": ["gin_tonic", "screwdriver"],
			"unlocked_ingredients": GameData.ingredients.keys(),
			"tutorial_done": true,
			"employee_hired": false,
		},
		"stats": {"total_earned": 0, "drinks_served": 0, "best_combo": 0},
	}
	get_tree().change_scene_to_file("res://scenes/bar/bar.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	var bar := get_tree().current_scene
	_check(bar != null and bar.name == "Bar", "应进入吧台")
	if bar == null or bar.name != "Bar":
		return

	var done_before: int = bar._customers_done
	bar._drag_kind = "bottle"
	bar._drag_id = "gin"
	bar._cup_dragging = true
	bar._pointer_position = bar._customer.get_global_rect().get_center()
	bar._on_menu_pressed()
	_check(bar._paused, "菜单应暂停营业")
	_check(bar._drag_kind == "", "暂停时应取消器具拖拽")
	_check(not bar._cup_dragging, "暂停时应取消拖杯")

	bar._cup_dragging = true
	bar._pointer_position = bar._customer.get_global_rect().get_center()
	bar._finish_cup_drag()
	_check(bar._customers_done == done_before, "暂停时松开鼠标不应上酒")
	_check(not bar._awaiting_feedback, "暂停时松开鼠标不应触发结算反馈")
	bar._on_pause_cancelled()

	bar._drag_kind = "stirrer"
	bar._cup_dragging = true
	bar._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(bar._drag_kind == "", "失焦时应取消器具拖拽")
	_check(not bar._cup_dragging, "失焦时应取消拖杯")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("[M5] ok: %s" % message)
	else:
		_failures += 1
		push_error("[M5] FAILED: %s" % message)
