class_name CountdownRing
extends Control
## حلقة بنفسجية رفيعة تدور حول الخيارات (الوثيقة 23، الخطوة 7).

var progress: float = 0.0   # 0..1 الوقت المنقضي


func _ready() -> void:
	custom_minimum_size = Vector2(0, 120)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.4
	draw_arc(c, r, 0, TAU, 48, Color(UI.UV, 0.25), 4.0)
	draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - progress), 48, UI.GLOW, 8.0)
	# نبض يقترب مع مرور الوقت
	draw_circle(c, r * (0.15 + 0.2 * progress), Color(UI.GLOW, 0.2 + 0.4 * progress))
