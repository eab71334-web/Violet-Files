extends Screen
## التحقيق مع الشاهد (الوثيقة 6.2): اقرأ الوجه، اسأل، اضغط أو هدّئ، ثم علّم ما تظنه كذبًا.

var w: Dictionary
var eng: InterrogationEngine
var face: FaceView
var tell_label: Label
var trust_label: Label
var q_box: VBoxContainer
var tool_box: GridContainer
var log_box: VBoxContainer
var ev_box: VBoxContainer


func _ready() -> void:
	setup("")
	var case_def := Game.load_case(Game.active_case)
	var wid := str(Game.case_state.get("current_witness", ""))
	for x in case_def["witnesses"]:
		if x["id"] == wid:
			w = x
	if not Game.engines.has(wid):
		var ne := InterrogationEngine.new(w)
		if str(Game.case_state.get("difficulty", "detective")) == "expert":
			ne.break_at += 5.0   # خبير: علامات أخفى وانهيار أصعب
		Game.engines[wid] = ne
	eng = Game.engines[wid]

	box.add_child(UI.label(Loc.pick(w["name"]), 44, UI.GOLD, true))
	face = FaceView.new()
	face.skin = Color(w.get("skin", "#D9B79A"))
	face.masked = bool(w.get("masked", false))
	face.assist = str(Game.case_state.get("difficulty", "detective")) == "beginner"
	box.add_child(face)
	tell_label = UI.label("", 30, UI.TEXT, true)
	box.add_child(tell_label)
	trust_label = UI.label("", 26, UI.MUTED, true)
	box.add_child(trust_label)

	box.add_child(UI.label(Loc.t("questions"), 36, UI.GLOW))
	q_box = VBoxContainer.new()
	q_box.add_theme_constant_override("separation", 12)
	box.add_child(q_box)

	box.add_child(UI.label(Loc.t("pressure_tools"), 36, UI.GLOW))
	tool_box = GridContainer.new()
	tool_box.columns = 2
	tool_box.add_theme_constant_override("h_separation", 12)
	tool_box.add_theme_constant_override("v_separation", 12)
	box.add_child(tool_box)
	ev_box = VBoxContainer.new()
	ev_box.add_theme_constant_override("separation", 10)
	box.add_child(ev_box)

	box.add_child(UI.label(Loc.t("transcript"), 36, UI.GLOW))
	box.add_child(UI.label(Loc.t("transcript_hint"), 26, UI.MUTED))
	log_box = VBoxContainer.new()
	log_box.add_theme_constant_override("separation", 10)
	box.add_child(log_box)

	box.add_child(UI.button(Loc.t("leave_witness"), func(): Game.goto("case_hub")))
	_rebuild()
	_rebuild_log()
	if w.has("intro"):
		toast(Loc.pick(w["intro"]))


func _rebuild() -> void:
	face.tension = eng.visible_tension()
	tell_label.text = Loc.t(eng.tell_key())
	trust_label.text = Loc.t(eng.trust_hint_key())

	for c in q_box.get_children():
		q_box.remove_child(c)
		c.queue_free()
	for q in w["questions"]:
		var done: bool = eng.asked.has(q["id"])
		var b := UI.button(Loc.pick(q["text"]), func(): _ask(q), 90)
		b.disabled = done
		q_box.add_child(b)

	for c in tool_box.get_children():
		tool_box.remove_child(c)
		c.queue_free()
	var tools := ["lean", "silence", "kindness", "water", "away", "subject"]
	for t in tools:
		var b := UI.button(Loc.t("tool_" + t), func(): _tool(t), 90)
		b.add_theme_font_size_override("font_size", UI.fs(28))
		tool_box.add_child(b)
	var ev_btn := UI.button(Loc.t("tool_evidence"), _show_evidence_list, 90)
	ev_btn.add_theme_font_size_override("font_size", UI.fs(28))
	tool_box.add_child(ev_btn)
	var rec := UI.button(Loc.t("tool_recording"), func(): _tool("recording"), 90)
	rec.add_theme_font_size_override("font_size", UI.fs(28))
	rec.disabled = not Game.in_bag("recorder")
	tool_box.add_child(rec)


func _ask(q: Dictionary) -> void:
	var r := eng.ask(q)
	Game.case_state["statements"].append({
		"w": w["id"], "q": q["id"], "who": Loc.pick(w["name"]),
		"text": Loc.pick(r["text"]), "lie": bool(r["lie"]), "flagged": false,
	})
	if str(r["reveals"]) != "":
		var clue: Dictionary = w["clues"][r["reveals"]]
		Game.add_evidence({
			"id": str(r["reveals"]), "label": Loc.pick(clue["label"]), "desc": Loc.pick(clue["desc"]),
			"kind": "real", "quality": 0.9, "src": "witness", "supports": clue.get("supports", []),
		})
		toast(Loc.t("new_clue"))
	Game.save()
	_rebuild()
	_rebuild_log()


func _tool(t: String) -> void:
	var key := eng.apply_tool(t)
	toast(Loc.t(key + "_msg"))
	_rebuild()


func _show_evidence_list() -> void:
	for c in ev_box.get_children():
		ev_box.remove_child(c)
		c.queue_free()
	var list: Array = Game.case_state["evidence"]
	if list.is_empty():
		ev_box.add_child(UI.label(Loc.t("no_evidence_yet"), 28, UI.MUTED))
		return
	for e in list:
		ev_box.add_child(UI.button(str(e["label"]), func(): _present(e), 80))


func _present(e: Dictionary) -> void:
	var key := eng.apply_tool("evidence", str(e["id"]))
	toast(Loc.t(key + "_msg"))
	for c in ev_box.get_children():
		ev_box.remove_child(c)
		c.queue_free()
	_rebuild()


func _rebuild_log() -> void:
	for c in log_box.get_children():
		log_box.remove_child(c)
		c.queue_free()
	var idx := 0
	for s in Game.case_state["statements"]:
		if s["w"] == w["id"]:
			var cb := CheckBox.new()
			cb.text = str(s["text"])
			cb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cb.add_theme_font_size_override("font_size", UI.fs(28))
			cb.button_pressed = bool(s["flagged"])
			var i := idx
			cb.toggled.connect(func(on: bool): Game.case_state["statements"][i]["flagged"] = on)
			log_box.add_child(cb)
		idx += 1
