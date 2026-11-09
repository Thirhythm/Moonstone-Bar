extends Node

const Synth := preload("res://scripts/audio/procedural_audio.gd")
const SETTINGS_PATH := "user://audio.cfg"
const SFX_POOL_SIZE := 10
const MUSIC_DB := -10.0
# 各曲目 RMS 不同（大厅约 -20 dBFS，商店 -34.3，游戏组 -16.4，尾声 -15.9），
# 按曲目补偿增益，切换场景时不出现音量跳变。
const BGM_GAIN_DB := {
	"lobby": 0.0,
	"shop": 14.0,
	"game": -3.5,
	"new_dawn": -3.5,
	"reinis_nait": -3.5,
	"finale": -4.0,
}
const LOOP_DB := {
	"pour": -12.0,
	"shake": -14.0,
	"stir": -16.0,
}
const LOOP_ASSETS := {
	"shake": "res://assets/audio/shake.wav",
	"stir": "res://assets/audio/stir.wav",
}
const SFX_ASSETS := {
	"glass": ["res://assets/audio/glass_1.wav", "res://assets/audio/glass_2.wav"],
	"ice": ["res://assets/audio/ice.wav"],
}
const BGM_ASSETS := {
	"lobby": "res://assets/audio/moonstone_login.wav",
	"shop": "res://assets/audio/moonstone_shop.wav",
	"game": "res://assets/audio/moonstone.wav",
	"new_dawn": "res://assets/audio/new_dawn.ogg",
	"reinis_nait": "res://assets/audio/reinis_nait.ogg",
}
# 分组内的曲目随机轮播；单曲 BGM 不配置分组。
const BGM_GROUPS := {
	"game": ["game", "new_dawn", "reinis_nait"],
}

var _music: Array[AudioStreamPlayer] = []
var _active_music := 0
var _bgm_cache: Dictionary = {}
var _bgm_bags: Dictionary = {}
var _current_track := ""
var _sfx_cache: Dictionary = {}
var _sfx_variants: Dictionary = {}
var _sfx_variant_index: Dictionary = {}
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index := 0
var _loops: Dictionary = {}
var _loop_tweens: Dictionary = {}
var _last_played: Dictionary = {}
var _current_bgm := ""
var _pending_bgm := ""
var _bgm_tween: Tween
var _rotate_tween: Tween
var _muted := false
var _thread: Thread
var _bgm_mutex := Mutex.new()
var _bgm_thread_result: Dictionary = {}
var _bgm_thread_done := false
var _bgm_generated := false
var _shut_down := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()

	for i in range(2):
		var player := AudioStreamPlayer.new()
		player.volume_db = -60.0
		add_child(player)
		_music.append(player)

	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.volume_db = -4.0
		add_child(player)
		_sfx_pool.append(player)

	for id in Synth.LOOP_IDS:
		var path := str(LOOP_ASSETS.get(id, ""))
		var stream: AudioStreamWAV = load(path) if path != "" else Synth.build(id)
		var loop_player := AudioStreamPlayer.new()
		loop_player.volume_db = -60.0
		loop_player.stream = stream
		add_child(loop_player)
		_loops[id] = loop_player

	var started := Time.get_ticks_msec()
	for id in Synth.SFX_IDS:
		var variants: Array[AudioStreamWAV] = []
		for path in SFX_ASSETS.get(id, []):
			var stream := load(str(path)) as AudioStreamWAV
			if stream != null:
				variants.append(stream)
		if variants.is_empty():
			variants.append(Synth.build(id))
		_sfx_variants[id] = variants
		_sfx_variant_index[id] = 0
		_sfx_cache[id] = variants[0]
	print("[AUDIO] sfx ready in %d ms" % (Time.get_ticks_msec() - started))

	for id in BGM_ASSETS:
		var stream := load(str(BGM_ASSETS[id])) as AudioStream
		if stream == null:
			continue
		if stream is AudioStreamWAV:
			var wav := stream as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(round(wav.get_length() * wav.mix_rate))
		elif stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		_bgm_cache[id] = stream

	_thread = Thread.new()
	_thread.start(_generate_bgm)


