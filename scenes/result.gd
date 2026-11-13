extends Screen
## نتيجة القضية (الوثيقة 21) + «ماذا فاتك» بدون عقاب (الوثيقة 19.5).


func _ready() -> void:
	setup(Loc.t("result_title"))
	var c := Game.load_case(Game.active_case)
	var r: Dictionary = Game.case_state.get("result", {})
	if r.is_empty():
		Game.goto("home")
		return

	var card := UI.card(box)
	card.add_child(UI.label(UI.stars(int(r["stars"])), 90, UI.GOLD, true))
	var verdict_key := "correct_verdict"
	if not r["correct"]:
		verdict_key = "partial_verdict" if r["partial"] else "wrong_verdict"
	card.add_child(UI.label(Loc.t(verdict_key), 40, UI.GLOW if r["correct"] else UI.RED, true))
	card.add_child(UI.label(Loc.f("score_fmt", [int(r["total"])]), 36, UI.TEXT, true))
	card.add_child(UI.label(Loc.f("score_detail", [int(r["evidence_score"]), int(r["verdict_score"]), int(r["style_score"]), int(r["time_score"])]), 26, UI.MUTED, true))
	card.add_child(UI.label(Loc.f("tier_fmt", [int(round(float(r["share"]) * 100.0))]), 28, UI.MUTED, true))
	card.add_child(UI.label(Loc.f("reward_fmt", [int(r["reward"])]), 44, UI.GOLD, true))

	var truth := UI.card(box)
	truth.add_child(UI.label(Loc.t("the_truth"), 36, UI.GLOW))
	truth.add_child(UI.label(Loc.pick(c["solution"]), 30))
	if c.has("twist"):
		truth.add_child(UI.label(Loc.pick(c["twist"]), 30, UI.GOLD))

	# ما فاتك: بدون عقاب إضافي
	var m: Dictionary = r.get("missed", {})
	var mc := UI.card(box)
	mc.add_child(UI.label(Loc.t("missed_title"), 36, UI.GLOW))
	mc.add_child(UI.label(Loc.f("note_accuracy", [int(m.get("note_accuracy", 100))]), 28, UI.MUTED))
	if m.get("items", []).is_empty() and m.get("lies_missed", []).is_empty() and m.get("false_flags", []).is_empty():
		mc.add_child(UI.label(Loc.t("missed_none"), 28, UI.GOLD))
	for it in m.get("items", []):
		mc.add_child(UI.label("• " + Loc.t("missed_item") + " " + Loc.pick(it), 28))
	for t in m.get("lies_missed", []):
		mc.add_child(UI.label("• " + Loc.t("missed_lie") + " " + str(t), 28, UI.RED))
	for t in m.get("false_flags", []):
		mc.add_child(UI.label("• " + Loc.t("missed_false") + " " + str(t), 28, UI.MUTED))

	if not r["correct"] and not r["partial"]:
		box.add_child(UI.label(Loc.t("wronged_warning"), 28, UI.RED))
	var yp = c.get("yasser_piece", null)
	if yp != null and Game.case_state["evidence"].any(func(e): return e["id"] == yp.get("evidence_id", "")):
		var y := UI.card(box)
		y.add_child(UI.label(Loc.t("yasser_piece"), 34, UI.GLOW))
		y.add_child(UI.label(Loc.pick(yp["text"]), 30))
	var rm := str(Game.case_state.get("rent_msg", ""))
	if rm != "":
		box.add_child(UI.label(Loc.t("sleep_" + rm), 28, UI.GOLD, true))
	box.add_child(UI.button(Loc.t("back_office"), _done))


func _done() -> void:
	Game.active_case = ""
	Game.case_state = {}
	Game.engines.clear()
	Game.save()
	Game.goto("home")
