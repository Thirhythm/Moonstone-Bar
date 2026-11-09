extends Control

const CONFIRM_DIALOG_SCENE := preload("res://scenes/ui/confirm_dialog.tscn")
const MOONSTONE_TEXTURE := preload("res://assets/art/moonstone.png")
const SPECIAL_CUSTOMER_TEXTURE := preload("res://assets/art/special_customer.png")

const HUD_HEIGHT := 30.0
const SHELF_TOP := 306.0
const CUP_HOME := Vector2(280, 144)
const CUP_SIZE := Vector2(96, 132)
const CUSTOMER_HOME := Vector2(486, 36)
const CUSTOMER_SIZE := Vector2(64, 100)
const SPECIAL_CUSTOMER_HOME := Vector2(470, 34)
const SPECIAL_CUSTOMER_SIZE := Vector2(128, 180)
const POUR_JITTER_DISTANCE := 14.0
const SHAKE_SPLASH_DISTANCE := 48.0
# 搅拌允许在杯内画小圈：阈值只用于过滤杯心静止抖动，过大会让小圈搅拌完全没有反馈。
const STIR_MIN_RADIUS := 6.0
const STIR_MAX_RADIUS := 130.0

var _day_label: Label
var _timer_label: Label
var _goal_label: Label
var _money_label: Label
var _menu_button: Button

var _order_panel: PanelContainer
var _order_name: Label
var _order_difficulty: Label
var _order_english: Label
var _order_customer: Label
var _order_detail: Label
var _order_garnish: Label
var _order_ingredients: VBoxContainer
var _order_color: ColorRect
var _ingredient_rows: Dictionary = {}

var _customer: CustomerArt
var _cup: DrinkVisual
var _meter_label: Label
var _spill_label: Label
var _toast: Label
var _overlay: DragOverlay
var _shelf: Control
var _glass_buttons: Dictionary = {}
var _bottle_buttons: Array[ToolButton] = []
var _pause_dialog: ConfirmDialog

var _feedback_layer: Control
var _feedback_panel: PanelContainer
var _feedback_title: Label
var _feedback_stars: StarRating
var _feedback_income: Label
var _feedback_notes: Label

var _result_layer: Control
var _result_panel: PanelContainer
var _result_title: Label
var _result_stats: Label
var _result_primary: Button
var _result_secondary: Button
var _result_primary_action := ""

var _help_button: Button
var _tutorial: TutorialOverlay
var _tutorial_active := false
var _damage_flash: ColorRect
var _tool_buttons: Dictionary = {}
var _garnish_buttons: Dictionary = {}
var _last_money_shown := -1
var _last_spill_notice_msec := 0

var _day_config: Dictionary = {}
var _day_number := 1
var _duration := 180.0
var _time_left := 180.0
var _goal := 100
var _base_patience := 55.0
var _customer_patience := 55.0
var _patience_left := 55.0
var _day_start_money := 0
var _day_earned := 0
var _day_served := 0
var _day_stars := 0
var _combo := 0
var _best_combo := 0
var _customers_done := 0
var _is_final_day := false
var _required_cups := 0
var _allowed_mistakes := 0
var _day_major_mistakes := 0

var _recipe_pool: Array[String] = []
var _available_ingredients: Array[String] = []
var _current_recipe: Dictionary = {}
var _session := DrinkSession.new()
var _last_recipe_id := ""
var _customer_type: Dictionary = {}
var _last_customer_id := ""

var _customer_active := false
var _epilogue_active := false
var _day_running := false
var _awaiting_feedback := false
var _result_open := false
var _paused := false

var _drag_tool: ToolButton
var _drag_kind := ""
var _drag_id := ""
var _pointer_position := Vector2.ZERO
var _pour_hold := 0.0
var _stir_last_angle := NAN
var _cup_dragging := false
var _cup_drag_offset := Vector2.ZERO
var _toast_tween: Tween
var _cup_tween: Tween


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_ui()
	queue_redraw()
	AudioDirector.set_bgm("game")

	if not GameState.has_active_game():
		_show_blocked()
		return

	_start_day()


func _exit_tree() -> void:
	AudioDirector.stop_all_loops()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# 窗口失焦时可能收不到鼠标松开事件，主动收尾避免回来后继续倒酒/拖杯。
		_cancel_drag()
		_cancel_cup_drag()


func _process(delta: float) -> void:
	if (_day_running or _epilogue_active) and not _paused and not _result_open:
		if _day_running and not _awaiting_feedback and not _tutorial_active:
			_time_left = maxf(0.0, _time_left - delta)
			if _time_left <= 0.0:
				_end_day()
				return

		if _day_running and _customer_active and not _awaiting_feedback and not _tutorial_active:
			_patience_left -= delta
			_customer.set_patience(_patience_left / maxf(1.0, _customer_patience))
			if _patience_left <= 0.0:
				_on_customer_gave_up()

		if _drag_tool != null:
			_update_drag(delta)

		_update_hud()
		_update_meter()

	if _cup_dragging:
		_cup.position = _pointer_position - _cup_drag_offset
		var over_customer := _customer_active and _customer.get_global_rect().grow(8.0).has_point(_pointer_position)
		Input.set_default_cursor_shape(Input.CURSOR_CAN_DROP if over_customer else Input.CURSOR_DRAG)
		_cup.mouse_default_cursor_shape = Control.CURSOR_CAN_DROP if over_customer else Control.CURSOR_DRAG


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_pointer_position = motion.position
		if _drag_tool != null and not _paused and not _result_open:
			_handle_drag_motion(motion)
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		_pointer_position = mouse_event.position
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			if not _can_interact():
				_cancel_drag()
				_cancel_cup_drag()
				return
			if _drag_tool != null:
				_finish_tool_drag()
			if _cup_dragging:
				_finish_cup_drag()


func _build_ui() -> void:
	_build_counter()
	_build_hud()
	_build_order_panel()
	_build_customer()
	_build_cup()
	_build_shelf()
	_build_toast()
	_build_feedback_layer()
	_build_result_layer()
	_build_pause_dialog()

	_overlay = DragOverlay.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.z_index = 50
	add_child(_overlay)

	_build_damage_flash()
	_build_tutorial()


func _build_damage_flash() -> void:
	_damage_flash = ColorRect.new()
	_damage_flash.color = Color(0.90, 0.28, 0.30, 0.0)
	_damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_flash.z_index = 26
	add_child(_damage_flash)


func _build_tutorial() -> void:
	_tutorial = TutorialOverlay.new()
	_tutorial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tutorial.finished.connect(_on_tutorial_finished)
	add_child(_tutorial)


func _build_counter() -> void:
	var counter := Control.new()
	counter.position = Vector2(196, 264)
	counter.size = Vector2(288, 40)
	counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(counter)

	var surface := ColorRect.new()
	surface.color = Color.html("#3A2A22")
	surface.size = Vector2(288, 12)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter.add_child(surface)

	var top_line := ColorRect.new()
	top_line.color = Color.html("#F0B95E")
	top_line.size = Vector2(288, 1)
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter.add_child(top_line)

	var front := ColorRect.new()
	front.color = Color.html("#211815")
	front.position = Vector2(0, 12)
	front.size = Vector2(288, 26)
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter.add_child(front)

	var front_line := ColorRect.new()
	front_line.color = Color(0.35, 0.46, 0.62, 0.35)
	front_line.position = Vector2(0, 12)
	front_line.size = Vector2(288, 1)
	front_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter.add_child(front_line)

	var shadow := ColorRect.new()
	shadow.color = Color(0, 0, 0, 0.35)
	shadow.position = Vector2(0, 38)
	shadow.size = Vector2(288, 2)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter.add_child(shadow)

	for x in [8, 278]:
		var rivet := ColorRect.new()
		rivet.color = Color.html("#6A5038")
		rivet.position = Vector2(x, 18)
		rivet.size = Vector2(2, 2)
		rivet.mouse_filter = Control.MOUSE_FILTER_IGNORE
		counter.add_child(rivet)


