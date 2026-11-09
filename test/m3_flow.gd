extends Node

const ALL_RECIPES := [
	"gin_tonic", "screwdriver", "mojito", "margarita", "old_fashioned",
	"black_russian", "blue_lagoon", "dry_martini", "sidecar", "manhattan",
]

var _failures := 0


func _ready() -> void:
	await get_tree().process_frame

	_check_data()
	_check_recipe_scoring()
	_check_ingredient_count_penalty()
	_check_amount_threshold_alignment()
	_check_stir_threshold_alignment()
	_check_wrong_method_penalty()
	_check_customer_data()
	await _check_bar_content()
	await _check_shop_content()

	if _failures == 0:
		print("[M3] ALL CHECKS PASSED")
	else:
		push_error("[M3] %d CHECK(S) FAILED" % _failures)
	await AudioDirector.shutdown()
	get_tree().quit(0 if _failures == 0 else 1)


func _check_data() -> void:
	print("[M3] recipes=%d ingredients=%d customers=%d shop=%d" % [
		GameData.recipes.size(),
		GameData.ingredients.size(),
		GameData.customers.size(),
		GameData.shop_items.size(),
	])
	_check(GameData.recipes.size() == 10, "配方应扩到 10 个")
	_check(GameData.ingredients.size() == 17, "原料应扩到 17 种")
	_check(GameData.customers.size() == 4, "应有 4 类顾客")
	_check(GameData.shop_items.size() == 8, "商店应上架 8 个配方")

	var difficulties := {}
	for recipe_id in GameData.recipes.keys():
		var recipe := GameData.get_recipe(str(recipe_id))
		var difficulty := int(recipe.get("difficulty", 0))
		_check(difficulty >= 1 and difficulty <= 3, "%s 难度应在 1–3" % recipe_id)
		difficulties[difficulty] = true
		_check(not recipe.get("ingredients", []).is_empty(), "%s 应有原料" % recipe_id)
		_check(float(recipe.get("price", 0)) > 0.0, "%s 应有售价" % recipe_id)
	_check(difficulties.size() == 3, "配方应覆盖 3 档难度")

	var last_day := 0
	for item in GameData.shop_items:
		var recipe_id := str(item.get("recipe", ""))
		_check(GameData.recipes.has(recipe_id), "商店条目应引用有效配方：%s" % recipe_id)
		_check(int(item.get("price", 0)) > 0, "商店价格应大于 0：%s" % recipe_id)
		var available_day := int(item.get("available_day", 0))
		_check(available_day >= last_day, "商店应按开放日递增：%s" % recipe_id)
		_check(available_day >= 2, "解锁配方应从第 2 天起开放：%s" % recipe_id)
		last_day = available_day

	for day in range(1, 8):
		var config := GameData.get_day_config(day)
		var pool: Array = config.get("recipe_pool", [])
		_check(not pool.is_empty(), "第 %d 天应有配方池" % day)
		for recipe_id in pool:
			_check(GameData.recipes.has(str(recipe_id)), "第 %d 天配方池引用未知配方：%s" % [day, recipe_id])
	_check(GameData.get_day_config(7).get("recipe_pool", []).size() == 10, "终局应开放全部 10 个配方")


func _check_recipe_scoring() -> void:
	for recipe_id in GameData.recipes.keys():
		var recipe := GameData.get_recipe(str(recipe_id))
		var result := DrinkScoring.evaluate(_standard_session(recipe), 1.0)
		_check(int(result["stars"]) == 3, "%s 标准操作应 3 星（notes=%s）" % [recipe_id, str(result["notes"])])
		_check(float(result["total"]) >= 0.99, "%s 标准操作应接近满分" % recipe_id)
		_check(int(result["income"]) > 0, "%s 应产生收入" % recipe_id)


func _check_ingredient_count_penalty() -> void:
	var recipe := GameData.get_recipe("gin_tonic")

	var missing := _standard_session(recipe)
	missing.poured.erase("lime_juice")
	var missing_result := DrinkScoring.evaluate(missing, 1.0)
	_check(float(missing_result["total"]) < 0.8, "少放配方原料应明显扣分")
	_check(int(missing_result["stars"]) == 2, "少放一味原料应降为 2 星")

	var extra := _standard_session(recipe)
	extra.poured["rum"] = 45.0
	var extra_result := DrinkScoring.evaluate(extra, 1.0)
	_check(float(extra_result["total"]) < 0.8, "多放配方外原料应明显扣分")
	_check(int(extra_result["stars"]) == 2, "多加一味原料应降为 2 星")


