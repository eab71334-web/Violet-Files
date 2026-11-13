extends SceneTree
## اختبارات المنطق بدون واجهة:
##   godot --headless --path . -s tests/run_tests.gd
## Headless logic tests. Exit code 0 = all passed.

const Neg := preload("res://scripts/negotiation_engine.gd")
const Inter := preload("res://scripts/interrogation_engine.gd")
const Score := preload("res://scripts/scoring.gd")
# أنواع الكشف التي تفتحها أدوات المتجر (انظر Game.TOOLS في autoload/game.gd)
const REVEAL_TYPES := ["light", "uv", "print", "detail"]

var failed := 0
var passed := 0


func check(cond: bool, name: String) -> void:
	if cond:
		passed += 1
		print("  PASS  ", name)
	else:
		failed += 1
		print("  FAIL  ", name)


func _json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text())


func _init() -> void:
	print("== Negotiation ==")
	var client := {"opening": 80, "patience": 3, "greed": 0.35, "max": 150, "honest_anger": true}
	var n = Neg.new(client)
	check(n.offer == 80, "opening offer is 80")
	check(n.reject() == "raise" and n.offer == 108, "first refusal raises to 108")
	check(n.reject() == "raise" and n.offer == 146, "second refusal raises to 146")
	n.reject()
	check(n.offer == 150 and n.at_cap(), "third refusal caps at max budget 150")
	check(n.reject() == "explode", "fourth refusal makes the client explode")
	var n2 = Neg.new(client)
	check(n2.accept() == 80, "accepting pays the current offer")
	var fake = Neg.new({"opening": 400, "patience": 2, "greed": 0.5, "max": 700, "honest_anger": false})
	fake.reject()
	check(fake.tell_key() == "tell_anger_fake", "acting client shows the fake-anger tell")

	print("== Interrogation ==")
	var nervous = Inter.new({"baseline": "nervous", "start_tension": 15, "start_trust": 40, "break_at": 70, "min_trust": 30, "weak_to": ["cam_c"]})
	check(nervous.visible_tension() >= 30.0, "nervous person looks tense even when calm (baseline)")
	var cold = Inter.new({"baseline": "cold", "start_tension": 60, "start_trust": 40})
	check(cold.visible_tension() < 60.0, "cold person hides real tension")

	var hq := {"id": "h", "cat": "hidden", "answer": "no", "lie": true, "truth": "yes", "reveals": "clue"}
	var w1 = Inter.new({"baseline": "normal", "start_tension": 15, "start_trust": 40, "break_at": 70, "min_trust": 30, "weak_to": ["cam_c"]})
	var r1: Dictionary = w1.ask(hq)
	check(r1["lie"] == true and r1["reveals"] == "", "hidden question without pressure gets the cover lie")
	var w2 = Inter.new({"baseline": "normal", "start_tension": 15, "start_trust": 40, "break_at": 70, "min_trust": 30, "weak_to": ["cam_c"]})
	w2.apply_tool("evidence", "cam_c")
	w2.apply_tool("lean")
	w2.apply_tool("silence")
	w2.apply_tool("silence")
	var r2: Dictionary = w2.ask(hq)
	check(r2["broke"] == true and r2["reveals"] == "clue", "pressure first, then hidden question breaks the liar")
	var w3 = Inter.new({"baseline": "normal", "start_tension": 15, "start_trust": 40, "break_at": 70, "min_trust": 30})
	var before: float = w3.tension
	w3.apply_tool("water")
	check(w3.tension < before + 1.0 and w3.trust > 40.0, "water calms and builds trust")
	var w4 = Inter.new({"baseline": "normal", "start_tension": 90, "start_trust": 5, "break_at": 70, "min_trust": 30})
	check(w4.ask(hq)["broke"] == false, "no trust means no confession even at high tension")

	print("== Scoring (GDD section 21) ==")
	var case_def := {"question": {"options": [{"id": "a", "correct": true}, {"id": "b", "correct": false}, {"id": "c", "correct": false, "partial": true}]}}
	var ev := []
	for i in range(4):
		ev.append({"id": "r%d" % i, "kind": "real", "quality": 0.9, "supports": ["a"]})
	ev.append({"id": "m1", "kind": "misleading", "quality": 0.9, "supports": ["b"]})
	var full := {"answer": "a", "price": 400, "illegal": 0, "evidence": ev, "support": ["r0", "r1", "r2", "r3"],
		"statements": [], "hours_left": 3, "nerves": 80}
	var rf: Dictionary = Score.evaluate(case_def, full)
	check(rf["total"] == 100.0 and rf["stars"] == 3 and rf["reward"] == 400, "perfect file = 100, 3 stars, full reward")
	var tainted := full.duplicate(true)
	tainted["support"] = ["r0", "r1", "r2", "m1"]
	check(Score.evaluate(case_def, tainted)["evidence_score"] == 20.0, "misleading evidence costs 10 and removes one good one")
	var wrong := full.duplicate(true)
	wrong["answer"] = "b"
	var rw: Dictionary = Score.evaluate(case_def, wrong)
	check(rw["total"] < 40.0 and rw["reward"] == 0 and rw["stars"] == 0, "innocent accused = failure, no reward")
	var part := full.duplicate(true)
	part["answer"] = "c"
	var rp: Dictionary = Score.evaluate(case_def, part)
	check(rp["verdict_score"] == 15.0, "partial truth earns 15 for the verdict")
	var shady := full.duplicate(true)
	shady["illegal"] = 2
	check(Score.evaluate(case_def, shady)["style_score"] == 5.0, "each illegal act costs 5 style points")
	var late := full.duplicate(true)
	late["hours_left"] = 0
	late["nerves"] = 10
	check(Score.evaluate(case_def, late)["time_score"] == 0.0, "missed deadline and broken nerves score 0 time")
	var mid := full.duplicate(true)
	mid["support"] = ["r0", "r1"]
	var rm: Dictionary = Score.evaluate(case_def, mid)
	check(rm["total"] == 80.0 and rm["stars"] == 2 and rm["reward"] == 280, "two good evidence = 80 points, 70% reward")

	print("== Data files ==")
	var index: Array = _json("res://data/cases/index.json")
	check(index.size() == 10, "season 1 catalog lists 10 cases")
	var shop: Dictionary = _json("res://data/shop.json")
	check(shop["tools"].size() >= 5 and shop["phones"].size() == 3, "shop.json lists tools and 3 phones")
	for entry in index:
		if not entry["playable"]:
			continue
		var c: Dictionary = _json("res://data/cases/%s.json" % entry["id"])
		var cid: String = entry["id"]
		var correct := 0
		var ids := {}
		for o in c["question"]["options"]:
			ids[o["id"]] = true
			if o["correct"]:
				correct += 1
		check(correct == 1, "%s has exactly one correct answer" % cid)
		var needs_ok := true
		var evid := {}
		var supports_ok := true
		for sc in c["scenes"]:
			for it in sc.get("items", []):
				evid[it["id"]] = true
				if it["needs"] != "none":
					needs_ok = needs_ok and (it["needs"] in REVEAL_TYPES)
				for s in it.get("supports", []):
					supports_ok = supports_ok and ids.has(s)
		check(needs_ok, "%s: every hidden item can be revealed by a shop tool" % cid)
		var clues_ok := true
		for w in c["witnesses"]:
			for q in w["questions"]:
				if q.has("reveals"):
					clues_ok = clues_ok and w["clues"].has(q["reveals"])
			for k in w["clues"]:
				for s in w["clues"][k].get("supports", []):
					supports_ok = supports_ok and ids.has(s)
		check(clues_ok, "%s: every revealed clue is defined" % cid)
		var tags_ok := true
		for d in c.get("decisions", []):
			for o in d["options"]:
				tags_ok = tags_ok and (o["tag"] in ["legal", "grey", "illegal"])
		check(tags_ok, "%s: decision options use legal/grey/illegal tags" % cid)
		check(supports_ok, "%s: every 'supports' points to a real answer id" % cid)

	print("\nPassed %d, failed %d" % [passed, failed])
	quit(1 if failed > 0 else 0)
