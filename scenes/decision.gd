extends Control
## لحظة قرار سينمائية (الوثيقة 23) بنسخة 2D: شريطان أسودان، وجه السائل، خيارات رفيعة بدون
## أزرار مستطيلة، وحلقة عدّ تنازلي. السكوت خيار دائم، وهو ما يحدث عند انتهاء الوقت.
## وسم كل خيار: قانوني (سمعة الشرطة) / رمادي (سمعة الشارع) / غير قانوني (سرعة وأدلة لكن عقوبة).

const TIME := 10.0

var dec: Dictionary
var t := 0.0
var done := false
var ring: CountdownRing
var opts_box: VBoxContainer
var body: VBoxContainer


func _ready() -> void:
	theme = UI.make_theme()
	layout_direction = Control.LAYOUT_DIRECTION_RTL if Loc.is_rtl() else Control.LAYOUT_DIRECTION_LTR
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var case_def := Game.load_case(Game.active_case)
	var did := str(Game.case_state.get("current_decision", ""))
	for d in case_def.get("decisions", []):
		if d["id"] == did:
			dec = d
	if dec.is_empty():
		Game.goto("case_hub")
		return

	var bg := ColorRect.new()
	bg.color = Color("07060E")
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var top := ColorRect.new()
	top.color = Color.BLACK
	add_child(top)
	top.anchor_right = 1.0
	top.offset_bottom = 0
	var bottom := ColorRect.new()
	bottom.color = Color.BLACK
	add_child(bottom)
	bottom.anchor_right = 1.0
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_top = 0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(top, "offset_bottom", 150.0, 0.8)
	tw.tween_property(bottom, "offset_top", -150.0, 0.8)

	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 50)
	margin.add_theme_constant_override("margin_right", 50)
	margin.add_theme_constant_override("margin_top", 190)
	margin.add_theme_constant_override("margin_bottom", 190)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	margin.add_child(body)

	body.add_child(UI.label(Loc.pick(dec["speaker"]), 40, UI.GOLD, true))
	var face := FaceView.new()
	face.skin = Color(dec.get("skin", "#D9B79A"))
	face.anger = float(dec.get("anger", 20))
	face.tension = float(dec.get("anger", 20))
	face.custom_minimum_size = Vector2(0, 360)
	body.add_child(face)
	body.add_child(UI.label(Loc.pick(dec["prompt"]), 34, UI.TEXT, true))

	opts_box = VBoxContainer.new()
	opts_box.add_theme_constant_override("separation", 10)
	body.add_child(opts_box)
	var opts: Array = dec["options"].duplicate()
	opts.append({"id": "silence", "text": {"ar": "…أصمت", "en": "…stay silent"}, "tag": "none"})
	for i in range(opts.size()):
		var o: Dictionary = opts[i]
		var tag := str(o.get("tag", "legal"))
		var txt := Loc.pick(o["text"])
		if tag != "none":
			txt += "  [" + Loc.t("tag_" + tag) + "]"
		var b := Button.new()
		b.text = txt
		b.flat = true
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0, 92)
		b.add_theme_font_size_override("font_size", UI.fs(32))
		var col := {"legal": UI.GLOW, "grey": UI.GOLD, "illegal": UI.RED, "none": UI.MUTED}[tag] as Color
		b.add_theme_color_override("font_color", col)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		var need := str(o.get("requires_tool", ""))
		if need != "" and not Game.in_bag(need):
			b.disabled = true
			b.text += "  (" + Loc.t("needs_tool") + " " + Loc.pick(Game.TOOLS[need]) + ")"
		b.pressed.connect(func(): _choose(o))
		opts_box.add_child(b)
	ring = CountdownRing.new()
	body.add_child(ring)


func _process(delta: float) -> void:
	if done or dec.is_empty() or ring == null:
		return
	t += delta
	ring.progress = clampf(t / TIME, 0.0, 1.0)
	if t >= TIME:
		_choose({"id": "silence", "tag": "none", "text": {"ar": "…أصمت", "en": "…stay silent"}})


func _choose(o: Dictionary) -> void:
	if done:
		return
	done = true
	var tag := str(o.get("tag", "none"))
	match tag:
		"legal":
			Game.change_police_rep(3)
		"grey":
			Game.change_street_rep(3)
		"illegal":
			Game.case_state["illegal"] = int(Game.case_state.get("illegal", 0)) + 1
			Game.change_police_rep(-5)
	var eff: Dictionary = o.get("effects", {})
	if eff.has("money"):
		Game.add_money(int(eff["money"]))
	if eff.has("nerves"):
		Game.change_nerves(int(eff["nerves"]))
	if eff.has("hours"):
		Game.case_state["hours_left"] = maxi(0, int(Game.case_state["hours_left"]) + int(eff["hours"]))
	if eff.has("rep"):
		for k in eff["rep"]:
			Game.change_rep(str(k), int(eff["rep"][k]))
	if eff.has("evidence"):
		var e: Dictionary = eff["evidence"].duplicate()
		e["label"] = Loc.pick(e["label"])
		e["desc"] = Loc.pick(e["desc"])
		Game.add_evidence(e)
	Game.case_state["decided"].append(str(dec["id"]))
	Game.save()

	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	body.add_child(UI.label(Loc.pick(o.get("result", dec.get("silence_result", {"ar": "...", "en": "..."}))), 36, UI.TEXT, true))
	if tag != "none":
		body.add_child(UI.label(Loc.t("tag_" + tag), 28, UI.GOLD, true))
	body.add_child(UI.button(Loc.t("back"), func(): Game.goto("case_hub")))
