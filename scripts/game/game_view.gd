# 게임 화면(2단계-1): 웹 판 defense.js의 가로 배치를 그대로 옮김.
# 논리 화면 1312×960 = 왼쪽 판(논리 540×680을 LS배로 키움) + 오른쪽 열(SIDE_X부터 540폭: 위 칸 + 아래 메뉴).
# 창(조합법·정보창·강화·외부탐사·더보기 …)은 windows.gd, 공격 연출은 fx.gd, 소리는 audio.gd. 아직 없는 것: 같이하기, 꾸미기, 첫 화면 꾸밈.
extends Control

const E = preload("res://scripts/engine/engine.gd")
const Gfx = preload("res://scripts/game/gfx.gd")
const Windows = preload("res://scripts/game/windows.gd")
const Fx = preload("res://scripts/game/fx.gd")
const Audio = preload("res://scripts/game/audio.gd")
const SAVE_PATH := "user://defense_save.json"
const SAVE_META := "user://defense_save_meta.json"
# 보스 등장 때 닫는 보조 창(웹 판과 같음): 일시정지·결과·보상 고르기처럼 일부러 연 큰 창은 그대로
const BOSS_CLOSE := ["book", "upgrade", "mission", "more", "storage", "recruit", "pick"]
const GOAL_COLOR := [Color("#4fd1e8"), Color("#f07ad8"), Color("#a6e05a")]
const FONT_PATH := "res://assets/fonts/workbench-noto-regular.otf"

const W := 540.0
const VH := 960.0
const LS := 960.0 / 680.0       # 왼쪽 판 확대 배율
const SIDE_X := 772.0           # 오른쪽 열 시작
const VW := SIDE_X + W          # 1312
const BASE_SPEED := 1.5         # 웹 판과 같은 기본 게임 속도
const GRADE_SIZE := [1, 1.06, 1.13, 1.22, 1.34, 1.4, 1.65, 1.65, 1.65, 1.65]
const C := Gfx.C
const GC := Gfx.GRADE_COLOR

var gfx: Gfx
var g: Dictionary = {}
var scene := "title"            # title · play
var paused := false
var speed := 1
var acc := 0.0
var selected: Array = []        # 고른 갈매미 번호들
var toast := {"msg": "", "t": -99.0}
var down := {}                  # 누르고 있는 중(끌기)
var sel_diff := "master"
var view_s := 1.0
var view_o := Vector2.ZERO
var freeze := false            # 화면 캡처용: 창 없이 시간만 멈춤
var modal: Dictionary = {}      # 열린 창(kind: book·upgrade·mission·more·pick·recruit·storage·choice)
var info: Dictionary = {}       # 갈매미 설명 창 {id, stack}
var wins: Windows
var search: LineEdit            # 조합법 이름 검색(창 위에 실제 입력칸을 겹침)
var fx: Fx
var audio: Audio
var watch := {"wave": 0, "warn": 0, "md": 0}   # 판이 바뀐 것을 보고 소리·보스 경고
var boss_warn := {"at": -99.0, "wave": 0}
var save_meta: Dictionary = {}  # 이어하기 정보(웨이브·난이도·저장 시각)
var save_at := 0.0


func _ready() -> void:
	var f = load(FONT_PATH)
	gfx = Gfx.new(self, f if f != null else ThemeDB.fallback_font)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	wins = Windows.new(self)
	search = LineEdit.new()
	search.placeholder_text = "이름 검색"
	search.visible = false
	search.clear_button_enabled = true
	if f != null:
		search.add_theme_font_override("font", f)
	search.text_changed.connect(func(t):
		wins.book_opt.q = t.strip_edges()
		if modal.get("kind") == "book":
			modal.scroll = 0.0)
	add_child(search)
	fx = Fx.new(gfx)
	audio = Audio.new()
	add_child(audio)
	save_meta = _read_json(SAVE_META)
	if not FileAccess.file_exists(SAVE_PATH):
		save_meta = {}


func start(diff: String) -> void:
	sel_diff = diff
	_begin(E.new_game(randi() & 0xFFFFFFFF, "normal", diff))


func _begin(game: Dictionary) -> void:
	g = game
	sel_diff = g.diff
	watch = {"wave": g.wave, "warn": g.warn, "md": g.missionDone}
	boss_warn = {"at": -99.0, "wave": 0}
	scene = "play"
	paused = false
	selected = []
	modal = {}
	info = {}
	acc = 0.0


func open_book(focus = null, using = null) -> void:
	modal = {"kind": "book", "scroll": 0.0, "scrollable": true, "focus": focus, "using": using}
	info = {}


func open(kind: String) -> void:
	modal = {"kind": kind, "scroll": 0.0}
	info = {}


func show_info(id: String, from_card: bool = false) -> void:   # 설명 안에서 재료를 누르면 그 재료로 파고들고 「뒤로」로 돌아옴
	if not E.UNIT.has(id):
		return
	var stack: Array = (info.stack + [info.id]) if (from_card and not info.is_empty()) else []
	info = {"id": id, "stack": stack}


# ── 이어하기(웹 판과 같은 저장 글자: E.save_game) ──
func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var o = JSON.parse_string(FileAccess.get_file_as_string(path))
	return o if typeof(o) == TYPE_DICTIONARY else {}


func save_now() -> void:
	if g.is_empty() or scene != "play" or g.over != null:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(E.save_game(g))
	f.close()
	save_meta = {"wave": g.wave, "diff": g.diff, "at": Time.get_unix_time_from_system()}
	var m := FileAccess.open(SAVE_META, FileAccess.WRITE)
	if m != null:
		m.store_string(JSON.stringify(save_meta))
		m.close()


func clear_save() -> void:
	for p in [SAVE_PATH, SAVE_META]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	save_meta = {}


func resume() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var game = E.load_game(FileAccess.get_file_as_string(SAVE_PATH))
	if game == null:
		say("저장한 판을 읽지 못했어요(규칙이 바뀌었을 수 있어요).")
		clear_save()
		return
	_begin(game)
	paused = true   # 이어하자마자 적이 밀려오지 않게 멈춘 채로
	say("이어하기: 웨이브 %d부터" % g.wave)


func _notification(what: int) -> void:
	# 앱이 뒤로 가거나(휴대폰) 창을 닫을 때 저장
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_now()


func combine(r: Dictionary, keep_uid: int = 0):
	var nu = E.combine(g, r, keep_uid)
	if nu != null:
		audio.play("combine")
	return nu


func sfx(name: String) -> void:
	audio.play(name)


