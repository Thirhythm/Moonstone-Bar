extends Node

signal slot_changed(slot: int)

const SLOT_COUNT := 4
const SCHEMA_VERSION := 2
const SAVE_DIR := "user://saves"

const STARTING_RECIPES := ["gin_tonic", "screwdriver"]
const STARTING_INGREDIENTS := ["gin", "vodka", "tonic_water", "orange_juice", "lime_juice"]


func _ready() -> void:
	_ensure_dir()


func get_slot_summary(slot: int) -> Dictionary:
	var target := _slot_file(slot)
	if not FileAccess.file_exists(target):
		return _empty_summary(slot, false)

	var save := read_save(slot)
	if save.is_empty():
		return _empty_summary(slot, true)

	var progress: Dictionary = save.get("progress", {})
	var stats: Dictionary = save.get("stats", {})
	return {
		"slot": slot,
		"exists": true,
		"corrupt": false,
		"day": int(progress.get("day", 1)),
		"money": int(progress.get("money", 0)),
		"finished": bool(progress.get("finished", false)),
		"stars": int(progress.get("stars", 0)),
		"completed_days": int(progress.get("completed_days", 0)),
		"updated_at_text": str(save.get("updated_at_text", "")),
		"play_seconds": int(save.get("play_seconds", 0)),
		"drinks_served": int(stats.get("drinks_served", 0)),
	}


func read_save(slot: int) -> Dictionary:
	if slot < 1 or slot > SLOT_COUNT:
		return {}

	var target := _slot_file(slot)
	if not FileAccess.file_exists(target):
		return {}

	var file := FileAccess.open(target, FileAccess.READ)
	if file == null:
		push_error("无法读取存档：%s" % target)
		return {}

	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("存档格式无效：%s" % target)
		return {}

	return _normalize_save(parsed, slot)


func create_save(slot: int) -> Dictionary:
	if slot < 1 or slot > SLOT_COUNT:
		return {}

	var data := _default_save(slot)
	if not write_save(slot, data):
		return {}
	return read_save(slot)


func write_save(slot: int, data: Dictionary) -> bool:
	if slot < 1 or slot > SLOT_COUNT or data.is_empty():
		return false
	if not _ensure_dir():
		return false

	var payload: Dictionary = data.duplicate(true)
	payload["schema_version"] = SCHEMA_VERSION
	payload["slot"] = slot
	payload["updated_at"] = int(Time.get_unix_time_from_system())
	payload["updated_at_text"] = Time.get_datetime_string_from_system(false, true)

	var target_name := "slot_%d.json" % slot
	var backup_name := target_name + ".bak"
	var temp_name := target_name + ".tmp"

	var file := FileAccess.open(SAVE_DIR.path_join(temp_name), FileAccess.WRITE)
	if file == null:
		push_error("无法写入存档临时文件：%s" % temp_name)
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	file.close()

	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		push_error("无法打开存档目录：%s" % SAVE_DIR)
		return false

	if dir.file_exists(target_name):
		if dir.file_exists(backup_name):
			dir.remove(backup_name)
		var source := FileAccess.open(SAVE_DIR.path_join(target_name), FileAccess.READ)
		if source != null:
			var backup_bytes := source.get_buffer(source.get_length())
			source.close()
			var backup := FileAccess.open(SAVE_DIR.path_join(backup_name), FileAccess.WRITE)
			if backup != null:
				backup.store_buffer(backup_bytes)
				backup.close()
			else:
				push_warning("备份旧存档失败：%s" % target_name)
		else:
			push_warning("备份旧存档失败：%s" % target_name)

	if dir.file_exists(target_name):
		dir.remove(target_name)

	var rename_error := dir.rename(temp_name, target_name)
	if rename_error != OK:
		push_error("替换存档失败：%s" % target_name)
		if dir.file_exists(backup_name) and not dir.file_exists(target_name):
			dir.rename(backup_name, target_name)
		return false

	slot_changed.emit(slot)
	return true


