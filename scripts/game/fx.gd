# 공격 연출: 웹 판 defense.js의 drawShot(속성별 투사체·근접 베기·번개·빛줄기, 닿으면 파편)과 drawSig(고유 기술 모양·이름)를 옮김.
extends RefCounted

const Gfx = preload("res://scripts/game/gfx.gd")
const ELEM_COL := {"FIRE": Color8(255, 140, 70), "WATER": Color8(90, 170, 255), "ICE": Color8(190, 240, 255), "LIGHTNING": Color8(255, 225, 74),
	"NATURE": Color8(120, 220, 110), "HOLY": Color8(255, 240, 190), "DARK": Color8(186, 120, 255), "NORMAL": Color8(255, 200, 140)}
const PHYS := Color8(255, 179, 107)
const MAG := Color8(143, 200, 255)

var gfx: Gfx
var labels := []   # 이번 화면에 쓴 기술 이름 자리(겹침 피하기)


func _init(g: Gfx) -> void:
	gfx = g


func col_of(f: Dictionary) -> Color:
	return ELEM_COL.get(f.get("elem", ""), PHYS if f.get("type") == "phys" else MAG)


func _a(c: Color, a: float) -> Color:
	return Color(c, clampf(a, 0, 1))


func arc(cx: float, cy: float, r: float, a0: float, a1: float, col: Color, lw: float) -> void:
	gfx.ci.draw_arc(gfx.P(cx, cy), r * gfx.s, a0, a1, 16, col, maxf(1.0, lw * gfx.s), true)


func poly(pts: Array, fill, stroke = null, lw: float = 1.0) -> void:
	var pv := PackedVector2Array()
	for p in pts:
		pv.append(gfx.P(p[0], p[1]))
	if fill != null:
		gfx.ci.draw_colored_polygon(pv, fill)
	if stroke != null:
		pv.append(pv[0])
		gfx.ci.draw_polyline(pv, stroke, maxf(1.0, lw * gfx.s), true)


func draw_shot(f: Dictionary, age: float, now_t: float) -> void:
	var sx: float = f.x0
	var sy: float = f.y0 - 24
	var tx: float = f.x1
	var ty: float = f.y1 - 10
	var dx := tx - sx
	var dy := ty - sy
	var dist := maxf(1.0, sqrt(dx * dx + dy * dy))
	var big: bool = f.tier >= 4
	var sc := (0.75 if f.job == "보조" else 1.0) * (1.4 if big else 1.0)
	var col := col_of(f)
	var near: bool = f.get("near", false)
	var T := 0.07 if near else clampf(dist / 950.0, 0.08, 0.22)
	var ang := atan2(dy, dx)
	var seed := fmod(f.t * 1000 + f.x0, 97.0)
	var elem: String = f.get("elem", "NORMAL")
	if age < T:
		var p := age / T
		var x := sx + dx * p
		var y := sy + dy * p
		if near and f.type == "phys":   # 근접 물리: 적 앞에서 칼날 호
			arc(tx - cos(ang) * 6, ty - sin(ang) * 6, 14 * sc, ang - 1.1 + p * 0.6, ang + 0.2 + p * 0.9, _a(col, 0.9), 3.2 * sc)
		elif elem == "LIGHTNING":   # 번개: 지그재그
			var px := sx
			var py := sy
			for i in range(1, 7):
				var q := i / 6.0
				var off := (fmod(seed * (i + 3), 13.0) - 6.0) * 1.6 if i < 6 else 0.0
				var nx := sx + dx * q - sin(ang) * off
				var ny := sy + dy * q + cos(ang) * off
				gfx.line(px, py, nx, ny, _a(col, 0.95 - p * 0.4), 2.2 * sc)
				px = nx
				py = ny
		elif elem == "HOLY":   # 성: 빛줄기
			gfx.line(sx, sy, x, y, _a(col, 0.35), 7 * sc)
			gfx.line(sx, sy, x, y, Color(1, 1, 1, 0.9), 2 * sc)
		else:
			var tail := 3 if (elem == "FIRE" or elem == "DARK") else (2 if elem == "WATER" else 1)
			for i in range(tail, 0, -1):
				var q := maxf(0.0, p - i * 0.12)
				gfx.circle(sx + dx * q, sy + dy * q, (3 + (tail - i)) * sc * 0.8, _a(col, 0.18 + 0.12 * (tail - i)))
			var ca := cos(ang)
			var sa := sin(ang)
			var rot := func(lx: float, ly: float) -> Array: return [x + lx * ca - ly * sa, y + lx * sa + ly * ca]
			if elem == "ICE":
				poly([rot.call(8 * sc, 0), rot.call(0, 3.5 * sc), rot.call(-6 * sc, 0), rot.call(0, -3.5 * sc)], _a(col, 0.95), Color(1, 1, 1, 0.9), 1)
			elif elem == "NATURE":
				gfx.ellipse(x, y, 6 * sc, 2.6 * sc, _a(col, 0.95))
			elif f.type == "phys" and elem == "NORMAL":   # 화살
				var a0: Array = rot.call(-9 * sc, 0)
				var a1: Array = rot.call(6 * sc, 0)
				gfx.line(a0[0], a0[1], a1[0], a1[1], _a(col, 0.95), 2.4 * sc)
				poly([rot.call(7 * sc, 0), rot.call(2 * sc, 2.6 * sc), rot.call(2 * sc, -2.6 * sc)], _a(col, 0.95))
			else:
				var r := (5.0 if elem == "FIRE" else (4.6 if elem == "DARK" else 4.0)) * sc
				gfx.circle(x, y, r * 1.7, _a(col, 0.22))
				gfx.circle(x, y, r, _a(col, 0.98))
		return
	var a2 := age - T
	if a2 < 0.13:   # 닿음: 불꽃 파편
		var q := a2 / 0.13
		var n := 7 if big else 5
		for i in n:
			var an := ang + PI + (i - (n - 1) / 2.0) * 0.55 + (fmod(seed + i * 17, 7.0) - 3) * 0.05
			var r0 := 3 + q * 6
			var r1 := r0 + (9.0 if big else 6.0) * (1 - q * 0.5)
			gfx.line(tx + cos(an) * r0, ty + sin(an) * r0, tx + cos(an) * r1, ty + sin(an) * r1, _a(col, 0.9 * (1 - q)), 2.2 if big else 1.6)