func _check_amount_threshold_alignment() -> void:
	var recipe := GameData.get_recipe("gin_tonic")

	var good := _standard_session(recipe)
	good.add_liquid("gin", 1.5)
	var good_result := DrinkScoring.evaluate(good, 1.0)
	_check(float(good_result["total"]) >= 0.99, "配料表绿色区间应不扣配方分")
	_check(not good_result["notes"].has("金酒偏多"), "绿色区间不应提示偏多")

	var over := _standard_session(recipe)
	over.add_liquid("gin", 3.0)
	var over_result := DrinkScoring.evaluate(over, 1.0)
	_check(float(over_result["total"]) < 0.99, "配料表红色区间应扣配方分")
	_check(over_result["notes"].has("金酒偏多"), "红色区间应提示偏多")

	# 严格按实际用量判定：不能因四舍五入显示成 8 就算命中，否则会降低难度
	_check(not DrinkScoring.amount_is_good(7.6, 8.0), "7.6 ml 不应因显示取整算作命中 8 ml")
	_check(DrinkScoring.amount_is_good(8.2, 8.0), "8.2 ml 应处于绿色区间")

	var mint_low := _standard_session(GameData.get_recipe("mojito"))
	mint_low.poured["mint"] = 7.6
	var mint_low_result := DrinkScoring.evaluate(mint_low, 1.0)
	_check(mint_low_result["notes"].has("薄荷偏少"), "未达绿色区间应提示薄荷偏少")
	_check(float(mint_low_result["total"]) < 1.0, "未达绿色区间应扣配方分")

	var mint_high := _standard_session(GameData.get_recipe("mojito"))
	mint_high.poured["mint"] = 8.6
	var mint_high_result := DrinkScoring.evaluate(mint_high, 1.0)
	_check(mint_high_result["notes"].has("薄荷偏多"), "超出绿色区间应提示薄荷偏多")
	_check(float(mint_high_result["total"]) < 1.0, "超出绿色区间应扣配方分")


func _check_stir_threshold_alignment() -> void:
	var recipe := GameData.get_recipe("old_fashioned")
	var required := float(recipe.get("stir_turns", 4))

	var almost := _standard_session(recipe)
	almost.stir_turns = 3.95
	var almost_result := DrinkScoring.evaluate(almost, 1.0)
	_check(almost_result["notes"].has("搅拌不足"), "未达 99% 应提示搅拌不足")

	var enough := _standard_session(recipe)
	enough.stir_turns = required * DrinkScoring.STIR_GOOD_RATIO
	var enough_result := DrinkScoring.evaluate(enough, 1.0)
	_check(not enough_result["notes"].has("搅拌不足"), "达到 99% 不应提示搅拌不足")

	var over := _standard_session(recipe)
	over.stir_turns = required * DrinkScoring.STIR_OVER_RATIO + 0.1
	var over_result := DrinkScoring.evaluate(over, 1.0)
	_check(over_result["notes"].has("搅拌过度"), "超过 1.2 倍应提示搅拌过度")


