class_name DrinkScoring
extends RefCounted

const WEIGHT_RECIPE := 0.55
const WEIGHT_TECHNIQUE := 0.25
const WEIGHT_GARNISH := 0.10
const WEIGHT_SPEED := 0.10

const MISSING_INGREDIENT_PENALTY := 0.4
const EXTRA_INGREDIENT_PENALTY := 0.4
const MAX_EXTRA_PENALTY := 0.8
# 与配料表绿色阈值一致：达到该准确度视为无偏差，不扣配方分。
const AMOUNT_GOOD_ACCURACY := 0.9

# 摇/搅配方误用另一种器具时的对应系数，与直调酒误摇搅的惩罚保持一致。
const WRONG_METHOD_RATIO := 0.55
const SHAKE_GESTURE_THRESHOLD := 1.5
const STIR_GESTURE_THRESHOLD := 0.3
# 搅拌完成/过度阈值：计量条状态显示与评分共用，避免显示达标却提示不足。
const STIR_GOOD_RATIO := 0.99
const STIR_OVER_RATIO := 1.2


# 只按实际用量判定是否命中，不因显示取整放宽容差。
static func amount_is_good(poured: float, target: float) -> bool:
	return amount_accuracy(poured, target) >= AMOUNT_GOOD_ACCURACY


static func evaluate(session: DrinkSession, patience_ratio: float) -> Dictionary:
	var recipe := session.recipe
	var notes: Array[String] = []

	var recipe_score := _recipe_score(session, notes)
	var technique_score := _technique_score(session, notes)
	var garnish_score := _garnish_score(session, notes)
	var speed_score := clampf(patience_ratio, 0.0, 1.0)

	var total := (
		recipe_score * WEIGHT_RECIPE
		+ technique_score * WEIGHT_TECHNIQUE
		+ garnish_score * WEIGHT_GARNISH
		+ speed_score * WEIGHT_SPEED
	)
	total -= minf(0.3, session.spill_ml / 250.0)
	if speed_score < 0.35:
		total -= 0.08
		_add_note(notes, "上酒偏慢")
	total = clampf(total, 0.0, 1.0)

	var stars := 0
	if total >= 0.80:
		stars = 3
	elif total >= 0.52:
		stars = 2
	elif total >= 0.24:
		stars = 1

	var price := float(recipe.get("price", 20))
	var payout := int(round(price * (0.35 + 0.65 * total))) + stars * 3

	return {
		"total": total,
		"stars": stars,
		"income": payout,
		"recipe_score": recipe_score,
		"technique_score": technique_score,
		"garnish_score": garnish_score,
		"speed_score": speed_score,
		"notes": notes,
	}


static func _recipe_score(session: DrinkSession, notes: Array[String]) -> float:
	var expected_map := {}
	var expected_total := 0.0
	for entry in session.recipe.get("ingredients", []):
		var id := str(entry.get("id", ""))
		var amount := float(entry.get("amount", 0))
		expected_map[id] = amount
		expected_total += amount

	var score := 0.0
	var missing_penalty := 0.0
	if expected_total > 0.0:
		for id in expected_map:
			var target := float(expected_map[id])
			var poured := session.get_poured(str(id))
			var share := target / expected_total
			var good := amount_is_good(poured, target)
			var credit := 1.0 if good else amount_accuracy(poured, target)
			score += share * credit
			if poured < 0.5:
				missing_penalty += MISSING_INGREDIENT_PENALTY
				_add_note(notes, "缺少%s" % _ingredient_name(str(id)))
			elif not good:
				var direction := "偏多" if poured > target else "偏少"
				_add_note(notes, "%s%s" % [_ingredient_name(str(id)), direction])
	score -= missing_penalty

	var extra_penalty := 0.0
	for id in session.poured:
		if not expected_map.has(id) and session.get_poured(str(id)) > 0.5:
			extra_penalty += EXTRA_INGREDIENT_PENALTY
			_add_note(notes, "多加%s" % _ingredient_name(str(id)))
	score -= minf(MAX_EXTRA_PENALTY, extra_penalty)

	if session.glass_id != str(session.recipe.get("glass", "")):
		score *= 0.7
		_add_note(notes, "杯型不对")

	return clampf(score, 0.0, 1.0)


