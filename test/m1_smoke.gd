extends Node


func _ready() -> void:
	var driver := Node.new()
	driver.name = "M1Driver"
	driver.set_script(load("res://test/m1_driver.gd"))
	get_tree().root.add_child.call_deferred(driver)
