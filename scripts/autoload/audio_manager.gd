extends Node
## 音频管理：SFX / 音乐播放 + 总线音量。autoload 名: AudioManager
## 用法: AudioManager.play_sfx(preload("res://...wav"))
##       AudioManager.set_bus_volume("Music", 0.5)  # 0..1 线性

var _music: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
const SFX_VOICES := 8

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)

func play_sfx(stream: AudioStream, volume_db := 0.0, pitch := 1.0) -> void:
	if stream == null:
		return
	for p in _sfx_pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return

func play_music(stream: AudioStream, loop := true) -> void:
	if stream == null:
		return
	_music.stream = stream
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
	_music.play()

func stop_music() -> void:
	_music.stop()

func set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))
