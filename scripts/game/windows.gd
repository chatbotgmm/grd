# 창들(2단계-2): 웹 판 defense.js의 조합법·정보창(재료 나무)·강화·외부탐사·더보기·선택위습·용병모집·창고·보상 고르기를 옮김.
# 가로 화면에서 창은 오른쪽 위(「이번 웨이브 피해」 자리, 0~664)에 열리고 아래 메뉴는 그대로 보인다. 게임은 계속 흐른다.
# v = 게임 화면(game_view.gd). 판 상태·고른 갈매미·알림은 v에 있다.
extends RefCounted

const E = preload("res://scripts/engine/engine.gd")
const Gfx = preload("res://scripts/game/gfx.gd")
const C := Gfx.C
const GC := Gfx.GRADE_COLOR
const W := 540.0
const MENU_Y := 664.0
const GOAL_COLOR := [Color("#4fd1e8"), Color("#f07ad8"), Color("#a6e05a")]
const ROLES := [["all", "전체"], ["phys", "물리딜러"], ["mag", "마법딜러"], ["shred", "방깍"], ["mshred", "마방깍"], ["slow", "이감"], ["stun", "스턴"], ["explore", "탐사"], ["etc", "기타"]]

var v
var gfx: Gfx
var book_roles := {}
var book_opt := {"ready": false, "near": false, "q": ""}
var search_rect := Rect2()   # 검색 입력칸 자리(화면 좌표, 게임 화면이 LineEdit을 겹침)


func _init(view) -> void:
	v = view
	gfx = view.gfx


func rect() -> Dictionary:
	return {"x": 14.0, "y": 8.0, "w": W - 28, "h": MENU_Y - 12}


func shade(a: float) -> void:
	gfx.rect(0, 0, W, MENU_Y, Color(3 / 255.0, 9 / 255.0, 14 / 255.0, a))
	gfx.hit(0, 0, W, MENU_Y, func(): pass)


func close_btn(x: float, y: float, w: float) -> void:
	gfx.button(x + w - 96, y + 10, 82, 40, "닫기", func(): v.modal = {}, "quiet")


func can_make(r: Dictionary, keep: int = 0) -> bool:
	return E.recipe_units(v.g, r, keep) != null and not E.top_blocked(v.g, r)


func roles_of(id: String) -> Array:
	var k := E.kit(id)
	var r := []
	if k.job == "주력": r.append("phys" if k.type == "phys" else "mag")
	if E.truthy(k.get("shred")): r.append("shred")
	if E.truthy(k.get("mshred")): r.append("mshred")
	if E.truthy(k.get("slow")): r.append("slow")
	if E.truthy(k.get("stun")) or E.truthy(k.get("astun")): r.append("stun")
	if E.truthy(k.get("explore")): r.append("explore")
	var util := E.truthy(k.get("shred")) or E.truthy(k.get("mshred")) or E.truthy(k.get("slow")) or E.truthy(k.get("stun")) or E.truthy(k.get("astun")) or E.truthy(k.get("explore"))
	if r.is_empty() or (k.job != "주력" and not util): r.append("etc")
	return r


func have_n(r: Dictionary, cnt: Dictionary) -> int:
	var left := cnt.duplicate()
	var n := 0
	for id in r.in:
		if int(left.get(id, 0)) > 0:
			left[id] -= 1
			n += 1
	return n


func draw() -> void:
	match v.modal.get("kind", ""):
		"book": _book()
		"mission": _mission()
		"upgrade": _upgrade()
		"more": _more()
		"pick": _pick()
		"recruit": _recruit()
		"storage": _storage()
		"choice": _choice()


# 스크롤 목록: 위·아래로 벗어난 줄은 그리지 않음(누르기 영역도 함께 빠짐). 스크롤 막대
func _scrollbar(x: float, top: float, view_h: float, total: float) -> void:
	if v.modal.get("maxScroll", 0.0) > 0:
		var bh := maxf(40.0, view_h * view_h / total)
		var by: float = top + (view_h - bh) * (v.modal.scroll / v.modal.maxScroll)
		gfx.box(x, by, 4, bh, Color(243 / 255.0, 216 / 255.0, 158 / 255.0, 0.5), null, 2)


# ── 조합법 ──
func _book() -> void:
	shade(0.35)
	var R := rect()
	var x: float = R.x
	var y: float = R.y
	var w: float = R.w
	var h: float = R.h
	gfx.box(x, y, w, h, C.panel, C.goldEdge, 14, 2)
	var using = v.modal.get("using")
	gfx.fit_text(("%s 재료" % E.UNIT[using].name) if using != null else "조합법", x + 18, y + 30, 120, 20, C.text)
	close_btn(x, y, w)
	gfx.box(x + 144, y + 12, w - 144 - 108, 36, Color("#0b1e2a"), C.edge, 8, 1.5)
	search_rect = gfx.R(x + 144, y + 12, w - 144 - 108, 36)
	var tw2 := (w - 24 - 6) / 2.0
	var opts := [["ready", "만들 수 있는 것만"], ["near", "재료 많이 모인 순"]]
	for i in 2:
		var key: String = opts[i][0]
		var on: bool = book_opt[key]
		var bx := x + 12 + i * (tw2 + 6)
		gfx.box(bx, y + 90, tw2, 28, Color(111 / 255.0, 208 / 255.0, 138 / 255.0, 0.16) if on else Color(11 / 255.0, 30 / 255.0, 42 / 255.0, 0.8), Color("#6fd08a") if on else Color(145 / 255.0, 122 / 255.0, 76 / 255.0, 0.45), 8, 2.0 if on else 1.0)
		gfx.fit_text(("✓ " if on else "") + opts[i][1], bx + tw2 / 2, y + 104, tw2 - 8, 13, C.good if on else C.muted, "center")
		gfx.hit(bx, y + 90, tw2, 28, func():
			book_opt[key] = not book_opt[key]
			v.modal.scroll = 0.0)
	var cw := (w - 24 - (ROLES.size() - 1) * 4) / ROLES.size()
	for i in ROLES.size():
		var key: String = ROLES[i][0]
		var on: bool = book_roles.is_empty() if key == "all" else book_roles.has(key)
		var bx := x + 12 + i * (cw + 4)
		gfx.box(bx, y + 54, cw, 30, Color(243 / 255.0, 216 / 255.0, 158 / 255.0, 0.18) if on else Color(11 / 255.0, 30 / 255.0, 42 / 255.0, 0.8), C.goldEdge if on else Color(145 / 255.0, 122 / 255.0, 76 / 255.0, 0.45), 8, 2.0 if on else 1.0)
		gfx.fit_text(ROLES[i][1], bx + cw / 2, y + 69, cw - 6, 13, C.goldEdge if on else C.muted, "center")
		gfx.hit(bx, y + 54, cw, 30, func():
			if key == "all":
				book_roles.clear()
			elif book_roles.has(key):
				book_roles.erase(key)
			else:
				book_roles[key] = true
			v.modal.scroll = 0.0)
	var top := y + 126
	var view_h := h - 136
	var cnt := E.count_on_field(v.g)
	var q: String = book_opt.q
	var rows := []
	for r in E.RECIPES:
		if using != null and not r.in.has(using):
			continue
		if not book_roles.is_empty():
			var ro := roles_of(r.out)
			if not book_roles.keys().all(func(k): return ro.has(k)):
				continue
		if q != "" and not E.UNIT[r.out].name.contains(q) and not r.in.any(func(id): return E.UNIT[id].name.contains(q)):
			continue
		var ok := can_make(r)
		if book_opt.ready and not ok:
			continue
		rows.append({"r": r, "ok": ok, "frac": float(have_n(r, cnt)) / r.in.size()})
	var items := []
	if book_opt.near:
		rows = E.stable_sort(rows, func(it): return -it.frac * 100 - E.tier_of(it.r.out))
		items = rows
	else:
		rows = E.stable_sort(rows, func(it): return E.tier_of(it.r.out) * 10 + (0 if it.ok else 1))
		var last := ""
		for it in rows:
			var gr: String = E.UNIT[it.r.out].grade
			if gr != last:
				items.append({"head": gr})
				last = gr
			items.append(it)
	if items.is_empty():
		gfx.fit_text(("「%s」에 맞는 조합법이 없어요" % q) if q != "" else "해당하는 조합법이 없어요", W / 2, top + 50, w - 40, 15, C.muted, "center")
	var total := 0.0
	for it in items:
		total += 30.0 if it.has("head") else 52.0
	v.modal.maxScroll = maxf(0.0, total - view_h)
	if v.modal.get("focus") != null and not v.modal.get("focused", false):
		var yy0 := 0.0
		for it in items:
			if it.has("r") and it.r.out == v.modal.focus:
				break
			yy0 += 30.0 if it.has("head") else 52.0
		v.modal.scroll = minf(v.modal.maxScroll, maxf(0.0, yy0 - 60))
		v.modal.focused = true
	v.modal.scroll = clampf(float(v.modal.get("scroll", 0.0)), 0.0, v.modal.maxScroll)
	var yy: float = top - v.modal.scroll
	for it in items:
		var rh := 30.0 if it.has("head") else 52.0
		if yy >= top - 1 and yy + rh <= top + view_h + 1:
			if it.has("head"):
				gfx.text(E.D.GRADE_NAME[it.head], x + 20, yy + 17, 15, GC[it.head])
				gfx.rect(x + 80, yy + 17, w - 110, 1, Color(145 / 255.0, 122 / 255.0, 76 / 255.0, 0.35))
			else:
				recipe_row(it.r, it.ok, x + 12, yy + 3, w - 24, rh - 6, cnt)
		yy += rh
	_scrollbar(x + w - 8, top, view_h, total)


