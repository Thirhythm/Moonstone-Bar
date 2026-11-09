extends Node


func _ready() -> void:
	var driver := Node.new()
	driver.name = "M1InputDriver"
	driver.set_script(load("res://test/m1_input.gd"))
	get_tree().root.add_child.call_deferred(driver)