func _check_wrong_method_penalty() -> void:
	var shake_recipe := GameData.get_recipe("margarita")
	var shaken := _standard_session(shake_recipe)
	var baseline := DrinkScoring.evaluate(shaken, 1.0)

	var stirred_by_mistake := _standard_session(shake_recipe)
	stirred_by_mistake.stir_turns = 2.0
	var stirred_result := DrinkScoring.evaluate(stirred_by_mistake, 1.0)
	_check(float(stirred_result["total"]) < float(baseline["total"]), "摇壶配方误用搅拌应扣分")
	_check(stirred_result["notes"].has("应摇壶而非搅拌"), "摇壶配方误用搅拌应提示")
	_check(float(stirred_result["technique_score"]) < float(baseline["technique_score"]), "误用搅拌应降低手法分")

	var tiny_stir := _standard_session(shake_recipe)
	tiny_stir.stir_turns = 0.1
	_check(float(DrinkScoring.evaluate(tiny_stir, 1.0)["total"]) >= 0.99, "轻微搅拌不应触发误用惩罚")

	var stir_recipe := GameData.get_recipe("old_fashioned")
	var stir_baseline := DrinkScoring.evaluate(_standard_session(stir_recipe), 1.0)

	var shaken_by_mistake := _standard_session(stir_recipe)
	shaken_by_mistake.shake_energy = 3.0
	var shaken_result := DrinkScoring.evaluate(shaken_by_mistake, 1.0)
	_check(float(shaken_result["total"]) < float(stir_baseline["total"]), "搅拌配方误用摇壶应扣分")
	_check(shaken_result["notes"].has("应搅拌而非摇壶"), "搅拌配方误用摇壶应提示")
	_check(float(shaken_result["technique_score"]) < float(stir_baseline["technique_score"]), "误用摇壶应降低手法分")

	var tiny_shake := _standard_session(stir_recipe)
	tiny_shake.shake_energy = 0.5
	_check(float(DrinkScoring.evaluate(tiny_shake, 1.0)["total"]) >= 0.99, "轻微摇动不应触发误用惩罚")


func _standard_session(recipe: Dictionary) -> DrinkSession:
	var session := DrinkSession.new(recipe)
	session.glass_id = str(recipe.get("glass", ""))
	for entry in recipe.get("ingredients", []):
		session.add_liquid(str(entry.get("id", "")), float(entry.get("amount", 0)))
	session.add_ice(int(recipe.get("ice", 0)))
	for garnish in recipe.get("garnish", []):
		session.garnish_added.append(str(garnish))
	var method := str(recipe.get("method", "build"))
	if method == "shake":
		session.shake_energy = float(recipe.get("shake_power", 8))
	elif method == "stir":
		session.stir_turns = float(recipe.get("stir_turns", 4))
	return session


func _check_customer_data() -> void:
	var regular := GameData.get_customer("regular")
	var hurried := GameData.get_customer("hurried")
	var connoisseur := GameData.get_customer("connoisseur")
	var nightowl := GameData.get_customer("nightowl")
	_check(not regular.is_empty(), "应存在常客")
	_check(not hurried.is_empty(), "应存在急客")
	_check(not connoisseur.is_empty(), "应存在品酒客")
	_check(not nightowl.is_empty(), "应存在夜归人")
	_check(float(hurried.get("patience_mult", 1.0)) < 1.0, "急客耐心应短于基准")
	_check(float(connoisseur.get("patience_mult", 1.0)) > 1.0, "品酒客耐心应长于基准")
	_check(str(hurried.get("recipe_pool", "")) == "simple", "急客应点简单配方")
	_check(str(connoisseur.get("recipe_pool", "")) == "complex", "品酒客应点复杂配方")

	_check(GameData.customers_for_day(1).size() == 2, "第 1 天应只有常客与急客")
	_check(GameData.customers_for_day(2).size() == 3, "第 2 天应加入品酒客")
	_check(GameData.customers_for_day(3).size() == 4, "第 3 天应加入夜归人")