func recipe_row(r: Dictionary, ok: bool, x: float, y: float, w: float, h: float, cnt: Dictionary, keep_uid: int = 0) -> void:
	var out: Dictionary = E.UNIT[r.out]
	var gi: int = v.g.goals.find(r.out)
	gfx.hit(x, y, w, h, func(): v.show_info(r.out))
	var edge: Color = GOAL_COLOR[gi] if gi >= 0 else (Color("#2b7a62") if ok else Color(145 / 255.0, 122 / 255.0, 76 / 255.0, 0.4))
	gfx.box(x, y, w, h, Color(43 / 255.0, 122 / 255.0, 98 / 255.0, 0.25) if ok else Color(11 / 255.0, 30 / 255.0, 42 / 255.0, 0.7), edge, 8, 2.5 if gi >= 0 else 1.5)
	gfx.draw_fit(gfx.unit_tex(r.out), x + 4, y + 2, 40, h - 4)
	gfx.fit_text(out.name, x + 50, y + 15, 92, 16, GC[out.grade])
	gfx.text(E.D.GRADE_NAME[out.grade] + (" · 히든 조합" if r.get("hidden", false) else ""), x + 50, y + 34, 12, C.muted)
	var left := cnt.duplicate()
	var x0 := x + 150
	var lines := 2 if r.in.size() > 4 else 1
	var per := int(ceilf(float(r.in.size()) / lines))
	var ch := 19.0 if lines == 2 else 24.0
	var fs := 12.0 if lines == 2 else 14.0
	var chip_max := (x + w - 112 - x0) / per - 4
	var cx := x0
	for idx in r.in.size():
		var id: String = r.in[idx]
		var ln := int(idx / per)
		var cy0 := (y + h / 2 - ch - 1 + ln * (ch + 2)) if lines == 2 else (y + h / 2 - ch / 2)
		if idx % per == 0:
			cx = x0
		var has_it := int(left.get(id, 0)) > 0
		if has_it:
			left[id] -= 1
		var t: String = E.UNIT[id].name
		var tw := minf(chip_max, gfx.text_w(t, fs) + 12)
		var gcol: Color = GC[E.UNIT[id].grade]
		gfx.hit(cx, cy0, tw, ch, func(): v.show_info(id))
		gfx.box(cx, cy0, tw, ch, Color(111 / 255.0, 208 / 255.0, 138 / 255.0, 0.22) if has_it else Color(0, 0, 0, 0.35), gcol, 6, 2.0 if has_it else 1.3)
		gfx.fit_text(t, cx + tw / 2, cy0 + ch / 2, tw - 6, fs, gcol, "center")
		cx += tw + 4
	var bx := x + w - 108
	gfx.button(bx, y + 5, 40, h - 10, "★" if gi >= 0 else "☆", func():
		var on := E.toggle_goal(v.g, r.out)
		v.say(("목표: %s (재료에 색 테두리)" % out.name) if on else "목표에서 뺐어요"), "quiet")
	var capped := E.top_blocked(v.g, r)
	gfx.button(bx + 46, y + 5, 58, h - 10, ("상위%s" % E.fmt(E.RULES.topCap)) if capped else "조합", func():
		var nu = v.combine(r, keep_uid)
		if nu != null:
			v.selected = [nu.uid]
			v.say("%s 완성!" % out.name), "primary", ok)


# ── 정보창(재료 나무) ──
func need_tree(id: String, cnt: Dictionary) -> Dictionary:
	var pool := cnt.duplicate()
	var node := func(c: String, depth: int, self_fn: Callable) -> Dictionary:
		if int(pool.get(c, 0)) > 0:
			pool[c] -= 1
			return {"id": c, "have": true, "kids": []}
		var r = E.recipe_for(c) if depth < 8 else null
		var kids := []
		if r != null:
			for x in r.in:
				kids.append(self_fn.call(x, depth + 1, self_fn))
		return {"id": c, "have": false, "kids": kids}
	var r = E.recipe_for(id)
	var kids := []
	if r != null:
		for x in r.in:
			kids.append(node.call(x, 1, node))
	return {"id": id, "have": false, "top": true, "kids": kids}