func _watch() -> void:   # 판 상태가 바뀐 것을 보고 소리·보스 경고(웹 판 sfxTick)
	if g.wave != watch.wave:
		if E.wave_info(g.wave).boss:
			audio.play("boss")
			_boss_alarm()
		watch.wave = g.wave
	if g.warn > watch.warn:
		audio.play("warn")
	watch.warn = g.warn
	if g.missionDone > watch.md:
		audio.play("story")
	watch.md = g.missionDone
	for f in g.fx:
		if f.kind == "wisp" and not f.has("heard"):
			f.heard = true
			audio.play("wisp")


func _boss_alarm() -> void:   # 보스 등장: 판을 가리는 보조 창을 닫고 빨간 경고(2.6초)
	boss_warn = {"at": Time.get_ticks_msec() / 1000.0, "wave": g.wave}
	info = {}
	if BOSS_CLOSE.has(modal.get("kind", "")):
		modal = {}


func say(msg: String) -> void:
	toast = {"msg": msg, "t": Time.get_ticks_msec() / 1000.0}


func usz(id: String) -> float:
	return GRADE_SIZE[E.tier_of(id)]


func _process(delta: float) -> void:
	if scene == "play" and not paused and not freeze and g.over == null:
		acc += minf(delta, 0.1) * speed * BASE_SPEED
		while acc >= 0.05:
			E.step(g, 0.05)
			acc -= 0.05
		_watch()
		if g.over != null:
			clear_save()   # 끝난 판은 이어하기에서 지움
		elif Time.get_ticks_msec() / 1000.0 - save_at > 5.0:
			save_at = Time.get_ticks_msec() / 1000.0
			save_now()
		if g.get("choice") != null and not g.get("choiceLater", false) and modal.get("kind") != "choice" and (modal.is_empty() or modal.get("kind") == "mission"):
			modal = {"kind": "choice"}   # 6장 보상 고르기
			info = {}
		selected = selected.filter(func(uid):
			var u = E.unit_by_id(g, uid)
			return u != null and not u.away and not u.get("stored", false))
	queue_redraw()


# ── 그리기 ──
func _draw() -> void:
	view_s = minf(size.x / VW, size.y / VH)
	view_o = (size - Vector2(VW, VH) * view_s) / 2.0
	gfx.hits = []
	gfx.ox = view_o.x
	gfx.oy = view_o.y
	gfx.s = view_s
	draw_rect(Rect2(Vector2.ZERO, size), C.bg)
	if scene == "title" or g.is_empty():
		_draw_title()
		return
	gfx.push(0, 0, LS)
	_draw_field()
	_draw_hud()
	_draw_toast()
	gfx.pop()
	gfx.push(SIDE_X, 0, 1.0)
	if not modal.is_empty():
		wins.draw()
	else:
		_draw_side_top()
	_draw_bottom()
	if not info.is_empty():
		wins.draw_info()
	gfx.pop()
	var show_search: bool = modal.get("kind") == "book" and info.is_empty() and not paused and g.over == null
	search.visible = show_search
	if show_search:
		search.position = wins.search_rect.position
		search.size = wins.search_rect.size
		search.add_theme_font_size_override("font_size", maxi(10, int(16 * view_s)))
	_draw_boss_warn()
	if paused and g.over == null:
		_draw_pause()
	if g.over != null:
		_draw_over()


func _draw_boss_warn() -> void:
	var age: float = Time.get_ticks_msec() / 1000.0 - boss_warn.at
	if age > 2.6 or g.over != null:
		return
	var fade := minf(1.0, minf(age / 0.15, (2.6 - age) / 0.5))
	var pulse := 0.55 + 0.45 * absf(sin(age / 0.19))
	var a := 0.42 * pulse * fade
	var red := Color(1, 40 / 255.0, 40 / 255.0, a)
	var clear := Color(1, 40 / 255.0, 40 / 255.0, 0)
	var bw := minf(size.x, size.y) * 0.22   # 가장자리에서 안쪽으로 옅어지는 빨간 띠
	var S := size
	for q in [[Vector2(0, 0), Vector2(S.x, 0), Vector2(S.x - bw, bw), Vector2(bw, bw)], [Vector2(0, S.y), Vector2(S.x, S.y), Vector2(S.x - bw, S.y - bw), Vector2(bw, S.y - bw)],
			[Vector2(0, 0), Vector2(0, S.y), Vector2(bw, S.y - bw), Vector2(bw, bw)], [Vector2(S.x, 0), Vector2(S.x, S.y), Vector2(S.x - bw, S.y - bw), Vector2(S.x - bw, bw)]]:
		draw_polygon(PackedVector2Array(q), PackedColorArray([red, red, clear, clear]))
	draw_rect(Rect2(Vector2(3, 3), S - Vector2(6, 6)), Color(1, 90 / 255.0, 80 / 255.0, 0.8 * pulse * fade), false, 6)
	gfx.push(0, 0, LS)
	var bx := 30.0
	var by := 330.0
	gfx.box(bx, by, W - 60, 92, Color(60 / 255.0, 8 / 255.0, 10 / 255.0, 0.9 * fade), Color(1, 107 / 255.0, 107 / 255.0, (0.6 + 0.4 * pulse) * fade), 12, 3)
	gfx.fit_text("⚠ 보스 등장!", W / 2, by + 34, W - 90, 30, Color(1, 107 / 255.0, 107 / 255.0, fade), "center")
	gfx.fit_text("웨이브 %d · 방어 %s · %s초 안에 잡아야 해요" % [boss_warn.wave, E.fmt(E.armor_at(g, boss_warn.wave)), E.fmt(E.RULES.waveLen)], W / 2, by + 70, W - 90, 15, Color(1, 210 / 255.0, 200 / 255.0, fade), "center")
	gfx.pop()


func _draw_title() -> void:
	gfx.text("갈매미맨 랜덤 디펜스", VW / 2.0, 260, 54, C.goldEdge, "center")
	gfx.text("고도 판 · 시험 중", VW / 2.0, 320, 22, C.muted, "center")
	if not save_meta.is_empty():
		var dn: String = E.D.DIFFS.get(save_meta.get("diff", "master"), E.D.DIFFS.master).name
		gfx.button(VW / 2.0 - 220, 350, 440, 56, "이어하기", func(): resume(), "primary", true, "웨이브 %d · %s" % [int(save_meta.get("wave", 1)), dn])
	gfx.text("새로 시작: 난이도를 고르세요", VW / 2.0, 430, 20, C.text, "center")
	var keys: Array = E.D.DIFF_ORDER
	var bw := 200.0
	var x0 := VW / 2.0 - (bw * keys.size() + 12 * (keys.size() - 1)) / 2.0
	for i in keys.size():
		var key: String = keys[i]
		gfx.button(x0 + i * (bw + 12), 460, bw, 70, E.D.DIFFS[key].name, func(): start(key), "normal" if not save_meta.is_empty() else ("primary" if key == sel_diff else "normal"))
	_sound_buttons(VW / 2.0 - 220, 570)


