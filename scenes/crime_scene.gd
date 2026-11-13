extends Control
## مسرح القضية (الوثيقة 6.4): تمسح بإصبعك ببطء فتظهر الأدلة المخفية داخل مخروط الضوء.
## المسح المتسرع يطمس الدليل. ثم تصوّر الدليل بالهاتف.
## Swipe slowly with a tool to reveal hidden evidence, then photograph it.

const PANEL_H := 360.0
const REACH := 190.0

var scene_def: Dictionary
var items: Array = []
var active_tool := ""
var finger := Vector2(540, 700)
var last_finger := Vector2(540, 700)
var touching := false
var speed := 0.0
var battery := 100.0
var shake := 0.0
var msg := ""
var msg_t := 0.0

var _tool_buttons := {}
var _status: Label
var _font: Font


func _ready() -> void:
	theme = UI.make_theme()
	layout_direction = Control.LAYOUT_DIRECTION_RTL if Loc.is_rtl() else Control.LAYOUT_DIRECTION_LTR
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = get_theme_default_font()

	var case_def := Game.load_case(Game.active_case)
	var sid := str(Game.case_state.get("current_scene", ""))
	for sc in case_def["scenes"]:
		if sc["id"] == sid:
			scene_def = sc
	battery = float(Game.case_state.get("battery", 100.0))
	var nerves := Game.nerves
	shake = 0.0 if nerves >= 50 else (50.0 - nerves) * 0.8

	for d in scene_def.get("items", []):
		items.append({"d": d, "p": 1.0 if d["needs"] == "none" else 0.0, "shot": Game.has_evidence(str(d["id"])), "told": false})

	_build_panel()
	_say(Loc.pick(scene_def.get("intro", "")), 5.0)


func _build_panel() -> void:
	var panel := PanelContainer.new()
	add_child(panel)
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -PANEL_H
	panel.offset_bottom = 0
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	_status = UI.label("", 26, UI.MUTED, true)
	v.add_child(_status)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	for t in Game.case_state["bag"]:
		var r: String = Game.TOOLS[t]["reveals"]
		if r == "":
			continue
		var b := UI.button(Loc.pick(Game.TOOLS[t]), func(): _select_tool(t), 84)
		b.add_theme_font_size_override("font_size", UI.fs(26))
		row.add_child(b)
		_tool_buttons[t] = b
	if _tool_buttons.size() > 0 and active_tool == "":
		_select_tool(_tool_buttons.keys()[0])

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	v.add_child(row2)
	row2.add_child(UI.button(Loc.t("photo"), _photo, 100))
	row2.add_child(UI.button(Loc.t("leave_scene"), _leave, 100))


func _select_tool(t: String) -> void:
	active_tool = t
	for k in _tool_buttons:
		_tool_buttons[k].disabled = (k == t)


func _leave() -> void:
	Game.case_state["battery"] = battery
	Game.save()
	Game.goto("case_hub")


func _say(m: String, t: float = 3.0) -> void:
	msg = m
	msg_t = t


func _item_pos(it: Dictionary) -> Vector2:
	return Vector2(float(it["d"]["x"]) * size.x, float(it["d"]["y"]) * (size.y - PANEL_H))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var inside: bool = event.position.y < size.y - PANEL_H
		touching = event.pressed and inside
		if inside:
			finger = event.position
			last_finger = finger
	elif event is InputEventScreenDrag:
		if touching:
			finger = event.position


func _tool_reveal() -> String:
	if active_tool == "" or battery <= 0.0:
		return ""
	return Game.TOOLS[active_tool]["reveals"]


func _process(delta: float) -> void:
	msg_t = maxf(0.0, msg_t - delta)
	speed = finger.distance_to(last_finger) / maxf(delta, 0.001)
	last_finger = finger
	var reveal := _tool_reveal()
	if touching and reveal != "":
		if active_tool in ["uv", "fingerprint"]:
			battery = maxf(0.0, battery - delta * 0.4)
		var eff := finger + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
		for it in items:
			if it["d"]["needs"] != reveal:
				continue
			if _item_pos(it).distance_to(eff) < REACH:
				if speed < 650.0:
					it["p"] = minf(1.0, it["p"] + delta * 0.7)
				elif speed > 1500.0:
					it["p"] = maxf(0.0, it["p"] - delta * 0.5)
					_say(Loc.t("scan_too_fast"), 1.0)
				if it["p"] >= 1.0 and not it["told"]:
					it["told"] = true
					_say(Loc.pick(it["d"]["label"]) + ": " + Loc.pick(it["d"]["desc"]), 5.0)
	_status.text = Loc.f("scene_status", [int(battery), Game.case_state["evidence"].size()])
	queue_redraw()


