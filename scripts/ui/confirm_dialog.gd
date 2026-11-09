class_name ConfirmDialog
extends Control

signal confirmed
signal cancelled

@onready var _dim: ColorRect = %Dim
@onready var _title: Label = %TitleLabel
@onready var _message: Label = %MessageLabel
@onready var _confirm_button: Button = %ConfirmButton
@onready var _cancel_button: Button = %CancelButton

var _open_tween: Tween


func _ready() -> void:
	hide()
	_cancel_button.pressed.connect(_cancel)
	_confirm_button.pressed.connect(_confirm)
	_dim.gui_input.connect(_on_dim_input)


func open(title_text: String, message_text: String, confirm_text: String = "确认", danger: bool = false) -> void:
	_title.text = title_text
	_message.text = message_text
	_confirm_button.text = confirm_text
	_confirm_button.theme_type_variation = &"DangerButton" if danger else &"PrimaryButton"
	show()
	modulate.a = 0.0
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	_open_tween = create_tween()
	_open_tween.tween_property(self, "modulate:a", 1.0, 0.14)
	UiAnim.pop_in($Center/Panel, 0.0, 0.18, 0.94)


func _confirm() -> void:
	hide()
	confirmed.emit()


func _cancel() -> void:
	hide()
	cancelled.emit()


func _on_dim_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_cancel()