func _draw_field() -> void:
	var FD: Dictionary = E.D.FIELD
	var L: Dictionary = E.LOOP
	# 바닥·길
	gfx.box(FD.x, FD.y, FD.w, FD.h, Color("#0c1c27"), C.edge, 12, 1.5)
	var lane := 40.0
	_rect_line(L.x0, L.y0, L.x1 - L.x0, L.y1 - L.y0, C.lane, lane)
	_rect_line(L.x0 - lane / 2, L.y0 - lane / 2, L.x1 - L.x0 + lane, L.y1 - L.y0 + lane, C.laneEdge, 1.5)
	_rect_line(L.x0 + lane / 2, L.y0 + lane / 2, L.x1 - L.x0 - lane, L.y1 - L.y0 - lane, C.laneEdge, 1.5)
	gfx.text("▼", L.x0, L.y0 + 2, 16, C.goldEdge, "center")
	gfx.ring(E.SPAWN.x, E.SPAWN.y, 34, Color(243 / 255.0, 216 / 255.0, 158 / 255.0, 0.25), 1.5)
	for sp in E.COMMON_SPOTS:
		gfx.ellipse(sp.x, sp.y, 22, 8, null, Color(154 / 255.0, 165 / 255.0, 173 / 255.0, 0.35), 1.5)
	# 고른 갈매미 사거리(한 마리일 때)
	var sel := sel_units()
	if sel.size() == 1:
		var k := E.kit(sel[0].id)
		gfx.circle(sel[0].x, sel[0].y - 14, k.range, Color(243 / 255.0, 216 / 255.0, 158 / 255.0, 0.07))
		gfx.ring(sel[0].x, sel[0].y - 14, k.range, Color(243 / 255.0, 216 / 255.0, 158 / 255.0, 0.55), 1.5)
	# 장판
	for z in g.zones:
		var a := minf(1.0, (z.until - g.t) / 0.4)
		gfx.ellipse(z.x, z.y - 6, z.r, z.r * 0.62, Color(0.78, 0.86, 1.0, 0.16 * a), Color(0.78, 0.86, 1.0, 0.6 * a), 2)
	# 적
	for e in g.enemies:
		var sz := 84.0 if e.boss else 44.0
		var t := gfx.enemy_tex(e.look)
		var ha: float = g.t - float(e.get("hitT", -9.0))
		var jit := (float((int(e.id) * 7) % 3) - 1.0) * 1.5 if ha < 0.07 else 0.0
		if t != null:
			gfx.draw_fit(t, e.x - sz / 2 + jit, e.y - sz * 0.75, sz, sz)
		else:
			gfx.circle(e.x, e.y - sz * 0.3, sz * 0.3, Color("#c98b6b"))
		if e.slow > 0:
			gfx.ring(e.x, e.y + 2, sz / 3.0, Color("#9fe8ff"), 1.5 + 2.5 * e.slow)
	# 갈매미(아래쪽부터)
	var list := E.field_units(g)
	list.sort_custom(func(a, b): return a.y < b.y)
	var last_shot := {}
	var goal_cols := _goal_colors()
	for f in g.fx:
		if f.kind == "shot" and f.get("uid", 0) != 0:
			var q = last_shot.get(f.uid)
			if q == null or q.t < f.t:
				last_shot[f.uid] = f
	for u in list:
		var unit: Dictionary = E.UNIT[u.id]
		var z := usz(u.id)
		var ox := 0.0
		var oy := 0.0
		var zm := 1.0
		var f = last_shot.get(u.uid)
		var a: float = g.t - f.t if f != null else 9.0
		if f != null and a < 0.18:   # 근접은 돌진, 원거리는 반동
			var dx: float = f.x1 - f.x0
			var dy: float = f.y1 - f.y0
			var d := maxf(1.0, sqrt(dx * dx + dy * dy))
			var w := sin(PI * a / 0.18)
			var m := minf(14.0, d * 0.25) if f.near else -3.0
			ox = dx / d * m * w
			oy = dy / d * m * w
			zm = 1.0 + 0.07 * w
		var is_sel := selected.has(u.uid)
		gfx.ellipse(u.x, u.y, 20 * z, 7 * z, Color(0, 0, 0, 0.35), Color.WHITE if is_sel else GC[unit.grade], 3.0 if is_sel else 2.0)
		var gcs: Array = goal_cols.get(u.id, [])
		for gk in gcs.size():
			gfx.ellipse(u.x, u.y, (24 + gk * 4) * z, (9 + gk * 2) * z, null, gcs[gk], 2.5)
		var zz := z * zm
		gfx.draw_fit(gfx.unit_tex(u.id), u.x + ox - 24 * zz, u.y + oy - 50 * zz, 48 * zz, 50 * zz)
		if u.get("lock", false):
			gfx.circle(u.x + 22 * z, u.y - 2, 8, Color(7 / 255.0, 19 / 255.0, 28 / 255.0, 0.9))
			gfx.text("🔒", u.x + 22 * z, u.y - 2, 10, C.goldEdge, "center")
		if g.t - u.born < 0.5:
			gfx.circle(u.x, u.y - 20 * z, 30 * z, Color(243 / 255.0, 216 / 255.0, 158 / 255.0, 0.35 * (1.0 - (g.t - u.born) / 0.5)))
	# 적 체력 칸·스턴 별(갈매미보다 위)
	for e in g.enemies:
		var sz := 84.0 if e.boss else 44.0
		var bw := 70.0 if e.boss else 32.0
		var by: float = e.y - sz * 0.75 - 6
		var below: bool = by < FD.y - 2
		if below:
			by = FD.y - 2
		gfx.box(e.x - bw / 2, by, bw, 5, Color(0, 0, 0, 0.6), null, 2)
		gfx.box(e.x - bw / 2, by, bw * maxf(0.0, e.hp / e.max), 5, Color("#ff6b6b") if e.boss else Color("#6fd08a"), null, 2)
		if g.t < e.stunUntil:
			gfx.text("★", e.x, by + 14 if below else by - 8, 12, Color("#ffe14a"), "center")
	# 겹친 갈매미 수
	var stacks := []
	for u in list:
		var z := usz(u.id)
		var found = null
		for st in stacks:
			if absf(st.x - u.x) < 14 and absf(st.y - u.y) < 14:
				found = st
				break
		if found != null:
			found.n += 1
			found.x = u.x
			found.y = u.y
			found.z = maxf(found.z, z)
		else:
			stacks.append({"x": u.x, "y": u.y, "n": 1, "z": z})
	for st in stacks:
		if st.n > 1:
			var by2: float = st.y - 50 * st.z - 4
			gfx.box(st.x + 10 * st.z, by2, 30, 20, Color(7 / 255.0, 19 / 255.0, 28 / 255.0, 0.9), C.goldEdge, 8, 1.5)
			gfx.text("×%d" % st.n, st.x + 10 * st.z + 15, by2 + 10.5, 13, C.goldEdge, "center")
	# 여러 마리 고르기 상자
	if down.get("box", false) and down.get("moved", false):
		gfx.box(minf(down.x0, down.x), minf(down.y0, down.y), absf(down.x - down.x0), absf(down.y - down.y0), Color(243 / 255.0, 216 / 255.0, 158 / 255.0, 0.08), C.goldEdge, 2, 1.5)
	_draw_fx()