func _photo() -> void:
	if battery <= 0.0:
		_say(Loc.t("no_battery"))
		return
	var best = null
	var bd := 1.0e9
	for it in items:
		if it["p"] < 1.0 or it["shot"]:
			continue
		var d := _item_pos(it).distance_to(finger)
		if d < 280.0 and d < bd:
			bd = d
			best = it
	if best == null:
		_say(Loc.t("scene_nothing"))
		return
	var q := Game.phone_quality() * (1.0 - clampf(shake / 80.0, 0.0, 0.4)) * randf_range(0.85, 1.0)
	if Game.in_bag("gloves"):
		q += 0.1
	q = clampf(q, 0.1, 1.0)
	battery = maxf(0.0, battery - 3.0)
	best["shot"] = true
	var d: Dictionary = best["d"]
	Game.add_evidence({
		"id": str(d["id"]), "label": Loc.pick(d["label"]), "desc": Loc.pick(d["desc"]),
		"kind": str(d.get("kind", "real")), "quality": q, "src": "scene", "supports": d.get("supports", []),
	})
	if d.has("yasser"):
		Game.add_yasser(str(d["id"]), Loc.pick(d["yasser"]))
	if bool(d.get("illegal", false)):
		Game.case_state["illegal"] = int(Game.case_state["illegal"]) + 1
	var qk := "q_weak" if q < 0.5 else ("q_ok" if q < 0.8 else "q_great")
	_say(Loc.f("photo_taken", [Loc.t(qk)]), 3.0)


func _draw() -> void:
	var area := Rect2(Vector2.ZERO, Vector2(size.x, size.y - PANEL_H))
	draw_rect(Rect2(Vector2.ZERO, size), Color(scene_def.get("bg", "#0F0C1D")))
	# أرضية وجدران مبسطة
	for i in range(12):
		var y := area.size.y * (0.45 + 0.05 * i)
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.04), 2.0)
	draw_string(_font, Vector2(40, 70), Loc.pick(scene_def.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, size.x - 80, UI.fs(40), UI.GLOW)

	for it in items:
		var pos := _item_pos(it)
		var needs: String = it["d"]["needs"]
		if needs == "none":
			draw_arc(pos, 46.0, 0, TAU, 32, Color(UI.GLOW, 0.8), 4.0)
			draw_circle(pos, 18.0, Color(UI.GLOW, 0.5))
		elif it["p"] > 0.0:
			draw_circle(pos, 30.0, Color(UI.UV, it["p"]))
		if it["p"] >= 1.0:
			var col := UI.GOLD if it["shot"] else Color.WHITE
			draw_string(_font, pos + Vector2(-200, 80), Loc.pick(it["d"]["label"]), HORIZONTAL_ALIGNMENT_CENTER, 400, UI.fs(28), col)

	# مخروط الضوء
	var reveal := _tool_reveal()
	if reveal != "":
		var tc: Color = {"light": Color(1, 1, 0.8), "uv": UI.UV, "print": UI.GOLD, "detail": Color(0.6, 0.9, 1.0)}[reveal]
		for k in range(5):
			draw_circle(finger, REACH * (1.0 - 0.15 * k), Color(tc, 0.06))
		if touching:
			draw_arc(finger, REACH, 0, TAU, 48, Color(tc, 0.6), 3.0)

	if msg_t > 0.0 and msg != "":
		var box_r := Rect2(30, area.size.y - 230, size.x - 60, 200)
		draw_rect(box_r, Color(0, 0, 0, 0.72))
		draw_multiline_string(_font, box_r.position + Vector2(20, 50), msg, HORIZONTAL_ALIGNMENT_LEFT, box_r.size.x - 40, UI.fs(28), 4, Color.WHITE)
