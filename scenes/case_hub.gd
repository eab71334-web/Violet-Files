extends Screen
## مركز القضية: المواقع (بنزين + ساعات) والشهود ولوحة التحقيق.

var case_def: Dictionary


func _ready() -> void:
	setup("")
	case_def = Game.load_case(Game.active_case)
	_render()


func _hours() -> int:
	return int(Game.case_state["hours_left"])


func _render() -> void:
	clear_box()
	var st: Dictionary = Game.case_state
	var head := UI.card(box)
	head.add_child(UI.label(Loc.pick(case_def["title"]), 44, UI.GOLD, true))
	head.add_child(UI.label(Loc.f("hours_left", [_hours()]), 32, UI.GLOW if _hours() > 2 else UI.RED, true))
	head.add_child(UI.label(Loc.f("evidence_count", [st["evidence"].size()]), 28, UI.MUTED, true))

	box.add_child(UI.label(Loc.t("locations"), 38, UI.GLOW))
	for sc in case_def["scenes"]:
		_scene_button(sc)
	box.add_child(UI.label(Loc.t("witnesses"), 38, UI.GLOW))
	for w in case_def["witnesses"]:
		_witness_button(w)
	var shown_header := false
	for d in case_def.get("decisions", []):
		var show_it := true
		for req in d.get("requires", []):
			if not (req in st["scenes_done"] or req in st["witnesses_done"]):
				show_it = false
		var decided: bool = str(d["id"]) in st["decided"]
		if show_it or decided:
			if not shown_header:
				box.add_child(UI.label(Loc.t("decisions"), 38, UI.GLOW))
				shown_header = true
			var b := UI.button(("✔ " if decided else "") + Loc.t("decision_btn"), func(): _go_decision(d), 100)
			b.disabled = decided
			box.add_child(b)
	box.add_child(UI.button(Loc.t("to_board"), func(): Game.goto("board")))


func _scene_button(sc: Dictionary) -> void:
	var id := str(sc["id"])
	var done: bool = id in Game.case_state["scenes_done"]
	var locked := false
	for req in sc.get("requires", []):
		if not (req in Game.case_state["scenes_done"]):
			locked = true
	var is_hide := str(sc.get("type", "search")) == "hide"
	var hours := 0 if is_hide else Game.HOURS_PER_SCENE
	var label := Loc.pick(sc["title"])
	if not is_hide:
		label += "  (%s)" % Loc.f("cost_fmt", [hours, Game.CAR["fuel"]])
	var b := UI.button(("✔ " if done else "") + label, func(): _go_scene(sc), 100)
	b.disabled = locked or (_hours() < hours and not done) or (is_hide and done)
	box.add_child(b)


func _go_scene(sc: Dictionary) -> void:
	var id := str(sc["id"])
	var is_hide := str(sc.get("type", "search")) == "hide"
	var first_time: bool = not (id in Game.case_state["scenes_done"])
	if first_time and not is_hide:
		if not Game.spend(int(Game.CAR["fuel"])):
			toast(Loc.t("no_fuel"))
			return
		Game.case_state["hours_left"] = _hours() - Game.HOURS_PER_SCENE
		# حوادث الطريق: عطل يكلفك مالًا ووقتًا
		if randf() < 0.2:
			Game.spend(mini(20, Game.money))
			Game.case_state["hours_left"] = maxi(0, _hours() - 1)
			toast(Loc.t("road_breakdown"))
	Game.case_state["current_scene"] = id
	if first_time:
		Game.case_state["scenes_done"].append(id)
	Game.save()
	Game.goto("hide" if is_hide else "crime_scene")


func _go_decision(d: Dictionary) -> void:
	Game.case_state["current_decision"] = str(d["id"])
	Game.goto("decision")


func _witness_button(w: Dictionary) -> void:
	var id := str(w["id"])
	var done: bool = id in Game.case_state["witnesses_done"]
	var b := UI.button(("✔ " if done else "") + Loc.pick(w["name"]) + "  (%s)" % Loc.f("cost_fmt", [Game.HOURS_PER_SCENE, 0]), func(): _go_witness(w), 100)
	b.disabled = (_hours() < Game.HOURS_PER_SCENE and not done)
	box.add_child(b)


func _go_witness(w: Dictionary) -> void:
	var id := str(w["id"])
	if not (id in Game.case_state["witnesses_done"]):
		Game.case_state["hours_left"] = _hours() - Game.HOURS_PER_SCENE
		Game.case_state["witnesses_done"].append(id)
	Game.case_state["current_witness"] = id
	Game.save()
	Game.goto("interrogation")
