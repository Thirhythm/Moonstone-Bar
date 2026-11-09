extends Node


func _ready() -> void:
	var driver := Node.new()
	driver.name = "M4FlowDriver"
	driver.set_script(load("res://test/m4_flow.gd"))
	get_tree().root.add_child.call_deferred(driver)