func _tree_layout(root: Dictionary, avail_w: float) -> int:
	var vis := func(n: Dictionary, d: int, md: int, self_fn: Callable) -> int:
		n.d = d
		n.show = n.kids if (d < md and not n.have) else []
		n.more = not n.have and n.kids.size() > 0 and n.show.is_empty()
		var leaves := 0
		for c in n.show:
			leaves += self_fn.call(c, d + 1, md, self_fn)
		n.leaves = leaves if leaves > 0 else 1
		return n.leaves
	var md := 3
	while md > 1 and vis.call(root, 0, md, vis) * 46 > avail_w:
		md -= 1
	vis.call(root, 0, md, vis)
	var depth := [0]
	var walk := func(n: Dictionary, self_fn: Callable) -> void:
		depth[0] = maxi(depth[0], n.d)
		for c in n.show:
			self_fn.call(c, self_fn)
	walk.call(root, walk)
	return depth[0]


func _check(cx: float, cy: float, r: float, fill: Color, mark: String) -> void:
	gfx.circle(cx, cy, r, fill)
	gfx.ring(cx, cy, r, Color("#07131c"), 1.5)
	var ink := Color("#07131c")
	if mark == "v":
		gfx.line(cx - r * 0.45, cy, cx - r * 0.1, cy + r * 0.4, ink, 2.2)
		gfx.line(cx - r * 0.1, cy + r * 0.4, cx + r * 0.5, cy - r * 0.4, ink, 2.2)
	elif mark == "+":
		gfx.line(cx - r * 0.5, cy, cx + r * 0.5, cy, ink, 2.2)
		gfx.line(cx, cy - r * 0.5, cx, cy + r * 0.5, ink, 2.2)
	else:
		gfx.line(cx, cy - r * 0.5, cx, cy + r * 0.15, ink, 2.2)
		gfx.circle(cx, cy + r * 0.48, 1.4, ink)


func _tree_label(name: String, cx: float, y: float, max_w: float, size: float, col: Color) -> void:
	var sz := size
	while sz >= 9:
		if gfx.text_w(name, sz) <= max_w:
			gfx.text(name, cx, y, sz, col, "center")
			return
		sz -= 1
	var sp := name.find(" ")
	if sp > 0:
		var a := name.substr(0, sp)
		var b := name.substr(sp + 1)
		sz = size
		while sz > 9 and not (gfx.text_w(a, sz) <= max_w and gfx.text_w(b, sz) <= max_w):
			sz -= 1
		gfx.text(a, cx, y - sz * 0.15, sz, col, "center")
		gfx.text(b, cx, y + sz * 1.05, sz, col, "center")
		return
	var t := name
	while t.length() > 1 and gfx.text_w(t + "…", 9) > max_w:
		t = t.substr(0, t.length() - 1)
	gfx.text(t + "…", cx, y, 9, col, "center")


func _draw_tree(root: Dictionary, x0: float, y0: float, w: float, h: float) -> void:
	var depth := _tree_layout(root, w)
	var row_h := minf(118.0, h / (depth + 1))
	var RR := [30.0, 25.0, 21.0, 19.0]
	var place := func(n: Dictionary, a: float, b: float, self_fn: Callable) -> void:
		n.cx = (a + b) / 2
		n.cy = y0 + 34 + n.d * row_h
		var s := a
		for c in n.show:
			var e: float = s + (b - a) * c.leaves / n.leaves
			self_fn.call(c, s, e, self_fn)
			s = e
		n.span = b - a
	place.call(root, x0, x0 + w, place)
	var lines := func(n: Dictionary, self_fn: Callable) -> void:
		var r: float = RR[n.d]
		var top: float = n.cy + r + 18
		var my: float = (top + n.cy + row_h - (RR[n.d + 1] if n.d + 1 < RR.size() else 19.0)) / 2
		for c in n.show:
			var col := Color(111 / 255.0, 208 / 255.0, 138 / 255.0, 0.55) if c.have else Color(243 / 255.0, 216 / 255.0, 158 / 255.0, 0.45)
			gfx.line(n.cx, top, n.cx, my, col, 1.8)
			gfx.line(n.cx, my, c.cx, my, col, 1.8)
			gfx.line(c.cx, my, c.cx, c.cy - RR[c.d], col, 1.8)
			self_fn.call(c, self_fn)
	lines.call(root, lines)
	var nodes := func(n: Dictionary, self_fn: Callable) -> void:
		var u: Dictionary = E.UNIT[n.id]
		var col: Color = GC[u.grade]
		var r := minf(RR[n.d], n.span / 2 - 4)
		var is_top: bool = n.get("top", false)
		gfx.circle(n.cx, n.cy, r, Color(43 / 255.0, 122 / 255.0, 98 / 255.0, 0.45) if n.have else Color(11 / 255.0, 30 / 255.0, 42 / 255.0, 0.96))
		gfx.ring(n.cx, n.cy, r, C.goldEdge if is_top else col, 3.0 if is_top else 2.2)
		gfx.draw_fit(gfx.unit_tex(n.id), n.cx - r * 0.72, n.cy - r * 0.72, r * 1.44, r * 1.44, 1.0 if (n.have or is_top) else 0.75)
		var br := maxf(6.5, r * 0.36)
		var bx: float = n.cx + r * 0.72
		var by: float = n.cy - r * 0.72
		if n.have:
			_check(bx, by, br, Color("#6fd08a"), "v")
		elif n.more:
			_check(bx, by, br, C.goldEdge, "+")
		elif u.role == E.SPECIAL_ROLE:
			gfx.circle(bx, by, br, GC.TRANSCEND)
			gfx.text("6", bx, by + 0.5, roundf(br * 1.5), Color("#07131c"), "center")
		elif not is_top and n.kids.is_empty():
			_check(bx, by, br, Color("#ff9a8a"), "!")
		_tree_label(u.name, n.cx, n.cy + r + 10, maxf(60.0, n.span - 4) if n.d == 0 else n.span - 4, 14.0 if n.d == 0 else 12.0, C.good if n.have else (C.goldEdge if is_top else C.text))
		if not is_top:
			var nid: String = n.id
			gfx.hit(n.cx - n.span / 2, n.cy - r, n.span, r * 2 + 18, func(): v.show_info(nid, true))
		for c in n.show:
			self_fn.call(c, self_fn)
	nodes.call(root, nodes)


func _chip_row(tips: Array, x: float, y: float, x_end: float, size: float, col: Color) -> float:
	var cx := x
	var cy := y
	var hh := size + 8
	for t in tips:
		var w := minf(gfx.text_w(t, size) + 14, x_end - x)
		if cx + w > x_end:
			cx = x
			cy += hh + 4
		gfx.box(cx, cy, w, hh, Color(0, 0, 0, 0.35), col, 6, 1.5)
		gfx.fit_text(t, cx + w / 2, cy + hh / 2 + 0.5, w - 8, size, col, "center")
		cx += w + 4
	return cy + hh