func _build_hud() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2.ZERO
	panel.size = Vector2(640, HUD_HEIGHT)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 2)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(row)

	_day_label = _make_label("第 1 天", "Body")
	row.add_child(_day_label)

	_timer_label = _make_label("03:00", "Money")
	_timer_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_timer_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	_goal_label = _make_label("目标 0 / 100", "Body")
	_goal_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_goal_label)

	var money_icon := TextureRect.new()
	money_icon.texture = MOONSTONE_TEXTURE
	money_icon.custom_minimum_size = Vector2(16, 16)
	money_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	money_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	money_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	money_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	money_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	money_icon.tooltip_text = "月亮石"
	row.add_child(money_icon)

	_money_label = _make_label("0", "Money")
	_money_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_money_label.tooltip_text = "月亮石"
	row.add_child(_money_label)

	_help_button = _make_button("?", "GhostButton")
	_help_button.custom_minimum_size = Vector2(20, 20)
	_help_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_help_button.tooltip_text = "新手引导"
	_help_button.pressed.connect(_on_help_pressed)
	row.add_child(_help_button)

	_menu_button = _make_button("菜单", "GhostButton")
	_menu_button.custom_minimum_size = Vector2(48, 20)
	_menu_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_menu_button.pressed.connect(_on_menu_pressed)
	row.add_child(_menu_button)


func _build_order_panel() -> void:
	_order_panel = PanelContainer.new()
	_order_panel.theme_type_variation = &"CardPanel"
	_order_panel.position = Vector2(12, 36)
	_order_panel.size = Vector2(180, 228)
	_order_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_order_panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	_order_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)

	# 英文名与“点单”同排，给 5 原料配方单留出高度，避免压到下方瓶架。
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 6)
	header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(header_row)
	
	var hint := _make_label("点单", "Hint")
	header_row.add_child(hint)
	
	_order_english = _make_label("", "Hint")
	_order_english.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_order_english.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_order_english.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_row.add_child(_order_english)
	
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_row)

	_order_name = _make_label("等待点单", "H1")
	_order_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_order_name)

	_order_difficulty = _make_label("", "Hint")
	_order_difficulty.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(_order_difficulty)

	_order_customer = _make_label("", "Hint")
	box.add_child(_order_customer)

	var line := ColorRect.new()
	line.color = Color.html("#3A4A66")
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(line)

	_order_detail = _make_label("", "Body")
	_order_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_order_detail)

	_order_garnish = _make_label("", "Body")
	box.add_child(_order_garnish)

	_order_ingredients = VBoxContainer.new()
	_order_ingredients.add_theme_constant_override("separation", 1)
	_order_ingredients.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_order_ingredients)

	var color_row := HBoxContainer.new()
	color_row.add_theme_constant_override("separation", 6)
	color_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(color_row)

	var color_label := _make_label("目标色", "Hint")
	color_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	color_row.add_child(color_label)

	_order_color = ColorRect.new()
	_order_color.custom_minimum_size = Vector2(40, 10)
	_order_color.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_order_color.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_row.add_child(_order_color)


func _build_customer() -> void:
	_customer = CustomerArt.new()
	_customer.position = CUSTOMER_HOME
	_customer.size = CUSTOMER_SIZE
	add_child(_customer)


func _build_cup() -> void:
	_cup = DrinkVisual.new()
	_cup.position = CUP_HOME
	_cup.size = CUP_SIZE
	_cup.drag_requested.connect(_on_cup_pressed)
	add_child(_cup)

	var meter_panel := PanelContainer.new()
	meter_panel.theme_type_variation = &"CardPanel"
	meter_panel.position = Vector2(232, 278)
	meter_panel.size = Vector2(210, 20)
	meter_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(meter_panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 0)
	meter_panel.add_child(margin)

	_meter_label = _make_label("", "Hint")
	_meter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	margin.add_child(_meter_label)


func _build_shelf() -> void:
	_shelf = Control.new()
	_shelf.position = Vector2(0, SHELF_TOP)
	_shelf.size = Vector2(640, 94)
	_shelf.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_shelf)

	var background := ColorRect.new()
	background.color = Color.html("#0A0F1C")
	background.size = Vector2(640, 94)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shelf.add_child(background)

	var top_line := ColorRect.new()
	top_line.color = Color.html("#3A4A66")
	top_line.size = Vector2(640, 1)
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shelf.add_child(top_line)

	var glass_defs := [["highball", "高球"], ["martini", "马天尼"], ["rocks", "古典"]]
	for i in range(glass_defs.size()):
		var glass_id: String = glass_defs[i][0]
		var button := ToolButton.new()
		button.configure("glass", glass_id, glass_defs[i][1], PixelFactory.glass_icon(glass_id))
		button.position = Vector2(8 + i * 46, 4)
		button.size = Vector2(44, 44)
		button.tooltip_text = GameData.glass_name(glass_id)
		button.press_started.connect(_on_tool_pressed)
		_shelf.add_child(button)
		_glass_buttons[glass_id] = button

	var dump_button := _make_button("倒掉", "GhostButton")
	dump_button.position = Vector2(150, 12)
	dump_button.size = Vector2(56, 24)
	dump_button.pressed.connect(_on_dump_pressed)
	_shelf.add_child(dump_button)

	var tool_defs := [
		["ice", "冰块", PixelFactory.ice_bucket(), "拖冰块入杯"],
		["shaker", "摇壶", PixelFactory.shaker(), "拖到杯上快速晃动"],
		["stirrer", "搅拌棒", PixelFactory.stirrer(), "拖到杯上绕圈"],
	]
	for i in range(tool_defs.size()):
		var entry: Array = tool_defs[i]
		var button := ToolButton.new()
		button.configure(str(entry[0]), str(entry[0]), str(entry[1]), entry[2])
		button.position = Vector2(214 + i * 48, 4)
		button.size = Vector2(44, 44)
		button.tooltip_text = str(entry[3])
		button.press_started.connect(_on_tool_pressed)
		_shelf.add_child(button)
		_tool_buttons[str(entry[0])] = button

	var garnish_defs := ["lime", "mint", "orange", "salt"]
	for i in range(garnish_defs.size()):
		var garnish_id: String = garnish_defs[i]
		var button := ToolButton.new()
		button.configure("garnish", garnish_id, GameData.garnish_name(garnish_id), PixelFactory.garnish_icon(garnish_id))
		button.position = Vector2(362 + i * 46, 4)
		button.size = Vector2(44, 44)
		button.tooltip_text = GameData.garnish_name(garnish_id)
		button.press_started.connect(_on_tool_pressed)
		_shelf.add_child(button)
		_garnish_buttons[garnish_id] = button

	_spill_label = _make_label("", "Hint")
	_spill_label.position = Vector2(540, 284)
	_spill_label.size = Vector2(92, 16)
	_spill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_spill_label)