func delete_slot(slot: int) -> bool:
	if slot < 1 or slot > SLOT_COUNT:
		return false

	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return false

	for suffix in ["", ".bak", ".tmp"]:
		var file_name := "slot_%d.json%s" % [slot, suffix]
		if dir.file_exists(file_name):
			dir.remove(file_name)

	slot_changed.emit(slot)
	return not dir.file_exists("slot_%d.json" % slot)


func _ensure_dir() -> bool:
	if DirAccess.dir_exists_absolute(SAVE_DIR):
		return true
	var error := DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if error != OK:
		push_error("无法创建存档目录：%s (%d)" % [SAVE_DIR, error])
		return false
	return true


func _slot_file(slot: int) -> String:
	return SAVE_DIR.path_join("slot_%d.json" % slot)


func _empty_summary(slot: int, corrupt: bool) -> Dictionary:
	return {
		"slot": slot,
		"exists": corrupt,
		"corrupt": corrupt,
		"day": 1,
		"money": 0,
		"stars": 0,
		"completed_days": 0,
		"finished": false,
		"updated_at_text": "",
		"play_seconds": 0,
		"drinks_served": 0,
	}


func _default_save(slot: int) -> Dictionary:
	var now := int(Time.get_unix_time_from_system())
	return {
		"schema_version": SCHEMA_VERSION,
		"slot": slot,
		"created_at": now,
		"updated_at": now,
		"updated_at_text": Time.get_datetime_string_from_system(false, true),
		"play_seconds": 0,
		"progress": {
			"day": 1,
			"money": 0,
			"stars": 0,
			"completed_days": 0,
			"finished": false,
			"finished_at": 0,
			"unlocked_recipes": STARTING_RECIPES.duplicate(),
			"unlocked_ingredients": STARTING_INGREDIENTS.duplicate(),
			"tutorial_done": false,
			"employee_hired": false,
		},
		"stats": {
			"total_earned": 0,
			"drinks_served": 0,
			"best_combo": 0,
		},
	}


func _normalize_save(raw: Dictionary, slot: int) -> Dictionary:
	if typeof(raw.get("progress")) != TYPE_DICTIONARY:
		return {}

	var data: Dictionary = raw.duplicate(true)
	var progress: Dictionary = data["progress"]
	progress["day"] = maxi(1, int(progress.get("day", 1)))
	progress["money"] = maxi(0, int(progress.get("money", 0)))
	progress["stars"] = maxi(0, int(progress.get("stars", 0)))
	progress["completed_days"] = maxi(0, int(progress.get("completed_days", 0)))
	progress["finished"] = bool(progress.get("finished", false))
	progress["finished_at"] = maxi(0, int(progress.get("finished_at", 0)))
	progress["tutorial_done"] = bool(progress.get("tutorial_done", false))
	progress["employee_hired"] = bool(progress.get("employee_hired", false))
	if typeof(progress.get("unlocked_recipes")) != TYPE_ARRAY:
		progress["unlocked_recipes"] = STARTING_RECIPES.duplicate()
	if typeof(progress.get("unlocked_ingredients")) != TYPE_ARRAY:
		progress["unlocked_ingredients"] = STARTING_INGREDIENTS.duplicate()
	data["progress"] = progress

	if typeof(data.get("stats")) != TYPE_DICTIONARY:
		data["stats"] = {"total_earned": 0, "drinks_served": 0, "best_combo": 0}
	var stats: Dictionary = data["stats"]
	stats["total_earned"] = maxi(0, int(stats.get("total_earned", 0)))
	stats["drinks_served"] = maxi(0, int(stats.get("drinks_served", 0)))
	stats["best_combo"] = maxi(0, int(stats.get("best_combo", 0)))
	data["stats"] = stats

	var now := int(Time.get_unix_time_from_system())
	data["schema_version"] = SCHEMA_VERSION
	data["slot"] = slot
	data["play_seconds"] = maxi(0, int(data.get("play_seconds", 0)))
	if not data.has("created_at"):
		data["created_at"] = now
	if not data.has("updated_at"):
		data["updated_at"] = data["created_at"]
	if not data.has("updated_at_text"):
		data["updated_at_text"] = ""
	return data