func _goal_colors() -> Dictionary:   # 목표(☆) 조합법의 재료(가진 것 포함) → 목표 색들
	var out := {}
	for k in g.goals.size():
		var gid: String = g.goals[k]
		var r = E.recipe_for(gid)
		if r == null:
			continue
		var ids := {}
		for id in r.in:
			ids[id] = true
		var walk := func(n: Dictionary, self_fn: Callable) -> void:
			if n.have:
				ids[n.id] = true
			for c in n.kids:
				self_fn.call(c, self_fn)
		walk.call(wins.need_tree(gid, E.count_on_field(g)), walk)
		for id in ids:
			if not out.has(id):
				out[id] = []
			out[id].append(GOAL_COLOR[k])
	return out


func _rect_line(x: float, y: float, w: float, h: float, col: Color, lw: float) -> void:
	var p0 := gfx.P(x, y)
	draw_rect(Rect2(p0, Vector2(w, h) * gfx.s), col, false, maxf(1.0, lw * gfx.s))


func _draw_fx() -> void:
	fx.labels = []
	for f in g.fx:
		var age: float = g.t - f.t
		match f.kind:
			"shot":
				if age < 0.4:
					fx.draw_shot(f, age, g.t)
			"boom":
				if age < 0.28:
					var a := 1.0 - age / 0.28
					var rr: float = f.r * (0.55 + 0.45 * (1.0 - a))
					var base: Color = Color(1, 0.55, 0.27) if f.elem == "FIRE" else (Color(1, 0.7, 0.42) if f.type == "phys" else Color(0.56, 0.78, 1))
					gfx.circle(f.x, f.y - 10, rr, Color(base, (0.26 if f.area else 0.14) * a))
					gfx.ring(f.x, f.y - 10, rr, Color(base, 0.85 * a), 2.5 if f.area else 2.0)
			"zap":
				if age < 0.2:
					gfx.line(f.x0, f.y0 - 10, f.x1, f.y1 - 10, Color("#ffe14a"), 2)
			"combine":
				var a := maxf(0.0, 1.0 - age / 0.6)
				gfx.ring(f.x, f.y - 20, 20 + (1.0 - a) * 30, Color(C.goldEdge, a), 2.5)
			"wisp":
				var a := maxf(0.0, 1.0 - age / 0.8)
				gfx.text("✦", f.x, f.y - 20 - (1.0 - a) * 30, 22, Color(GC[f.grade], a), "center")
			"sig":
				if age < 0.75:
					fx.draw_sig(f, age)
			"num":
				if age < 0.75:
					var a := minf(1.0, (1.0 - age / 0.75) * 1.6)
					var big: bool = f.tier >= 6
					var sq: int = int(f.get("n", 0))
					var nx := clampf(f.x + float((sq * 23) % 60) - 30.0, 30.0, W - 30.0)
					var ny: float = f.y - 92 - (sq % 4) * 15 - age * 40
					gfx.text(_fmt_n(f.v), nx, ny, 19 if big else 15, Color(1.0, 0.84, 0.42, a) if big else Color(1.0, 0.95, 0.84, a), "center")


func _fmt_n(n: float) -> String:
	if n >= 1e8:
		return "%.1f억" % (n / 1e8)
	if n >= 1e4:
		return "%.1f만" % (n / 1e4)
	return str(int(roundf(n)))


