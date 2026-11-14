# 화면 캡처(디자인 검토용).
# 사용: xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 915x412 --script res://scripts/test/shot.gd -- <출력.png> <장면> [상황]
#   장면: game(기본) · preview
#   상황(game): title · play(자동 봇으로 몇 웨이브 진행) · unit(갈매미 하나 고름) · group(여러 마리) · pause · over · boss
extends SceneTree

const E = preload("res://scripts/engine/engine.gd")
const Bot = preload("res://scripts/engine/simple_bot.gd")

var out := ""
var what := "play"
var frames := 0
var node: Node


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0]
	var sc: String = args[1] if args.size() > 1 else "game"
	what = args[2] if args.size() > 2 else "play"
	node = (load("res://scenes/%s.tscn" % sc) as PackedScene).instantiate()
	root.add_child(node)


func _setup() -> void:
	if not node.has_method("start") or what == "title":
		return
	seed(7)
	node.start("intro" if what != "over" else "master")
	var g: Dictionary = node.g
	var until := 330.0 if what != "boss" else 196.0
	var i := 0
	while g.t < until and g.over == null:
		E.step(g, 0.05)
		i += 1
		if i % 10 == 0:
			Bot.act(g)
	if what == "boss":
		while g.over == null and not (E.wave_info(g.wave).boss and g.enemies.any(func(e): return e.boss)):
			E.step(g, 0.05)
	var f := E.field_units(g)
	if what == "unit" and f.size() > 0:
		var best = f[0]
		for u in f:
			if E.tier_of(u.id) > E.tier_of(best.id):
				best = u
		node.selected = [best.uid]
	elif what == "group":
		node.selected = f.slice(0, 9).map(func(u): return u.uid)
	elif what == "pause":
		node.paused = true
	elif what == "over":
		g.over = "lose"
		g.reason = "%d웨이브 보스를 라운드 안에 잡지 못했어요." % g.wave
	node.freeze = what != "play"


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 2:
		_setup()
	if frames >= 30:
		var img := root.get_texture().get_image()
		img.save_png(out)
		print("캡처: %s (%dx%d)" % [out, img.get_width(), img.get_height()])
		return true
	return false
