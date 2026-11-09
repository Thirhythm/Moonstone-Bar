extends Control

const CARD_SCENE := preload("res://scenes/ui/save_slot_card.tscn")

@onready var _slot_list: GridContainer = %SlotList
@onready var _back_button: Button = %BackButton
@onready var _notice: Label = %Notice
@onready var _confirm_dialog: ConfirmDialog = %ConfirmDialog

var _cards: Array[SaveSlotCard] = []
var _pending_slot := 0
var _busy := false
var _notice_tween: Tween


func _ready() -> void:
	AudioDirector.set_bgm("lobby")
	for i in range(SaveManager.SLOT_COUNT):
		var card := CARD_SCENE.instantiate() as SaveSlotCard
		_slot_list.add_child(card)
		card.action_requested.connect(_on_card_action)
		_cards.append(card)

	_back_button.pressed.connect(_on_back_pressed)
	_confirm_dialog.confirmed.connect(_on_confirmed)
	_confirm_dialog.cancelled.connect(_on_cancelled)
	refresh()
	UiAnim.stagger_in(_slot_list, 0.045, 0.22)
	AudioDirector.play_sfx("whoosh", 1.05, -20.0, 0.0)


func refresh() -> void:
	for i in range(_cards.size()):
		_cards[i].setup(i + 1, SaveManager.get_slot_summary(i + 1))


func _on_card_action(action: StringName, slot: int) -> void:
	if _busy:
		return
	match action:
		&"new":
			_start_new_game(slot)
		&"continue":
			_continue_game(slot)
		&"delete":
			_ask_delete(slot)


func _start_new_game(slot: int) -> void:
	if GameState.new_game(slot):
		_busy = true
		SceneRouter.change_scene(SceneRouter.BAR)
	else:
		_show_notice("创建存档失败")


func _continue_game(slot: int) -> void:
	if GameState.load_game(slot):
		_busy = true
		if GameState.is_finished():
			SceneRouter.change_scene(SceneRouter.ENDING)
		elif GameState.get_day() > 1:
			SceneRouter.change_scene(SceneRouter.SHOP)
		else:
			SceneRouter.change_scene(SceneRouter.BAR)
	else:
		_show_notice("存档读取失败")
		refresh()


func _ask_delete(slot: int) -> void:
	_pending_slot = slot
	_confirm_dialog.open(
		"删除存档 %d" % slot,
		"进度将被永久删除，确定吗？",
		"删除",
		true
	)


func _on_confirmed() -> void:
	var slot := _pending_slot
	_pending_slot = 0
	if SaveManager.delete_slot(slot):
		_show_notice("存档 %d 已删除" % slot)
	else:
		_show_notice("删除失败")
	refresh()


func _on_cancelled() -> void:
	_pending_slot = 0


func _on_back_pressed() -> void:
	SceneRouter.change_scene(SceneRouter.MAIN_MENU)


func _show_notice(text: String) -> void:
	_notice.text = text
	_notice.modulate.a = 1.0
	if _notice_tween != null and _notice_tween.is_valid():
		_notice_tween.kill()
	_notice_tween = create_tween()
	_notice_tween.tween_interval(2.2)
	_notice_tween.tween_property(_notice, "modulate:a", 0.0, 0.5)
