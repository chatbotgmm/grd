# 그리기 도구: 웹 판 defense.js의 box·text·fitText·button·chip·drawFit을 고도로 옮긴 것.
# 좌표는 웹 판과 같은 논리 좌표(가로 배치 1312×960)로 받아 화면 좌표로 바꿔 그린다(글자를 실제 픽셀 크기로 그려 흐리지 않게).
# 누르기 영역(hit)도 그릴 때 함께 등록 — 웹 판처럼 매 프레임 새로 만든다.
extends RefCounted

const C := {
	"bg": Color("#07131c"), "panel": Color(16 / 255.0, 36 / 255.0, 51 / 255.0, 0.95), "header": Color("#132c3b"), "text": Color("#f5ead0"), "muted": Color("#b0bec4"),
	"gold": Color("#d9bb7f"), "goldEdge": Color("#f3d89e"), "edge": Color("#917a4c"), "line": Color("#5b675d"), "ink": Color("#192e39"), "bad": Color("#ff9a8a"), "good": Color("#9fe3a8"),
	"lane": Color(214 / 255.0, 190 / 255.0, 140 / 255.0, 0.22), "laneEdge": Color(243 / 255.0, 216 / 255.0, 158 / 255.0, 0.35), "phys": Color("#ffb36b"), "mag": Color("#8fc8ff"),
}
const GRADE_COLOR := {"COMMON": Color("#9aa5ad"), "UNCOMMON": Color("#62c370"), "RARE": Color("#4d9de0"), "EPIC": Color("#a77be8"), "LEGEND": Color("#f0a03c"),
	"HIDDEN": Color("#3fd0c0"), "LIMITED": Color("#ef5a5a"), "TRANSCEND": Color("#ff8fc7"), "IMMORTAL": Color("#f3d36b"), "ETERNAL": Color("#ffffff")}
const ART := "res://assets/art/"

var ci: CanvasItem
var font: Font
# 지금 변환(논리 → 화면): 화면 = 논리 × s + (ox, oy)
var ox := 0.0
var oy := 0.0
var s := 1.0
var _stack := []
var hits := []
var _tex := {}
var _styles := {}


func _init(canvas: CanvasItem, f: Font) -> void:
	ci = canvas
	font = f


func push(tx: float, ty: float, sc: float = 1.0) -> void:   # 논리 (tx, ty)로 옮기고 sc배(웹 판 ctx.translate+scale)
	_stack.append([ox, oy, s])
	ox += tx * s
	oy += ty * s
	s *= sc


func pop() -> void:
	var t = _stack.pop_back()
	ox = t[0]
	oy = t[1]
	s = t[2]


func P(x: float, y: float) -> Vector2:
	return Vector2(x * s + ox, y * s + oy)