func _exit_tree() -> void:
	_stop_all_audio()


# 退出前主动停掉所有播放并等待一次混音周期，否则音频服务器仍持有播放实例，
# 会在 ObjectDB 泄漏检查中报 AudioStreamPlaybackWAV 泄漏。
func shutdown() -> void:
	if _shut_down:
		return
	_shut_down = true
	_stop_all_audio()
	await get_tree().create_timer(0.2, true, false, true).timeout


func _stop_all_audio() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	_thread = null
	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_bgm_tween = null
	_stop_rotation()
	for id in _loop_tweens:
		var loop_tween: Tween = _loop_tweens[id]
		if loop_tween != null and loop_tween.is_valid():
			loop_tween.kill()
	_loop_tweens.clear()
	for player in _music:
		player.stop()
		player.stream = null
	for player in _sfx_pool:
		player.stop()
		player.stream = null
	for id in _loops:
		var loop_player: AudioStreamPlayer = _loops[id]
		loop_player.stop()
		loop_player.stream = null
	_loops.clear()
	_bgm_cache.clear()
	_bgm_bags.clear()
	_sfx_cache.clear()
	_sfx_variants.clear()
	_sfx_variant_index.clear()
	_current_bgm = ""
	_current_track = ""
	_pending_bgm = ""


func _process(_delta: float) -> void:
	if _shut_down or _bgm_generated:
		return
	_bgm_mutex.lock()
	var done := _bgm_thread_done
	_bgm_mutex.unlock()
	if not done:
		return
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	_bgm_mutex.lock()
	var result := _bgm_thread_result
	_bgm_thread_result = {}
	_bgm_mutex.unlock()
	_on_bgm_generated(result)


func _generate_bgm() -> void:
	var result := {}
	for id in Synth.BGM_IDS:
		result[id] = Synth.build(id)
	_bgm_mutex.lock()
	_bgm_thread_result = result
	_bgm_thread_done = true
	_bgm_mutex.unlock()


func _on_bgm_generated(result: Dictionary) -> void:
	_bgm_cache.merge(result)
	_bgm_generated = true
	if _pending_bgm != "":
		var id := _pending_bgm
		_pending_bgm = ""
		set_bgm(id)


func set_bgm(id: String) -> void:
	_current_bgm = id
	if id == "":
		_fade_out_music()
		return
	var tracks := _bgm_tracks(id)
	if _playing_track(tracks) != "":
		return
	var track := _next_bgm_track(id)
	if track != "" and _bgm_cache.has(track):
		_play_bgm(track)
	else:
		_pending_bgm = id


func _bgm_tracks(id: String) -> Array:
	var group: Array = BGM_GROUPS.get(id, [])
	return group if not group.is_empty() else [id]


func _playing_track(tracks: Array) -> String:
	var player := _music[_active_music]
	if not player.playing:
		return ""
	for id in tracks:
		if _bgm_cache.get(id) == player.stream:
			return str(id)
	return ""


func _next_bgm_track(id: String) -> String:
	var tracks := _bgm_tracks(id)
	if tracks.is_empty():
		return ""
	if tracks.size() == 1:
		return str(tracks[0])
	var bag: Array = _bgm_bags.get(id, [])
	if bag.is_empty():
		bag = tracks.duplicate()
		bag.shuffle()
		if bag.size() > 1 and str(bag[0]) == _current_track:
			bag.append(bag.pop_front())
		_bgm_bags[id] = bag
	return str(bag.pop_front())


func _play_bgm(track: String) -> void:
	var stream := _bgm_cache.get(track) as AudioStream
	if stream == null:
		return
	if _music[_active_music].stream == stream and _music[_active_music].playing:
		return

	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()

	var previous := _music[_active_music]
	var next_index := 1 - _active_music
	var next := _music[next_index]
	_active_music = next_index
	_current_track = track

	next.stream = stream
	next.volume_db = -60.0
	next.play()

	var target_db := MUSIC_DB + float(BGM_GAIN_DB.get(track, 0.0))
	_bgm_tween = create_tween()
	_bgm_tween.set_parallel(true)
	_bgm_tween.tween_property(next, "volume_db", target_db, 0.9)
	_bgm_tween.tween_property(previous, "volume_db", -60.0, 0.9)
	_bgm_tween.chain().tween_callback(previous.stop)
	_schedule_rotation(track)


