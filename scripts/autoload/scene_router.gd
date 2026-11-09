extends Node

const MAIN_MENU := "res://scenes/main_menu/main_menu.tscn"
const SAVE_SELECT := "res://scenes/save_select/save_select.tscn"
const BAR := "res://scenes/bar/bar.tscn"
const SHOP := "res://scenes/shop/shop.tscn"
const ENDING := "res://scenes/ending/ending.tscn"

var _layer: CanvasLayer
var _fade: ColorRect
var _transitioning := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_layer = CanvasLayer.new()
	_layer.layer = 128
	add_child(_layer)

	_fade = ColorRect.new()
	_fade.color = Color(0.015, 0.02, 0.04, 1.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_startup_fade.call_deferred()


func change_scene(path: String) -> void:
	if _transitioning:
		return

	_transitioning = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	AudioDirector.play_sfx("whoosh", 0.9, -20.0, 0.0)
	AudioDirector.stop_all_loops()

	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.22)
	await tween.finished

	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("切换场景失败：%s (%d)" % [path, error])

	await get_tree().process_frame

	var tween_out := create_tween()
	tween_out.tween_property(_fade, "color:a", 0.0, 0.28)
	await tween_out.finished

	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transitioning = false


func quit_game() -> void:
	if _transitioning:
		return

	_transitioning = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.25)
	await tween.finished
	await AudioDirector.shutdown()
	UITheme.clear_cursor()
	get_tree().quit()


func _startup_fade() -> void:
	_transitioning = true
	await get_tree().process_frame

	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 0.0, 0.45)
	await tween.finished

	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transitioning = false