func _build_toast() -> void:
	_toast = _make_label("", "Toast")
	_toast.position = Vector2(220, 32)
	_toast.size = Vector2(200, 16)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.z_index = 60
	_toast.visible = false
	add_child(_toast)


func _build_feedback_layer() -> void:
	_feedback_layer = Control.new()
	_feedback_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_feedback_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_feedback_layer.z_index = 30
	_feedback_layer.visible = false
	add_child(_feedback_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.015, 0.03, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.theme_type_variation = &"ModalPanel"
	panel.custom_minimum_size = Vector2(300, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)
	_feedback_panel = panel

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)

	_feedback_title = _make_label("", "H1")
	_feedback_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_feedback_title)

	_feedback_stars = StarRating.new()
	_feedback_stars.custom_minimum_size = Vector2(66, 18)
	_feedback_stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_feedback_stars)

	_feedback_income = _make_label("", "Money")
	_feedback_income.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_feedback_income)

	_feedback_notes = _make_label("", "Body")
	_feedback_notes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback_notes.custom_minimum_size = Vector2(260, 0)
	box.add_child(_feedback_notes)


func _build_result_layer() -> void:
	_result_layer = Control.new()
	_result_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_result_layer.z_index = 40
	_result_layer.visible = false
	add_child(_result_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.015, 0.03, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.theme_type_variation = &"ModalPanel"
	panel.custom_minimum_size = Vector2(360, 0)
	center.add_child(panel)
	_result_panel = panel

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	_result_title = _make_label("", "H1")
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result_title)

	var line := ColorRect.new()
	line.color = Color.html("#3A4A66")
	line.custom_minimum_size = Vector2(0, 1)
	box.add_child(line)

	_result_stats = _make_label("", "Body")
	_result_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_stats.custom_minimum_size = Vector2(320, 0)
	box.add_child(_result_stats)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)

	_result_primary = _make_button("下一天", "PrimaryButton")
	_result_primary.custom_minimum_size = Vector2(112, 28)
	_result_primary.pressed.connect(_on_result_primary_pressed)
	buttons.add_child(_result_primary)

	_result_secondary = _make_button("返回主菜单", "GhostButton")
	_result_secondary.custom_minimum_size = Vector2(128, 28)
	_result_secondary.pressed.connect(_on_result_secondary_pressed)
	buttons.add_child(_result_secondary)


func _build_pause_dialog() -> void:
	_pause_dialog = CONFIRM_DIALOG_SCENE.instantiate() as ConfirmDialog
	add_child(_pause_dialog)
	_pause_dialog.confirmed.connect(_on_pause_confirmed)
	_pause_dialog.cancelled.connect(_on_pause_cancelled)


func _start_day() -> void:
	_day_config = GameData.get_day_config(GameState.get_day())
	_day_number = int(_day_config.get("day", GameState.get_day()))
	_duration = maxf(30.0, float(_day_config.get("duration", 180)))
	_time_left = _duration
	_goal = maxi(1, int(_day_config.get("goal", 100)))
	_base_patience = maxf(20.0, float(_day_config.get("patience", 55)))
	_customer_patience = _base_patience
	_is_final_day = bool(_day_config.get("final", false))
	_required_cups = maxi(1, int(_day_config.get("required_cups", 6)))
	_allowed_mistakes = maxi(0, int(_day_config.get("max_major_mistakes", 1)))
	_day_start_money = GameState.begin_day()
	_day_earned = 0
	_day_served = 0
	_day_stars = 0
	_combo = 0
	_best_combo = 0
	_customers_done = 0
	_day_major_mistakes = 0
	_last_recipe_id = ""
	_customer_type = {}
	_last_customer_id = ""
	_day_running = true
	_awaiting_feedback = false
	_result_open = false
	_epilogue_active = false
	_paused = false
	_tutorial_active = false
	_last_money_shown = -1
	_last_spill_notice_msec = 0
	AudioDirector.stop_all_loops()
	if _tutorial != null:
		_tutorial.stop()

	_build_recipe_pool()
	_build_available_ingredients()
	_build_bottle_tools()
	_update_hud()
	_spawn_customer()
	_maybe_start_tutorial()


func _build_recipe_pool() -> void:
	var pool: Array[String] = []
	var configured: Array = _day_config.get("recipe_pool", [])
	for recipe_id in configured:
		var id := str(recipe_id)
		if GameData.recipes.has(id):
			pool.append(id)

	var unlocked := GameState.get_unlocked_recipes()
	if not unlocked.is_empty():
		var filtered: Array[String] = []
		for id in pool:
			if unlocked.has(id):
				filtered.append(id)
		if not filtered.is_empty():
			pool = filtered

	if pool.is_empty():
		for id in GameData.recipes.keys():
			pool.append(str(id))
	_recipe_pool = pool


func _build_available_ingredients() -> void:
	var recipe_ids: Array = GameState.get_unlocked_recipes()
	if recipe_ids.is_empty():
		recipe_ids = _recipe_pool.duplicate()
	_available_ingredients = GameData.ingredient_ids_for(recipe_ids)


func _build_bottle_tools() -> void:
	for button in _bottle_buttons:
		button.queue_free()
	_bottle_buttons.clear()

	var count := _available_ingredients.size()
	if count == 0:
		return

	var gap := 3
	var side_margin := 8.0
	var width := mini(44, floori((640.0 - side_margin * 2.0 - gap * float(count - 1)) / float(count)))
	width = maxi(30, width)
	var total_width := count * width + (count - 1) * gap
	var start_x := int(floorf((640.0 - float(total_width)) * 0.5))
	for i in range(count):
		var ingredient_id: String = _available_ingredients[i]
		var ingredient := GameData.get_ingredient(ingredient_id)
		var button := ToolButton.new()
		button.configure("bottle", ingredient_id, GameData.ingredient_short_name(ingredient_id), PixelFactory.bottle(ingredient))
		button.position = Vector2(start_x + i * (width + gap), 50)
		button.size = Vector2(width, 42)
		button.tooltip_text = str(ingredient.get("name", ingredient_id))
		button.press_started.connect(_on_tool_pressed)
		_shelf.add_child(button)
		_bottle_buttons.append(button)


func _spawn_customer(customer_id: String = "") -> void:
	if _result_open or (not _day_running and not _epilogue_active):
		return
	if _recipe_pool.is_empty():
		_end_day()
		return

	_stop_tool_loops()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if _cup != null:
		_cup.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_last_spill_notice_msec = 0
	_customer.position = CUSTOMER_HOME
	_customer.size = CUSTOMER_SIZE
	_customer.set_patience_bar_visible(true)

	var customer := _pick_customer(customer_id)
	_apply_customer(customer)

	var recipe_id := _pick_recipe(customer)
	_current_recipe = GameData.get_recipe(recipe_id)
	_last_recipe_id = recipe_id
	_session.reset_for(_current_recipe)
	_cup.position = CUP_HOME
	_cup.z_index = 0
	_cup.update_from(_session)
	_clear_glass_selection()
	_populate_order_card(_current_recipe)

	_customer_active = true
	_update_hud()
	_update_meter()