func _draw_hud() -> void:
	gfx.box(8, 6, W - 16, 88, C.header, C.edge, 10)
	var wv := maxi(1, g.wave)
	var wi := E.wave_info(wv)
	var left := int(ceilf(E.next_wave_in(g)))
	gfx.text("웨이브 %d/%s" % [g.wave, E.fmt(E.RULES.waves)], 20, 28, 20, C.text)
	var armor := E.armor_at(g, wv)
	var mr := E.mr_at(g, wv)
	var cw := gfx.chip("%s방어 %s%s" % ["보스 " if wi.boss else "", E.fmt(armor), ("·마%s" % E.fmt(mr)) if mr != armor else ""], 150, 17, Color("#ff8a7a") if wi.boss else C.muted, 13)
	var sh := 0.0
	var msh := 0.0
	var sl := 0.0
	var stn := 0.0
	for u in E.field_units(g):
		var k := E.kit(u.id)
		sh += float(k.get("shred", 0.0))
		msh += float(k.get("mshred", 0.0))
		sl += float(k.get("slow", 0.0))
		stn += float(k.get("stun", 0.0)) + float(k.get("astun", 0.0))
	var okc := func(v: float, a: float) -> Color: return C.good if v >= a * 0.7 else (C.goldEdge if v >= a * 0.35 else C.bad)
	var sx := 150 + cw + 8
	var t1 := "깎기 물%d" % int(roundf(sh))
	gfx.text(t1, sx, 28, 12, okc.call(sh, armor))
	gfx.text(" · 마%d" % int(roundf(msh)), sx + gfx.text_w(t1, 12), 28, 12, okc.call(msh, mr))
	var rest := E.resting(g)
	var line2 := ""
	var col2: Color = C.muted
	if rest:
		line2 = "쉬는 시간 · 다음 웨이브까지 %d초" % left
		col2 = C.good
	elif wi.boss:
		if g.get("bossDone") == g.wave:
			line2 = "보스 처치! 다음 웨이브까지 %d초" % left
			col2 = C.good
		else:
			line2 = "보스를 %d초 안에 잡기" % int(ceilf(maxf(0.0, float(E.RULES.waveLen) - g.waveT)))
			col2 = C.bad if left <= 12 else Color("#ffc2a8")
	else:
		line2 = "다음 웨이브 %d초" % left
	gfx.text(line2, 20, 58, 15, col2)
	if g.wave < int(E.RULES.waves):
		var nx := E.wave_info(g.wave + 1)
		var na := E.armor_at(g, g.wave + 1)
		var lx := 20 + gfx.text_w(line2, 15) + 10
		var rf := 0.0 if nx.boss else E.rift_at(g.wave + 1)
		var nt := "▸ 다음 %s%s" % [("보스! 방어 %s" % E.fmt(na)) if nx.boss else ("방어 %s" % E.fmt(na)), (" · 균열 저항 %d%%" % int(roundf(rf * 100))) if rf > 0 else ""]
		gfx.fit_text(nt, lx, 58, W - 30 - lx, 14, Color("#ff8a7a") if nx.boss else (Color("#c9a3ff") if rf > 0 else (C.goldEdge if na > armor else C.muted)))
	var n: int = g.enemies.size()
	var lim := int(E.RULES.limit)
	var ratio := minf(1.0, float(n) / lim)
	gfx.text("적 %d/%d" % [n, lim], 20, 82, 14, C.bad if n > lim else C.text)
	gfx.box(92, 77, 150, 10, Color(0, 0, 0, 0.5), C.line, 5, 1)
	gfx.box(92, 77, 150 * ratio, 10, Color("#e0533f") if n > lim else (Color("#e8b04a") if ratio > 0.7 else Color("#6fd08a")), null, 5)
	gfx.text("경고 %d/%s" % [g.warn, E.fmt(E.RULES.warnMax)], 256, 82, 14, C.bad if g.warn > 0 else C.muted)
	gfx.draw_fit(gfx.tex("menu/currency-shrimp.webp"), 340, 64, 22, 22)
	var gold := E.fmt(int(g.gold))
	gfx.text(gold, 366, 76, 16, C.goldEdge)
	var gx := 366 + gfx.text_w(gold, 16) + 12
	var slp := int(roundf(minf(1.0, sl) * 100))
	var stp := int(roundf(stn * 100))
	var ta := "이감 %d%%" % slp
	gfx.text(ta, gx, 77, 12, C.good if slp >= 60 else (C.goldEdge if slp >= 30 else C.muted))
	gfx.text(" · 스턴 %d%%" % stp, gx + gfx.text_w(ta, 12), 77, 12, C.good if stp >= 30 else (C.goldEdge if stp > 0 else C.muted))
	gfx.button(W - 164, 12, 46, 40, "♪", func():
		audio.set_music(not audio.music_on)
		say("배경음악 켬" if audio.music_on else "배경음악 끔"), "primary" if audio.music_on else "normal")
	if not audio.music_on:   # 꺼짐: 음표 위에 빗금
		gfx.line(W - 164 + 12, 12 + 31, W - 164 + 34, 12 + 9, Color("#ff8a7a"), 2.5)
	gfx.button(W - 112, 12, 46, 40, "Ⅱ", func(): paused = true, "normal")
	gfx.button(W - 60, 12, 46, 40, "×%d" % speed, func(): speed = {1: 2, 2: 3, 3: 1}[speed], "normal")
	if g.news.size() > 0:
		var nw: Dictionary = g.news[g.news.size() - 1]
		if g.t - nw.t < 3.5:
			var tw := minf(W - 40, gfx.text_w(nw.msg, 15) + 28)
			gfx.box((W - tw) / 2, E.D.FIELD.y + 6, tw, 32, Color(19 / 255.0, 44 / 255.0, 59 / 255.0, 0.95), C.goldEdge, 8, 1.5)
			gfx.fit_text(nw.msg, W / 2, E.D.FIELD.y + 22, tw - 16, 15, C.goldEdge, "center")


func _draw_toast() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if toast.msg == "" or now - toast.t > 2.6:
		return
	var tw := minf(W - 40, gfx.text_w(toast.msg, 15) + 28)
	gfx.box((W - tw) / 2, 612, tw, 36, Color(19 / 255.0, 44 / 255.0, 59 / 255.0, 0.96), C.goldEdge, 8, 1.5)
	gfx.fit_text(toast.msg, W / 2, 630, tw - 16, 15, C.text, "center")


func _draw_side_top() -> void:   # 오른쪽 위: 이번 웨이브 피해 순위
	gfx.box(8, 6, W - 16, 658, C.panel, C.edge, 12)
	gfx.text("이번 웨이브 피해", 24, 30, 16, C.gold)
	var rows := []
	for uid in g.dmgWave:
		var u = E.unit_by_id(g, uid)
		if u != null:
			rows.append([u, float(g.dmgWave[uid])])
	rows.sort_custom(func(a, b): return a[1] > b[1])
	if rows.is_empty():
		gfx.text("아직 이번 웨이브에 피해를 준 갈매미가 없어요", W / 2, 80, 14, C.muted, "center")
		return
	var top: float = rows[0][1]
	for i in mini(12, rows.size()):
		var u: Dictionary = rows[i][0]
		var y := 52.0 + i * 50
		gfx.draw_fit(gfx.unit_tex(u.id), 22, y, 40, 42)
		gfx.fit_text(E.UNIT[u.id].name, 70, y + 12, 150, 15, GC[E.UNIT[u.id].grade])
		gfx.box(70, y + 26, 300, 10, Color(0, 0, 0, 0.45), null, 5)
		gfx.box(70, y + 26, 300 * rows[i][1] / maxf(1.0, top), 10, C.phys if E.kit(u.id).type == "phys" else C.mag, null, 5)
		gfx.text(_fmt_n(rows[i][1]), W - 30, y + 20, 15, C.text, "right")
		gfx.hit(16, y, W - 32, 46, func(): selected = [u.uid])


# ── 아래 메뉴 ──
func _draw_bottom() -> void:
	var y0 := 672.0
	gfx.box(8, y0, W - 16, VH - y0 - 8, C.panel, C.edge, 12)
	_decor_corners(8, y0, W - 16, VH - y0 - 8)
	var sel := sel_units()
	if sel.size() == 1:
		_draw_unit_panel(y0, sel[0])
	elif sel.size() > 1:
		_draw_group_panel(y0, sel)
	else:
		_draw_main_panel(y0)


func _decor_corners(x: float, y: float, w: float, h: float, sz: float = 46.0) -> void:
	var r := 216.0 / 256.0
	for pair in [["tl", x - 4, y - 4], ["tr", x + w - sz + 4, y - 4], ["bl", x - 4, y + h - sz * r + 4], ["br", x + w - sz + 4, y + h - sz * r + 4]]:
		var t := gfx.tex("ui/decor-corner-%s.webp" % pair[0])
		if t != null:
			draw_texture_rect(t, gfx.R(pair[1], pair[2], sz, sz * r), false, Color(1, 1, 1, 0.85))


