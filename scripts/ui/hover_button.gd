extends Button


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_on_hover)
	pressed.connect(_on_pressed)


func _on_hover() -> void:
	AudioDirector.play_sfx("ui_click", 1.4, -22.0, 0.07)


func _on_pressed() -> void:
	AudioDirector.play_sfx("ui_click", 1.0, -6.0, 0.02)
