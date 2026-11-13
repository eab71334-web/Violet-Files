extends Screen
## الأرشيف (الوثيقة 3): القضايا المحلولة، السمعة، وقطع لغز ياسر.


func _ready() -> void:
	setup(Loc.t("archive_title"))
	box.add_child(UI.label(Loc.t("solved_cases"), 38, UI.GLOW))
	for entry in Game.case_index():
		var id := str(entry["id"])
		var c := UI.card(box)
		var stars := ""
		if Game.completed.has(id):
			stars = "  " + UI.stars(int(Game.completed[id]))
		c.add_child(UI.label("%d. %s%s" % [int(entry["number"]), Loc.pick(entry["title"]), stars], 34, UI.GOLD if Game.completed.has(id) else UI.TEXT))
		c.add_child(UI.label(Loc.pick(Game.DISTRICTS[entry["district"]]), 24, UI.MUTED))
		if Game.completed.has(id) or not entry.get("playable", false):
			c.add_child(UI.label(Loc.pick(entry["summary"]), 28))
		if not entry.get("playable", false):
			c.add_child(UI.label(Loc.t("coming_soon"), 26, UI.MUTED))

	box.add_child(UI.label(Loc.t("reputation"), 38, UI.GLOW))
	var rc := UI.card(box)
	for k in Game.DISTRICTS:
		rc.add_child(UI.label("%s: %d" % [Loc.pick(Game.DISTRICTS[k]), int(Game.reputation[k])], 30))

	rc.add_child(UI.label("%s: %d" % [Loc.t("police_rep"), Game.police_rep], 30, UI.GLOW))
	rc.add_child(UI.label("%s: %d" % [Loc.t("street_rep"), Game.street_rep], 30, UI.GLOW))

	box.add_child(UI.label(Loc.t("yasser_board"), 38, UI.GLOW))
	var yc := UI.card(box)
	if Game.yasser_pieces.is_empty():
		yc.add_child(UI.label(Loc.t("yasser_empty"), 28, UI.MUTED))
	for p in Game.yasser_pieces:
		yc.add_child(UI.label("• " + str(p["text"]), 28))
	box.add_child(UI.button(Loc.t("back"), func(): Game.goto(Game.return_to), 90))