func menu_button(x: float, y: float, w: float, h: float, icon: String, label: String, fn: Callable, style: String, sub: String, sub_col = null) -> void:
	var prim := style == "primary"
	if prim:
		gfx.box(x, y, w, h, Color("#e3c27f"), Color("#fff3cf"), 12, 2)
	else:
		gfx.box(x, y, w, h, Color("#163447"), C.gold, 12, 1.5)
	var tc: Color = C.ink if prim else C.text
	var sc: Color = sub_col if sub_col != null else (Color("#3d2f1a") if prim else C.muted)
	var isz := minf(h - 14, 44)
	var tx := x + 10 + isz + 8
	gfx.draw_fit(gfx.tex(icon + ".webp"), x + 10, y + (h - isz) / 2, isz, isz)
	gfx.fit_text(label, tx, y + h / 2 - 10, x + w - tx - 6, 17, tc)
	gfx.fit_text(sub, tx, y + h / 2 + 12, x + w - tx - 6, 13, sc)
	gfx.hit(x, y, w, h, fn)


func _badge(x: float, y: float, n: int) -> void:
	gfx.circle(x, y, 11, Color("#e0533f"))
	gfx.ring(x, y, 11, Color("#07131c"), 2)
	gfx.text(str(n), x, y + 0.5, 13, Color.WHITE, "center")


func _ready_count() -> int:
	var n := 0
	for r in E.RECIPES:
		if E.recipe_units(g, r) != null and not E.top_blocked(g, r):
			n += 1
	return n


func _draw_main_panel(y0: float) -> void:
	var ws: Array = E.D.WISP_GRADES
	var bw := (W - 44 - 4 * 6) / 5.0
	var wy := y0 + 30
	var wh := 60.0
	gfx.text("위습", 22, y0 + 18, 14, C.gold)
	for k in ws.size():
		var gr: String = ws[k]
		var n := int(g.wisps.get(gr, 0))
		var x := 22 + k * (bw + 6)
		var col: Color = GC[gr]
		gfx.box(x, wy, bw, wh, Color(11 / 255.0, 30 / 255.0, 42 / 255.0, 0.92 if n else 0.45), col if n else Color("#33434d"), 10, 2.0 if n else 1.0)
		if n:
			gfx.circle(x + bw * 0.3, wy + wh / 2, wh * 0.34, Color(col, 0.25))
		gfx.text("✦", x + bw * 0.3, wy + wh / 2 + 1, minf(30, wh * 0.42), col if n else Color("#3d4c55"), "center")
		gfx.fit_text(E.D.GRADE_NAME[gr], x + bw * 0.72, wy + wh * 0.32, bw * 0.5, 13, col if n else Color("#5b6a73"), "center")
		gfx.text(str(n), x + bw * 0.72, wy + wh * 0.68, minf(24, wh * 0.32), C.text if n else Color("#5b6a73"), "center")
		if n:
			gfx.hit(x, wy, bw, wh, func(): _summon(gr))
	var b2 := (W - 44 - 6) / 2.0
	var bh := 82.0
	var by := wy + wh + 10
	var by2 := by + bh + 8
	var rc := _ready_count()
	menu_button(22, by, b2, bh, "menu/icon-combine", "조합법", func(): open_book(), "primary" if rc else "normal", ("조합 가능 %d" % rc) if rc else ("%d개" % E.RECIPES.size()), Color("#1f5a3c") if rc else null)
	if rc:
		_badge(22 + b2 - 6, by + 6, rc)
	var can_up := false
	for gi in 8:
		if not E.upg_maxed(g, gi) and g.gold >= E.upgrade_cost(g, gi):
			can_up = true
	menu_button(28 + b2, by, b2, bh, "ui/icon-goldenstrike", "강화", func(): open("upgrade"), "normal", "강화 가능" if can_up else "새우 %s" % E.fmt(int(g.gold)), C.good if can_up else null)
	var away := E.away_units(g).size()
	var msub := "모두 완료" if g.missionDone >= E.REGIONS.size() else (("%d마리 탐사 중" % away) if away else ("%s장 가능" % E.fmt(E.REGIONS[g.missionDone].ch)))
	menu_button(22, by2, b2, bh, "menu/icon-explore", "외부탐사", func(): open("mission"), "normal", msub)
	var mc := wins.pick_count() + (1 if int(g.tickets) >= int(E.RULES.recruitCost) else 0) + (1 if g.get("choice") != null else 0)
	var msub2 := "보상 고르기" if g.get("choice") != null else (("선택위습 %d" % wins.pick_count()) if wins.pick_count() > 0 else "선택위습·모집·창고")
	menu_button(28 + b2, by2, b2, bh, "menu/icon-draw", "더보기", func(): open("more"), "primary" if mc > 0 else "normal", msub2, Color("#3d2f1a") if mc > 0 else null)
	if mc > 0:
		_badge(28 + b2 + b2 - 6, by2 + 6, mc)


func _summon(gr: String) -> void:
	var res := E.summon(g, gr)
	if res.ok:
		audio.play("summon")
	elif res.why != "":
		say(res.why)


func _sound_buttons(x: float, y: float) -> void:   # 배경음악 켜기/끄기 · 효과음 크기
	gfx.button(x, y, 214, 48, "배경음악 %s" % ("켬" if audio.music_on else "끔"), func(): audio.set_music(not audio.music_on), "primary" if audio.music_on else "normal")
	var vols := [0.0, 0.25, 0.5, 1.0]
	var k := vols.find(audio.sfx_vol)
	gfx.button(x + 226, y, 214, 48, "효과음 %s" % ("끔" if audio.sfx_vol <= 0 else "%d%%" % int(audio.sfx_vol * 100)), func():
		audio.set_sfx_vol(vols[(k + 1) % vols.size()] if k >= 0 else 0.5)
		audio.play("summon"), "normal")


func _tip_lines(tips: Array, x: float, y0: float, max_w: float, col: Color) -> void:
	var cx := x
	var cy := y0 + 66
	for t in tips:
		var w := gfx.text_w(t, 12) + 12
		if cx + w > x + max_w:
			cx = x
			cy += 22
			if cy > y0 + 88:
				return
		gfx.box(cx, cy, w, 18, Color(0, 0, 0, 0.35), col, 6, 1)
		gfx.text(t, cx + w / 2, cy + 9.5, 12, col, "center")
		cx += w + 4