static func _technique_score(session: DrinkSession, notes: Array[String]) -> float:
	var method := str(session.recipe.get("method", "build"))
	var method_ratio := 1.0

	match method:
		"shake":
			var required_shake := maxf(1.0, float(session.recipe.get("shake_power", 8)))
			method_ratio = clampf(session.shake_energy / required_shake, 0.0, 1.0)
			if method_ratio < 0.99:
				_add_note(notes, "摇壶不足")
			if session.stir_turns > STIR_GESTURE_THRESHOLD:
				method_ratio *= WRONG_METHOD_RATIO
				_add_note(notes, "应摇壶而非搅拌")
		"stir":
			var required_stir := maxf(0.5, float(session.recipe.get("stir_turns", 4)))
			if session.stir_turns <= required_stir:
				method_ratio = clampf(session.stir_turns / required_stir, 0.0, 1.0)
				if method_ratio < STIR_GOOD_RATIO:
					_add_note(notes, "搅拌不足")
			else:
				method_ratio = clampf(2.0 - session.stir_turns / required_stir, 0.0, 1.0)
				if session.stir_turns > required_stir * STIR_OVER_RATIO:
					_add_note(notes, "搅拌过度")
			if session.shake_energy > SHAKE_GESTURE_THRESHOLD:
				method_ratio *= WRONG_METHOD_RATIO
				_add_note(notes, "应搅拌而非摇壶")
		_:
			if session.shake_energy > SHAKE_GESTURE_THRESHOLD or session.stir_turns > STIR_GESTURE_THRESHOLD:
				method_ratio = WRONG_METHOD_RATIO
				_add_note(notes, "直调酒无需摇搅")

	var required_ice := int(session.recipe.get("ice", 0))
	var ice_ratio := 1.0
	if required_ice <= 0:
		if session.ice_count > 0:
			ice_ratio = 0.7
			_add_note(notes, "这杯不需要冰")
	elif session.ice_count < required_ice:
		ice_ratio = float(session.ice_count) / float(required_ice)
		_add_note(notes, "冰量不足")
	else:
		var extra_ice := session.ice_count - required_ice
		ice_ratio = clampf(1.0 - float(extra_ice) * 0.4, 0.0, 1.0)
		if extra_ice > 0:
			_add_note(notes, "冰量超标")

	var spill_penalty := minf(1.0, session.spill_ml / 80.0)
	if session.spill_ml >= 8.0:
		_add_note(notes, "洒酒 %d ml" % int(round(session.spill_ml)))

	return clampf(method_ratio * 0.6 + ice_ratio * 0.4 - spill_penalty, 0.0, 1.0)


static func _garnish_score(session: DrinkSession, notes: Array[String]) -> float:
	var expected: Array = session.recipe.get("garnish", [])
	var correct := 0
	var wrong := 0
	for garnish in expected:
		if session.garnish_added.has(str(garnish)):
			correct += 1
	for garnish in session.garnish_added:
		if not expected.has(garnish):
			wrong += 1

	if expected.is_empty():
		return 1.0 if wrong == 0 else 0.6

	if correct < expected.size():
		_add_note(notes, "装饰缺失")
	if wrong > 0:
		_add_note(notes, "装饰不对")

	return clampf(float(correct) / float(expected.size()) - float(wrong) * 0.2, 0.0, 1.0)


static func amount_accuracy(poured: float, target: float) -> float:
	if poured < 0.5:
		return 0.0
	# 任意偏差都扣分：容忍区间只随目标量缩放，不设绝对下限。
	var diff := absf(poured - target)
	var max_tolerance := maxf(1.0, target * 0.45)
	return clampf(1.0 - diff / max_tolerance, 0.0, 1.0)


static func _ingredient_name(id: String) -> String:
	var ingredient := GameData.get_ingredient(id)
	return str(ingredient.get("name", id))


static func _add_note(notes: Array[String], text: String) -> void:
	if not notes.has(text):
		notes.append(text)