# 轮播曲目在结束前 1 秒交叉淡入下一首；单曲 BGM 不排程。
func _schedule_rotation(track: String) -> void:
	_stop_rotation()
	if _bgm_tracks(_current_bgm).size() < 2:
		return
	var stream := _bgm_cache.get(track) as AudioStream
	if stream == null:
		return
	var wait := stream.get_length() - 1.0
	if wait <= 1.0:
		return
	_rotate_tween = create_tween()
	_rotate_tween.tween_interval(wait)
	_rotate_tween.tween_callback(_rotate_bgm.bind(track))


func _rotate_bgm(track: String) -> void:
	_rotate_tween = null
	if _shut_down or _current_track != track or _current_bgm == "":
		return
	if _playing_track(_bgm_tracks(_current_bgm)) == "":
		return
	var next := _next_bgm_track(_current_bgm)
	if next == "" or next == track:
		return
	_play_bgm(next)


func _stop_rotation() -> void:
	if _rotate_tween != null and _rotate_tween.is_valid():
		_rotate_tween.kill()
	_rotate_tween = null


func _fade_out_music() -> void:
	_stop_rotation()
	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	for player in _music:
		if player.playing:
			_bgm_tween = create_tween()
			_bgm_tween.tween_property(player, "volume_db", -60.0, 0.5)
			_bgm_tween.tween_callback(player.stop)


func play_sfx(id: String, pitch: float = 1.0, volume_offset_db: float = 0.0, cooldown: float = 0.04) -> void:
	if _muted:
		return
	var variants: Array = _sfx_variants.get(id, [])
	if variants.is_empty():
		return
	if cooldown > 0.0:
		var now := Time.get_ticks_msec()
		var last := int(_last_played.get(id, -100000))
		if now - last < int(cooldown * 1000.0):
			return
		_last_played[id] = now

	var index := int(_sfx_variant_index[id]) % variants.size()
	_sfx_variant_index[id] = (index + 1) % variants.size()
	var player := _sfx_pool[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_pool.size()
	player.stream = variants[index]
	player.pitch_scale = clampf(pitch, 0.5, 2.0)
	player.volume_db = -4.0 + volume_offset_db
	player.play()


func start_loop(id: String, volume_offset_db: float = 0.0) -> void:
	var player: AudioStreamPlayer = _loops.get(id)
	if player == null or player.playing:
		return
	_kill_loop_tween(id)
	player.volume_db = -60.0
	player.play()
	var target := float(LOOP_DB.get(id, -14.0)) + volume_offset_db
	var tween := create_tween()
	tween.tween_property(player, "volume_db", target, 0.12)
	_loop_tweens[id] = tween


func stop_loop(id: String) -> void:
	var player: AudioStreamPlayer = _loops.get(id)
	if player == null or not player.playing:
		return
	_kill_loop_tween(id)
	var tween := create_tween()
	tween.tween_property(player, "volume_db", -60.0, 0.16)
	tween.tween_callback(player.stop)
	_loop_tweens[id] = tween


func stop_all_loops() -> void:
	for id in _loops:
		stop_loop(str(id))


func _kill_loop_tween(id: String) -> void:
	var tween: Tween = _loop_tweens.get(id)
	if tween != null and tween.is_valid():
		tween.kill()


func toggle_mute() -> bool:
	_muted = not _muted
	AudioServer.set_bus_mute(0, _muted)
	_save_settings()
	return _muted


func is_muted() -> bool:
	return _muted


func is_bgm_ready() -> bool:
	return _bgm_generated


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		_muted = bool(config.get_value("audio", "muted", false))
	AudioServer.set_bus_mute(0, _muted)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "muted", _muted)
	config.save(SETTINGS_PATH)