func _check_bar_content() -> void:
	_setup_state(3, 200, ALL_RECIPES)
	get_tree().change_scene_to_file("res://scenes/bar/bar.tscn")
	await get_tree().process_frame
	await get_tree().process_frame

	var bar := get_tree().current_scene
	_check(bar != null and bar.name == "Bar", "应进入吧台")
	_check(bar._recipe_pool.size() == 5, "第 3 天全解锁时应点 5 个配方")
	_check(bar._bottle_buttons.size() == 17, "瓶架应显示 17 种原料")

	for button in bar._bottle_buttons:
		var rect: Rect2 = button.get_rect()
		_check(rect.position.x >= 0.0, "酒瓶不应越过左边界")
		_check(rect.end.x <= 640.0, "酒瓶不应越过右边界：%s" % button.label_text)
		_check(rect.end.y <= 94.0, "酒瓶不应越过瓶架底部：%s" % button.label_text)
		_check(button.label_text.length() <= 2, "酒瓶应使用短名：%s" % button.label_text)

	_check(bar._spill_label.get_parent() == bar, "洒酒提示应移出瓶架")
	_check(["简单", "进阶", "复杂"].has(bar._order_difficulty.text), "订单卡应显示难度")

	bar._current_recipe = GameData.get_recipe("gin_tonic")
	bar._session.reset_for(bar._current_recipe)
	bar._populate_order_card(bar._current_recipe)
	var gin_row: Label = bar._ingredient_rows["gin"]
	_check(gin_row.get_theme_color("font_color") == UITheme.COLORS["amber"], "空配料应显示橙色")
	bar._session.poured["gin"] = 45.0
	bar._update_recipe_progress()
	_check(gin_row.get_theme_color("font_color") == UITheme.COLORS["teal"], "准确用量应显示绿色")
	bar._session.poured["gin"] = 48.0
	bar._update_recipe_progress()
	_check(gin_row.get_theme_color("font_color") == UITheme.COLORS["danger"], "超量应显示红色")

	# 用量显示与颜色一致：达到目标显示绿色，偏少/偏多显示低于/高于目标
	bar._current_recipe = GameData.get_recipe("mojito")
	bar._session.reset_for(bar._current_recipe)
	bar._populate_order_card(bar._current_recipe)
	var mint_row: Label = bar._ingredient_rows["mint"]
	bar._session.poured["mint"] = 7.4
	bar._update_recipe_progress()
	_check(mint_row.text == "薄荷  7 / 8", "偏少应向下取整：%s" % mint_row.text)
	_check(mint_row.get_theme_color("font_color") == UITheme.COLORS["amber"], "偏少应显示橙色")
	bar._session.poured["mint"] = 7.6
	bar._update_recipe_progress()
	_check(mint_row.text == "薄荷  7 / 8", "未达标时不应取整显示为目标值：%s" % mint_row.text)
	_check(mint_row.get_theme_color("font_color") == UITheme.COLORS["amber"], "未达标应显示橙色")
	bar._session.poured["mint"] = 8.2
	bar._update_recipe_progress()
	_check(mint_row.text == "薄荷  8 / 8", "进入绿色区间后应显示 8 / 8：%s" % mint_row.text)
	_check(mint_row.get_theme_color("font_color") == UITheme.COLORS["teal"], "显示 8 / 8 时应为绿色")
	bar._session.poured["mint"] = 8.6
	bar._update_recipe_progress()
	_check(mint_row.text == "薄荷  9 / 8", "偏多应向上取整：%s" % mint_row.text)
	_check(mint_row.get_theme_color("font_color") == UITheme.COLORS["danger"], "偏多应显示红色")

	# 搅拌计量条只显示实际圈数并向下取整，不区分完成/过度状态
	bar._current_recipe = GameData.get_recipe("old_fashioned")
	bar._session.reset_for(bar._current_recipe)
	bar._session.glass_id = "rocks"
	bar._session.stir_turns = 3.95
	bar._update_meter()
	_check(bar._meter_label.text == "搅 3.9/4 圈 · 冰 0/1", "未达标圈数应向下取整：%s" % bar._meter_label.text)
	_check(bar._meter_label.get_theme_color("font_color") == UITheme.COLORS["dim"], "搅拌进度应使用次要色")
	bar._session.stir_turns = 3.96
	bar._update_meter()
	_check(bar._meter_label.text == "搅 3.9/4 圈 · 冰 0/1", "达标后仍应显示实际圈数：%s" % bar._meter_label.text)
	_check(bar._meter_label.get_theme_color("font_color") == UITheme.COLORS["dim"], "搅拌进度应使用次要色")
	bar._session.stir_turns = 4.9
	bar._update_meter()
	_check(bar._meter_label.text == "搅 4.9/4 圈 · 冰 0/1", "超过目标后仍应显示实际圈数：%s" % bar._meter_label.text)
	_check(bar._meter_label.get_theme_color("font_color") == UITheme.COLORS["dim"], "搅拌进度应使用次要色")

	var hurried_pool: Array = bar._recipe_ids_for_customer(GameData.get_customer("hurried"))
	var connoisseur_pool: Array = bar._recipe_ids_for_customer(GameData.get_customer("connoisseur"))
	var regular_pool: Array = bar._recipe_ids_for_customer(GameData.get_customer("regular"))
	_check(regular_pool.size() == 5, "常客点单池应覆盖当天全部配方")
	_check(not hurried_pool.is_empty() and not connoisseur_pool.is_empty(), "急客/品酒客点单池不应为空")
	for recipe_id in hurried_pool:
		_check(int(GameData.get_recipe(str(recipe_id)).get("difficulty", 0)) <= 1, "急客不应点复杂配方：%s" % recipe_id)
	for recipe_id in connoisseur_pool:
		_check(int(GameData.get_recipe(str(recipe_id)).get("difficulty", 0)) >= 2, "品酒客不应点简单配方：%s" % recipe_id)

	bar._spawn_customer("hurried")
	_check(str(bar._customer_type.get("id", "")) == "hurried", "应生成急客")
	_check(absf(bar._customer_patience - bar._base_patience * 0.75) < 0.01, "急客耐心应为基准的 75%")
	_check(bar._customer.variant == 1, "急客应使用第 2 个顾客外观")
	_check(bar._order_customer.text.contains("急客"), "订单卡应显示急客")
	_check(int(bar._current_recipe.get("difficulty", 0)) <= 1, "急客订单应为简单配方")
	await _capture("res://test/m3_bar.png")

	bar._spawn_customer("connoisseur")
	_check(str(bar._customer_type.get("id", "")) == "connoisseur", "应生成品酒客")
	_check(absf(bar._customer_patience - bar._base_patience * 1.35) < 0.01, "品酒客耐心应为基准的 135%")
	_check(bar._customer.variant == 2, "品酒客应使用第 3 个顾客外观")
	_check(int(bar._current_recipe.get("difficulty", 0)) >= 2, "品酒客订单应为进阶以上配方")
	print("[M3] bar: pool=%s hurried_pool=%s connoisseur_pool=%s" % [
		str(bar._recipe_pool), str(hurried_pool), str(connoisseur_pool)
	])


