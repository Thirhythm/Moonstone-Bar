extends Node

const INGREDIENTS_PATH := "res://data/ingredients.json"
const RECIPE_DIR := "res://data/recipes"
const DAY_DIR := "res://data/days"
const SHOP_PATH := "res://data/shop.json"
const CUSTOMER_PATH := "res://data/customers.json"
const FALLBACK_DAY := 1

const GLASS_NAMES := {
	"highball": "高球杯",
	"martini": "马天尼杯",
	"rocks": "古典杯",
}

const GLASS_SHORT_NAMES := {
	"highball": "高球",
	"martini": "马天尼",
	"rocks": "古典",
}

const DIFFICULTY_NAMES := {
	1: "简单",
	2: "进阶",
	3: "复杂",
}

const METHOD_NAMES := {
	"build": "直调",
	"shake": "摇壶",
	"stir": "搅拌",
}

const GARNISH_NAMES := {
	"lime": "青柠",
	"mint": "薄荷",
	"orange": "橙皮",
	"salt": "盐边",
}

var ingredients: Dictionary = {}
var recipes: Dictionary = {}
var days: Dictionary = {}
var shop_items: Array = []
var customers: Array = []


func _ready() -> void:
	_load_ingredients()
	_load_recipes()
	_load_days()
	_load_shop()
	_load_customers()


func get_ingredient(id: String) -> Dictionary:
	return ingredients.get(id, {})


func ingredient_short_name(id: String) -> String:
	var ingredient := get_ingredient(id)
	var short_name := str(ingredient.get("short", ""))
	return short_name if short_name != "" else str(ingredient.get("name", id))


func difficulty_name(difficulty: int) -> String:
	return str(DIFFICULTY_NAMES.get(clampi(difficulty, 1, 3), DIFFICULTY_NAMES[1]))


func get_customer(id: String) -> Dictionary:
	for customer in customers:
		if str(customer.get("id", "")) == id:
			return customer
	return {}


func customers_for_day(day: int) -> Array:
	var result: Array = []
	for customer in customers:
		if day >= int(customer.get("min_day", 1)):
			result.append(customer)
	return result


func get_recipe(id: String) -> Dictionary:
	return recipes.get(id, {})


func get_day_config(day: int) -> Dictionary:
	if days.has(day):
		return days[day].duplicate(true)
	var fallback: Dictionary = days.get(FALLBACK_DAY, {}).duplicate(true)
	fallback["day"] = day
	return fallback


func ingredient_ids_for(recipe_ids: Array) -> Array[String]:
	var result: Array[String] = []
	for recipe_id in recipe_ids:
		var recipe := get_recipe(str(recipe_id))
		for entry in recipe.get("ingredients", []):
			var ingredient_id := str(entry.get("id", ""))
			if ingredient_id != "" and not result.has(ingredient_id):
				result.append(ingredient_id)
	return result


func glass_name(glass_id: String) -> String:
	return str(GLASS_NAMES.get(glass_id, glass_id))


func glass_short_name(glass_id: String) -> String:
	return str(GLASS_SHORT_NAMES.get(glass_id, glass_name(glass_id)))


func method_name(method_id: String) -> String:
	return str(METHOD_NAMES.get(method_id, method_id))


func garnish_name(garnish_id: String) -> String:
	return str(GARNISH_NAMES.get(garnish_id, garnish_id))


func recipe_glass_capacity(glass_id: String) -> float:
	match glass_id:
		"martini":
			return 150.0
		"rocks":
			return 220.0
		_:
			return 260.0


func _load_ingredients() -> void:
	var parsed := _read_json(INGREDIENTS_PATH)
	ingredients = parsed


func _load_recipes() -> void:
	for file_name in _list_json(RECIPE_DIR):
		var parsed := _read_json(RECIPE_DIR.path_join(file_name))
		var id := str(parsed.get("id", ""))
		if id == "":
			push_warning("配方缺少 id：%s" % file_name)
			continue
		parsed["difficulty"] = clampi(int(parsed.get("difficulty", 1)), 1, 3)
		recipes[id] = parsed


func _load_days() -> void:
	for file_name in _list_json(DAY_DIR):
		var parsed := _read_json(DAY_DIR.path_join(file_name))
		var day := int(parsed.get("day", 0))
		if day <= 0:
			push_warning("每日配置缺少 day：%s" % file_name)
			continue
		days[day] = parsed


func _load_shop() -> void:
	shop_items.clear()
	var parsed := _read_json(SHOP_PATH)
	var items: Variant = parsed.get("items", [])
	if typeof(items) != TYPE_ARRAY:
		push_warning("商店配置格式无效：%s" % SHOP_PATH)
		return
	for raw in items:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = raw
		if not recipes.has(str(item.get("recipe", ""))):
			push_warning("商店条目引用了未知配方：%s" % raw)
			continue
		shop_items.append(item)


func _load_customers() -> void:
	customers.clear()
	var parsed := _read_json(CUSTOMER_PATH)
	var items: Variant = parsed.get("items", [])
	if typeof(items) != TYPE_ARRAY:
		push_warning("顾客配置格式无效：%s" % CUSTOMER_PATH)
		return
	for raw in items:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var customer: Dictionary = raw
		if str(customer.get("id", "")) == "":
			continue
		customer["patience_mult"] = maxf(0.1, float(customer.get("patience_mult", 1.0)))
		customer["weight"] = maxi(1, int(customer.get("weight", 1)))
		customer["min_day"] = maxi(1, int(customer.get("min_day", 1)))
		customer["variant"] = clampi(int(customer.get("variant", 0)), 0, 3)
		var pool := str(customer.get("recipe_pool", "any"))
		if not ["any", "simple", "complex"].has(pool):
			pool = "any"
		customer["recipe_pool"] = pool
		customers.append(customer)


func _list_json(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("无法打开数据目录：%s" % dir_path)
		return result
	for file_name in dir.get_files():
		if file_name.get_extension().to_lower() == "json":
			result.append(file_name)
	result.sort()
	return result


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("无法读取数据文件：%s" % path)
		return {}
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("数据文件格式无效：%s" % path)
		return {}
	return parsed
