# 입력 시험: 실제 누르기·끌기 사건을 화면에 보내 위습 소환·갈매미 끌어 옮기기·여러 마리 고르기·버튼이 되는지 확인.
# 사용: xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1280x720 --script res://scripts/test/input_test.gd
extends SceneTree

const E = preload("res://scripts/engine/engine.gd")

var node: Control
var frames := 0
var step := 0
var fails := 0
var info := {}


func _init() -> void:
	node = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	root.add_child(node)


func scr(x: float, y: float) -> Vector2:   # 논리 좌표(1312×960) → 화면
	return node.view_o + Vector2(x, y) * node.view_s


func board(x: float, y: float) -> Vector2:   # 판 논리 좌표 → 화면
	return node.view_o + Vector2(x, y) * node.view_s * node.LS


func press(p: Vector2, on: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = on
	ev.position = p
	ev.global_position = p
	root.push_input(ev, true)   # 화면 늘이기(stretch)와 상관없이 장면 좌표로


func move(p: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = p
	ev.global_position = p
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(ev, true)   # 화면 늘이기(stretch)와 상관없이 장면 좌표로


func check(name: String, ok: bool, detail: String = "") -> void:
	print("%s %s %s" % ["통과" if ok else "실패", name, detail])
	if not ok:
		fails += 1


func _process(_d: float) -> bool:
	frames += 1
	if frames % 4 != 0:
		return false
	step += 1
	var g: Dictionary = node.g
	match step:
		1:   # 처음 화면에서 「입문」 버튼 누르기
			var bw := 200.0
			var x0: float = node.VW / 2.0 - (bw * 5 + 12 * 4) / 2.0
			press(scr(x0 + bw / 2, 495), true)
			press(scr(x0 + bw / 2, 495), false)
		2:
			check("난이도 버튼으로 시작", node.scene == "play" and node.g.diff == "intro", node.g.get("diff", "-"))
			node.freeze = true
			info.c = int(node.g.wisps.COMMON)
			var bw := (540.0 - 44 - 24) / 5.0
			press(scr(node.SIDE_X + 22 + bw / 2, 702 + 30), true)
			press(scr(node.SIDE_X + 22 + bw / 2, 702 + 30), false)
		3:
			check("커먼 위습 칸 누르면 소환", int(g.wisps.COMMON) == info.c - 1 and g.units.size() >= 1, "위습 %d → %d, 갈매미 %d" % [info.c, g.wisps.COMMON, g.units.size()])
			var u: Dictionary = g.units[0]
			info.uid = u.uid
			info.x = u.x
			var z: float = node.usz(u.id)
			var p := board(u.x, u.y - 22 * z)
			press(p, true)
			move(p + Vector2(-30, 0))
			move(p + Vector2(-150 * node.view_s * node.LS / 1.5, 0))
			press(p + Vector2(-150 * node.view_s * node.LS / 1.5, 0), false)
		4:
			var u = E.unit_by_id(g, info.uid)
			check("갈매미 끌어 옮기기", u != null and absf(u.x - (info.x - 100.0)) < 2.0, "x %.1f → %.1f(목표 %.1f)" % [info.x, u.x, info.x - 100.0])
			check("누른 갈매미가 골라짐", node.selected == [info.uid], str(node.selected))
			for k in 4:
				E.summon(g, "COMMON")
			press(board(120, 170), true)
			move(board(200, 300))
			move(board(500, 640))
			press(board(500, 640), false)
		5:
			var inbox := E.field_units(g).filter(func(u): return u.x >= 120 and u.x <= 500 and u.y >= 170 and u.y <= 640).size()
			check("빈 곳을 끌어 여러 마리 고르기", node.selected.size() == inbox and inbox >= 2, "고름 %d · 상자 안 %d" % [node.selected.size(), inbox])
			press(scr(node.SIDE_X + 540 - 112 + 45, 672 + 30), true)   # 「해제」
			press(scr(node.SIDE_X + 540 - 112 + 45, 672 + 30), false)
		6:
			check("해제 버튼", node.selected.is_empty(), str(node.selected))
			press(board(540 - 112 + 23, 32), true)   # 일시정지 버튼(판 위 정보 줄)
			press(board(540 - 112 + 23, 32), false)
		7:
			check("일시정지 버튼", node.paused, "")
			node.paused = false
			var sx: float = node.SIDE_X
			var b2 := (540.0 - 44 - 6) / 2.0
			press(scr(sx + 22 + b2 / 2, 772 + 41), true)   # 「조합법」 메뉴 버튼
			press(scr(sx + 22 + b2 / 2, 772 + 41), false)
		8:
			check("조합법 창 열기", node.modal.get("kind") == "book", str(node.modal.get("kind")))
			var sx: float = node.SIDE_X
			press(scr(sx + 300, 500), true)   # 목록을 위로 끌어 스크롤
			move(scr(sx + 300, 460))
			move(scr(sx + 300, 300))
			press(scr(sx + 300, 300), false)
		9:
			check("목록 끌어 스크롤(누름은 안 됨)", float(node.modal.get("scroll", 0)) > 100 and node.info.is_empty(), "scroll %.0f" % float(node.modal.get("scroll", 0)))
			node.modal.scroll = 0.0
		10:
			var sx: float = node.SIDE_X
			press(scr(sx + 14 + 12 + 70, 8 + 126 + 30 + 3 + 23), true)   # 첫 조합법 줄(이름 부분) → 설명 창
			press(scr(sx + 14 + 12 + 70, 8 + 126 + 30 + 3 + 23), false)
		11:
			check("조합법 줄 누르면 설명 창", not node.info.is_empty(), str(node.info))
			var sx: float = node.SIDE_X
			press(scr(sx + 14 + 512 - 96 + 41, 8 + 30), true)   # 설명 창 「닫기」
			press(scr(sx + 14 + 512 - 96 + 41, 8 + 30), false)
		12:
			check("설명 창 닫기", node.info.is_empty(), "")
			g.gold = 5000.0
			info.u0 = int(g.upg[0])
			var sx: float = node.SIDE_X
			var b2 := (540.0 - 44 - 6) / 2.0
			press(scr(sx + 28 + b2 + b2 / 2, 772 + 41), true)   # 「강화」 메뉴 버튼
			press(scr(sx + 28 + b2 + b2 / 2, 772 + 41), false)
		13:
			check("강화 창 열기", node.modal.get("kind") == "upgrade", str(node.modal.get("kind")))
			var sx: float = node.SIDE_X
			var rh := minf(84.0, (652.0 - 96) / 8.0)
			press(scr(sx + 20 + 500 - 28 - 75, 8 + 88 + 6 + (rh - 20) / 2), true)   # 커먼·언커먼 「강화」
			press(scr(sx + 20 + 500 - 28 - 75, 8 + 88 + 6 + (rh - 20) / 2), false)
		14:
			check("강화 버튼", int(g.upg[0]) == info.u0 + 1, "%d → %d" % [info.u0, int(g.upg[0])])
			for k in 400:   # 조금 진행한 뒤 저장 → 처음 화면 → 이어하기
				E.step(g, 0.05)
			node.save_now()
			info.saved = E.save_game(g)
			node.scene = "title"
			node.g = {}
		15:
			check("처음 화면에 이어하기 정보", not node.save_meta.is_empty(), str(node.save_meta))
			press(scr(node.VW / 2.0, 378), true)   # 「이어하기」 버튼
			press(scr(node.VW / 2.0, 378), false)
		16:
			check("이어하기로 같은 판", node.scene == "play" and E.save_game(node.g) == info.saved and node.paused, "웨이브 %d · 멈춤 %s" % [int(node.g.get("wave", -1)), str(node.paused)])
			node.clear_save()
			print("입력 시험 끝: 실패 %d" % fails)
			quit(1 if fails else 0)
	return false
