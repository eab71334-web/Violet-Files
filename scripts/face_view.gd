class_name FaceView
extends Control
## وجه ثنائي الأبعاد يعرض علامات التوتر: الرمش، تجنب النظر، العرق، الارتجاف.
## 2D face that shows tells: blinking, gaze avoidance, sweat, trembling.

var tension: float = 0.0      # التوتر الظاهر 0..100
var anger: float = 0.0        # الغضب 0..100
var fake_anger: bool = false  # تمثيل: الفم والحواجب غاضبة لكن العين ثابتة
var skin: Color = Color("D9B79A")
var hair: Color = Color("2A2233")
var masked: bool = false
var assist: bool = false      # مستوى مبتدئ: لمعة حول العين عند ظهور علامة (الوثيقة 19.4)

var _blink_left := 2.0
var _closed := 0.0
var _t := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(0, 420)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _process(delta: float) -> void:
	_t += delta
	_blink_left -= delta
	if _closed > 0.0:
		_closed -= delta
	if _blink_left <= 0.0:
		_closed = 0.14
		var v := tension
		if fake_anger:
			v = 15.0
		_blink_left = lerpf(4.0, 0.6, clampf(v / 100.0, 0.0, 1.0)) * randf_range(0.7, 1.3)
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.40
	# ارتجاف عند التوتر العالي
	if tension > 85.0 and not fake_anger:
		c += Vector2(sin(_t * 60.0), cos(_t * 53.0)) * 3.0

	# خلفية ضوء بنفسجي خفيف
	draw_circle(c, r * 1.35, Color(UI.UV, 0.10))
	# الرأس والشعر
	draw_circle(c, r, skin)
	draw_arc(c, r * 1.0, PI, TAU, 40, hair, r * 0.22)

	var eye_y := c.y - r * 0.12
	var ex := r * 0.38
	var eye_r := r * 0.16
	var gaze := 0.0
	if tension > 60.0 and not fake_anger:
		gaze = sin(_t * 1.7) * eye_r * 0.7   # تجنب النظر

	for sgn in [-1.0, 1.0]:
		var p := Vector2(c.x + sgn * ex, eye_y)
		if assist and tension >= 60.0 and not fake_anger:
			draw_arc(p, eye_r * 1.9, 0, TAU, 24, Color(UI.GLOW, 0.5 + 0.4 * sin(_t * 6.0)), 4.0)
		if masked:
			draw_rect(Rect2(p - Vector2(eye_r * 1.4, eye_r * 0.5), Vector2(eye_r * 2.8, eye_r)), Color.BLACK)
			continue
		if _closed > 0.0:
			draw_line(p - Vector2(eye_r, 0), p + Vector2(eye_r, 0), hair, 5.0)
		else:
			draw_circle(p, eye_r, Color("F4F1EA"))
			draw_circle(p + Vector2(gaze, 0), eye_r * 0.5, Color("1B1626"))
		# الحواجب: تميل للأسفل مع الغضب
		var tilt := clampf(anger / 100.0, 0.0, 1.0) * r * 0.16
		var inner := Vector2(p.x - sgn * eye_r * 0.2, p.y - eye_r * 1.6 + tilt)
		var outer := Vector2(p.x + sgn * eye_r * 1.3, p.y - eye_r * 1.6 - tilt * 0.3)
		draw_line(inner, outer, hair, 8.0)

	# الأنف
	draw_line(Vector2(c.x, c.y), Vector2(c.x - r * 0.06, c.y + r * 0.22), Color(0, 0, 0, 0.25), 4.0)

	# الفم: ينحني للأسفل مع الغضب ويتموج مع التوتر
	var my := c.y + r * 0.50
	var curve := -clampf(anger / 100.0, 0.0, 1.0) * r * 0.12 + r * 0.04
	var wob := 0.0
	if tension > 60.0 and not fake_anger:
		wob = sin(_t * 18.0) * 3.0
	var pts := PackedVector2Array()
	for i in range(0, 11):
		var u := float(i) / 10.0
		var x := c.x + lerpf(-r * 0.3, r * 0.3, u)
		var y := my + curve * (1.0 - pow(2.0 * u - 1.0, 2.0)) + wob * sin(u * PI)
		pts.append(Vector2(x, y))
	draw_polyline(pts, Color("5A2630"), 6.0)

	# عرق عند التوتر العالي
	if tension >= 70.0 and not fake_anger:
		for i in range(3):
			var ph := fmod(_t * 0.8 + float(i) * 0.33, 1.0)
			var sx := c.x + (float(i) - 1.0) * r * 0.35
			var sy := c.y - r * 0.62 + ph * r * 0.35
			draw_circle(Vector2(sx, sy), 7.0, Color(0.55, 0.8, 1.0, 1.0 - ph))
