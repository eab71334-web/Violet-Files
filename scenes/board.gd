extends Screen
## لوحة التحقيق (الوثيقة 5.8): اختر الإجابة، اربط حتى 3 أدلة، واطبع الملف للشرطة.
## Evidence board: choose the answer, attach up to 3 pieces of evidence, hand the file over.

const MAX_SUPPORT := 4

var case_def: Dictionary
var answer_buttons := {}
var support_boxes := {}


func _ready() -> void:
	setup(Loc.t("board_title"))
	case_def = Game.load_case(Game.active_case)
	var st: Dictionary = Game.case_state

	box.add_child(UI.label(Loc.pick(case_def["question"]["text"]), 40, UI.GOLD, true))

	box.add_child(UI.label(Loc.t("your_answer"), 36, UI.GLOW))
	for o in case_def["question"]["options"]:
		var b := Button.new()
		b.text = Loc.pick(o["text"])
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 100)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.button_pressed = (str(st["answer"]) == str(o["id"]))
		b.pressed.connect(func(): _pick_answer(str(o["id"])))
		box.add_child(b)
		answer_buttons[str(o["id"])] = b

	box.add_child(UI.label(Loc.f("support_title", [MAX_SUPPORT]), 36, UI.GLOW))
	if st["evidence"].is_empty():
		box.add_child(UI.label(Loc.t("no_evidence_yet"), 30, UI.MUTED))
	for e in st["evidence"]:
		var cb := CheckBox.new()
		var qk := "q_weak" if float(e["quality"]) < 0.5 else ("q_ok" if float(e["quality"]) < 0.8 else "q_great")
		cb.text = "%s — %s\n%s" % [e["label"], Loc.t(qk), e["desc"]]
		cb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cb.add_theme_font_size_override("font_size", UI.fs(28))
		cb.button_pressed = str(e["id"]) in st["support"]
		var eid := str(e["id"])
		cb.toggled.connect(func(on: bool): _toggle_support(eid, on, cb))
		box.add_child(cb)
		support_boxes[eid] = cb

	var flagged := 0
	for s in st["statements"]:
		if s["flagged"]:
			flagged += 1
	box.add_child(UI.label(Loc.f("flagged_info", [flagged, st["statements"].size()]), 28, UI.MUTED))
	box.add_child(UI.button(Loc.t("submit_police"), _submit))
	box.add_child(UI.button(Loc.t("back"), func(): Game.goto("case_hub"), 90))


func _pick_answer(id: String) -> void:
	Game.case_state["answer"] = id
	for k in answer_buttons:
		answer_buttons[k].button_pressed = (k == id)


func _toggle_support(id: String, on: bool, cb: CheckBox) -> void:
	var sup: Array = Game.case_state["support"]
	if on:
		if sup.size() >= MAX_SUPPORT:
			cb.set_pressed_no_signal(false)
			toast(Loc.t("support_full"))
			return
		if not (id in sup):
			sup.append(id)
	else:
		sup.erase(id)


func _submit() -> void:
	if str(Game.case_state["answer"]) == "":
		toast(Loc.t("pick_answer_first"))
		return
	Game.case_state["nerves"] = Game.nerves
	var result := Scoring.evaluate(case_def, Game.case_state)
	result["missed"] = Scoring.missed(case_def, Game.case_state)
	Game.case_state["result"] = result
	Game.finish_case(result)
	Game.goto("result")