func _draw_unit_panel(y0: float, u: Dictionary) -> void:
	var unit: Dictionary = E.UNIT[u.id]
	var k := E.kit(u.id)
	gfx.draw_fit(gfx.unit_tex(u.id), 18, y0 + 8, 68, 70)
	gfx.hit(18, y0 + 8, 68, 70, func(): show_info(u.id))
	gfx.fit_text(unit.name, 94, y0 + 22, 150, 21, C.text)
	var cx := 94 + minf(150, gfx.text_w(unit.name, 21)) + 8
	cx += gfx.chip(E.D.GRADE_NAME[unit.grade], cx, y0 + 11, GC[unit.grade]) + 6
	var special := bool(k.get("special", false))
	var tcol: Color = C.goldEdge if special else (C.phys if k.type == "phys" else C.mag)
	gfx.chip("조합 재료" if special else "%s %s" % ["물딜" if k.type == "phys" else "마딜", k.job], cx, y0 + 11, tcol)
	if special:
		gfx.fit_text("공격하지 않아요 · 초월 등급 조합 재료", 94, y0 + 50, W - 210, 15, C.muted)
	else:
		var gp := E.gap_of(g, k)
		var spd_word := "빠름" if gp * float(E.RULES.atkSpeed) <= 0.6 else ("느림" if gp * float(E.RULES.atkSpeed) >= 1.1 else "보통")
		gfx.fit_text("공격 %d · %s(%.2f초) · 사거리 %s" % [int(roundf(k.dmg * E.upg_mul(g, k.tier))), spd_word, gp, E.fmt(k.range)], 94, y0 + 50, W - 210, 15, C.muted)
	_tip_lines(E.kit_tips(k), 94, y0, W - 210, tcol)
	gfx.button(W - 112, y0 + 10, 90, 40, "닫기", func(): selected = [], "quiet")
	if E.tier_of(u.id) >= 3 and u.get("got", false) and unit.role != E.SPECIAL_ROLE:
		var ok := E.can_reroll(g, u)
		gfx.button(W - 222, y0 + 10, 104, 40, "리롤 (%d)" % int(g.rerolls), func():
			var was: String = unit.name
			var nu = E.reroll_unit(g, u.uid)
			say(("리롤: %s → %s" % [was, E.UNIT[nu.id].name]) if nu != null else "리롤권이 없어요. 10웨이브 보스마다 1개 받아요."), "primary" if ok else "normal")
	# 이 갈매미로 만들 수 있는 것(만들 수 있는 것 먼저)
	var list := []
	for r in E.recipes_using(u.id):
		list.append([r, E.recipe_units(g, r, u.uid) != null and not E.top_blocked(g, r)])
	list = E.stable_sort(list, func(p): return (0 if p[1] else 100) + E.tier_of(p[0].out))
	gfx.text("이 갈매미로 만들 수 있는 것" if list.size() > 0 else "이 갈매미가 들어가는 조합법이 없어요", 22, y0 + 100, 15, C.gold)
	var BH := 44.0
	var b6 := (W - 44 - 12) / 3.0
	var by2 := VH - 16 - BH
	var by1 := by2 - 6 - BH
	var rows_n := maxi(1, mini(4, int((by1 - 6 - (y0 + 112)) / 50)))
	var cnt := E.count_on_field(g)
	for i in mini(rows_n, list.size()):
		wins.recipe_row(list[i][0], list[i][1], 18, y0 + 112 + i * 50, W - 36, 46, cnt, u.uid)
	var bx := func(i: int) -> float: return 22 + (i % 3) * (b6 + 6)
	gfx.button(bx.call(0), by1, b6, BH, ("조합법 +%d" % (list.size() - rows_n)) if list.size() > rows_n else "조합법", func(): open_book(null, u.id), "normal")
	gfx.button(bx.call(1), by1, b6, BH, "모으기", func():
		selected = E.gather(g, u.uid)
		say("같은 %s %d마리를 모았어요(고정한 것은 그 자리)." % [unit.name, selected.size()]), "normal")
	var locked: bool = u.get("lock", false)
	gfx.button(bx.call(2), by1, b6, BH, "고정 풀기" if locked else "위치 고정", func():
		E.set_lock(g, [u.uid], not locked)
		say("고정을 풀었어요." if locked else "위치를 고정했어요. 끌어도 안 움직여요."), "primary" if locked else "normal")
	gfx.button(bx.call(3), by2, b6, BH, "창고로", func():
		E.store(g, [u.uid])
		selected = []
		say("%s을(를) 창고에 넣었어요(조합 재료로는 쓰여요)." % unit.name), "normal")
	gfx.button(bx.call(4), by2, b6, BH, "탐사", func(): send([u]), "normal", E.mission_open(g))
	if special or k.tier >= E.TOP_TIER:
		gfx.button(bx.call(5), by2, b6, BH, "판매 불가", func(): pass, "normal", false)
	else:
		gfx.button(bx.call(5), by2, b6, BH, "판매+%s" % E.fmt(k.sell), func():
			E.sell(g, u.uid)
			selected = [], "danger")


func _draw_group_panel(y0: float, sel: Array) -> void:
	var p := 0
	var m := 0
	for u in sel:
		if E.kit(u.id).type == "phys":
			p += 1
		else:
			m += 1
	gfx.text("갈매미 %d마리 고름" % sel.size(), 22, y0 + 24, 20, C.text)
	gfx.text("물딜 %d · 마딜 %d" % [p, m], 22, y0 + 52, 15, C.muted)
	gfx.button(W - 112, y0 + 10, 90, 40, "해제", func(): selected = [], "quiet")
	var BH := 46.0
	var by := VH - 18 - BH
	var avail := by - 8 - (y0 + 62)
	var sz := maxf(60.0, minf(84.0, floorf(avail / 2.0) - 8))
	var per := int((W - 44 + 8) / (sz + 8))
	var rows := maxi(1, int((avail + 8) / (sz + 8)))
	var shown := per * rows
	for i in mini(shown, sel.size()):
		var u: Dictionary = sel[i]
		var x := 22 + (i % per) * (sz + 8)
		var y := y0 + 62 + int(i / per) * (sz + 8)
		gfx.box(x, y, sz, sz, Color(11 / 255.0, 30 / 255.0, 42 / 255.0, 0.85), GC[E.UNIT[u.id].grade], 6, 1.5)
		gfx.draw_fit(gfx.unit_tex(u.id), x + 2, y + 2, sz - 4, sz - 4)
		gfx.hit(x, y, sz, sz, func(): selected = [u.uid])
	if sel.size() > shown:
		gfx.text("외 %d마리" % (sel.size() - shown), W - 124, y0 + 30, 14, C.muted, "right")
	var b4 := (W - 44 - 18) / 4.0
	var all_lock := sel.all(func(u): return u.get("lock", false))
	var uids := sel.map(func(u): return u.uid)
	gfx.button(22, by, b4, BH, "탐사 보내기 (%d)" % sel.size(), func(): send(sel), "normal", E.mission_open(g))
	gfx.button(22 + (b4 + 6), by, b4, BH, "창고로 (%d)" % sel.size(), func():
		var n := E.store(g, uids)
		selected = []
		say("%d마리를 창고에 넣었어요." % n), "normal")
	gfx.button(22 + 2 * (b4 + 6), by, b4, BH, ("고정 풀기 (%d)" if all_lock else "위치 고정 (%d)") % sel.size(), func():
		var n := E.set_lock(g, uids, not all_lock)
		say(("%d마리 고정을 풀었어요." if all_lock else "%d마리 위치를 고정했어요.") % n), "primary" if all_lock else "normal")
	gfx.button(22 + 3 * (b4 + 6), by, b4, BH, "고르기 해제", func(): selected = [], "quiet")


