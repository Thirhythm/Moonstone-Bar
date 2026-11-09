extends Node


func _ready() -> void:
	var driver := Node.new()
	driver.name = "M1DayDriver"
	driver.set_script(load("res://test/m1_day.gd"))
	get_tree().root.add_child.call_deferred(driver)