func draw_info() -> void:
	var g: Dictionary = v.g
	var id: String = v.info.id
	var u: Dictionary = E.UNIT[id]
	var k := E.kit(id)
	var col: Color = GC[u.grade]
	var r = E.recipe_for(id)
	gfx.rect(0, 0, W, MENU_Y, Color(3 / 255.0, 9 / 255.0, 14 / 255.0, 0.62))
	gfx.hit(0, 0, W, MENU_Y, func(): v.info = {})
	var R := rect()
	var x: float = R.x
	var y: float = R.y
	var w: float = R.w
	var h: float = R.h
	gfx.box(x, y, w, h, C.panel, col, 14, 2)
	gfx.hit(x, y, w, h, func(): pass)
	gfx.draw_fit(gfx.unit_tex(id), x + 14, y + 12, 80, 86)
	gfx.fit_text(u.name, x + 106, y + 28, w - 220, 24, C.text)
	var cx := x + 106
	cx += gfx.chip(E.D.GRADE_NAME[u.grade], cx, y + 50, col) + 6
	var special := bool(k.get("special", false))
	var tcol: Color = C.goldEdge if special else (C.phys if k.type == "phys" else C.mag)
	gfx.chip("조합 재료" if special else "%s %s" % ["물딜" if k.type == "phys" else "마딜", k.job], cx, y + 50, tcol)
	if special:
		gfx.fit_text("공격하지 않아요 · 판에 두거나 창고에 넣어도 조합 재료로 쓰여요", x + 106, y + 92, w - 120, 14, C.muted)
	else:
		var gp: float = k.gap * float(E.RULES.atkSpeed)
		gfx.fit_text("공격 %d · %s(%s초) · 사거리 %s" % [int(roundf(k.dmg * E.upg_mul(g, k.tier))), "빠름" if gp <= 0.6 else ("느림" if gp >= 1.1 else "보통"), E.fmt(k.gap), E.fmt(k.range)], x + 106, y + 92, w - 120, 14, C.muted)
	gfx.button(x + w - 96, y + 10, 82, 40, "닫기", func(): v.info = {}, "quiet")
	if v.info.stack.size() > 0:
		var back: String = v.info.stack[v.info.stack.size() - 1]
		gfx.button(x + w - 96, y + 56, 82, 36, "← 뒤로", func(): v.info = {"id": back, "stack": v.info.stack.slice(0, -1)}, "normal")
	gfx.text("유틸·특수", x + 16, y + 124, 15, C.gold)
	var used_in := E.recipes_using(id).size()
	if used_in > 0:
		gfx.button(x + w - 186, y + 100, 172, 32, "이걸로 만드는 것 %d" % used_in, func():
			v.info = {}
			v.open_book(null, id), "normal")
	var tips := E.kit_tips(k)
	var tip_end := y + 170
	if tips.size() > 0:
		tip_end = _chip_row(tips, x + 16, y + 138, x + w - 12, 12.0 if tips.size() > 6 else 14.0, tcol)
	else:
		gfx.text("기본 공격만 해요", x + 16, y + 150, 14, C.muted)
	var py := maxf(y + 200, tip_end + 26)
	gfx.rect(x + 12, py - 14, w - 24, 1, Color(145 / 255.0, 122 / 255.0, 76 / 255.0, 0.35))
	var pickable: bool = E.D.PICK_GRADES.has(u.grade) and E.units_of_grade(u.grade).has(id)
	var pn := int(g.picks.get(u.grade, 0))
	var pick_btn := func(bx: float, bw: float) -> void:
		gfx.button(bx, y + h - 76, bw, 56, "선택위습 사용", func():
			var res := E.summon_pick(g, id)
			if res.ok:
				v.sfx("summon")
				v.selected = [res.unit.uid]
				v.say("%s 소환! (%s 선택 위습 %d개 남음)" % [u.name, E.D.GRADE_NAME[u.grade], int(g.picks.get(u.grade, 0))])
			elif res.why != "":
				v.say(res.why), "primary", pn > 0, "%s %d개" % [E.D.GRADE_NAME[u.grade], pn])
	if r == null:
		gfx.fit_text("외부탐사 6장 보상으로 받아요 · 초월 등급 조합에 재료로 쓰면 사라져요" if u.role == E.SPECIAL_ROLE else "조합법이 없어요 · %s 위습으로 소환해요" % E.D.GRADE_NAME[u.grade], W / 2, py + 30, w - 40, 15, C.muted, "center")
		if pickable:
			pick_btn.call(x + 14, w - 28)
		return
	gfx.text("재료 나무", x + 16, py + 6, 15, C.gold)
	var lx := x + 100
	for it in [[Color("#6fd08a"), "v", "가진 것"], [Color("#ff9a8a"), "!", "위습으로 소환"], [C.goldEdge, "+", "누르면 더 아래"]]:
		_check(lx, py + 6, 7, it[0], it[1])
		gfx.text(it[2], lx + 11, py + 7, 12, C.muted)
		lx += 28 + gfx.text_w(it[2], 12)
	var cnt := E.count_on_field(g)
	_draw_tree(need_tree(id, cnt), x + 10, py + 18, w - 20, y + h - 146 - (py + 18))
	var base := {}
	var walk := func(n: Dictionary, self_fn: Callable) -> void:
		if not n.have and n.kids.is_empty() and not n.get("top", false):
			base[n.id] = int(base.get(n.id, 0)) + 1
		for c in n.kids:
			self_fn.call(c, self_fn)
	walk.call(need_tree(id, cnt), walk)
	var ready := can_make(r)
	var miss := " · ".join(base.keys().map(func(b): return "%s×%d" % [E.UNIT[b].name, base[b]]))
	gfx.box(x + 12, y + h - 132, w - 24, 50, Color(243 / 255.0, 216 / 255.0, 158 / 255.0, 0.08), Color(243 / 255.0, 216 / 255.0, 158 / 255.0, 0.3), 8, 1)
	if ready:
		gfx.fit_text("재료가 모두 있어요! 바로 조합할 수 있어요.", W / 2, y + h - 107, w - 40, 15, C.good, "center")
	elif miss != "":
		gfx.wrap("더 필요: " + miss, x + 22, y + h - 127, w - 44, 13, C.goldEdge, 19)
	else:
		gfx.fit_text("하위 재료는 다 있어요. 아래 단부터 조합해 올라가세요.", W / 2, y + h - 107, w - 40, 14, C.goldEdge, "center")
	var gi: int = g.goals.find(id)
	var nb := 3 if pickable else 2
	var bw := (w - 28 - 12 * (nb - 1)) / nb
	gfx.button(x + 14, y + h - 76, bw, 56, "★ 목표에서 빼기" if gi >= 0 else "☆ 목표로", func():
		var on := E.toggle_goal(g, id)
		v.say(("목표: %s (하위 재료까지 색 테두리)" % u.name) if on else "목표에서 뺐어요"), "primary" if gi >= 0 else "normal")
	if pickable:
		pick_btn.call(x + 26 + bw, bw)
	gfx.button(x + 14 + (nb - 1) * (bw + 12), y + h - 76, bw, 56, "조합", func():
		var nu = v.combine(r)
		if nu != null:
			v.selected = [nu.uid]
			v.say("%s 완성!" % u.name)
			if v.info.stack.size() > 0:
				var back2: String = v.info.stack[v.info.stack.size() - 1]
				v.info = {"id": back2, "stack": v.info.stack.slice(0, -1)}, "primary", ready)


