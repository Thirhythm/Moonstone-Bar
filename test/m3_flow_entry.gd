extends Node


func _ready() -> void:
	var driver := Node.new()
	driver.name = "M3FlowDriver"
	driver.set_script(load("res://test/m3_flow.gd"))
	get_tree().root.add_child.call_deferred(driver)
