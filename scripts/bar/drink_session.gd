class_name DrinkSession
extends RefCounted

var recipe: Dictionary = {}
var glass_id := ""
var poured: Dictionary = {}
var ice_count := 0
var garnish_added: Array[String] = []
var shake_energy := 0.0
var stir_turns := 0.0
var spill_ml := 0.0


func _init(recipe_data: Dictionary = {}) -> void:
	reset_for(recipe_data)


func reset_for(recipe_data: Dictionary) -> void:
	recipe = recipe_data
	glass_id = ""
	poured.clear()
	ice_count = 0
	garnish_added.clear()
	shake_energy = 0.0
	stir_turns = 0.0
	spill_ml = 0.0


func clear_liquid() -> void:
	poured.clear()
	ice_count = 0
	garnish_added.clear()
	shake_energy = 0.0
	stir_turns = 0.0
	spill_ml = 0.0


func get_capacity() -> float:
	if glass_id == "":
		return 0.0
	return GameData.recipe_glass_capacity(glass_id)


func total_volume() -> float:
	var total := 0.0
	for amount in poured.values():
		total += float(amount)
	return total


func get_poured(id: String) -> float:
	return float(poured.get(id, 0.0))


func add_liquid(id: String, amount: float) -> float:
	if glass_id == "" or amount <= 0.0:
		return 0.0
	var room := get_capacity() - total_volume()
	if room <= 0.0:
		spill_ml += amount
		return 0.0
	var actual := minf(amount, room)
	poured[id] = get_poured(id) + actual
	if amount > actual:
		spill_ml += amount - actual
	return actual


func add_ice(count: int = 1) -> void:
	ice_count = mini(ice_count + count, 5)


func add_shake(distance: float) -> void:
	shake_energy += distance / 90.0


func add_stir(angle_delta: float) -> void:
	stir_turns += angle_delta / TAU


func toggle_garnish(id: String) -> void:
	if garnish_added.has(id):
		garnish_added.erase(id)
	else:
		garnish_added.append(id)


func liquid_color() -> Color:
	var total := total_volume()
	if total <= 0.0:
		return Color.html("#D7E7EA")

	var mixed := _average_color(poured, total)
	if not recipe.has("target_color"):
		return mixed

	var target_amounts := {}
	var target_total := 0.0
	var completion := 1.0
	for entry in recipe.get("ingredients", []):
		var id := str(entry.get("id", ""))
		var amount := float(entry.get("amount", 0.0))
		if id == "" or amount <= 0.0:
			continue
		target_amounts[id] = amount
		target_total += amount
		completion = minf(completion, clampf(get_poured(id) / amount, 0.0, 1.0))
	if target_total <= 0.0:
		return mixed

	# 按正确用量混合时呈现目标色；缺料或用量不足时保留实际混色，随完成度收敛。
	var baseline := _average_color(target_amounts, target_total)
	var target := Color.html(str(recipe.get("target_color", "#FFFFFF")))
	return Color(
		clampf(mixed.r + (target.r - baseline.r) * completion, 0.0, 1.0),
		clampf(mixed.g + (target.g - baseline.g) * completion, 0.0, 1.0),
		clampf(mixed.b + (target.b - baseline.b) * completion, 0.0, 1.0),
		1.0
	)


func _average_color(amounts: Dictionary, total: float) -> Color:
	var mixed := Color(0, 0, 0, 0)
	for id in amounts:
		var ingredient := GameData.get_ingredient(str(id))
		var tint := Color.html(str(ingredient.get("color", "#DCEFE4")))
		mixed += tint * float(amounts[id])
	mixed /= total
	mixed.a = 1.0
	return mixed
