extends Control

@onready var _stats_label: Label = %StatsLabel
@onready var _menu_button: Button = %MenuButton


func _ready() -> void:
	AudioDirector.set_bgm("finale")
	_menu_button.pressed.connect(_on_menu_pressed)
	_populate()
	UiAnim.pop_in($Center/Panel, 0.05, 0.32, 0.9)
	UiAnim.stagger_in($Center/Panel/Margin/Content, 0.055, 0.26)
	AudioDirector.play_sfx("success", 0.95, -3.0, 0.0)


func _populate() -> void:
	if not GameState.has_active_game():
		_stats_label.text = "7 天营业完成"
		return

	var progress := GameState.get_progress()
	var stats := GameState.get_stats()
	var play_seconds := int(GameState.data.get("play_seconds", 0))
	_stats_label.text = "7 天营业完成\n总营业额 %d · 结余 %d 月亮石\n服务 %d 杯 · 累计 %d 星\n最佳连击 %d · 游玩 %s" % [
		int(stats.get("total_earned", 0)),
		int(progress.get("money", 0)),
		int(stats.get("drinks_served", 0)),
		int(progress.get("stars", 0)),
		int(stats.get("best_combo", 0)),
		_format_playtime(play_seconds),
	]


func _format_playtime(seconds: int) -> String:
	var minutes := seconds / 60
	if minutes <= 0:
		return "%d 秒" % seconds
	return "%d 分 %d 秒" % [minutes, seconds % 60]


func _on_menu_pressed() -> void:
	AudioDirector.play_sfx("ui_click", 1.0, -4.0, 0.0)
	GameState.end_game(true)
	SceneRouter.change_scene(SceneRouter.MAIN_MENU)
