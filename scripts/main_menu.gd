extends Control

@onready var _start_button: Button = %StartButton
@onready var _quit_button: Button = %QuitButton
@onready var _sound_button: Button = %SoundButton


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_sound_button.pressed.connect(_on_sound_pressed)
	_update_sound_button()
	AudioDirector.set_bgm("lobby")
	_play_intro()


func _play_intro() -> void:
	var content := $Margin/Content
	UiAnim.stagger_in(content, 0.06, 0.3)
	AudioDirector.play_sfx("whoosh", 1.0, -16.0, 0.0)


func _on_start_pressed() -> void:
	SceneRouter.change_scene(SceneRouter.SAVE_SELECT)


func _on_quit_pressed() -> void:
	SceneRouter.quit_game()


func _on_sound_pressed() -> void:
	var muted := AudioDirector.toggle_mute()
	_update_sound_button()
	if not muted:
		AudioDirector.play_sfx("ui_click", 1.0, -4.0, 0.0)


func _update_sound_button() -> void:
	_sound_button.text = "♪ 关" if AudioDirector.is_muted() else "♪ 开"
	_sound_button.tooltip_text = "声音：关" if AudioDirector.is_muted() else "声音：开"