# ── 외부탐사 ──
func _mission() -> void:
	var g: Dictionary = v.g
	shade(0.35)
	var R := rect()
	var x: float = R.x
	var y: float = R.y
	var w: float = R.w
	var h: float = R.h
	gfx.box(x, y, w, h, C.panel, C.goldEdge, 14, 2)
	gfx.text("외부탐사", x + 18, y + 30, 22, C.text)
	gfx.text("완료 %d/%d장" % [g.missionDone, E.REGIONS.size()], x + 120, y + 31, 15, C.good if g.missionDone else C.muted)
	close_btn(x, y, w)
	var late: bool = E.story_left(g) and g.wave >= int(E.RULES.storyDeadline) - 10
	gfx.fit_text("%s웨이브까지 %d장 · ★특기 피해 ×2~5" % [E.fmt(E.RULES.storyDeadline), E.REGIONS.size()], x + 18, y + 64, w - 36, 13, C.bad if late else C.muted)
	var ly := y + 84
	var lh := 32.0
	var shown := [g.missionDone, g.missionDone + 1].filter(func(k): return k < E.REGIONS.size())
	if shown.is_empty():
		shown.append(E.REGIONS.size() - 1)
	for i in shown.size():
		var k: int = shown[i]
		var r: Dictionary = E.REGIONS[k]
		var yy := ly + i * lh
		var done: bool = k < g.missionDone
		var cur: bool = k == g.missionDone
		var open := cur and E.mission_open(g)
		gfx.box(x + 12, yy, w - 24, lh - 6, Color(43 / 255.0, 122 / 255.0, 98 / 255.0, 0.2) if cur else Color(11 / 255.0, 30 / 255.0, 42 / 255.0, 0.6), (Color("#2b7a62") if open else C.edge) if cur else Color(145 / 255.0, 122 / 255.0, 76 / 255.0, 0.3), 6, 2.0 if cur else 1.0)
		var my := yy + (lh - 6) / 2
		gfx.fit_text("%s장 %s" % [E.fmt(r.ch), r.name], x + 24, my, 220, 14, C.muted if done else C.text)
		gfx.fit_text("완료 ✓" if done else ("진행 가능" if open else "잠김"), x + 250, my, 80, 13, C.good if done else (C.goldEdge if open else Color("#6f7f88")))
		var parts := []
		for gr in r.reward:
			parts.append("%s%s" % [E.D.GRADE_NAME[gr], E.fmt(r.reward[gr])])
		var rw := "·".join(parts)
		if r.has("pick"):
			rw += " + 선택 " + "·".join(r.pick.keys().map(func(gr): return "%s%s" % [E.D.GRADE_NAME[gr], E.fmt(r.pick[gr])]))
		if E.truthy(r.get("ticket")):
			rw += " + 모집권%s" % E.fmt(r.ticket)
		if r.has("choice"):
			rw += " + 골라 받기"
		gfx.fit_text(rw, x + w - 24, my, w - 24 - 336 - 12, 13, C.gold, "right", 9)   # 「진행 가능」과 겹치지 않게 오른쪽 맞춤·작게
	var cy := ly + shown.size() * lh + 4
	var PB := 180.0
	var q := func(val: float) -> float: return roundf(val * PB / 230.0)
	if g.missionDone >= E.REGIONS.size():
		gfx.text("모든 지역을 되찾았어요!", W / 2, cy + 80, 20, C.goldEdge, "center")
		return
	var r: Dictionary = E.REGIONS[g.missionDone]
	gfx.box(x + 12, cy, w - 24, PB, Color(7 / 255.0, 19 / 255.0, 28 / 255.0, 0.8), C.edge, 10)
	gfx.draw_fit(gfx.tex("village/%s.webp" % r.img), x + 14, cy + 2, w - 28, PB - 4, 0.28)
	gfx.box(x + 18, cy + 6, 230, 26, Color(7 / 255.0, 19 / 255.0, 28 / 255.0, 0.85), null, 6)
	gfx.fit_text("%s장 · %s" % [E.fmt(r.ch), r.place], x + 26, cy + 19, 216, 15, C.goldEdge)
	var rw_all := [E.wisp_text(r.reward)]
	if r.has("pick"): rw_all.append(E.pick_text(r.pick))
	if E.truthy(r.get("ticket")): rw_all.append("모집권 %s" % E.fmt(r.ticket))
	if E.truthy(r.get("gold")): rw_all.append("새우 %s" % E.fmt(r.gold))
	if r.has("choice"): rw_all.append("+ 골라 받기(초월 갈매미맨·전설 위습 1·에픽 선택 2)")
	gfx.box(x + 18, cy + q.call(40), w - 36, 24, Color(7 / 255.0, 19 / 255.0, 28 / 255.0, 0.85), null, 6)
	gfx.fit_text("보상: " + " · ".join(rw_all), x + 26, cy + q.call(40) + 12, w - 52, 13, C.gold)
	var t = E.mission_target(g)
	gfx.draw_fit(gfx.enemy_tex(r.look), W / 2 - q.call(50), cy + q.call(68), q.call(100), q.call(94))
	gfx.box(x + 40, cy + q.call(166), w - 80, 12, Color(0, 0, 0, 0.6), C.line, 6, 1)
	gfx.box(x + 40, cy + q.call(166), (w - 80) * maxf(0.0, t.hp / t.max), 12, Color("#ff6b6b"), null, 6)
	gfx.box(x + 24, cy + PB - 46, w - 48, 40, Color(7 / 255.0, 19 / 255.0, 28 / 255.0, 0.88), null, 8)
	gfx.fit_text("그림자 대장 체력 %s · 방어력 %s · 마법방어 %s" % [_comma(maxf(0.0, ceilf(t.hp))), E.fmt(t.armor), E.fmt(t.mr)], W / 2, cy + PB - 34, w - 60, 14, C.text, "center")
	var away := E.away_units(g)
	gfx.fit_text(("탐사 중 %d마리" % away.size()) if away.size() > 0 else "보낸 갈매미 없음", W / 2, cy + PB - 16, w - 60, 14, C.good if away.size() > 0 else C.muted, "center")
	var ay := cy + PB + 6
	var AS := 74.0
	var aper := int((w - 28 + 6) / (AS + 6))
	var arows := maxi(1, int((y + h - 64 - 8 - ay) / (AS + 6)))
	if away.size() > aper * arows:
		gfx.text("외 %d마리" % (away.size() - aper * arows), x + w - 20, y + h - 76, 13, C.muted, "right")
	for i in mini(away.size(), aper * arows):
		var u: Dictionary = away[i]
		var xx := x + 14 + (i % aper) * (AS + 6)
		var yy := ay + int(i / aper) * (AS + 6)
		gfx.box(xx, yy, AS, AS, Color(11 / 255.0, 30 / 255.0, 42 / 255.0, 0.85), GC[E.UNIT[u.id].grade], 6, 1.5)
		gfx.draw_fit(gfx.unit_tex(u.id), xx + 2, yy + 2, AS - 4, AS - 4)
		if E.truthy(E.kit(u.id).get("explore")):
			gfx.text("★×%s" % E.fmt(E.kit(u.id).explore), xx + AS - 4, yy + 10, 11, C.goldEdge, "right")
		gfx.hit(xx, yy, AS, AS, func():
			if E.recall(g, [u.uid]) > 0:
				v.say("%s이(가) 판으로 돌아왔어요." % E.UNIT[u.id].name))
	if away.is_empty():
		var sp := E.field_units(g).filter(func(u): return E.truthy(E.kit(u.id).get("explore")))
		var names := {}
		for u in sp:
			names["%s(×%s)" % [E.UNIT[u.id].name, E.fmt(E.kit(u.id).explore)]] = true
		var msg := ("판에 탐사 특기 %d마리: " % sp.size() + ", ".join(names.keys())) if sp.size() > 0 else "탐사 특기 갈매미를 보내면 대장에게 피해가 커요(초불영제는 모두 ×2 이상)."
		gfx.wrap(msg, x + 18, ay + 8, w - 36, 13, C.goldEdge if sp.size() > 0 else C.muted)
	var by := y + h - 64
	var sel: Array = v.sel_units()
	gfx.button(x + 14, by, (w - 40) / 2, 50, ("고른 %d마리 보내기" % sel.size()) if sel.size() > 0 else "판에서 먼저 고르기", func():
		if sel.size() > 0:
			v.send(sel)
		else:
			v.modal = {}, "primary" if sel.size() > 0 else "normal")
	gfx.button(x + 26 + (w - 40) / 2, by, (w - 40) / 2, 50, "모두 불러오기", func():
		var n := E.recall(g)
		v.say("%d마리가 돌아왔어요." % n), "normal", away.size() > 0)