func send(units: Array) -> void:
	var n := E.send_away(g, units.map(func(u): return u.uid))
	selected = []
	say(("%d마리를 외부탐사에 보냈어요." % n) if n > 0 else "보낼 수 있는 갈매미가 없어요.")


func sel_units() -> Array:
	var out := []
	for uid in selected:
		var u = E.unit_by_id(g, uid)
		if u != null and not u.away and not u.get("stored", false):
			out.append(u)
	return out


func _draw_pause() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(3 / 255.0, 9 / 255.0, 14 / 255.0, 0.7))
	gfx.box(VW / 2 - 240, 300, 480, 370, C.panel, C.edge, 14, 2)
	gfx.text("일시정지", VW / 2, 360, 30, C.goldEdge, "center")
	gfx.button(VW / 2 - 200, 410, 400, 64, "계속하기", func(): paused = false, "primary")
	gfx.button(VW / 2 - 200, 490, 400, 56, "저장하고 처음 화면으로", func():
		save_now()
		paused = false
		scene = "title", "normal")
	_sound_buttons(VW / 2 - 220, 600)


func _draw_over() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(3 / 255.0, 9 / 255.0, 14 / 255.0, 0.72))
	var win: bool = g.over == "win"
	gfx.box(VW / 2 - 300, 280, 600, 320, C.panel, C.goldEdge if win else C.edge, 14, 2)
	gfx.text("클리어!" if win else "게임 끝", VW / 2, 340, 34, C.goldEdge if win else C.bad, "center")
	gfx.fit_text(g.reason, VW / 2, 400, 540, 18, C.text, "center")
	gfx.text("웨이브 %d · 처치 %d · 외부탐사 %d장" % [g.wave, g.kills, g.missionDone], VW / 2, 470, 16, C.muted, "center")
	gfx.button(VW / 2 - 200, 510, 190, 60, "다시 하기", func(): start(sel_diff), "primary")
	gfx.button(VW / 2 + 10, 510, 190, 60, "처음 화면", func(): scene = "title", "normal")


# ── 입력: 누르기(버튼) · 갈매미 끌어 옮기기 · 빈 곳 끌어 여러 마리 고르기 ──
func _board_pos(p: Vector2) -> Vector2:   # 화면 → 판 논리 좌표
	return (p - view_o) / (view_s * LS)


func _unit_at(bp: Vector2):
	var best = null
	var best_d := INF
	for u in E.field_units(g):
		var z := usz(u.id)
		var d := bp.distance_to(Vector2(u.x, u.y - 22 * z))
		if d < 28 * z and d < best_d:
			best_d = d
			best = u
	return best


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and (ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		if modal.get("maxScroll", 0.0) > 0:
			modal.scroll = clampf(float(modal.get("scroll", 0.0)) + (60.0 if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN else -60.0), 0.0, modal.maxScroll)
		accept_event()
		return
	var pressed := false
	var released := false
	var moved := false
	var pos := Vector2.ZERO
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		pos = ev.position
		pressed = ev.pressed
		released = not ev.pressed
	elif ev is InputEventMouseMotion and down.size() > 0:
		pos = ev.position
		moved = true
	elif ev is InputEventScreenTouch:
		pos = ev.position
		pressed = ev.pressed
		released = not ev.pressed
	elif ev is InputEventScreenDrag and down.size() > 0:
		pos = ev.position
		moved = true
	else:
		return
	accept_event()
	if pressed:
		var h = gfx.hit_at(pos)
		if h != null:   # 버튼·창: 손을 뗄 때 누름(끌면 스크롤)
			down = {"hit": h, "p0": pos, "moved": false, "scroll0": float(modal.get("scroll", 0.0))}
			return
		if scene != "play" or g.over != null or paused:
			return
		var bp := _board_pos(pos)
		var FD: Dictionary = E.D.FIELD
		if bp.x < FD.x or bp.x > FD.x + FD.w or bp.y < FD.y or bp.y > FD.y + FD.h:
			return
		var u = _unit_at(bp)
		if u != null:
			if not selected.has(u.uid):
				selected = [u.uid]
			down = {"unit": u.uid, "x0": bp.x, "y0": bp.y, "x": bp.x, "y": bp.y, "moved": false, "start": {}}
			for uid in selected:
				var su = E.unit_by_id(g, uid)
				if su != null:
					down.start[uid] = [su.x, su.y]
		else:
			down = {"box": true, "x0": bp.x, "y0": bp.y, "x": bp.x, "y": bp.y, "moved": false}
	elif moved:
		if down.has("hit"):
			var dy: float = pos.y - down.p0.y
			if absf(dy) + absf(pos.x - down.p0.x) > 10 * maxf(1.0, view_s):
				down.moved = true
			if down.moved and modal.get("maxScroll", 0.0) > 0:
				modal.scroll = clampf(down.scroll0 - dy / view_s, 0.0, modal.maxScroll)
			return
		var bp := _board_pos(pos)
		down.x = bp.x
		down.y = bp.y
		if absf(bp.x - down.x0) + absf(bp.y - down.y0) > 8:
			down.moved = true
		if down.moved and down.has("unit"):
			var dx: float = bp.x - down.x0
			var dyy: float = bp.y - down.y0
			for uid in down.start:
				E.move_unit(g, uid, down.start[uid][0] + dx, down.start[uid][1] + dyy, true)
	elif released and down.size() > 0:
		if down.has("hit"):
			if not down.moved:
				down.hit.fn.call()
		elif down.get("box", false):
			if down.moved:
				var x0 := minf(down.x0, down.x)
				var x1 := maxf(down.x0, down.x)
				var y0 := minf(down.y0, down.y)
				var y1 := maxf(down.y0, down.y)
				selected = []
				for u in E.field_units(g):
					if u.x >= x0 and u.x <= x1 and u.y >= y0 and u.y <= y1:
						selected.append(u.uid)
			else:
				selected = []
		down = {}


func _unhandled_key_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed) or scene != "play":
		return
	match ev.keycode:
		KEY_SPACE, KEY_P:
			paused = not paused
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			_summon(E.D.WISP_GRADES[ev.keycode - KEY_1])
		KEY_ESCAPE:
			if not info.is_empty():
				info = {}
			elif not modal.is_empty():
				modal = {}
			else:
				selected = []
		KEY_B:
			if modal.get("kind") == "book": modal = {}
			else: open_book()
		KEY_U:
			open("upgrade")
		KEY_M:
			open("mission")
