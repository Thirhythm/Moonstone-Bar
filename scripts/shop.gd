extends Control

const MOONSTONE_TEXTURE := preload("res://assets/art/moonstone.png")

@onready var _shop_grid: GridContainer = %ShopGrid
@onready var _day_label: Label = %DayLabel
@onready var _money_label: Label = %MoneyLabel
@onready var _start_button: Button = %StartButton
@onready var _menu_button: Button = %MenuButton
@onready var _notice: Label = %Notice

var _notice_tween: Tween


func _ready() -> void:
	AudioDirector.set_bgm("shop")
	_start_button.pressed.connect(_on_start_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	_refresh()
	AudioDirector.play_sfx("whoosh", 1.05, -20.0, 0.0)


func _refresh() -> void:
	for child in _shop_grid.get_children():
		_shop_grid.remove_child(child)
		child.queue_free()

	if not GameState.has_active_game():
		_day_label.text = ""
		_money_label.text = "--"
		_start_button.text = "开始营业"
		_start_button.disabled = true
		return

	var day := GameState.get_day()
	_day_label.text = "第 %d 天 · 准备营业" % day
	_money_label.text = str(GameState.get_money())
	_start_button.text = "开始第 %d 天" % day
	_start_button.disabled = false

	for item in GameData.shop_items:
		_shop_grid.add_child(_build_card(item))
	UiAnim.stagger_in(_shop_grid, 0.03, 0.2)


func _build_card(item: Dictionary) -> PanelContainer:
	var recipe_id := str(item.get("recipe", ""))
	var recipe := GameData.get_recipe(recipe_id)
	var price := int(item.get("price", 0))
	var available_day := maxi(1, int(item.get("available_day", 1)))
	var unlocked := GameState.has_recipe(recipe_id)
	var available := GameState.get_day() >= available_day
	var affordable := GameState.get_money() >= price

	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	card.custom_minimum_size = Vector2(286, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	box.add_child(title_row)

	var title := _make_label(str(recipe.get("name", recipe_id)), "H1")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override(
		"font_color",
		UITheme.COLORS["teal"] if unlocked else UITheme.COLORS["text"]
	)
	title_row.add_child(title)

	var difficulty := int(recipe.get("difficulty", 1))
	var difficulty_label := _make_label(
		"难度 · %s" % GameData.difficulty_name(difficulty),
		"Hint"
	)
	difficulty_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	difficulty_label.add_theme_color_override("font_color", _difficulty_color(difficulty))
	title_row.add_child(difficulty_label)

	var english := _make_label(str(recipe.get("english", "")), "Hint")
	box.add_child(english)

	var ice_count := int(recipe.get("ice", 0))
	var ice_text := "冰 %d" % ice_count if ice_count > 0 else "不加冰"
	var detail := _make_label("%s · %s · %s" % [
		GameData.glass_name(str(recipe.get("glass", ""))),
		GameData.method_name(str(recipe.get("method", "build"))),
		ice_text,
	], "Body")
	box.add_child(detail)

	var ingredient_names: Array[String] = []
	for entry in recipe.get("ingredients", []):
		var ingredient_id := str(entry.get("id", ""))
		ingredient_names.append(str(GameData.get_ingredient(ingredient_id).get("name", ingredient_id)))
	var ingredient_label := _make_label("、".join(ingredient_names), "Hint")
	ingredient_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(ingredient_label)

	var garnish_names: Array[String] = []
	for garnish in recipe.get("garnish", []):
		garnish_names.append(GameData.garnish_name(str(garnish)))
	var garnish_label := _make_label(
		"装饰：%s" % ("、".join(garnish_names) if not garnish_names.is_empty() else "无"),
		"Hint"
	)
	box.add_child(garnish_label)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	box.add_child(bottom)

	if not unlocked:
		bottom.add_child(_build_price_row(price))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(spacer)

	var purchasable := not unlocked and available and affordable
	var button := _make_button("", "PrimaryButton" if purchasable else "GhostButton")
	button.custom_minimum_size = Vector2(78, 22)
	button.tooltip_text = "解锁%s（%d 月亮石）" % [str(recipe.get("name", recipe_id)), price]
	if unlocked:
		button.text = "已解锁"
		button.disabled = true
		button.add_theme_color_override("font_disabled_color", UITheme.COLORS["teal"])
	elif not available:
		button.text = "第 %d 天开放" % available_day
		button.disabled = true
	elif not affordable:
		button.text = "月亮石不足"
		button.disabled = true
	else:
		button.text = "解锁"
		button.pressed.connect(_on_buy_pressed.bind(item))
	bottom.add_child(button)

	return card


func _difficulty_color(difficulty: int) -> Color:
	if difficulty >= 3:
		return UITheme.COLORS["danger"]
	if difficulty == 2:
		return UITheme.COLORS["amber"]
	return UITheme.COLORS["teal"]


func _build_price_row(price: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)

	var icon := TextureRect.new()
	icon.texture = MOONSTONE_TEXTURE
	icon.custom_minimum_size = Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.tooltip_text = "月亮石"
	row.add_child(icon)

	var value := _make_label(str(price), "Money")
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	value.tooltip_text = "月亮石"
	row.add_child(value)
	return row


func _on_buy_pressed(item: Dictionary) -> void:
	var recipe_id := str(item.get("recipe", ""))
	var recipe := GameData.get_recipe(recipe_id)
	if GameState.unlock_recipe(recipe_id, int(item.get("price", 0))):
		GameState.autosave()
		AudioDirector.play_sfx("purchase", 1.0, -2.0, 0.0)
		_show_notice("已解锁%s" % str(recipe.get("name", recipe_id)))
		_refresh()
	else:
		AudioDirector.play_sfx("fail", 1.1, -6.0, 0.2)
		_show_notice("月亮石不足")


func _on_start_pressed() -> void:
	AudioDirector.play_sfx("ui_click", 1.0, -4.0, 0.0)
	SceneRouter.change_scene(SceneRouter.BAR)


func _on_menu_pressed() -> void:
	AudioDirector.play_sfx("ui_click", 0.9, -4.0, 0.0)
	GameState.end_game(true)
	SceneRouter.change_scene(SceneRouter.MAIN_MENU)


func _show_notice(text: String) -> void:
	_notice.text = text
	_notice.modulate.a = 1.0
	if _notice_tween != null and _notice_tween.is_valid():
		_notice_tween.kill()
	_notice_tween = create_tween()
	_notice_tween.tween_interval(1.6)
	_notice_tween.tween_property(_notice, "modulate:a", 0.0, 0.4)


func _make_label(text: String, variation: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = StringName(variation)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_button(text: String, variation: String) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = StringName(variation)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button