func _pick_customer(forced_id: String = "") -> Dictionary:
	if forced_id != "":
		var forced := GameData.get_customer(forced_id)
		if not forced.is_empty():
			return forced

	var pool := GameData.customers_for_day(_day_number)
	if pool.is_empty():
		return {}

	var candidates: Array = []
	for customer in pool:
		if pool.size() > 1 and str(customer.get("id", "")) == _last_customer_id:
			continue
		candidates.append(customer)
	if candidates.is_empty():
		candidates = pool

	var total := 0
	for customer in candidates:
		total += maxi(1, int(customer.get("weight", 1)))
	var roll := randi() % total
	for customer in candidates:
		roll -= maxi(1, int(customer.get("weight", 1)))
		if roll < 0:
			return customer
	return candidates[candidates.size() - 1]


func _apply_customer(customer: Dictionary) -> void:
	_customer_type = customer
	_last_customer_id = str(customer.get("id", ""))
	var multiplier := maxf(0.1, float(customer.get("patience_mult", 1.0)))
	_customer_patience = maxf(5.0, _base_patience * multiplier)
	_patience_left = _customer_patience
	_customer.set_variant(int(customer.get("variant", 0)))
	_customer.set_patience(1.0)

	var type_name := str(customer.get("name", ""))
	if type_name == "":
		_order_customer.text = ""
	else:
		_order_customer.text = "%s · 耐心%s" % [type_name, _patience_hint(multiplier)]
	_order_customer.add_theme_color_override(
		"font_color",
		Color.html(str(customer.get("color", "#9AA7C0")))
	)


func _patience_hint(multiplier: float) -> String:
	if multiplier <= 0.8:
		return "短"
	if multiplier >= 1.25:
		return "长"
	return "一般"


func _maybe_start_tutorial() -> void:
	if _tutorial == null or not _day_running or not _customer_active:
		return
	if GameState.is_tutorial_done():
		return
	if _day_number != 1 or _customers_done > 0:
		return
	_start_tutorial()


func _start_tutorial() -> void:
	if _tutorial == null or not _customer_active:
		return
	var steps := _build_tutorial_steps()
	if steps.is_empty():
		return
	_tutorial_active = true
	_cancel_drag()
	_overlay.clear_all()
	_tutorial.start(steps)
	_update_meter()


func _build_tutorial_steps() -> Array[Dictionary]:
	var steps: Array[Dictionary] = []

	var glass_rects: Array[Rect2] = []
	for id in _glass_buttons:
		glass_rects.append((_glass_buttons[id] as ToolButton).get_global_rect())
	steps.append({
		"id": "glass",
		"title": "选杯",
		"text": "点击底部杯型，选「%s」。" % GameData.glass_name(str(_current_recipe.get("glass", ""))),
		"rects": glass_rects,
	})

	var bottle_rects: Array[Rect2] = []
	for button in _bottle_buttons:
		bottle_rects.append(button.get_global_rect())
	bottle_rects.append(_cup.get_global_rect())
	steps.append({
		"id": "pour",
		"title": "倒酒",
		"text": "按住酒瓶拖到杯口，按住越久倒得越多。",
		"rects": bottle_rects,
	})

	if int(_current_recipe.get("ice", 0)) > 0 and _tool_buttons.has("ice"):
		steps.append({
			"id": "ice",
			"title": "加冰",
			"text": "把冰块拖进杯子里。",
			"rects": [(_tool_buttons["ice"] as ToolButton).get_global_rect(), _cup.get_global_rect()],
		})

	var method := str(_current_recipe.get("method", "build"))
	if method == "shake" and _tool_buttons.has("shaker"):
		steps.append({
			"id": "method",
			"title": "摇壶",
			"text": "把摇壶拖到杯上，快速晃动鼠标。",
			"rects": [(_tool_buttons["shaker"] as ToolButton).get_global_rect(), _cup.get_global_rect()],
		})
	elif method == "stir" and _tool_buttons.has("stirrer"):
		steps.append({
			"id": "method",
			"title": "搅拌",
			"text": "把搅拌棒拖到杯上，绕杯口画圈。",
			"rects": [(_tool_buttons["stirrer"] as ToolButton).get_global_rect(), _cup.get_global_rect()],
		})

	var garnish_rects: Array[Rect2] = []
	var garnish_names: Array[String] = []
	for garnish in _current_recipe.get("garnish", []):
		var garnish_id := str(garnish)
		if _garnish_buttons.has(garnish_id):
			garnish_rects.append((_garnish_buttons[garnish_id] as ToolButton).get_global_rect())
			garnish_names.append(GameData.garnish_name(garnish_id))
	if not garnish_rects.is_empty():
		steps.append({
			"id": "garnish",
			"title": "装饰",
			"text": "点击「%s」加入装饰。" % "、".join(garnish_names),
			"rects": garnish_rects,
		})

	steps.append({
		"id": "serve",
		"title": "上酒",
		"text": "把杯子拖到右侧顾客面前上酒。",
		"rects": [_cup.get_global_rect(), _customer.get_global_rect()],
	})
	for i in range(steps.size()):
		steps[i]["title"] = "%d · %s" % [i + 1, str(steps[i].get("title", ""))]
	return steps


func _notify_tutorial(step_id: String) -> void:
	if not _tutorial_active or _tutorial == null:
		return
	if _tutorial.current_step_id() == step_id:
		_tutorial.complete_current()


func _finish_tutorial_on_serve() -> void:
	if not _tutorial_active or _tutorial == null:
		return
	if _tutorial.current_step_id() == "serve":
		_tutorial.complete_current()
	else:
		_tutorial.skip()


func _on_tutorial_finished(skipped: bool) -> void:
	_tutorial_active = false
	GameState.mark_tutorial_done()
	if _customers_done == 0 and _day_earned == 0:
		GameState.autosave()
	if _day_running:
		_show_toast("已跳过引导" if skipped else "引导完成")


func _on_help_pressed() -> void:
	AudioDirector.play_sfx("ui_click", 1.0, -3.0, 0.0)
	if _tutorial_active:
		_tutorial.skip()
		return
	if not _can_interact():
		_show_toast("营业中才能查看引导")
		return
	_start_tutorial()


func _expected_volume() -> float:
	var total := 0.0
	for entry in _current_recipe.get("ingredients", []):
		total += float(entry.get("amount", 0))
	return total


func _difficulty_color(difficulty: int) -> Color:
	if difficulty >= 3:
		return UITheme.COLORS["danger"]
	if difficulty == 2:
		return UITheme.COLORS["amber"]
	return UITheme.COLORS["teal"]


func _pick_recipe(customer: Dictionary = {}) -> String:
	var candidates := _recipe_ids_for_customer(customer)
	if candidates.is_empty():
		candidates = _recipe_pool.duplicate()
	var filtered: Array[String] = []
	for id in candidates:
		if candidates.size() > 1 and id == _last_recipe_id:
			continue
		filtered.append(id)
	if filtered.is_empty():
		filtered = candidates
	return filtered[randi() % filtered.size()]


func _recipe_ids_for_customer(customer: Dictionary) -> Array[String]:
	var mode := str(customer.get("recipe_pool", "any"))
	var result: Array[String] = []
	for id in _recipe_pool:
		var difficulty := int(GameData.get_recipe(id).get("difficulty", 1))
		if mode == "simple" and difficulty > 1:
			continue
		if mode == "complex" and difficulty < 2:
			continue
		result.append(id)
	return result


