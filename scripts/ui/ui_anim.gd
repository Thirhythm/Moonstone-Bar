class_name UiAnim
extends RefCounted


static func fade_in(control: Control, delay: float = 0.0, duration: float = 0.25) -> void:
	if control == null:
		return
	control.modulate.a = 0.0
	var tween := control.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(control, "modulate:a", 1.0, duration)


static func pop_in(control: Control, delay: float = 0.0, duration: float = 0.22, from_scale: float = 0.92) -> void:
	if control == null:
		return
	_prepare_pivot(control)
	control.scale = Vector2.ONE * from_scale
	control.modulate.a = 0.0
	var tween := control.create_tween().set_parallel(true)
	tween.tween_property(control, "scale", Vector2.ONE, duration).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, duration * 0.8).set_delay(delay)


static func stagger_in(container: Node, step: float = 0.05, duration: float = 0.25) -> void:
	if container == null or not container.is_inside_tree():
		return
	await container.get_tree().process_frame
	var index := 0
	for child in container.get_children():
		if child is Control and (child as Control).visible:
			fade_in(child, float(index) * step, duration)
			index += 1


static func pulse(control: Control, amount: float = 1.16, duration: float = 0.2) -> void:
	if control == null:
		return
	_prepare_pivot(control)
	var previous: Tween = null
	if control.has_meta("_ui_pulse"):
		previous = control.get_meta("_ui_pulse") as Tween
	if previous != null and previous.is_valid():
		previous.kill()
	var tween := control.create_tween()
	control.set_meta("_ui_pulse", tween)
	tween.tween_property(control, "scale", Vector2.ONE * amount, duration * 0.4)
	tween.tween_property(control, "scale", Vector2.ONE, duration * 0.6)


static func _prepare_pivot(control: Control) -> void:
	if control.has_meta("_ui_pivot"):
		return
	control.set_meta("_ui_pivot", true)
	control.resized.connect(_update_pivot.bind(control))
	_update_pivot(control)


static func _update_pivot(control: Control) -> void:
	control.pivot_offset = control.size * 0.5