func R(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(P(x, y), Vector2(w * s, h * s))


func to_logical(p: Vector2) -> Vector2:
	return Vector2((p.x - ox) / s, (p.y - oy) / s)


func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		var full := ART + path
		_tex[path] = load(full) if ResourceLoader.exists(full) else null
	return _tex[path]


func unit_tex(id: String) -> Texture2D:
	return tex("units/%s-front.webp" % id)


func enemy_tex(look: String) -> Texture2D:   # e:v1 → enemies/v1, b:u01 → black/u01
	var parts := look.split(":")
	if parts.size() != 2:
		return null
	return tex("%s/%s.webp" % ["enemies" if parts[0] == "e" else "black", parts[1]])


func _style(fill: Color, stroke, r: float, lw: float) -> StyleBoxFlat:
	var key := "%s|%s|%d|%.2f" % [fill.to_html(), str(stroke.to_html()) if stroke != null else "-", int(r * s), lw]
	if not _styles.has(key):
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill
		sb.set_corner_radius_all(int(r * s))
		sb.anti_aliasing = true
		if stroke != null:
			sb.border_color = stroke
			sb.set_border_width_all(maxi(1, int(roundf(lw))))
		_styles[key] = sb
		if _styles.size() > 600:
			_styles.clear()
	return _styles[key]


func box(x: float, y: float, w: float, h: float, fill, stroke = null, r: float = 8.0, lw: float = 1.5) -> void:
	if w <= 0 or h <= 0:
		return
	var f: Color = fill if fill != null else Color(0, 0, 0, 0)
	ci.draw_style_box(_style(f, stroke, r, lw), R(x, y, w, h))


func rect(x: float, y: float, w: float, h: float, col: Color) -> void:
	ci.draw_rect(R(x, y, w, h), col)


func circle(x: float, y: float, r: float, col: Color) -> void:
	ci.draw_circle(P(x, y), r * s, col)


func ring(x: float, y: float, r: float, col: Color, lw: float = 1.5) -> void:
	ci.draw_arc(P(x, y), r * s, 0, TAU, 48, col, maxf(1.0, lw * s), true)


func ellipse(x: float, y: float, rx: float, ry: float, fill, stroke = null, lw: float = 1.5) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		pts.append(P(x + cos(a) * rx, y + sin(a) * ry))
	if fill != null:
		ci.draw_colored_polygon(pts, fill)
	if stroke != null:
		ci.draw_polyline(pts, stroke, maxf(1.0, lw * s), true)


func line(x0: float, y0: float, x1: float, y1: float, col: Color, lw: float = 1.5) -> void:
	ci.draw_line(P(x0, y0), P(x1, y1), col, maxf(1.0, lw * s), true)


func text_w(t: String, size: float) -> float:   # 논리 좌표 너비
	var px := maxi(1, int(roundf(size * s)))
	return font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x / s


# align: "left"·"center"·"right", base: "middle"·"top" (웹 판 textBaseline)
func text(t: String, x: float, y: float, size: float = 18.0, col: Color = C.text, align: String = "left", base: String = "middle") -> void:
	var px := maxi(1, int(roundf(size * s)))
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var p := P(x, y)
	if align == "center":
		p.x -= w / 2.0
	elif align == "right":
		p.x -= w
	var asc := font.get_ascent(px)
	var desc := font.get_descent(px)
	p.y += asc if base == "top" else (asc - desc) / 2.0
	ci.draw_string(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func fit_text(t: String, x: float, y: float, max_w: float, size: float = 18.0, col: Color = C.text, align: String = "left", min_size: float = 11.0) -> void:
	var sz := size
	while sz > min_size and text_w(t, sz) > max_w:
		sz -= 1
	if text_w(t, sz) > max_w:   # 가장 작게 해도 넘치면 뒤를 「…」로(칸 밖으로 나가지 않게)
		while t.length() > 1 and text_w(t + "…", sz) > max_w:
			t = t.substr(0, t.length() - 1)
		t += "…"
	text(t, x, y, sz, col, align)


func wrap(t: String, x: float, y: float, max_w: float, size: float = 15.0, col: Color = C.muted, line_h: float = -1.0) -> float:
	var lh := size * 1.45 if line_h < 0 else line_h
	var cur := ""
	var yy := y
	for word in t.split(" "):
		var tt: String = word if cur == "" else cur + " " + word
		if text_w(tt, size) > max_w and cur != "":
			text(cur, x, yy, size, col, "left", "top")
			cur = word
			yy += lh
		else:
			cur = tt
	if cur != "":
		text(cur, x, yy, size, col, "left", "top")
		yy += lh
	return yy - y


func draw_fit(t: Texture2D, x: float, y: float, w: float, h: float, alpha: float = 1.0) -> void:   # 칸 안에 비율 유지, 아래 가운데 맞춤
	if t == null:
		return
	var iw := float(t.get_width())
	var ih := float(t.get_height())
	if iw <= 0:
		return
	var sc := minf(w / iw, h / ih)
	var dw := iw * sc
	var dh := ih * sc
	ci.draw_texture_rect(t, R(x + (w - dw) / 2.0, y + h - dh, dw, dh), false, Color(1, 1, 1, alpha))


func hit(x: float, y: float, w: float, h: float, fn: Callable) -> void:
	hits.append({"r": R(x, y, w, h), "fn": fn})


func hit_at(p: Vector2):
	for k in range(hits.size() - 1, -1, -1):
		if hits[k].r.has_point(p):
			return hits[k]
	return null


const BTN := {
	"primary": [Color("#e3c27f"), Color("#fff3cf"), "ink"],
	"normal": [Color("#163447"), Color("#d9bb7f"), "text"],
	"quiet": [Color(11 / 255.0, 30 / 255.0, 42 / 255.0, 0.6), Color("#5b675d"), "muted"],
	"danger": [Color("#5a2418"), Color("#b4482a"), "danger"],
}


func button(x: float, y: float, w: float, h: float, label: String, fn: Callable, style: String = "normal", enabled: bool = true, sub: String = "", sub_col = null) -> void:
	var st: Array = BTN[style]
	if enabled:
		box(x, y, w, h, st[0], st[1], 10, 2.0 if style == "primary" else 1.5)
	else:
		box(x, y, w, h, Color("#1b2a33"), Color("#33434d"), 10, 1.5)
	var col: Color = Color("#6f7f88")
	if enabled:
		col = Color("#ffd9cf") if st[2] == "danger" else C[st[2]]
	var sc: Color = Color("#5b6a73")
	if enabled:
		sc = sub_col if sub_col != null else (Color("#3d2f1a") if style == "primary" else C.muted)
	if sub != "" and h < 48:
		fit_text(label, x + w * 0.3, y + h / 2.0, w * 0.5, 16, col, "center")
		fit_text(sub, x + w * 0.72, y + h / 2.0, w * 0.48, 13, sc, "center")
	elif sub != "":
		fit_text(label, x + w / 2.0, y + h / 2.0 - 10, w - 12, 17, col, "center")
		fit_text(sub, x + w / 2.0, y + h / 2.0 + 12, w - 12, 14, sc, "center")
	else:
		fit_text(label, x + w / 2.0, y + h / 2.0, w - 12, 17, col, "center")
	if enabled:
		hit(x, y, w, h, fn)


func chip(t: String, x: float, y: float, col: Color, size: float = 14.0) -> float:
	var w := text_w(t, size) + 14
	box(x, y, w, size + 8, Color(0, 0, 0, 0.35), col, 6, 1.5)
	text(t, x + w / 2.0, y + (size + 8) / 2.0 + 0.5, size, col, "center")
	return w