func _populate_order_card(recipe: Dictionary) -> void:
	_order_name.text = str(recipe.get("name", ""))
	_order_english.text = str(recipe.get("english", ""))
	var ice_count := int(recipe.get("ice", 0))
	var ice_text := "冰%d" % ice_count if ice_count > 0 else "不加冰"
	_order_detail.text = "%s · %s · %s" % [
		GameData.glass_short_name(str(recipe.get("glass", ""))),
		GameData.method_name(str(recipe.get("method", "build"))),
		ice_text,
	]

	var difficulty := int(recipe.get("difficulty", 1))
	_order_difficulty.text = GameData.difficulty_name(difficulty)
	_order_difficulty.add_theme_color_override("font_color", _difficulty_color(difficulty))

	var garnish_names: Array[String] = []
	for garnish in recipe.get("garnish", []):
		garnish_names.append(GameData.garnish_name(str(garnish)))
	_order_garnish.text = "装饰：%s" % ("、".join(garnish_names) if not garnish_names.is_empty() else "无")
	_order_color.color = Color.html(str(recipe.get("target_color", "#FFFFFF")))

	for child in _order_ingredients.get_children():
		_order_ingredients.remove_child(child)
		child.queue_free()
	_ingredient_rows.clear()

	for entry in recipe.get("ingredients", []):
		var ingredient_id := str(entry.get("id", ""))
		var ingredient := GameData.get_ingredient(ingredient_id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(8, 8)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch.color = Color.html(str(ingredient.get("color", "#DCEFE4")))
		row.add_child(swatch)

		var label := _make_label("", "Body")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		_order_ingredients.add_child(row)
		_ingredient_rows[ingredient_id] = label

	_update_recipe_progress()


func _update_recipe_progress() -> void:
	for entry in _current_recipe.get("ingredients", []):
		var ingredient_id := str(entry.get("id", ""))
		var label: Label = _ingredient_rows.get(ingredient_id)
		if label == null:
			continue
		var target := float(entry.get("amount", 0))
		var current := _session.get_poured(ingredient_id)
		var ingredient := GameData.get_ingredient(ingredient_id)

		# 显示值与颜色/结算共用同一判定：达标时显示目标量，
		# 偏少向下取整、偏多向上取整，确保“显示目标值”一定为绿色。
		var good := DrinkScoring.amount_is_good(current, target)
		var shown: int
		var color: Color
		if good:
			shown = int(round(target))
			color = UITheme.COLORS["teal"]
		elif current > target:
			shown = int(ceil(current))
			color = UITheme.COLORS["danger"]
		else:
			shown = int(floor(current))
			color = UITheme.COLORS["amber"]
		label.text = "%s  %d / %d" % [str(ingredient.get("name", ingredient_id)), shown, int(target)]
		label.add_theme_color_override("font_color", color)


func _update_hud() -> void:
	if _day_label == null:
		return
	var shown_day := _day_number
	if _epilogue_active:
		_day_label.text = "第 %d 天 · 打烊" % shown_day
		_timer_label.text = "--:--"
		_timer_label.add_theme_color_override("font_color", UITheme.COLORS["muted"])
		_goal_label.text = "谢幕订单 · 不计时"
		_goal_label.add_theme_color_override("font_color", UITheme.COLORS["amber"])
	elif _is_final_day:
		_day_label.text = "第 %d 天 · 终局" % shown_day
		_timer_label.text = _format_time(_time_left)
		_timer_label.add_theme_color_override(
			"font_color",
			UITheme.COLORS["danger"] if _time_left <= 30.0 else UITheme.COLORS["amber"]
		)
		_goal_label.text = "完成 %d/%d · 失误 %d/%d" % [
			_day_served,
			_required_cups,
			_day_major_mistakes,
			_allowed_mistakes,
		]
		_goal_label.add_theme_color_override(
			"font_color",
			UITheme.COLORS["danger"] if _day_major_mistakes > _allowed_mistakes else UITheme.COLORS["muted"]
		)
	else:
		_day_label.text = "第 %d 天" % shown_day
		_timer_label.text = _format_time(_time_left)
		_timer_label.add_theme_color_override(
			"font_color",
			UITheme.COLORS["danger"] if _time_left <= 30.0 else UITheme.COLORS["amber"]
		)
		_goal_label.text = "目标 %d / %d" % [_day_earned, _goal]
		_goal_label.add_theme_color_override(
			"font_color",
			UITheme.COLORS["teal"] if _day_earned >= _goal else UITheme.COLORS["muted"]
		)
	var money := GameState.get_money()
	_money_label.text = str(money)
	if _last_money_shown >= 0 and money != _last_money_shown:
		UiAnim.pulse(_money_label, 1.22, 0.22)
	_last_money_shown = money


func _format_time(seconds: float) -> String:
	var total := int(ceil(maxf(0.0, seconds)))
	var minutes := floori(float(total) / 60.0)
	return "%02d:%02d" % [minutes, total % 60]


func _update_meter() -> void:
	if _meter_label == null or _spill_label == null:
		return
	if _session.glass_id == "":
		_meter_label.text = "先选杯"
		_meter_label.add_theme_color_override("font_color", UITheme.COLORS["dim"])
	else:
		var method := str(_current_recipe.get("method", "build"))

		var method_text: String
		var method_color: Color = UITheme.COLORS["dim"]
		match method:
			"build":
				method_text = "直调"
			"shake":
				var required := maxf(1.0, float(_current_recipe.get("shake_power", 8)))
				method_text = "摇 %d%%" % int(round(clampf(_session.shake_energy / required, 0.0, 1.0) * 100.0))
			"stir":
				var required := maxf(0.5, float(_current_recipe.get("stir_turns", 4)))
				var shown := floorf(_session.stir_turns * 10.0) / 10.0
				method_text = "搅 %.1f/%.0f 圈" % [shown, required]

		_meter_label.text = "%s · 冰 %d/%d" % [
			method_text,
			_session.ice_count,
			int(_current_recipe.get("ice", 0)),
		]
		_meter_label.add_theme_color_override("font_color", method_color)

	if _session.spill_ml >= 1.0:
		_spill_label.text = "洒酒 %d ml" % int(round(_session.spill_ml))
	else:
		_spill_label.text = ""


func _on_tool_pressed(tool: ToolButton) -> void:
	if not _can_interact():
		return
	match tool.tool_kind:
		"glass":
			_select_glass(tool.tool_id)
		"garnish":
			_toggle_garnish(tool.tool_id)
		"bottle", "ice", "shaker", "stirrer":
			_begin_tool_drag(tool)


func _select_glass(glass_id: String) -> void:
	if _session.glass_id != "" and (
		_session.total_volume() > 0.5
		or _session.ice_count > 0
		or not _session.garnish_added.is_empty()
		or _session.shake_energy > 0.0
		or _session.stir_turns > 0.0
	):
		_show_toast("先倒掉这杯再换杯")
		return

	_session.glass_id = glass_id
	for id in _glass_buttons:
		var button: ToolButton = _glass_buttons[id]
		button.set_selected(str(id) == glass_id)
	_cup.update_from(_session)
	_update_recipe_progress()
	_update_meter()
	AudioDirector.play_sfx("glass", 1.0, -2.0, 0.08)
	UiAnim.pulse(_cup, 1.03, 0.18)
	_notify_tutorial("glass")


func _clear_glass_selection() -> void:
	for id in _glass_buttons:
		var button: ToolButton = _glass_buttons[id]
		button.set_selected(false)


func _toggle_garnish(garnish_id: String) -> void:
	if _session.glass_id == "":
		_show_toast("先选一个杯子")
		AudioDirector.play_sfx("fail", 1.2, -10.0, 0.2)
		return
	var had := _session.garnish_added.has(garnish_id)
	_session.toggle_garnish(garnish_id)
	_cup.update_from(_session)
	if not had:
		AudioDirector.play_sfx("garnish", 1.0, -6.0, 0.05)
		UiAnim.pulse(_cup, 1.03, 0.16)
		_check_tutorial_garnish()


func _check_tutorial_garnish() -> void:
	if not _tutorial_active:
		return
	for garnish in _current_recipe.get("garnish", []):
		if not _session.garnish_added.has(str(garnish)):
			return
	_notify_tutorial("garnish")


func _begin_tool_drag(tool: ToolButton) -> void:
	if _session.glass_id == "":
		_show_toast("先选一个杯子")
		AudioDirector.play_sfx("fail", 1.2, -10.0, 0.2)
		return
	_drag_tool = tool
	_drag_kind = tool.tool_kind
	_drag_id = tool.tool_id
	_stir_last_angle = NAN
	_pour_hold = 0.0
	AudioDirector.play_sfx("ui_click", 0.8, -8.0, 0.05)
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)
	var mouse := _pointer_position
	_overlay.show_ghost(tool.icon_texture, mouse + _ghost_offset(_drag_kind), 2)
	_overlay.set_target(_cup.get_global_rect(), UITheme.COLORS["amber"])
	_update_meter()


