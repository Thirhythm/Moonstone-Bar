class_name SaveSlotCard
extends PanelContainer

signal action_requested(action: StringName, slot: int)

@onready var _slot_number: Label = %SlotNumber
@onready var _slot_title: Label = %SlotTitle
@onready var _state_label: Label = %StateLabel
@onready var _detail_row: HBoxContainer = %DetailRow
@onready var _detail_label: Label = %DetailLabel
@onready var _money_icon: TextureRect = %MoneyIcon
@onready var _money_value: Label = %MoneyValue
@onready var _meta_label: Label = %MetaLabel
@onready var _primary_button: Button = %PrimaryButton
@onready var _delete_button: Button = %DeleteButton

var _slot := 1
var _summary: Dictionary = {}
var _primary_action: StringName = &"new"
var _is_ready := false


func _ready() -> void:
	_primary_button.pressed.connect(_on_primary_pressed)
	_delete_button.pressed.connect(_emit_action.bind(&"delete"))
	_is_ready = true
	_apply()


func setup(slot: int, summary: Dictionary) -> void:
	_slot = slot
	_summary = summary
	if _is_ready:
		_apply()


func _apply() -> void:
	_slot_number.text = str(_slot)
	_slot_title.text = "存档 %d" % _slot

	var exists := bool(_summary.get("exists", false))
	var corrupt := bool(_summary.get("corrupt", false))

	if corrupt:
		_state_label.text = "存档损坏"
		_state_label.add_theme_color_override("font_color", UITheme.COLORS["danger"])
		_detail_label.text = "无法读取"
		_money_icon.hide()
		_money_value.hide()
		_detail_row.show()
		_meta_label.text = ""
		_meta_label.hide()
		_primary_button.hide()
		_delete_button.show()
		return

	if not exists:
		_state_label.text = "空存档"
		_state_label.add_theme_color_override("font_color", UITheme.COLORS["muted"])
		_detail_label.text = ""
		_money_icon.hide()
		_money_value.hide()
		_detail_row.hide()
		_meta_label.text = ""
		_meta_label.hide()
		_primary_button.text = "新建"
		_primary_action = &"new"
		_primary_button.show()
		_delete_button.hide()
		return

	var day := int(_summary.get("day", 1))
	var money := int(_summary.get("money", 0))
	var updated := str(_summary.get("updated_at_text", ""))
	var finished := bool(_summary.get("finished", false))

	_state_label.text = "已通关" if finished else "营业中"
	_state_label.add_theme_color_override(
		"font_color",
		UITheme.COLORS["amber"] if finished else UITheme.COLORS["muted"]
	)
	_detail_label.text = "7 天完成 ·" if finished else "第 %d 天 ·" % day
	_money_value.text = str(money)
	_money_icon.show()
	_money_value.show()
	_detail_row.show()
	if updated.is_empty():
		_meta_label.text = ""
		_meta_label.hide()
	else:
		var short_updated := updated
		if short_updated.length() >= 16:
			short_updated = short_updated.substr(5, 11)
		_meta_label.text = "最近 %s" % short_updated
		_meta_label.show()
	_primary_button.text = "查看结算" if finished else "继续"
	_primary_action = &"continue"
	_primary_button.show()
	_delete_button.show()


func _on_primary_pressed() -> void:
	action_requested.emit(_primary_action, _slot)


func _emit_action(action: StringName) -> void:
	action_requested.emit(action, _slot)
