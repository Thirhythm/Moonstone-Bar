extends Node

var _failures := 0


func _ready() -> void:
	await get_tree().process_frame
	await _check_audio()
	_check_save_flag()
	await _check_ui_hooks()
	await _check_bar_feedback()
	await _check_tutorial()

	if _failures == 0:
		print("[M4] ALL CHECKS PASSED")
	else:
		push_error("[M4] %d CHECK(S) FAILED" % _failures)
	await AudioDirector.shutdown()
	get_tree().quit(0 if _failures == 0 else 1)


func _check_audio() -> void:
	for id in ProceduralAudio.SFX_IDS:
		_check(AudioDirector._sfx_cache.has(id), "应合成音效 %s" % id)
		var stream: AudioStreamWAV = AudioDirector._sfx_cache.get(id)
		_check(stream != null and not stream.data.is_empty(), "音效应有音频数据：%s" % id)

	for id in ProceduralAudio.LOOP_IDS:
		_check(AudioDirector._loops.has(id), "应有循环音 %s" % id)

	var waited := 0.0
	while not AudioDirector.is_bgm_ready() and waited < 6.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	_check(AudioDirector.is_bgm_ready(), "后台 BGM 应在 6 秒内合成完成")
	_check(AudioDirector._bgm_cache.size() == ProceduralAudio.BGM_IDS.size() + AudioDirector.BGM_ASSETS.size(), "应加载外部 BGM 并合成尾声 BGM")
	for id in AudioDirector.BGM_ASSETS:
		var bgm := AudioDirector._bgm_cache.get(id) as AudioStream
		var loops := false
		if bgm is AudioStreamWAV:
			loops = (bgm as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD
		elif bgm is AudioStreamOggVorbis:
			loops = (bgm as AudioStreamOggVorbis).loop
		_check(bgm != null and loops, "外部 BGM 应循环播放：%s" % id)
	_check(AudioDirector._bgm_tracks("game").size() == 3, "游戏 BGM 应配置 3 首随机轮播曲目")

	AudioDirector.play_sfx("ui_click")
	AudioDirector.start_loop("pour")
	await get_tree().create_timer(0.05).timeout
	var pour_player: AudioStreamPlayer = AudioDirector._loops["pour"]
	_check(pour_player.playing, "倒酒循环音应可播放")
	AudioDirector.stop_all_loops()
	await get_tree().create_timer(0.25).timeout
	_check(not pour_player.playing, "循环音应可停止")

	var muted := AudioDirector.is_muted()
	_check(AudioDirector.toggle_mute() != muted, "静音开关应生效")
	_check(AudioDirector.toggle_mute() == muted, "静音开关应可恢复")

	AudioDirector.set_bgm("finale")
	_check(AudioDirector._current_bgm == "finale", "应可切换尾声 BGM")
	AudioDirector.set_bgm("lobby")
	print("[M4] audio: sfx=%d bgm=%d wait=%.1fs" % [
		AudioDirector._sfx_cache.size(), AudioDirector._bgm_cache.size(), waited
	])


func _check_save_flag() -> void:
	var defaults := SaveManager._default_save(1)
	_check(not bool(defaults["progress"].get("tutorial_done", true)), "新存档应默认未完成引导")
	var missing := SaveManager._normalize_save({"progress": {}}, 1)
	_check(missing["progress"].get("tutorial_done") == false, "旧存档应补默认引导标记")
	var done := SaveManager._normalize_save({"progress": {"tutorial_done": true}}, 1)
	_check(done["progress"].get("tutorial_done") == true, "引导标记应可保留")


func _check_ui_hooks() -> void:
	# 静音状态会持久化到用户配置，先复位以免受上一轮运行影响。
	if AudioDirector.is_muted():
		AudioDirector.toggle_mute()
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	var menu := get_tree().current_scene
	_check(menu != null and menu.name == "MainMenu", "应进入主菜单")
	var sound_button := menu.get_node_or_null("%SoundButton") as Button
	_check(sound_button != null, "主菜单应有声音开关")
	_check(sound_button.text.begins_with("♪"), "声音开关应显示状态")
	var muted_before := AudioDirector.is_muted()
	sound_button.pressed.emit()
	await get_tree().process_frame
	_check(AudioDirector.is_muted() != muted_before, "点击声音开关应切换静音")
	_check(sound_button.text == "♪ 关", "静音后按钮应显示关闭")
	sound_button.pressed.emit()
	await get_tree().process_frame
	_check(AudioDirector.is_muted() == muted_before, "再次点击应恢复声音")
	_check(AudioDirector._current_bgm == "lobby", "主菜单应播放大厅 BGM")
	var menu_bgm: AudioStreamPlayer = AudioDirector._music[AudioDirector._active_music]
	_check(menu_bgm.playing and menu_bgm.stream == AudioDirector._bgm_cache["lobby"], "大厅 BGM 应实际播放")
	await _capture("res://test/m4_menu.png")

	_setup_state(2, 400, true)
	get_tree().change_scene_to_file("res://scenes/shop/shop.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(AudioDirector._current_bgm == "shop", "商店应播放商店 BGM")
	_check(AudioDirector._playing_track(AudioDirector._bgm_tracks("shop")) == "shop", "商店 BGM 应实际播放")

	_setup_state(7, 1000, true, true)
	get_tree().change_scene_to_file("res://scenes/ending/ending.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	var ending := get_tree().current_scene
	_check(ending != null and ending.name == "Ending", "应进入通关页")
	_check(AudioDirector._current_bgm == "finale", "通关页应播放尾声 BGM")
	await _capture("res://test/m4_ending.png")


func _check_bar_feedback() -> void:
	_setup_state(1, 120, true)
	get_tree().change_scene_to_file("res://scenes/bar/bar.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	var bar := get_tree().current_scene
	_check(bar != null and bar.name == "Bar", "应进入吧台")
	_check(AudioDirector._current_bgm == "game", "吧台应播放游戏 BGM")
	_check(bar._help_button != null, "吧台 HUD 应有引导入口")
	_check(not bar._tutorial.is_active(), "已完成引导的存档不应自动弹出教学")

	bar._overlay.burst_spill(Vector2(320, 150), 12.0)
	_check(bar._overlay._droplets.size() > 0, "洒酒应产生溅出粒子")
	bar._flash_damage(1.0)
	_check(bar._damage_flash.color.a > 0.0, "洒酒应有屏幕警示闪烁")
	bar._cup.pulse_error()
	_check(bar._cup._error_flash > 0.0, "酒杯应闪红")

	bar._show_feedback({"stars": 3, "income": 48, "notes": []})
	await get_tree().process_frame
	_check(bar._feedback_layer.visible, "评分反馈应显示")
	_check(bar._feedback_stars.stars == 3, "反馈应显示 3 星")
	_check(bar._feedback_stars._reveal >= 0.0, "星级应有弹出动画")
	await get_tree().create_timer(0.7).timeout
	_check(bar._feedback_income.text == "+48 月亮石", "收入应滚动到最终值：%s" % bar._feedback_income.text)
	await _capture("res://test/m4_feedback.png")
	bar._hide_feedback()

	bar._tutorial.start(_dummy_steps())
	await get_tree().process_frame
	_check(bar._tutorial.is_active(), "引导层应可手动打开")
	bar._tutorial.stop()


func _check_tutorial() -> void:
	_setup_state(1, 120, false)
	get_tree().change_scene_to_file("res://scenes/bar/bar.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	var bar := get_tree().current_scene
	_check(bar._tutorial.is_active(), "新档第 1 天应自动开始引导")
	_check(bar._tutorial.current_step_id() == "glass", "第一步应提示选杯")
	_check(bar._tutorial._steps.size() == 5, "金汤力引导应有 5 步")
	var time_before: float = bar._time_left
	var patience_before: float = bar._patience_left
	await get_tree().create_timer(0.5).timeout
	_check(absf(bar._time_left - time_before) < 0.01, "引导期间计时应暂停")
	_check(absf(bar._patience_left - patience_before) < 0.01, "引导期间耐心应暂停")
	await _capture("res://test/m4_tutorial.png")

	bar._select_glass("highball")
	_check(bar._tutorial.current_step_id() == "pour", "选杯后应进入倒酒步骤")
	await get_tree().process_frame
	await _capture("res://test/m4_tutorial_pour.png")

	var recipe: Dictionary = bar._current_recipe
	var glass_id := str(recipe.get("glass", "highball"))
	var garnish_id := str(recipe.get("garnish", [""])[0])
	bar._drag_kind = "bottle"
	bar._drag_id = "gin"
	bar._pointer_position = bar._cup.get_global_rect().get_center()
	for i in range(4):
		bar._update_drag(0.5)
	bar._stop_tool_loops()
	_check(bar._tutorial.current_step_id() == "ice", "倒酒达到进度后应进入加冰步骤")

	bar._drag_kind = "ice"
	bar._pointer_position = bar._cup.get_global_rect().get_center()
	bar._finish_tool_drag()
	_check(bar._tutorial.current_step_id() == "garnish", "加冰后应进入装饰步骤")

	bar._toggle_garnish(garnish_id)
	_check(bar._tutorial.current_step_id() == "serve", "装饰后应进入上酒步骤")

	bar._session.reset_for(recipe)
	bar._session.glass_id = glass_id
	for entry in recipe.get("ingredients", []):
		bar._session.add_liquid(str(entry.get("id", "")), float(entry.get("amount", 0)))
	bar._session.add_ice(int(recipe.get("ice", 0)))
	bar._session.garnish_added.append(garnish_id)
	bar._serve_current_drink()
	await get_tree().process_frame
	_check(not bar._tutorial.is_active(), "上酒后引导应结束")
	_check(GameState.is_tutorial_done(), "引导结束应写入存档标记")

	await get_tree().create_timer(2.6).timeout
	bar._on_help_pressed()
	_check(bar._tutorial.is_active(), "已完成引导后仍可手动重看")
	bar._tutorial._next_button.pressed.emit()
	await get_tree().process_frame
	_check(bar._tutorial.current_step_id() == "pour", "下一步按钮应推进引导")
	bar._tutorial._skip_button.pressed.emit()
	await get_tree().process_frame
	_check(not bar._tutorial.is_active(), "跳过应关闭引导")

	bar._current_recipe = GameData.get_recipe("mojito")
	_check(bar._build_tutorial_steps().size() == 6, "含冰、搅拌与装饰的配方应有 6 步")

	print("[M4] tutorial: steps=%d done=%s" % [
		bar._tutorial._steps.size(), str(GameState.is_tutorial_done())
	])


func _dummy_steps() -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	steps.append({
		"id": "glass",
		"title": "测试",
		"text": "测试",
		"rects": [Rect2(8, 306, 44, 44)],
	})
	return steps


func _setup_state(day: int, money: int, tutorial_done: bool, finished: bool = false) -> void:
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
			"finished": finished,
			"finished_at": 0,
			"unlocked_recipes": ["gin_tonic", "screwdriver"],
			"unlocked_ingredients": GameData.ingredients.keys(),
			"tutorial_done": tutorial_done,
			"employee_hired": false,
		},
		"stats": {"total_earned": 0, "drinks_served": 0, "best_combo": 0},
	}


func _check(condition: bool, message: String) -> void:
	if condition:
		print("[M4] ok: %s" % message)
	else:
		_failures += 1
		push_error("[M4] FAILED: %s" % message)


func _capture(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	print("[M4] screenshot %s err=%d" % [path, error])