func _finish_tool_drag() -> void:
	if _drag_kind == "":
		return
	if not _can_interact():
		_cancel_drag()
		return
	var finished_kind := _drag_kind
	if _drag_kind == "ice" and _is_over_cup():
		_session.add_ice(1)
		_cup.update_from(_session)
		_update_recipe_progress()
		_update_meter()
		AudioDirector.play_sfx("ice", 1.0, -4.0, 0.05)
		UiAnim.pulse(_cup, 1.04, 0.16)
		_notify_tutorial("ice")
	elif finished_kind == "bottle" and _is_over_cup():
		AudioDirector.play_sfx("glass", 1.15, -14.0, 0.2)
	_stop_tool_loops()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_cup.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_drag_tool = null
	_drag_kind = ""
	_drag_id = ""
	_stir_last_angle = NAN
	_pour_hold = 0.0
	_overlay.clear_all()


func _cancel_drag() -> void:
	_stop_tool_loops()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if _cup != null:
		_cup.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_drag_tool = null
	_drag_kind = ""
	_drag_id = ""
	_stir_last_angle = NAN
	_pour_hold = 0.0
	if _overlay != null:
		_overlay.clear_all()


func _stop_tool_loops() -> void:
	AudioDirector.stop_loop("pour")
	AudioDirector.stop_loop("shake")
	AudioDirector.stop_loop("stir")
	if _cup != null:
		_cup.clear_activity()


func _handle_drag_motion(motion: InputEventMouseMotion) -> void:
	if not _is_over_cup():
		_stir_last_angle = NAN
		return

	var distance := motion.relative.length()

	if _drag_kind == "bottle" and _pour_hold > 0.2 and distance > POUR_JITTER_DISTANCE:
		var spill := minf(6.0, (distance - POUR_JITTER_DISTANCE) * 0.25)
		_session.spill_ml += spill
		_overlay.flash_spill(spill)
		_overlay.burst_spill(_stream_target(), spill, Vector2.ZERO, _session.liquid_color())
		AudioDirector.play_sfx("splash", randf_range(0.9, 1.15), -6.0, 0.1)
		_cup.pulse_error()
		_flash_damage(0.5)
		_notify_spill()
		_update_meter()
	elif _drag_kind == "shaker" and _session.total_volume() > 0.0:
		if distance <= 0.0:
			return
		_session.add_shake(distance)
		if distance > SHAKE_SPLASH_DISTANCE:
			var spill := minf(4.0, (distance - SHAKE_SPLASH_DISTANCE) * 0.12)
			_session.spill_ml += spill
			_overlay.flash_spill(spill)
			_overlay.burst_spill(_stream_target(), spill, Vector2(0, -30), _session.liquid_color())
			AudioDirector.play_sfx("splash", randf_range(0.95, 1.2), -6.0, 0.1)
			_cup.pulse_error()
			_flash_damage(0.45)
			_notify_spill()
		var required := maxf(1.0, float(_current_recipe.get("shake_power", 8)))
		if _tutorial_active and str(_current_recipe.get("method", "")) == "shake" and _session.shake_energy >= required * 0.4:
			_notify_tutorial("method")
		_update_meter()
	elif _drag_kind == "stirrer" and _session.total_volume() > 0.0:
		var center := _cup.get_global_rect().get_center()
		var world_mouse := _pointer_position
		var radius := world_mouse.distance_to(center)
		if radius < STIR_MIN_RADIUS or radius > STIR_MAX_RADIUS:
			_stir_last_angle = NAN
			return
		var angle := (world_mouse - center).angle()
		if not is_nan(_stir_last_angle):
			var delta_angle := wrapf(angle - _stir_last_angle, -PI, PI)
			if absf(delta_angle) < 1.2:
				_session.add_stir(absf(delta_angle))
		_stir_last_angle = angle
		var required_stir := maxf(0.5, float(_current_recipe.get("stir_turns", 4)))
		if _tutorial_active and str(_current_recipe.get("method", "")) == "stir" and _session.stir_turns >= required_stir * 0.35:
			_notify_tutorial("method")
		_update_meter()


func _notify_spill() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_spill_notice_msec < 1800:
		return
	_last_spill_notice_msec = now
	_show_toast("手抖，酒洒了")


func _flash_damage(strength: float) -> void:
	if _damage_flash == null:
		return
	_damage_flash.color.a = 0.16 * clampf(strength, 0.0, 1.0)
	var tween := create_tween()
	tween.tween_property(_damage_flash, "color:a", 0.0, 0.28)


func _update_drag(delta: float) -> void:
	var mouse := _pointer_position
	_overlay.set_ghost_position(mouse + _ghost_offset(_drag_kind))
	var over_cup := _is_over_cup()
	Input.set_default_cursor_shape(Input.CURSOR_CAN_DROP if over_cup else Input.CURSOR_DRAG)
	_cup.mouse_default_cursor_shape = Control.CURSOR_CAN_DROP if over_cup else Control.CURSOR_DRAG

	if _drag_kind == "bottle":
		if over_cup:
			_pour_hold += delta
			var ingredient := GameData.get_ingredient(_drag_id)
			var rate := float(ingredient.get("rate", 32))
			var before := _session.total_volume()
			_session.add_liquid(_drag_id, rate * delta)
			if _session.total_volume() > before:
				_cup.update_from(_session)
				_update_recipe_progress()
			_overlay.show_stream(_session.liquid_color(), _stream_target())
			AudioDirector.start_loop("pour", -2.0)
			_cup.set_activity("pour")
			if _tutorial_active and _session.total_volume() >= _expected_volume() * 0.35:
				_notify_tutorial("pour")
			_update_meter()
		else:
			_pour_hold = 0.0
			_overlay.hide_stream()
			AudioDirector.stop_loop("pour")
			_cup.clear_activity()
	elif _drag_kind == "shaker":
		_overlay.hide_stream()
		if over_cup and _session.total_volume() > 0.0:
			AudioDirector.start_loop("shake", -4.0)
			_cup.set_activity("shake")
		else:
			AudioDirector.stop_loop("shake")
			_cup.clear_activity()
	elif _drag_kind == "stirrer":
		_overlay.hide_stream()
		if over_cup and _session.total_volume() > 0.0:
			AudioDirector.start_loop("stir", -6.0)
			_cup.set_activity("stir")
		else:
			AudioDirector.stop_loop("stir")
			_cup.clear_activity()
	else:
		_overlay.hide_stream()