func _comma(n: float) -> String:
	var s := str(int(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


# ── 강화 ──
func _upgrade() -> void:
	var g: Dictionary = v.g
	shade(0.3)
	var R := rect()
	var x: float = R.x + 6
	var y: float = R.y
	var w: float = R.w - 12
	var h: float = R.h
	gfx.box(x, y, w, h, C.panel, C.goldEdge, 14, 2)
	gfx.text("등급별 강화", x + 18, y + 30, 22, C.text)
	close_btn(x, y, w)
	gfx.draw_fit(gfx.tex("menu/currency-shrimp.webp"), x + 18, y + 56, 24, 24)
	gfx.text("가진 새우 %s" % E.fmt(int(g.gold)), x + 48, y + 69, 17, C.goldEdge)
	var have := []
	have.resize(8)
	have.fill(0)
	for u in E.field_units(g):
		have[E.upg_group(E.tier_of(u.id))] += 1
	var color := ["UNCOMMON", "RARE", "EPIC", "LEGEND", "LIMITED", "TRANSCEND", "IMMORTAL", "ETERNAL"]
	var row_h := minf(84.0, (h - 96) / 8.0)
	var bh := row_h - 8
	for gi in 8:
		var yy := y + 88 + gi * row_h
		var cost := E.upgrade_cost(g, gi)
		var col: Color = GC[color[gi]]
		gfx.box(x + 14, yy, w - 28, bh, Color(11 / 255.0, 30 / 255.0, 42 / 255.0, 0.85), col, 10, 2)
		gfx.text(E.D.UPG_NAME[gi], x + 30, yy + bh * 0.32, 17.0 if bh < 62 else 19.0, col)
		var maxed := E.upg_maxed(g, gi)
		gfx.fit_text("%d/%s단계 · 공격력 +%d%% · 공속 +%d%% · 판에 %d마리" % [g.upg[gi], E.fmt(E.RULES.upgMax), int(roundf(g.upg[gi] * float(E.RULES.upgPct) * 100)), int(roundf(g.upg[gi] * float(E.RULES.upgSpd) * 100)), have[gi]], x + 30, yy + bh * 0.72, w - 230, 13.0 if bh < 62 else 15.0, C.goldEdge if maxed else C.text)
		var gii := gi
		if maxed:
			gfx.button(x + w - 28 - 150, yy + 6, 150, bh - 12, "최대(풀강)", func(): pass, "normal", false)
		else:
			gfx.button(x + w - 28 - 150, yy + 6, 150, bh - 12, "강화", func():
				var res := E.upgrade(g, gii)
				if not res.ok and res.why != "":
					v.say(res.why), "primary", g.gold >= cost, "새우 %s" % E.fmt(cost))


# ── 더보기 ──
func pick_count() -> int:
	var n := 0
	for gr in E.D.PICK_GRADES:
		n += int(v.g.picks.get(gr, 0))
	return n


func _more() -> void:
	var g: Dictionary = v.g
	var R := rect()
	var x: float = R.x
	var y: float = R.y
	var w: float = R.w
	var h: float = R.h
	shade(0.3)
	gfx.box(x, y, w, h, C.panel, C.goldEdge, 14, 2)
	gfx.text("더보기", x + 18, y + 30, 20, C.text)
	close_btn(x, y, w)
	var picks := pick_count()
	var tk := int(g.tickets)
	var st := E.stored_units(g).size()
	var auto_on: bool = g.autoGrades.values().any(func(b): return b)
	var first_pick := "COMMON"
	for gr in E.D.PICK_GRADES:
		if int(g.picks.get(gr, 0)) > 0:
			first_pick = gr
			break
	var items := [
		["menu/icon-draw", "선택위습", func(): v.modal = {"kind": "pick", "grade": first_pick}, "primary" if picks else "normal", ("%d개 있음" % picks) if picks else "없음"],
		["menu/icon-team", "용병모집", func(): v.modal = {"kind": "recruit"}, "primary" if tk >= int(E.RULES.recruitCost) else "normal", "모집권 %d" % tk],
		["menu/icon-shop", "창고", func(): v.modal = {"kind": "storage", "scroll": 0.0, "scrollable": true}, "normal", "%d마리%s" % [st, "·자동" if auto_on else ""]],
		["ui/icon-goldenstrike", "피해 순위", func(): v.modal = {}; v.say("피해 순위는 창을 닫으면 오른쪽 위에 보여요."), "normal", "갈매미별 피해"],
	]
	var cy0 := 0.0
	if g.get("choice") != null:
		cy0 = 76.0
		gfx.button(x + 12, y + 64, w - 24, 64, "%s장 보상 고르기" % E.fmt(E.REGIONS[g.choice.k].ch), func(): v.modal = {"kind": "choice"}, "primary", true, "초월 갈매미맨 · 전설 위습 1 · 에픽 선택 위습 2 중 하나")
	var gw := (w - 36) / 2.0
	var gh := minf(96.0, (h - 80 - 12 - cy0) / 2.0)
	for i in items.size():
		var it: Array = items[i]
		v.menu_button(x + 12 + (i % 2) * (gw + 12), y + 64 + cy0 + int(i / 2) * (gh + 12), gw, gh, it[0], it[1], it[2], it[3], it[4])


func _pick() -> void:
	var g: Dictionary = v.g
	shade(0.35)
	var R := rect()
	var x: float = R.x
	var y: float = R.y
	var w: float = R.w
	var h: float = R.h
	gfx.box(x, y, w, h, C.panel, C.goldEdge, 14, 2)
	gfx.text("선택 위습", x + 18, y + 30, 22, C.text)
	close_btn(x, y, w)
	var tw := (w - 24 - 18) / 4.0
	for k in E.D.PICK_GRADES.size():
		var gr: String = E.D.PICK_GRADES[k]
		var tx: float = x + 12 + k * (tw + 6)
		var on: bool = v.modal.grade == gr
		var n := int(g.picks.get(gr, 0))
		gfx.box(tx, y + 82, tw, 52, Color(243 / 255.0, 216 / 255.0, 158 / 255.0, 0.14) if on else Color(11 / 255.0, 30 / 255.0, 42 / 255.0, 0.8), C.goldEdge if on else GC[gr], 8, 2.5 if on else 1.5)
		gfx.fit_text(E.D.GRADE_NAME[gr], tx + tw / 2, y + 100, tw - 8, 15, GC[gr], "center")
		gfx.text("×%d" % n, tx + tw / 2, y + 121, 15, C.text if n else Color("#6f7f88"), "center")
		gfx.hit(tx, y + 82, tw, 52, func(): v.modal.grade = gr)
	var gr2: String = v.modal.grade
	var n2 := int(g.picks.get(gr2, 0))
	var list := E.units_of_grade(gr2)
	var cw := (w - 24 - 18) / 4.0
	var ch := 168.0
	for i in list.size():
		var id: String = list[i]
		var cx := x + 12 + (i % 4) * (cw + 6)
		var cy := y + 148 + int(i / 4) * (ch + 8)
		var u: Dictionary = E.UNIT[id]
		var k := E.kit(id)
		gfx.box(cx, cy, cw, ch, Color(11 / 255.0, 30 / 255.0, 42 / 255.0, 0.9 if n2 else 0.5), GC[gr2] if n2 else Color("#33434d"), 10, 2.0 if n2 else 1.0)
		gfx.draw_fit(gfx.unit_tex(id), cx + 8, cy + 6, cw - 16, 96, 1.0 if n2 else 0.45)
		gfx.fit_text(u.name, cx + cw / 2, cy + 116, cw - 10, 16, C.text if n2 else Color("#6f7f88"), "center")
		gfx.fit_text("%s %s" % ["물딜" if k.type == "phys" else "마딜", k.job], cx + cw / 2, cy + 138, cw - 10, 13, C.phys if k.type == "phys" else C.mag, "center")
		var tip := ""
		for t in E.kit_tips(k):
			if not t.contains("형("):
				tip = t
				break
		if tip == "":
			tip = (("라인 정리형" if k.line else "단일 공격형") if k.job == "주력" else "기본 공격")
		gfx.fit_text(tip, cx + cw / 2, cy + 156, cw - 10, 12, C.muted, "center", 9)
		if n2:
			gfx.hit(cx, cy, cw, ch, func():
				var res := E.summon_pick(g, id)
				if res.ok:
					v.sfx("summon")
					v.say("%s 소환!" % u.name)
					if not (int(g.picks.get(gr2, 0)) > 0):
						v.modal = {}
				elif res.why != "":
					v.say(res.why))
	if not n2:
		gfx.fit_text("%s 선택 위습이 없어요" % E.D.GRADE_NAME[gr2], W / 2, y + h - 30, w - 40, 15, C.muted, "center")


func _recruit() -> void:
	var g: Dictionary = v.g
	shade(0.3)
	var R := rect()
	var x: float = R.x
	var y: float = R.y
	var w: float = R.w
	var h: float = R.h
	gfx.box(x, y, w, h, C.panel, C.goldEdge, 14, 2)
	gfx.text("용병모집", x + 18, y + 30, 22, C.text)
	close_btn(x, y, w)
	var tk := int(g.tickets)
	var cost := int(E.RULES.recruitCost)
	var odds: Dictionary = E.RULES.recruitOdds
	gfx.text("모집권 %d" % tk, W / 2, y + 96, 30, C.goldEdge, "center")
	var sum := 0.0
	var items := []
	for gr in odds:
		sum += float(odds[gr])
		items.append(["%s %d%%" % [E.D.GRADE_NAME[gr], int(roundf(float(odds[gr]) * 100))], GC[gr]])
	items.append(["실패 %d%%" % int(roundf(100 * (1.0 - sum))), C.muted])
	var tw := -6.0
	for it in items:
		tw += gfx.text_w(it[0], 15) + 20
	var cx := (W - tw) / 2
	for it in items:
		cx += gfx.chip(it[0], cx, y + 128, it[1], 15) + 6
	var bh := minf(96.0, h * 0.18)
	gfx.button(x + 40, y + 176, w - 80, bh, "모집하기", func():
		var res := E.recruit(g)
		if not res.ok:
			if res.why != "":
				v.say(res.why)
			return
		v.sfx("recruitFail" if res.get("fail", false) else "recruitOk")
		v.modal.last = {"fail": true} if res.get("fail", false) else {"id": res.unit.id, "grade": res.grade}, "primary", tk >= cost, "모집권 %d개" % cost)
	var L = v.modal.get("last")
	var ry := y + 176 + bh + 24
	if L != null:
		gfx.box(x + 40, ry, w - 80, minf(220.0, h - (ry - y) - 20), Color(11 / 255.0, 30 / 255.0, 42 / 255.0, 0.85), Color("#46555f") if L.get("fail", false) else GC[L.grade], 12, 2)
		if L.get("fail", false):
			gfx.text("모집 실패…", W / 2, ry + 60, 22, C.muted, "center")
		else:
			gfx.draw_fit(gfx.unit_tex(L.id), W / 2 - 55, ry + 10, 110, 110)
			gfx.text(E.UNIT[L.id].name, W / 2, ry + 136, 20, GC[L.grade], "center")
			gfx.text("%s · 판 가운데에 나왔어요" % E.D.GRADE_NAME[L.grade], W / 2, ry + 162, 13, C.muted, "center")


func _storage() -> void:
	var g: Dictionary = v.g
	shade(0.3)
	var R := rect()
	var x: float = R.x
	var y: float = R.y
	var w: float = R.w
	var h: float = R.h
	gfx.box(x, y, w, h, C.panel, C.goldEdge, 14, 2)
	var list := E.stored_units(g)
	gfx.text("창고 %d마리" % list.size(), x + 18, y + 30, 22, C.text)
	close_btn(x, y, w)
	gfx.text("등급별 한 번에 넣기", x + 18, y + 90, 15, C.gold)
	var gw := (w - 24 - 5 * 6) / 6.0
	for i in E.D.STORE_GROUPS.size():
		var q: Dictionary = E.D.STORE_GROUPS[i]
		var gx: float = x + 12 + i * (gw + 6)
		var n := E.store_group_units(g, q.key).size()
		var col: Color = GC[q.grades[0]]
		var on: bool = g.autoGrades.get(q.key, false)
		gfx.button(gx, y + 104, gw, 50, q.name, func():
			var m := E.store_group(g, q.key)
			v.say(("%s %d마리를 창고에 넣었어요." % [q.name, m]) if m else ("판에 넣을 %s이(가) 없어요." % q.name)), "normal", n > 0, "넣기 %d" % n, col if n else null)
		if q.auto:
			gfx.button(gx, y + 158, gw, 30, "자동 켬" if on else "자동 끔", func():
				var m := E.set_auto_grade(g, q.key, not on)
				v.say(("%s 자동 창고 켬%s" % [q.name, (" (%d마리 넣음)" % m) if m else ""]) if not on else ("%s 자동 창고 끔" % q.name)), "primary" if on else "quiet")
		else:
			gfx.fit_text("자동 없음", gx + gw / 2, y + 173, gw - 6, 11, Color("#6f7f88"), "center")
	var groups := []
	for u in list:
		var found = null
		for gr in groups:
			if gr.id == u.id:
				found = gr
				break
		if found == null:
			found = {"id": u.id, "uids": []}
			groups.append(found)
		found.uids.append(u.uid)
	groups = E.stable_sort(groups, func(gr): return E.tier_of(gr.id) * 1000 + int(gr.id.substr(1)))
	var top := y + 198
	var view_h := h - 208 - 56
	var row_h := 62.0
	var total := groups.size() * row_h
	v.modal.maxScroll = maxf(0.0, total - view_h)
	v.modal.scroll = clampf(float(v.modal.get("scroll", 0.0)), 0.0, v.modal.maxScroll)
	if groups.is_empty():
		gfx.fit_text("창고가 비어 있어요. 갈매미를 고르고 「창고로」를 누르세요.", W / 2, top + 60, w - 40, 15, C.muted, "center")
	for i in groups.size():
		var gr: Dictionary = groups[i]
		var yy: float = top + i * row_h - v.modal.scroll
		if yy < top - 1 or yy + row_h > top + view_h + 1:
			continue
		var u: Dictionary = E.UNIT[gr.id]
		var k := E.kit(gr.id)
		gfx.box(x + 12, yy + 3, w - 24, row_h - 6, Color(11 / 255.0, 30 / 255.0, 42 / 255.0, 0.85), GC[u.grade], 8, 1.5)
		gfx.draw_fit(gfx.unit_tex(gr.id), x + 16, yy + 6, 46, row_h - 12)
		gfx.fit_text("%s ×%d" % [u.name, gr.uids.size()], x + 68, yy + 22, 150, 16, C.text)
		var no_sell: bool = bool(k.get("special", false)) or k.tier >= E.TOP_TIER
		gfx.text("%s · %s" % [E.D.GRADE_NAME[u.grade], "판매 불가" if no_sell else ("판매 %s" % E.fmt(k.sell))], x + 68, yy + 43, 12, C.muted)
		var bx := x + w - 12 - 4 - 3 * 82
		gfx.button(bx, yy + 9, 76, row_h - 18, "1 꺼내기", func(): E.unstore(g, [gr.uids[0]]), "normal")
		gfx.button(bx + 82, yy + 9, 76, row_h - 18, "모두", func():
			E.unstore(g, gr.uids)
			v.say("%s %d마리를 꺼냈어요." % [u.name, gr.uids.size()]), "normal")
		if no_sell:
			gfx.button(bx + 164, yy + 9, 76, row_h - 18, "판매 불가", func(): pass, "normal", false)
		else:
			gfx.button(bx + 164, yy + 9, 76, row_h - 18, "1 팔기", func(): E.sell(g, gr.uids[0]), "danger")
	_scrollbar(x + w - 8, top, view_h, total)
	gfx.button(x + 18, y + h - 52, w - 36, 42, "모두 꺼내기", func():
		var n := E.unstore(g, list.map(func(u): return u.uid))
		v.say("%d마리를 꺼냈어요." % n), "normal", list.size() > 0)


func _choice() -> void:
	var g: Dictionary = v.g
	if g.get("choice") == null:
		v.modal = {}
		return
	shade(0.45)
	var R := rect()
	var x: float = R.x
	var y: float = R.y
	var w: float = R.w
	var h: float = R.h
	var r: Dictionary = E.REGIONS[g.choice.k]
	gfx.box(x, y, w, h, C.panel, C.goldEdge, 14, 2)
	gfx.text("%s장 보상 고르기" % E.fmt(r.ch), x + 18, y + 30, 22, C.text)
	gfx.fit_text("하나만 받을 수 있어요. 미뤄 두고 「더보기」에서 나중에 받아도 돼요.", x + 18, y + 60, w - 36, 14, C.muted)
	gfx.button(x + w - 110, y + 10, 96, 40, "나중에", func():
		g.choiceLater = true
		v.modal = {}
		v.say("보상은 아래 「더보기」에서 언제든 받을 수 있어요."), "quiet")
	var ch := minf(150.0, (h - 96 - 24) / 3.0)
	for i in r.choice.size():
		var c: Dictionary = r.choice[i]
		var cy: float = y + 84 + i * (ch + 12)
		var col: Color = GC.TRANSCEND if c.has("unit") else (GC.LEGEND if c.has("wisps") else GC.EPIC)
		gfx.box(x + 12, cy, w - 24, ch, Color(11 / 255.0, 30 / 255.0, 42 / 255.0, 0.9), col, 12, 2)
		if c.has("unit"):
			gfx.draw_fit(gfx.unit_tex(c.unit), x + 22, cy + 10, 100, ch - 20)
		else:
			gfx.circle(x + 72, cy + ch / 2, 36, Color(7 / 255.0, 19 / 255.0, 28 / 255.0, 0.9))
			gfx.ring(x + 72, cy + ch / 2, 36, col, 3)
			gfx.text("위습" if c.has("wisps") else "선택", x + 72, cy + ch / 2, 16, col, "center")
		gfx.fit_text(E.choice_text(c), x + 136, cy + 30, w - 136 - 24 - 110, 18, col)
		var desc := ["초월 등급 조합 재료", "공격하지 않고 팔 수 없음, 조합하면 사라짐"] if c.has("unit") else (["누르면 전설 갈매미 1마리(무작위)", "바로 전력이 필요할 때"] if c.has("wisps") else ["원하는 에픽 2마리를 골라 소환", "조합 재료를 맞출 때"])
		for k in desc.size():
			gfx.fit_text(desc[k], x + 136, cy + 60 + k * 22, w - 136 - 24 - 110, 13, C.muted)
		var ii: int = i
		gfx.button(x + w - 24 - 100, cy + ch / 2 - 24, 100, 48, "받기", func():
			if E.choose_reward(g, ii):
				g.choiceLater = false
				v.modal = {}
				v.say("%s을(를) 받았어요." % E.choice_text(c)), "primary")
