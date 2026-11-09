extends Node


func _ready() -> void:
	for i in range(4):
		await get_tree().process_frame
	var bar := get_tree().current_scene
	if bar == null:
		print("[MANUAL] no scene")
		return
	bar._current_recipe = GameData.get_recipe("gin_tonic")
	bar._session.reset_for(bar._current_recipe)
	bar._populate_order_card(bar._current_recipe)
	bar._select_glass("highball")
	bar._session.add_liquid("gin", 45)
	bar._session.add_liquid("tonic_water", 90)
	bar._session.add_liquid("lime_juice", 15)
	bar._session.add_ice(2)
	bar._cup.update_from(bar._session)
	bar._update_recipe_progress()
	print("[MANUAL] ready for real mouse")