func _ghost_offset(kind: String) -> Vector2:
	match kind:
		"bottle":
			return Vector2(-16, -58)
		"ice":
			return Vector2(-16, -34)
		"shaker":
			return Vector2(-14, -40)
		"stirrer":
			return Vector2(-8, -44)
	return Vector2(-16, -40)


func _is_over_cup() -> bool:
	var rect := _cup.get_global_rect().grow(10.0)
	return rect.has_point(_pointer_position)


func _stream_target() -> Vector2:
	return _cup.global_position + Vector2(_cup.size.x * 0.5, 24.0)


func _on_dump_pressed() -> void:
	if not _can_interact():
		return
	if _session.glass_id == "":
		return
	_session.clear_liquid()
	_cup.update_from(_session)
	_update_recipe_progress()
	_update_meter()
	AudioDirector.play_sfx("splash", 0.8, -14.0, 0.3)
	_stop_tool_loops()
	_show_toast("已倒掉")


func _on_cup_pressed() -> void:
	if not _can_interact():
		return
	if _session.glass_id == "":
		_show_toast("先选一个杯子")
		AudioDirector.play_sfx("fail", 1.2, -10.0, 0.2)
		return
	if _session.total_volume() <= 0.5:
		_show_toast("杯里还没有酒")
		AudioDirector.play_sfx("fail", 1.2, -10.0, 0.2)
		return
	_stop_tool_loops()
	AudioDirector.play_sfx("glass", 1.1, -8.0, 0.08)
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)
	_cup_dragging = true
	_cup.z_index = 10
	_cup_drag_offset = _pointer_position - _cup.position
	_overlay.set_target(_customer.get_global_rect().grow(6.0), UITheme.COLORS["teal"])
	if _cup_tween != null and _cup_tween.is_valid():
		_cup_tween.kill()


func _finish_cup_drag() -> void:
	if not _cup_dragging:
		return
	if not _can_interact():
		_cancel_cup_drag()
		return
	_cup_dragging = false
	_cup.z_index = 0
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_cup.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_overlay.clear_all()
	var drop_position := _pointer_position
	if _customer_active and _customer.get_global_rect().grow(8.0).has_point(drop_position):
		_cup.position = CUP_HOME
		_serve_current_drink()
	else:
		_return_cup_home()


func _cancel_cup_drag() -> void:
	if not _cup_dragging:
		return
	_cup_dragging = false
	if _cup != null:
		_cup.z_index = 0
		_cup.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if _overlay != null:
		_overlay.clear_all()
	_return_cup_home()


func _return_cup_home() -> void:
	if _cup == null:
		return
	if _cup_tween != null and _cup_tween.is_valid():
		_cup_tween.kill()
	_cup_tween = create_tween()
	_cup_tween.tween_property(_cup, "position", CUP_HOME, 0.14)


func _serve_current_drink() -> void:
	if not _customer_active or _awaiting_feedback:
		return

	_stop_tool_loops()
	_finish_tutorial_on_serve()

	var patience_ratio := clampf(_patience_left / maxf(1.0, _customer_patience), 0.0, 1.0)
	var result := DrinkScoring.evaluate(_session, patience_ratio)
	var stars := int(result.get("stars", 0))
	var income := int(result.get("income", 0))
	var is_epilogue := _epilogue_active

	_customer_active = false
	if not is_epilogue:
		_customers_done += 1
		_day_served += 1
		_day_earned += income
		_day_stars += stars
		if stars <= 1:
			_day_major_mistakes += 1
		if stars >= 2:
			_combo += 1
		else:
			_combo = 0
		_best_combo = maxi(_best_combo, _combo)

		GameState.add_money(income)
	_update_hud()
	_show_feedback(result, not is_epilogue)

	_awaiting_feedback = true
	await get_tree().create_timer(2.4).timeout
	if not is_inside_tree():
		return
	_awaiting_feedback = false
	_hide_feedback()

	if is_epilogue:
		_finish_epilogue()
	elif _time_left <= 0.0:
		_end_day()
	elif _day_running:
		_spawn_customer()


func _on_customer_gave_up() -> void:
	if not _customer_active or _awaiting_feedback:
		return
	_customer_active = false
	_customers_done += 1
	_day_major_mistakes += 1
	_combo = 0
	_show_toast("客人等太久了")
	AudioDirector.play_sfx("leave", 1.0, -2.0, 0.0)
	AudioDirector.stop_all_loops()
	_flash_damage(1.0)
	if _tutorial_active:
		_tutorial.stop()
		_tutorial_active = false
	_cup_dragging = false
	_cup.z_index = 0
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_cancel_drag()
	_return_cup_home()
	_reset_current_drink()

	_awaiting_feedback = true
	await get_tree().create_timer(1.2).timeout
	if not is_inside_tree():
		return
	_awaiting_feedback = false

	if _time_left <= 0.0:
		_end_day()
	elif _day_running:
		_spawn_customer()


func _reset_current_drink() -> void:
	_session.reset_for(_current_recipe)
	_cup.position = CUP_HOME
	_cup.update_from(_session)
	_clear_glass_selection()
	_update_recipe_progress()
	_update_meter()


func _show_feedback(result: Dictionary, show_income: bool = true) -> void:
	var stars := int(result.get("stars", 0))
	_feedback_title.text = str(_current_recipe.get("name", ""))
	var title_color: Color = UITheme.COLORS["danger"] if stars <= 1 else UITheme.COLORS["cream"]
	_feedback_title.add_theme_color_override("font_color", title_color)
	_feedback_stars.set_stars(stars)
	_feedback_income.text = "+0 月亮石" if show_income else "不计营业额"
	var notes: Array = result.get("notes", [])
	if notes.is_empty():
		_feedback_notes.text = "完美出杯" if stars >= 3 else ""
	else:
		var shown: Array[String] = []
		for i in range(mini(3, notes.size())):
			shown.append(str(notes[i]))
		_feedback_notes.text = " · ".join(shown)
	_feedback_layer.visible = true
	_feedback_layer.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_feedback_layer, "modulate:a", 1.0, 0.12)

	UiAnim.pop_in(_feedback_panel, 0.0, 0.22, 0.9)
	_feedback_stars.play_reveal()
	if show_income:
		var income_tween := create_tween()
		income_tween.tween_method(_set_feedback_income, 0.0, float(result.get("income", 0)), 0.42).set_delay(0.18)

	if stars >= 2:
		AudioDirector.play_sfx("star", 1.0 + float(stars) * 0.06, -2.0, 0.0)
		if show_income:
			_play_coin_sound_later()
	else:
		AudioDirector.play_sfx("fail", 1.0, -4.0, 0.0)