func draw_sig(f: Dictionary, age: float) -> void:
	var col := col_of(f)
	var a := maxf(0.0, 1.0 - age / 0.45)
	var sk: String = f.sk
	if a > 0:
		var stroke := _a(col, 0.95 * a)
		var fill := _a(col, 0.22 * a)
		if sk == "pierce":
			gfx.line(f.x0, f.y0 - 24, f.x1, f.y1 - 10, stroke, 12 * a + 3)
			gfx.line(f.x0, f.y0 - 24, f.x1, f.y1 - 10, Color(1, 1, 1, 0.8 * a), 3)
		elif sk == "bounce" or sk == "storm":
			var pts: Array = f.get("pts", [])
			for p in pts:
				if sk == "storm":
					var zz := [[p[0] - 6, p[1] - 120], [p[0] + 6, p[1] - 60], [p[0] - 4, p[1] - 50], [p[0], p[1] - 8]]
					for i in 3:
						gfx.line(zz[i][0], zz[i][1], zz[i + 1][0], zz[i + 1][1], stroke, 4)
				gfx.circle(p[0], p[1] - 10, 14 * (1.4 - a), fill)
			if sk == "bounce" and pts.size() > 1:
				for i in range(1, pts.size()):
					gfx.line(pts[i - 1][0], pts[i - 1][1] - 12, pts[i][0], pts[i][1] - 12, stroke, 3)
		elif sk == "nova" or sk == "bind" or sk == "field":
			var rr: float = float(f.get("r", 80.0)) * (0.5 + 0.5 * (1 - a))
			gfx.circle(f.x1, f.y1 - 10, rr, fill)
			gfx.ring(f.x1, f.y1 - 10, rr, stroke, 5.0 if sk == "bind" else 3.0)
			if sk == "bind":
				for i in 6:
					var an := i * PI / 3 + age * 3
					gfx.line(f.x1 + cos(an) * rr, f.y1 - 10 + sin(an) * rr, f.x1 + cos(an) * rr * 0.35, f.y1 - 10 + sin(an) * rr * 0.35, stroke, 5)
		else:   # smash·execute: 대상에 큰 별·베기
			var R := 26 + 18 * (1 - a)
			var cx: float = f.x1
			var cy: float = f.y1 - 10
			if sk == "execute":
				gfx.line(cx - R, cy - R, cx + R, cy + R, stroke, 5)
				gfx.line(cx + R, cy - R, cx - R, cy + R, stroke, 5)
			else:
				var pts2 := []
				for i in 8:
					var an := i * PI / 4
					var r2 := R * 0.45 if i % 2 else R
					pts2.append([cx + cos(an) * r2, cy + sin(an) * r2])
				poly(pts2, fill, stroke, 5)
	# 기술 이름(0.75초): 다른 이름과 겹치면 위로 비켜 쓰고, 그래도 겹치면 건너뜀
	var tw := gfx.text_w(f.name, 14) + 8
	var base: float = f.y0 - 76 - age * 16
	for k in 3:
		var ty := base - k * 18
		var r := Rect2(f.x0 - tw / 2, ty - 9, tw, 18)
		if labels.any(func(q): return q.intersects(r)):
			continue
		labels.append(r)
		var al := minf(1.0, (0.75 - age) / 0.25)
		gfx.text(f.name, f.x0 + 1.5, ty + 1.5, 14, Color(7 / 255.0, 19 / 255.0, 28 / 255.0, 0.95 * al), "center")
		gfx.text(f.name, f.x0, ty, 14, Color(1.0, 0.914, 0.659, al), "center")
		break