func _check_shop_content() -> void:
	_setup_state(3, 500, ["gin_tonic", "screwdriver", "mojito"])
	get_tree().change_scene_to_file("res://scenes/shop/shop.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout

	var shop := get_tree().current_scene
	_check(shop != null and shop.name == "Shop", "应进入商店")
	var grid: GridContainer = shop.get_node("%ShopGrid")
	_check(grid.columns == 2, "商店应为 2 列网格")
	_check(grid.get_child_count() == 8, "商店应显示 8 张配方卡")

	for card in grid.get_children():
		var has_difficulty := false
		for node in card.find_children("*", "Label", true, false):
			if (node as Label).text.begins_with("难度 ·"):
				has_difficulty = true
				break
		_check(has_difficulty, "每张商店卡片应显示难度")

	var scroll: ScrollContainer = shop.get_node("%ShopScroll")
	await get_tree().process_frame
	await get_tree().process_frame
	var scroll_bar := scroll.get_v_scroll_bar()
	_check(scroll_bar.max_value > scroll_bar.page, "8 张卡片应产生纵向滚动")

	var second_card := grid.get_child(1)
	var title := second_card.find_children("*", "Label", true, false)[0] as Label
	_check(title.text == "黑俄罗斯", "第二张卡应为黑俄罗斯")
	var buy_button := second_card.find_children("*", "Button", true, false)[0] as Button
	_check(buy_button.text == "解锁", "第 3 天黑俄罗斯应可解锁")
	buy_button.pressed.emit()
	await get_tree().process_frame

	_check(GameState.has_recipe("black_russian"), "购买后应解锁黑俄罗斯")
	_check(GameState.get_money() == 430, "购买黑俄罗斯应扣除 70 月亮石")
	var ingredients: Array = GameState.get_progress().get("unlocked_ingredients", [])
	_check(ingredients.has("coffee_liqueur"), "解锁黑俄罗斯应附带咖啡利口酒")
	print("[M3] shop: cards=%d scroll_max=%.0f money=%d" % [
		grid.get_child_count(), scroll_bar.max_value, GameState.get_money()
	])
	await _capture("res://test/m3_shop.png")


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
			"unlocked_ingredients": GameData.ingredients.keys(),
			"tutorial_done": true,
			"employee_hired": false,
		},
		"stats": {"total_earned": 0, "drinks_served": 0, "best_combo": 0},
	}


func _check(condition: bool, message: String) -> void:
	if condition:
		print("[M3] ok: %s" % message)
	else:
		_failures += 1
		push_error("[M3] FAILED: %s" % message)


func _capture(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	print("[M3] screenshot %s err=%d" % [path, error])