func _set_feedback_income(value: float) -> void:
	_feedback_income.text = "+%d 月亮石" % int(round(value))


func _play_coin_sound_later() -> void:
	await get_tree().create_timer(0.4).timeout
	if is_inside_tree():
		AudioDirector.play_sfx("coin", 1.0, -5.0, 0.0)


func _hide_feedback() -> void:
	_feedback_layer.visible = false


func _end_day() -> void:
	if not _day_running:
		return
	_day_running = false
	_customer_active = false
	_awaiting_feedback = false
	_cup_dragging = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	AudioDirector.stop_all_loops()
	_cancel_drag()
	_hide_feedback()
	_toast.visible = false
	if _tutorial_active:
		_tutorial.stop()
		_tutorial_active = false

	var success := _is_day_success()
	if success:
		GameState.complete_day(_day_earned, _day_served, _day_stars, _best_combo)
		if _is_final_day:
			GameState.mark_finished()
	else:
		GameState.set_money(_day_start_money)
	GameState.end_day()
	_update_hud()
	GameState.autosave()
	if success and _is_final_day:
		_start_epilogue()
	else:
		_show_result(success)


func _start_epilogue() -> void:
	_epilogue_active = true
	_customer_active = false
	_cup_dragging = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

	if _recipe_pool.is_empty():
		_epilogue_active = false
		_show_result(true)
		return

	var recipe_id := _pick_recipe({})
	_current_recipe = GameData.get_recipe(recipe_id)
	_last_recipe_id = recipe_id
	_session.reset_for(_current_recipe)
	_cup.position = CUP_HOME
	_cup.z_index = 0
	_cup.update_from(_session)
	_clear_glass_selection()
	_populate_order_card(_current_recipe)

	_customer.position = SPECIAL_CUSTOMER_HOME
	_customer.size = SPECIAL_CUSTOMER_SIZE
	_customer.set_portrait(SPECIAL_CUSTOMER_TEXTURE)
	_customer.set_patience_bar_visible(false)
	_customer.set_patience(1.0)
	_customer_type = {"id": "epilogue", "name": "", "patience_mult": 1.0}
	_last_customer_id = "epilogue"
	_customer_patience = 1.0
	_patience_left = 1.0
	_order_customer.text = "打烊后的来客 · 不计时"
	_order_customer.add_theme_color_override("font_color", UITheme.COLORS["cream"])

	_customer_active = true
	_update_hud()
	_update_meter()
	_show_toast("打烊了，最后一位客人")
	AudioDirector.play_sfx("ui_click", 1.12, -3.0, 0.0)


func _finish_epilogue() -> void:
	_epilogue_active = false
	_customer_active = false
	_customer.position = CUSTOMER_HOME
	_customer.size = CUSTOMER_SIZE
	_customer.set_patience_bar_visible(true)
	_customer.set_variant(0)
	_update_hud()
	_show_result(true)


func _is_day_success() -> bool:
	if _is_final_day:
		return _day_served >= _required_cups and _day_major_mistakes <= _allowed_mistakes
	return _day_earned >= _goal


func _show_result(success: bool) -> void:
	_result_open = true
	_result_layer.visible = true
	_result_layer.modulate.a = 0.0
	var outcome := "通关" if success and _is_final_day else ("达标" if success else "未达标")
	_result_title.text = "第 %d 天 · %s" % [_day_number, outcome]
	_result_title.add_theme_color_override(
		"font_color",
		UITheme.COLORS["teal"] if success else UITheme.COLORS["danger"]
	)
	var average := 0.0
	if _day_served > 0:
		average = float(_day_stars) / float(_day_served)
	if _is_final_day:
		_result_stats.text = "完成 %d / %d 杯 · 重大失误 %d / %d\n营业额 %d · 平均 %.1f 星\n剩余时间 %s" % [
			_day_served,
			_required_cups,
			_day_major_mistakes,
			_allowed_mistakes,
			_day_earned,
			average,
			_format_time(_time_left),
		]
	else:
		_result_stats.text = "营业额 %d / %d\n接待 %d 杯 · 平均 %.1f 星\n剩余时间 %s" % [
			_day_earned,
			_goal,
			_day_served,
			average,
			_format_time(_time_left),
		]
	if success and _is_final_day:
		_result_primary.text = "通关结算"
		_result_primary_action = "ending"
	elif success:
		_result_primary.text = "前往商店"
		_result_primary_action = "shop"
	else:
		_result_primary.text = "重试当天"
		_result_primary_action = "retry"
	_result_secondary.visible = true
	var tween := create_tween()
	tween.tween_property(_result_layer, "modulate:a", 1.0, 0.16)
	UiAnim.pop_in(_result_panel, 0.04, 0.26, 0.9)
	AudioDirector.play_sfx("success" if success else "fail", 1.0 if not _is_final_day else 1.12, -2.0, 0.0)


func _show_blocked() -> void:
	_result_open = true
	_result_layer.visible = true
	_result_title.text = "未载入存档"
	_result_stats.text = "请从主菜单选择一个存档"
	_result_primary.text = "返回主菜单"
	_result_primary_action = "menu"
	_result_secondary.visible = false
	_day_label.text = "第 -- 天"
	_timer_label.text = "--:--"
	_goal_label.text = "目标 --"
	_money_label.text = "--"
	_meter_label.text = ""
	_customer.set_patience(0.0)


func _on_result_primary_pressed() -> void:
	match _result_primary_action:
		"menu":
			_leave_to_menu()
		"shop":
			SceneRouter.change_scene(SceneRouter.SHOP)
		"ending":
			SceneRouter.change_scene(SceneRouter.ENDING)
		_:
			SceneRouter.change_scene(SceneRouter.BAR)


func _on_result_secondary_pressed() -> void:
	_leave_to_menu()


func _on_menu_pressed() -> void:
	if _result_open or _paused:
		return
	AudioDirector.play_sfx("ui_click", 1.0, -3.0, 0.0)
	AudioDirector.stop_all_loops()
	_cancel_drag()
	_cancel_cup_drag()
	_paused = true
	var body := "今日营业额将回滚到开店时。"
	if _epilogue_active:
		body = "打烊后的最后一杯尚未完成，离开后可从结算页继续。"
	_pause_dialog.open("离开吧台", body, "保存并离开", true)


func _on_pause_cancelled() -> void:
	_paused = false


func _on_pause_confirmed() -> void:
	_paused = false
	GameState.end_game(true)
	SceneRouter.change_scene(SceneRouter.MAIN_MENU)


func _leave_to_menu() -> void:
	GameState.end_game(true)
	SceneRouter.change_scene(SceneRouter.MAIN_MENU)


func _can_interact() -> bool:
	return (
		(_day_running or _epilogue_active)
		and _customer_active
		and not _awaiting_feedback
		and not _result_open
		and not _paused
	)


func _show_toast(text: String) -> void:
	if _toast == null:
		return
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.3)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.35)
	_toast_tween.tween_callback(_hide_toast)


func _hide_toast() -> void:
	_toast.visible = false


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
