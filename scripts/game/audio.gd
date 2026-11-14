# 소리: 효과음은 웹 판처럼 소리 파일 없이 짧은 음을 만들어 냄(같은 주파수·시작·길이·파형), 배경음악은 웹 판 bgm.mp3(기본 꺼짐).
extends Node

# [주파수, 시작(초), 길이(초), 파형] — 웹 판 defense.js SFX와 같음
const SFX := {
	"summon": [[660, 0, 0.08, "triangle"], [990, 0.06, 0.1, "triangle"]],
	"combine": [[523, 0, 0.12, "triangle"], [784, 0.09, 0.14, "triangle"], [1047, 0.18, 0.2, "sine"]],
	"boss": [[110, 0, 0.5, "sawtooth"], [82, 0.25, 0.6, "sawtooth"]],
	"warn": [[880, 0, 0.09, "square"]],
	"recruitOk": [[587, 0, 0.1, "triangle"], [880, 0.08, 0.12, "triangle"], [1175, 0.17, 0.22, "sine"]],
	"recruitFail": [[300, 0, 0.15, "sine"], [220, 0.12, 0.25, "sine"]],
	"story": [[523, 0, 0.12, "triangle"], [659, 0.1, 0.12, "triangle"], [784, 0.2, 0.12, "triangle"], [1047, 0.3, 0.3, "sine"]],
	"signal": [[1320, 0, 0.08, "sine"], [1760, 0.09, 0.12, "sine"]],
	"wisp": [[1568, 0, 0.1, "sine"], [2093, 0.07, 0.14, "sine"]],
}
const RATE := 22050
const SETTINGS := "user://settings.cfg"

var sfx_vol := 0.5
var music_on := false
var music_vol := 0.5
var _streams := {}
var _last := {}
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer


func _ready() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS) == OK:
		sfx_vol = float(cf.get_value("sound", "sfx", 0.5))
		music_on = bool(cf.get_value("sound", "music", false))
		music_vol = float(cf.get_value("sound", "music_vol", 0.5))
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_sync_music()


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("sound", "sfx", sfx_vol)
	cf.set_value("sound", "music", music_on)
	cf.set_value("sound", "music_vol", music_vol)
	cf.save(SETTINGS)


func set_music(on: bool) -> void:
	music_on = on
	save_settings()
	_sync_music()


func set_sfx_vol(v: float) -> void:
	sfx_vol = clampf(roundf(v * 20) / 20, 0, 1)
	save_settings()


func _sync_music() -> void:
	if music_on:
		if _music.stream == null:
			var s = load("res://assets/audio/bgm.mp3")
			if s is AudioStreamMP3:
				s.loop = true
			_music.stream = s
		_music.volume_db = linear_to_db(maxf(0.001, music_vol * 0.6))
		if not _music.playing and _music.stream != null:
			_music.play()
	elif _music.playing:
		_music.stop()


func _wave(kind: String, ph: float) -> float:   # ph: 0~1 한 주기 안의 위치
	match kind:
		"square":
			return 1.0 if ph < 0.5 else -1.0
		"sawtooth":
			return 2.0 * ph - 1.0
		"triangle":
			return 4.0 * ph - 1.0 if ph < 0.5 else 3.0 - 4.0 * ph
	return sin(TAU * ph)


func _make(name: String) -> AudioStreamWAV:   # 웹 판과 같은 모양: 0.01초 동안 커졌다가 길이 끝까지 지수로 작아짐
	var notes: Array = SFX[name]
	var total := 0.0
	for n in notes:
		total = maxf(total, float(n[1]) + float(n[2]) + 0.02)
	var count := int(total * RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	for n in notes:
		var f := float(n[0])
		var at := float(n[1])
		var dur := float(n[2])
		var i0 := int(at * RATE)
		var i1 := mini(count, int((at + dur) * RATE))
		for i in range(i0, i1):
			var t := (i - i0) / float(RATE)
			var env := t / 0.01 if t < 0.01 else pow(0.0001, (t - 0.01) / maxf(0.001, dur - 0.01))
			buf[i] += _wave(n[3], fmod(f * t, 1.0)) * env
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		data.encode_s16(i * 2, int(clampf(buf[i] * 0.9, -1, 1) * 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


func play(name: String) -> void:
	if sfx_vol <= 0 or not SFX.has(name):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(name, -1000)) < 60:   # 같은 소리가 한꺼번에 겹치지 않게
		return
	_last[name] = now
	if not _streams.has(name):
		_streams[name] = _make(name)
	var vol := sfx_vol * (0.18 if name == "boss" else 0.12) * 4.0
	for p in _pool:
		if not p.playing:
			p.stream = _streams[name]
			p.volume_db = linear_to_db(maxf(0.0001, vol))
			p.play()
			return
